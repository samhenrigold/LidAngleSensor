//
//  ContentView.swift
//  LidAngleSensor
//
//  Created by Sam on 2026-03-22.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.lidAngleSensor) private var sensor

    @State private var creakEngine = CreakAudioEngine()
    @State private var thereminEngine = ThereminAudioEngine()
    @State private var mode: AudioMode = .creak
    @State private var isPlaying = false

    private var activeEngine: any AudioEngineProtocol { engine(for: mode) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Group {
                    if sensor.isAvailable {
                        Text("\(sensor.angle, format: .number.precision(.fractionLength(1)))°")
                            .monospacedDigit()
                            .foregroundStyle(.blue)
                            .contentTransition(.numericText(value: sensor.angle))
                            .animation(.default, value: sensor.angle)
                    } else {
                        Text("Not Available")
                            .foregroundStyle(.red)
                    }
                }
                .font(.system(size: 48, weight: .light, design: .default))

                // yes yes the old style formatter is gross but I can't figure out how to do leading zero padding w/ the new formatter
                Text("Velocity: \(String(format: "%02d", Int(sensor.velocity.rounded()))) deg/s")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Text(sensor.status)
                    .foregroundStyle(.secondary)

                Divider()
                    .padding(.horizontal, 40)

                Button(isPlaying ? "Stop Audio" : "Start Audio") {
                    toggleAudio()
                }
                .controlSize(.large)
                .disabled(!sensor.isAvailable)

                AudioParameterView(
                    mode: mode,
                    creakEngine: creakEngine,
                    thereminEngine: thereminEngine
                )
                .foregroundStyle(.secondary)
                .opacity(isPlaying ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: isPlaying)

                Picker("Audio Mode", selection: $mode) {
                    ForEach(AudioMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: mode) { oldMode, newMode in
                    switchMode(from: oldMode, to: newMode)
                }

            }
            .padding(40)
            .frame(minWidth: 440, minHeight: 400)
            .animation(.easeInOut(duration: 0.2), value: mode)
            .onAppear { sensor.start() }
            .onDisappear { sensor.stop() }
            .onChange(of: sensor.tick) {
                feedAudioEngine()
            }
        }
    }

    // MARK: Audio Control

    private func engine(for mode: AudioMode) -> any AudioEngineProtocol {
        switch mode {
        case .creak:    creakEngine
        case .theremin: thereminEngine
        }
    }

    private func toggleAudio() {
        if isPlaying {
            activeEngine.stop()
        } else {
            activeEngine.start()
        }
        isPlaying.toggle()
    }

    private func switchMode(from oldMode: AudioMode, to newMode: AudioMode) {
        guard isPlaying else { return }
        engine(for: oldMode).stop()
        engine(for: newMode).start()
    }

    private func feedAudioEngine() {
        guard isPlaying else { return }
        switch mode {
        case .creak:
            creakEngine.update(velocity: sensor.velocity)
        case .theremin:
            thereminEngine.update(angle: sensor.angle, velocity: sensor.velocity)
        }
    }
}

#Preview {
    ContentView()
}
