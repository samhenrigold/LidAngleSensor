//
//  ThereminAudioEngine.swift
//  LidAngleSensor
//
//  Created by Sam on 2026-03-22.
//

import AVFoundation

@Observable
final class ThereminAudioEngine: AudioEngineProtocol {
    private(set) var isRunning = false
    private(set) var frequency = 110.0
    private(set) var volume = 0.6

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?

    // MARK: Audio-Thread State
    //
    // The render block runs on the audio thread. These properties are written
    // on the main actor (in ramp()) and read on the audio thread (in render()).
    // nonisolated(unsafe) opts out of actor-isolation checking; the write/read
    // race is benign here — a briefly stale value produces no audible artefact.

    @ObservationIgnored nonisolated(unsafe) private var renderFrequency = 110.0
    @ObservationIgnored nonisolated(unsafe) private var renderVolume = 0.6
    @ObservationIgnored nonisolated(unsafe) private var renderVibratoFreq = 5.0
    @ObservationIgnored nonisolated(unsafe) private var renderVibratoDepth = 0.03
    @ObservationIgnored nonisolated(unsafe) private var phase = Double.zero
    @ObservationIgnored nonisolated(unsafe) private var vibratoPhase = Double.zero

    // MARK: Ramping State

    private var targetFrequency = 110.0
    private var targetVolume = 0.6
    private var lastRampTime: TimeInterval = 0

    // MARK: Parameters

    var minFrequency = 110.0  // A2
    var maxFrequency = 440.0  // A4
    var baseVolume = 0.6
    var velocityVolumeBoost = 0.4
    var velocityQuiet = 80.0
    var vibratoFreq = 5.0
    var vibratoDepth = 0.03
    var frequencyRampMs = 30.0
    var volumeRampMs = 50.0

    private static let minAngle = 0.0
    private static let maxAngle = 135.0
    nonisolated private static let sampleRate = 44100.0

    // MARK: Lifecycle

    init() {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.sampleRate,
            channels: 1,
            interleaved: false
        ) else { return }

        let renderBlock: AVAudioSourceNodeRenderBlock = { [weak self] _, _, frameCount, bufferList in
            guard let self else { return noErr }
            return self.render(frameCount: frameCount, bufferList: bufferList)
        }

        sourceNode = AVAudioSourceNode(format: format, renderBlock: renderBlock)

        guard let sourceNode else { return }
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
    }

    // MARK: Control

    func start() {
        guard !isRunning else { return }
        try? engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.stop()
        isRunning = false
    }

    // MARK: Reset

    func resetToDefaults() {
        minFrequency = 110.0
        maxFrequency = 440.0
        baseVolume = 0.6
        velocityVolumeBoost = 0.4
        velocityQuiet = 80.0
        vibratoFreq = 5.0
        vibratoDepth = 0.03
        frequencyRampMs = 30.0
        volumeRampMs = 50.0
    }

    // MARK: Parameter Update

    func update(angle: Double, velocity: Double) {
        let normalizedAngle = min(1, max(0, (angle - Self.minAngle) / (Self.maxAngle - Self.minAngle)))
        let ratio = pow(normalizedAngle, 0.7)
        targetFrequency = minFrequency + ratio * (maxFrequency - minFrequency)

        var boost = 0.0
        if velocity > 0 {
            let t = min(1, max(0, velocity / velocityQuiet))
            let s = t * t * (3 - 2 * t)
            boost = (1 - s) * velocityVolumeBoost
        }
        targetVolume = min(1, baseVolume + boost)

        ramp()
    }

    private func ramp() {
        let now = CACurrentMediaTime()
        let dt = lastRampTime == 0 ? 0.016 : now - lastRampTime
        lastRampTime = now

        frequency = frequency.ramped(toward: targetFrequency, dt: dt, tauMs: frequencyRampMs)
        volume = volume.ramped(toward: targetVolume, dt: dt, tauMs: volumeRampMs)

        // Sync observable values to the render-thread copies.
        renderFrequency = frequency
        renderVolume = volume
        renderVibratoFreq = vibratoFreq
        renderVibratoDepth = vibratoDepth
    }

    // MARK: Render
    //
    // nonisolated so the AVAudioSourceNode render block can call this directly
    // from the audio thread without a main-actor hop.

    nonisolated private func render(
        frameCount: AVAudioFrameCount,
        bufferList: UnsafeMutablePointer<AudioBufferList>
    ) -> OSStatus {
        let output = bufferList.pointee.mBuffers.mData!.assumingMemoryBound(to: Float.self)
        let vibratoInc = 2.0 * .pi * renderVibratoFreq / Self.sampleRate

        for i in 0..<Int(frameCount) {
            let vibrato = sin(vibratoPhase) * renderVibratoDepth
            let modFreq = renderFrequency * (1 + vibrato)
            let inc = 2.0 * .pi * modFreq / Self.sampleRate

            output[i] = Float(sin(phase) * renderVolume * 0.25)

            phase += inc
            vibratoPhase += vibratoInc

            if phase >= 2.0 * .pi { phase -= 2.0 * .pi }
            if vibratoPhase >= 2.0 * .pi { vibratoPhase -= 2.0 * .pi }
        }

        return noErr
    }
}
