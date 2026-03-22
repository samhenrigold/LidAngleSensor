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
    // race is benign here — a briefly stale frequency or volume value produces
    // no audible artefact.
    
    @ObservationIgnored nonisolated(unsafe) private var renderFrequency = 110.0
    @ObservationIgnored nonisolated(unsafe) private var renderVolume = 0.6
    @ObservationIgnored nonisolated(unsafe) private var phase = Double.zero
    @ObservationIgnored nonisolated(unsafe) private var vibratoPhase = Double.zero
    
    // MARK: Ramping State
    
    private var targetFrequency = 110.0
    private var targetVolume = 0.6
    private var lastRampTime: TimeInterval = 0
    
    // MARK: Constants
    //
    // Constants used in the nonisolated render() function must also be nonisolated
    // so they are accessible from any concurrency context.
    
    nonisolated private static let sampleRate = 44100.0
    private static let minFrequency = 110.0  // A2
    private static let maxFrequency = 440.0  // A4
    private static let minAngle = 0.0
    private static let maxAngle = 135.0
    
    private static let baseVolume = 0.6
    private static let velocityVolumeBoost = 0.4
    private static let velocityQuiet = 80.0
    
    nonisolated private static let vibratoFreq = 5.0
    nonisolated private static let vibratoDepth = 0.03
    
    private static let frequencyRampMs = 30.0
    private static let volumeRampMs = 50.0
    
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
    
    // MARK: Parameter Update
    
    func update(angle: Double, velocity: Double) {
        let normalizedAngle = min(1, max(0, (angle - Self.minAngle) / (Self.maxAngle - Self.minAngle)))
        let ratio = pow(normalizedAngle, 0.7)
        targetFrequency = Self.minFrequency + ratio * (Self.maxFrequency - Self.minFrequency)
        
        var boost = 0.0
        if velocity > 0 {
            let t = min(1, max(0, velocity / Self.velocityQuiet))
            let s = t * t * (3 - 2 * t)
            boost = (1 - s) * Self.velocityVolumeBoost
        }
        targetVolume = min(1, Self.baseVolume + boost)
        
        ramp()
    }
    
    private func ramp() {
        let now = CACurrentMediaTime()
        let dt = lastRampTime == 0 ? 0.016 : now - lastRampTime
        lastRampTime = now
        
        frequency = frequency.ramped(toward: targetFrequency, dt: dt, tauMs: Self.frequencyRampMs)
        volume = volume.ramped(toward: targetVolume, dt: dt, tauMs: Self.volumeRampMs)
        
        // Sync observable values to the render-thread copies.
        renderFrequency = frequency
        renderVolume = volume
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
        let vibratoInc = 2.0 * .pi * Self.vibratoFreq / Self.sampleRate
        
        for i in 0..<Int(frameCount) {
            let vibrato = sin(vibratoPhase) * Self.vibratoDepth
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
