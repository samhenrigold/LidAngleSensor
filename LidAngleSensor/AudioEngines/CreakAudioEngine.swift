//
//  CreakAudioEngine.swift
//  LidAngleSensor
//
//  Created by Sam on 2026-03-22.
//

import AVFoundation

@Observable
final class CreakAudioEngine: AudioEngineProtocol {
    
    // MARK: Published State
    
    private(set) var isRunning = false
    private(set) var gain = Double.zero
    private(set) var rate = 1.0
    
    // MARK: Audio Graph
    
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let varispeed = AVAudioUnitVarispeed()
    private var loopBuffer: AVAudioPCMBuffer?
    
    // MARK: Ramping State
    
    private var targetGain = Double.zero
    private var targetRate = 1.0
    private var lastRampTime: TimeInterval = 0
    
    // MARK: Constants
    
    private static let deadzone = 1.0
    private static let velocityFull = 10.0
    private static let velocityQuiet = 100.0
    private static let minRate = 0.80
    private static let maxRate = 1.10
    private static let gainRampMs = 50.0
    private static let rateRampMs = 80.0
    
    // MARK: Lifecycle
    
    init() {
        engine.attach(playerNode)
        engine.attach(varispeed)
        
        guard let url = Bundle.main.url(forResource: "CREAK_LOOP", withExtension: "wav"),
              let file = try? AVAudioFile(forReading: url) else {
            return
        }
        
        let format = file.processingFormat
        engine.connect(playerNode, to: varispeed, format: format)
        engine.connect(varispeed, to: engine.mainMixerNode, format: format)
        
        let frameCount = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return
        }
        try? file.read(into: buffer)
        loopBuffer = buffer
    }
    
    // MARK: Control
    
    func start() {
        guard !isRunning, let buffer = loopBuffer else { return }
        
        try? engine.start()
        playerNode.scheduleBuffer(buffer, at: nil, options: .loops)
        playerNode.play()
        playerNode.volume = 0
        isRunning = true
    }
    
    func stop() {
        guard isRunning else { return }
        playerNode.stop()
        engine.stop()
        isRunning = false
    }
    
    // MARK: Parameter Update
    
    func update(velocity: Double) {
        let speed = abs(velocity)
        
        // Gain: slow = loud, fast = quiet
        if speed < Self.deadzone {
            targetGain = 0
        } else {
            let e0 = max(0, Self.velocityFull - 0.5)
            let e1 = Self.velocityQuiet + 0.5
            let t = min(1, max(0, (speed - e0) / (e1 - e0)))
            let s = t * t * (3 - 2 * t) // smoothstep
            targetGain = 1 - s
        }
        
        // Rate: speed maps linearly across pitch range
        let normalized = min(1, max(0, speed / Self.velocityQuiet))
        targetRate = Self.minRate + normalized * (Self.maxRate - Self.minRate)
        
        ramp()
    }
    
    private func ramp() {
        guard isRunning else { return }
        
        let now = CACurrentMediaTime()
        let dt = lastRampTime == 0 ? 0.016 : now - lastRampTime
        lastRampTime = now
        
        gain = gain.ramped(toward: targetGain, dt: dt, tauMs: Self.gainRampMs)
        rate = rate.ramped(toward: targetRate, dt: dt, tauMs: Self.rateRampMs)
        
        playerNode.volume = Float(gain * 2.0)
        varispeed.rate = Float(rate)
    }
}
