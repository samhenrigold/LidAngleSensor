//
//  ContentView.swift
//  LidAngleSensor
//
//  Created by Sam on 2026-03-22.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.lidAngleSensor) private var sensor
    @Environment(\.audioController) private var audioController

    @State private var inspectorShown = true

    var body: some View {
        @Bindable var controller = audioController

        NavigationStack {
            VStack {
                if sensor.isAvailable {
                    Text("\(sensor.angle, format: .number.precision(.fractionLength(1)))°")
                        .monospacedDigit()
                        .foregroundStyle(.blue)
                        .contentTransition(.numericText(value: sensor.angle))
                        .animation(.default, value: sensor.angle)
                        .font(.system(size: 144, weight: .thin))
                        .tracking(-3)

                    Group {
                        Text("Velocity: \(String(format: "%02d", Int(sensor.velocity.rounded()))) deg/s")
                        Text(sensor.status)
                    }
                    .foregroundStyle(.secondary)
                } else {
                    Text("Not Available")
                        .foregroundStyle(.red)
                        .font(.system(size: 56, weight: .light))
                }
            }
            .monospacedDigit()
            .onAppear {
                sensor.start()
            }
            .onChange(of: sensor.tick) {
                audioController.feed(angle: sensor.angle, velocity: sensor.velocity)
            }
            .toolbar {
                ToolbarItemGroup {
                    Button(
                        audioController.isPlaying ? "Stop" : "Play",
                        systemImage: audioController.isPlaying ? "stop" : "play"
                    ) {
                        audioController.toggle()
                    }
                    .symbolVariant(.fill)
                    .disabled(!sensor.isAvailable)
                    .keyboardShortcut(.space, modifiers: [])

                    Button {
                        inspectorShown.toggle()
                    } label: {
                        Label("Audio Controls", systemImage: "slider.horizontal.3")
                    }
                }
            }
            .inspector(isPresented: $inspectorShown) {
                Form {
                    Picker("Audio Mode", selection: $controller.mode) {
                        ForEach(AudioMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }

                    Section {
                        switch audioController.mode {
                        case .creak:
                            LabeledContent("Gain", value: audioController.creakEngine.gain, format: .number.precision(.fractionLength(2)))
                            LabeledContent("Rate", value: audioController.creakEngine.rate, format: .number.precision(.fractionLength(2)))
                        case .theremin:
                            LabeledContent("Frequency (Hz)", value: audioController.thereminEngine.frequency, format: .number.precision(.fractionLength(1)))
                            LabeledContent("Volume", value: audioController.thereminEngine.volume, format: .number.precision(.fractionLength(2)))
                        }
                    }
                }
                .inspectorColumnWidth(min: 200, ideal: 240, max: 320)
            }
        }
        .frame(minWidth: 800, minHeight: 400)
        .frame(idealWidth: 900, idealHeight: 667)
    }
}

#Preview {
    ContentView()
}
