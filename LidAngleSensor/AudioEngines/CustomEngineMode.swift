//
//  CustomEngineMode.swift
//  LidAngleSensor
//
//  Created by Sam on 2026-03-22.
//

enum CustomEngineMode: String, CaseIterable, Identifiable {
    /// Always plays; angle controls playback rate (pitch).
    case continuous = "Continuous"
    /// Plays only while the lid is moving; velocity controls volume and rate.
    case motionOnly = "Motion Only"

    var id: Self { self }
}
