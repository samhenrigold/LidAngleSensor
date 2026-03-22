//
//  WaveformRangeView.swift
//  LidAngleSensor
//
//  Created by Sam on 2026-03-22.
//

import SwiftUI

/// A waveform display with four draggable handles defining three playback regions:
///
/// - **Attack** (`inPoint`→`loopStart`, amber): plays once when motion begins.
/// - **Loop** (`loopStart`→`loopEnd`, blue): repeats while the lid is moving.
/// - **Release** (`loopEnd`→`outPoint`, teal): plays once when motion stops.
///
/// `onRangeChangeEnded` fires when the pointer is lifted, so the caller can
/// rebuild audio buffers without glitching on every drag event.
struct WaveformRangeView: View {
    let samples: [Float]
    @Binding var inPoint: Double
    @Binding var loopStart: Double
    @Binding var loopEnd: Double
    @Binding var outPoint: Double
    var onRangeChangeEnded: () -> Void = {}

    private enum DragHandle { case inPoint, loopStart, loopEnd, outPoint }
    @State private var activeHandle: DragHandle?

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            Canvas { context, size in
                drawWaveform(context: context, size: size)
                drawHandle(context: context, size: size, x: inPoint   * size.width, style: .boundary)
                drawHandle(context: context, size: size, x: loopStart * size.width, style: .loopEdge)
                drawHandle(context: context, size: size, x: loopEnd   * size.width, style: .loopEdge)
                drawHandle(context: context, size: size, x: outPoint  * size.width, style: .boundary)
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        let t = (value.location.x / width).clamped(to: 0...1)

                        if activeHandle == nil {
                            let candidates: [(Double, DragHandle)] = [
                                (abs(inPoint   - t), .inPoint),
                                (abs(loopStart - t), .loopStart),
                                (abs(loopEnd   - t), .loopEnd),
                                (abs(outPoint  - t), .outPoint),
                            ]
                            activeHandle = candidates.min(by: { $0.0 < $1.0 })?.1
                        }

                        switch activeHandle {
                        case .inPoint:
                            inPoint    = min(t, loopStart - 0.01)
                        case .loopStart:
                            loopStart  = max(inPoint + 0.01, min(t, loopEnd - 0.01))
                        case .loopEnd:
                            loopEnd    = max(loopStart + 0.01, min(t, outPoint - 0.01))
                        case .outPoint:
                            outPoint   = max(t, loopEnd + 0.01)
                        case nil:
                            break
                        }
                    }
                    .onEnded { _ in
                        activeHandle = nil
                        onRangeChangeEnded()
                    }
            )
        }
    }

    // MARK: Drawing

    private func drawWaveform(context: GraphicsContext, size: CGSize) {
        guard !samples.isEmpty else { return }
        let barWidth = size.width / Double(samples.count)
        let midY = size.height / 2

        for (i, sample) in samples.enumerated() {
            let x = Double(i) * barWidth
            let t = Double(i) / Double(max(1, samples.count - 1))
            let barH = max(2, Double(sample) * size.height * 0.85)
            let rect = CGRect(x: x, y: midY - barH / 2, width: max(1, barWidth - 0.5), height: barH)

            let color: Color
            if t < inPoint || t > outPoint {
                color = .white.opacity(0.15)       // outside selection
            } else if t < loopStart {
                color = .orange.opacity(0.70)      // attack region
            } else if t < loopEnd {
                color = .accentColor.opacity(0.85) // loop region
            } else {
                color = .teal.opacity(0.70)        // release region
            }
            context.fill(Path(rect), with: .color(color))
        }
    }

    private enum HandleStyle { case boundary, loopEdge }

    private func drawHandle(context: GraphicsContext, size: CGSize, x: Double, style: HandleStyle) {
        let midY = size.height / 2
        let color: Color = switch style {
            case .boundary: .white
            case .loopEdge: .accentColor
        }

        let lineRect = CGRect(x: x - 1, y: 0, width: 2, height: size.height)
        context.fill(Path(lineRect), with: .color(color))

        let dotRect = CGRect(x: x - 5, y: midY - 5, width: 10, height: 10)
        context.fill(Path(ellipseIn: dotRect), with: .color(color))
        context.stroke(Path(ellipseIn: dotRect), with: .color(.black.opacity(0.3)), lineWidth: 1)
    }
}

// MARK: - Comparable+clamped

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
