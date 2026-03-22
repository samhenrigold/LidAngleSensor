//
//  LidAngleSensorApp.swift
//  LidAngleSensor
//
//  Created by Sam on 2026-03-22.
//

import SwiftUI

@main
struct LidAngleSensorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var sensor = LidAngleSensor()

    var body: some Scene {
        Window(Text("Lid Angle Sensor"), id: "main") {
            ContentView()
                .environment(\.lidAngleSensor, sensor)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
        }
        .windowResizability(.contentSize)
    }
}
