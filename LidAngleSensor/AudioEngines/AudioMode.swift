//
//  AudioMode.swift
//  LidAngleSensor
//
//  Created by Sam on 2026-03-22.
//

enum AudioMode: String, CaseIterable, Identifiable {
    case creak = "Creak"
    case theremin = "Theremin"
    case custom = "Custom"
    var id: Self { self }
}
