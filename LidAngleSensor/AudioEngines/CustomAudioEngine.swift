//
//  CustomAudioEngine.swift
//  LidAngleSensor
//
//  Created by Sam on 2026-03-22.
//

import AVFoundation

@Observable
final class CustomAudioEngine: AudioEngineProtocol {

    // MARK: Published State

    private(set) var isRunning = false
    private(set) var gain: Double = 0
    private(set) var rate: Double = 1.0
    /// Downsampled amplitude envelope for the waveform display (~500 samples).
    private(set) var waveformSamples: [Float] = []
    /// File duration in seconds.
    private(set) var duration: Double = 0
    /// Display name derived from the loaded file.
    private(set) var filename: String = ""

    // MARK: Range Points (0…1 normalized)

    /// Start of the attack section.
    var inPoint: Double = 0
    /// End of the attack / start of the loop.
    var loopStart: Double = 0.25
    /// End of the loop / start of the release.
    var loopEnd: Double = 0.75
    /// End of the release section.
    var outPoint: Double = 1

    var playbackMode: CustomEngineMode = .continuous

    var isFileLoaded: Bool { loopBuffer != nil }

    // MARK: Audio Graph

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let varispeed = AVAudioUnitVarispeed()
    private var fullBuffer: AVAudioPCMBuffer?
    /// `inPoint`→`loopStart`: plays once when motion begins.
    private var attackBuffer: AVAudioPCMBuffer?
    /// `loopStart`→`loopEnd`: repeats while moving. Also used for continuous mode.
    private var loopBuffer: AVAudioPCMBuffer?
    /// `loopEnd`→`outPoint`: plays once when motion stops.
    private var releaseBuffer: AVAudioPCMBuffer?
    private var isGraphConnected = false

    // MARK: Motion State Machine

    private enum MotionState { case idle, attacking, looping, releasing }
    private var motionState: MotionState = .idle

    // MARK: Ramping State

    private var targetGain: Double = 0
    private var targetRate: Double = 1.0
    private var lastRampTime: TimeInterval = 0

    // MARK: Constants

    private static let gainRampMs = 50.0
    private static let rateRampMs = 80.0

    // Continuous mode
    private static let continuousMinRate = 0.5
    private static let continuousMaxRate = 2.0
    private static let minAngle = 0.0
    private static let maxAngle = 135.0
    private static let baseVolume = 0.8
    private static let velocityVolumeBoost = 0.2
    private static let continuousVelocityQuiet = 80.0

    // Motion-only mode
    //
    // Two separate thresholds prevent velocity noise from toggling state rapidly:
    // motion must clearly start (> startThreshold) before the engine engages,
    // and must clearly stop (< stopThreshold) before it disengages. The gap
    // between them acts as a dead-band that absorbs sensor jitter.
    private static let startThreshold = 5.0   // deg/s — must exceed to enter motion
    private static let stopThreshold  = 1.0   // deg/s — must fall below to exit motion
    private static let velocityFull = 10.0
    private static let motionVelocityQuiet = 100.0
    private static let motionMinRate = 0.80
    private static let motionMaxRate = 1.10
    private static let releaseVolume = 0.85

    nonisolated private static let waveformSampleCount = 500

    // MARK: Lifecycle

    init() {
        engine.attach(playerNode)
        engine.attach(varispeed)
    }

    deinit {
        // AVAudioEngine and its nodes clean up their resources on dealloc.
    }

    // MARK: AudioEngineProtocol

    func start() {
        guard !isRunning, let buffer = loopBuffer else { return }
        try? engine.start()

        switch playbackMode {
        case .continuous:
            playerNode.scheduleBuffer(buffer, at: nil, options: .loops)
            playerNode.play()
            playerNode.volume = 0
        case .motionOnly:
            // Start silent; the first update() call begins playback when velocity > threshold.
            motionState = .idle
        }
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        playerNode.stop()
        engine.stop()
        motionState = .idle
        isRunning = false
    }

    // MARK: File Loading

    func loadFile(from url: URL) {
        let wasRunning = isRunning
        if isRunning { stop() }

        waveformSamples = []
        duration = 0
        filename = ""
        fullBuffer = nil
        attackBuffer = nil
        loopBuffer = nil
        releaseBuffer = nil

        Task {
            guard let result = await Self.readFile(at: url) else { return }
            fullBuffer = result.buffer
            duration = result.duration
            waveformSamples = result.samples
            filename = url.deletingPathExtension().lastPathComponent
            setupGraph(format: result.format)
            rebuildBuffers()
            if wasRunning { start() }
        }
    }

    /// Reads and downsamples the audio file. Runs on the cooperative thread pool
    /// (nonisolated), keeping the main actor free during I/O.
    private nonisolated static func readFile(
        at url: URL
    ) async -> (buffer: AVAudioPCMBuffer, format: AVAudioFormat, samples: [Float], duration: Double)? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        do { try file.read(into: buffer) } catch { return nil }
        let samples = downsample(buffer: buffer, targetCount: waveformSampleCount)
        let duration = Double(frameCount) / format.sampleRate
        return (buffer, format, samples, duration)
    }

    private nonisolated static func downsample(buffer: AVAudioPCMBuffer, targetCount: Int) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameCount > 0, channelCount > 0 else { return [] }

        let strideSize = max(1, frameCount / targetCount)
        let actualCount = min(targetCount, frameCount)
        var result = [Float](repeating: 0, count: actualCount)

        for i in 0..<actualCount {
            let start = i * strideSize
            let end = min(start + strideSize, frameCount)
            var peak: Float = 0
            for frame in start..<end {
                for ch in 0..<channelCount {
                    peak = Swift.max(peak, abs(channelData[ch][frame]))
                }
            }
            result[i] = peak
        }
        return result
    }

    private func setupGraph(format: AVAudioFormat) {
        if isGraphConnected {
            engine.disconnectNodeOutput(playerNode)
            engine.disconnectNodeOutput(varispeed)
        }
        engine.connect(playerNode, to: varispeed, format: format)
        engine.connect(varispeed, to: engine.mainMixerNode, format: format)
        isGraphConnected = true
    }

    // MARK: Range Control

    /// Rebuilds attack, loop, and release buffers from the current four range points
    /// and reschedules playback if the engine is running.
    func rebuildBuffers() {
        guard let full = fullBuffer else { return }

        let totalFrames = Int(full.frameLength)

        // Compute frame indices and enforce strict ordering with minimum 1-frame gaps.
        let rawIn        = frameIndex(totalFrames, normalized: inPoint)
        let rawLoopStart = frameIndex(totalFrames, normalized: loopStart)
        let rawLoopEnd   = frameIndex(totalFrames, normalized: loopEnd)
        let rawOut       = frameIndex(totalFrames, normalized: outPoint)

        let safeIn        = rawIn
        let safeOut       = max(safeIn + 3, rawOut)
        let safeLoopEnd   = max(safeIn + 2, min(rawLoopEnd, safeOut - 1))
        let safeLoopStart = max(safeIn + 1, min(rawLoopStart, safeLoopEnd - 1))

        attackBuffer  = sliceBuffer(full, from: safeIn,        to: safeLoopStart)
        loopBuffer    = sliceBuffer(full, from: safeLoopStart, to: safeLoopEnd)
        releaseBuffer = sliceBuffer(full, from: safeLoopEnd,   to: safeOut)

        if isRunning {
            stop()
            start()
        }
    }

    private func frameIndex(_ total: Int, normalized value: Double) -> Int {
        Int((Double(total) * max(0, min(1, value))).rounded())
    }

    private func sliceBuffer(_ source: AVAudioPCMBuffer, from start: Int, to end: Int) -> AVAudioPCMBuffer? {
        let count = AVAudioFrameCount(max(1, end - start))
        guard let dest = AVAudioPCMBuffer(pcmFormat: source.format, frameCapacity: count) else { return nil }
        let channelCount = Int(source.format.channelCount)
        for ch in 0..<channelCount {
            guard let src = source.floatChannelData?[ch],
                  let dst = dest.floatChannelData?[ch] else { continue }
            memcpy(dst, src.advanced(by: start), Int(count) * MemoryLayout<Float>.size)
        }
        dest.frameLength = count
        return dest
    }

    // MARK: Motion Playback Transitions

    /// Plays the attack once, then the loop repeats seamlessly via pre-scheduling.
    /// If there is no meaningful attack section, jumps directly to the loop.
    private func startAttack() {
        guard let attack = attackBuffer, attack.frameLength > 1,
              let loop = loopBuffer else {
            startLoop()
            return
        }

        motionState = .attacking
        playerNode.stop()

        // Pre-schedule the loop so it follows the attack with no gap.
        // The completion handler only updates the state flag — no buffer operations.
        playerNode.scheduleBuffer(
            attack, at: nil, options: [],
            completionCallbackType: .dataConsumed
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.motionState == .attacking else { return }
                self.motionState = .looping
            }
        }
        playerNode.scheduleBuffer(loop, at: nil, options: .loops)
        playerNode.play()
    }

    /// Cancels any pending buffers and starts looping immediately.
    private func startLoop() {
        guard let buffer = loopBuffer else { return }
        motionState = .looping
        playerNode.stop()
        playerNode.scheduleBuffer(buffer, at: nil, options: .loops)
        playerNode.play()
    }

    /// Cancels any pending buffers and plays the release once.
    private func startRelease() {
        motionState = .releasing
        playerNode.stop()

        guard let buffer = releaseBuffer, buffer.frameLength > 1 else {
            motionState = .idle
            return
        }

        playerNode.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.motionState == .releasing else { return }
                self.motionState = .idle
            }
        }
        playerNode.play()
    }

    // MARK: Parameter Update

    func update(angle: Double, velocity: Double) {
        switch playbackMode {
        case .continuous: updateContinuous(angle: angle, velocity: velocity)
        case .motionOnly: updateMotionOnly(velocity: velocity)
        }
    }

    private func updateContinuous(angle: Double, velocity: Double) {
        // Rate: angle 0°→135° maps to 0.5×→2.0× (one octave down to one octave up).
        let normalizedAngle = min(1, max(0, (angle - Self.minAngle) / (Self.maxAngle - Self.minAngle)))
        targetRate = Self.continuousMinRate + normalizedAngle * (Self.continuousMaxRate - Self.continuousMinRate)

        // Volume: base level with a small boost when the lid is still.
        let t = min(1, max(0, velocity / Self.continuousVelocityQuiet))
        let s = t * t * (3 - 2 * t) // smoothstep
        targetGain = min(1, Self.baseVolume + (1 - s) * Self.velocityVolumeBoost)

        ramp()
    }

    private func updateMotionOnly(velocity: Double) {
        let speed = abs(velocity)

        switch motionState {
        case .idle:
            // Require a clear movement signal before engaging.
            if speed > Self.startThreshold {
                startAttack()
                let (g, r) = motionParameters(for: speed)
                targetGain = g; targetRate = r
            } else {
                targetGain = 0; targetRate = Self.motionMinRate
            }

        case .attacking, .looping:
            // Require a clear stop before disengaging.
            if speed > Self.stopThreshold {
                let (g, r) = motionParameters(for: speed)
                targetGain = g; targetRate = r
            } else {
                startRelease()
                targetGain = Self.releaseVolume; targetRate = 1.0
            }

        case .releasing:
            if speed > Self.startThreshold {
                // Skip the attack on re-engage for snappier response.
                startLoop()
                let (g, r) = motionParameters(for: speed)
                targetGain = g; targetRate = r
            } else {
                targetGain = Self.releaseVolume; targetRate = 1.0
            }
        }

        ramp()
    }

    private func motionParameters(for speed: Double) -> (gain: Double, rate: Double) {
        let e0 = max(0, Self.velocityFull - 0.5)
        let e1 = Self.motionVelocityQuiet + 0.5
        let t = min(1, max(0, (speed - e0) / (e1 - e0)))
        let s = t * t * (3 - 2 * t) // smoothstep
        let normalized = min(1, max(0, speed / Self.motionVelocityQuiet))
        return (gain: 1 - s, rate: Self.motionMinRate + normalized * (Self.motionMaxRate - Self.motionMinRate))
    }

    private func ramp() {
        guard isRunning else { return }

        let now = CACurrentMediaTime()
        let dt = lastRampTime == 0 ? 0.016 : now - lastRampTime
        lastRampTime = now

        gain = gain.ramped(toward: targetGain, dt: dt, tauMs: Self.gainRampMs)
        rate = rate.ramped(toward: targetRate, dt: dt, tauMs: Self.rateRampMs)

        playerNode.volume = Float(gain)
        varispeed.rate = Float(rate)
    }
}
