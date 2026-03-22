//
//  AudioEngineHelpers.swift
//  LidAngleSensor
//
//  Created by Sam on 2026-03-22.
//

extension Double {
    /// Exponential ramp toward `target` using a time constant of `tauMs` milliseconds.
    func ramped(toward target: Double, dt: Double, tauMs: Double) -> Double {
        let alpha = min(1, dt / (tauMs / 1000.0))
        return self + (target - self) * alpha
    }
}
