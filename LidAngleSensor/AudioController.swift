//
//  AudioController.swift
//  LidAngleSensor
//
//  Created by Sam on 2026-03-22.
//

import SwiftUI

extension EnvironmentValues {
    @Entry var audioController: AudioController = .init()
}

@MainActor
@Observable
final class AudioController {

    // MARK: Published State

    private(set) var isPlaying = false

    var mode: AudioMode = .creak {
        didSet {
            guard oldValue != mode else { return }
            modeDidChange(from: oldValue)
        }
    }

    // MARK: Engines

    let creakEngine = CreakAudioEngine()
    let thereminEngine = ThereminAudioEngine()

    // MARK: Control

    func toggle() {
        if isPlaying {
            engine(for: mode).stop()
        } else {
            engine(for: mode).start()
        }
        isPlaying.toggle()
    }

    func feed(angle: Double, velocity: Double) {
        guard isPlaying else { return }
        switch mode {
        case .creak:
            creakEngine.update(velocity: velocity)
        case .theremin:
            thereminEngine.update(angle: angle, velocity: velocity)
        }
    }

    // MARK: Private

    private func engine(for mode: AudioMode) -> any AudioEngineProtocol {
        switch mode {
        case .creak:    creakEngine
        case .theremin: thereminEngine
        }
    }

    private func modeDidChange(from oldMode: AudioMode) {
        guard isPlaying else { return }
        engine(for: oldMode).stop()
        engine(for: mode).start()
    }
}
