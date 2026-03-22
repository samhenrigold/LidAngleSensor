//
//  MenuBarView.swift
//  LidAngleSensor
//
//  Created by Sam on 2026-03-22.
//

import SwiftUI

struct MenuBarView: View {
    @Environment(\.lidAngleSensor) private var sensor
    @Environment(\.audioController) private var audioController

    var body: some View {
        @Bindable var controller = audioController

        if !sensor.isAvailable {
            Text("Sensor Not Available")
        }

        Section {
            Picker("Sound Mode", selection: $controller.mode) {
                ForEach(AudioMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.inline)

            Button(audioController.isPlaying ? "Stop" : "Start") {
                audioController.toggle()
            }
        }
        .disabled(!sensor.isAvailable)

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
}
