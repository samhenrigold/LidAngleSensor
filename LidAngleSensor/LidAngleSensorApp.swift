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
    @State private var audioController = AudioController()

    var body: some Scene {
        Window(Text("Lid Angle Sensor"), id: "main") {
            ContentView()
                .environment(\.lidAngleSensor, sensor)
                .environment(\.audioController, audioController)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarView()
                .environment(\.lidAngleSensor, sensor)
                .environment(\.audioController, audioController)
        } label: {
            Image(systemName: "angle")

            if sensor.isAvailable {
                Text("\(sensor.angle, format: .number.precision(.fractionLength(0)))°")
                    .monospacedDigit()
            }
        }
    }
}
