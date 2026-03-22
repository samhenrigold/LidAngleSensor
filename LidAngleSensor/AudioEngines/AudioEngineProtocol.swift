//
//  AudioEngineProtocol.swift
//  LidAngleSensor
//
//  Created by Sam on 2026-03-22.
//

protocol AudioEngineProtocol {
    var isRunning: Bool { get }
    func start()
    func stop()
    func resetToDefaults()
}
