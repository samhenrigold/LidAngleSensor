//
//  CustomParameterView.swift
//  LidAngleSensor
//
//  Created by Sam on 2026-03-22.
//

import SwiftUI

/// Configuration and status panel for the custom audio engine.
///
/// Always visible when the "Custom" mode is selected. Shows a drop zone when
/// no file is loaded; switches to the waveform range editor once a file is
/// dropped.
struct CustomParameterView: View {
    @Bindable var engine: CustomAudioEngine

    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            waveformSection
            controlRow
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            engine.loadFile(from: url)
            return true
        } isTargeted: {
            isTargeted = $0
        }
        .onChange(of: engine.playbackMode) { _, _ in
            guard engine.isRunning else { return }
            engine.stop()
            engine.start()
        }
    }

    // MARK: Subviews

    @ViewBuilder
    private var waveformSection: some View {
        if engine.isFileLoaded {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(engine.filename)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    Spacer()
                    Text(Duration.seconds(engine.duration).formatted(.time(pattern: .minuteSecond)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                WaveformRangeView(
                    samples: engine.waveformSamples,
                    inPoint: $engine.inPoint,
                    loopStart: $engine.loopStart,
                    loopEnd: $engine.loopEnd,
                    outPoint: $engine.outPoint,
                    onRangeChangeEnded: { engine.rebuildBuffers() }
                )
                .frame(height: 64)
                .clipShape(.rect(cornerRadius: 6))
                .background(.black.opacity(0.35), in: .rect(cornerRadius: 6))

                HStack(spacing: 14) {
                    legend(color: .orange, label: "Attack")
                    legend(color: .accentColor, label: "Loop")
                    legend(color: .teal, label: "Release")
                }
                .font(.caption2)
            }
        } else {
            dropZone
        }
    }

    private func legend(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color.opacity(0.85))
                .frame(width: 6, height: 6)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(
                isTargeted ? Color.accentColor : Color.secondary,
                style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: isTargeted ? [] : [5])
            )
            .frame(height: 80)
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: "waveform.badge.plus")
                        .font(.title2)
                    Text("Drop an audio file")
                        .font(.caption)
                }
                .foregroundStyle(isTargeted ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
            }
            .animation(.easeInOut(duration: 0.15), value: isTargeted)
    }

    private var controlRow: some View {
        Picker("Mode", selection: $engine.playbackMode) {
            ForEach(CustomEngineMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}
