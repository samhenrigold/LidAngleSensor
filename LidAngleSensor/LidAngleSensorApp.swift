//
//  LidAngleSensorApp.swift
//  LidAngleSensor
//
//  Created by Sam on 2026-03-22.
//

import SwiftUI

@main
struct LidAngleSensorApp: App {
    @State private var sensor = LidAngleSensor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.lidAngleSensor, sensor)
        }
        .windowResizability(.contentSize)
    }
}
