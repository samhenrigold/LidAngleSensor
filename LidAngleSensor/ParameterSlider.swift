//
//  ParameterSlider.swift
//  LidAngleSensor
//
//  Created by Sam on 2026-03-22.
//

import SwiftUI

struct ParameterSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var unit = ""
    var fractionDigits = 1
    
    var body: some View {
        LabeledContent {
            Slider(value: $value, in: range)
        } label: {
            Text(label)
            Text(formattedValue)
        }
    }
    
    private var formattedValue: String {
        let number = value.formatted(.number.precision(.fractionLength(fractionDigits)))
        return unit.isEmpty ? number : "\(number) \(unit)"
    }
}
