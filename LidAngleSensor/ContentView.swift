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
    @State private var inspectorShown = true
    
    private var activeEngine: any AudioEngineProtocol { engine(for: mode) }
    
    var body: some View {
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
                feedAudioEngine()
            }
            .toolbar {
                ToolbarItemGroup {
                    Button(isPlaying ? "Stop" : "Play", systemImage: isPlaying ? "stop" : "play") {
                        toggleAudio()
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
                    Picker("Audio Mode", selection: $mode) {
                        ForEach(AudioMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .onChange(of: mode) { oldMode, newMode in
                        switchMode(from: oldMode, to: newMode)
                    }
                    
                    Section {
                        switch mode {
                        case .creak:
                            LabeledContent("Gain", value: creakEngine.gain, format: .number.precision(.fractionLength(2)))
                            LabeledContent("Rate", value: creakEngine.rate, format: .number.precision(.fractionLength(2)))
                        case .theremin:
                            LabeledContent("Frequency (Hz)", value: thereminEngine.frequency, format: .number.precision(.fractionLength(1)))
                            LabeledContent("Volume", value: thereminEngine.volume, format: .number.precision(.fractionLength(2)))
                        }
                    }
                }
                .inspectorColumnWidth(min: 200, ideal: 240, max: 320)
            }
        }
        .frame(minWidth: 800, minHeight: 400)
        .frame(idealWidth: 900, idealHeight: 667)
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
