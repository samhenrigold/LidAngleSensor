//
//  AudioParameterView.swift
//  LidAngleSensor
//
//  Created by Sam on 2026-03-22.
//

import SwiftUI

struct AudioParameterView: View {
    let mode: AudioMode
    let creakEngine: CreakAudioEngine
    let thereminEngine: ThereminAudioEngine

    var body: some View {
        switch mode {
        case .creak:
            Text("Gain: \(creakEngine.gain, format: .number.precision(.fractionLength(2))), Rate: \(creakEngine.rate, format: .number.precision(.fractionLength(2)))")
        case .theremin:
            Text("Freq: \(thereminEngine.frequency, format: .number.precision(.fractionLength(1))) Hz, Vol: \(thereminEngine.volume, format: .number.precision(.fractionLength(2)))")
        }
    }
}
