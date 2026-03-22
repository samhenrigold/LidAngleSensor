//
//  LidAngleSensor.swift
//  LidAngleSensor
//
//  Created by Sam on 2026-03-22.
//

import IOKit
import SwiftUI

extension EnvironmentValues {
    @Entry var lidAngleSensor: LidAngleSensor = .init()
}

// MARK: - Sensor

@Observable
final class LidAngleSensor {
    
    // MARK: Published State
    
    // 120 is completely arbitrary, but it's the angle that my laptop is currently at so it doesn't animate from zero.
    private(set) var angle = 120.0
    private(set) var velocity = Double.zero
    private(set) var isAvailable = false
    private(set) var tick = UInt.zero
    
    /// Full diagnostic report from hardware detection.
    @ObservationIgnored private(set) var diagnostic: LASDiagnostic?
    
    var status: String {
        guard isAvailable else {
            return diagnostic?.statusMessage ?? "Sensor not available"
        }
        return switch angle {
        case ..<5: "Lid is closed"
        case ..<45: "Lid slightly open"
        case ..<90: "Lid partially open"
        case ..<120: "Lid mostly open"
        default: "Lid fully open"
        }
    }
    
    // MARK: HID State
    //
    // nonisolated(unsafe) so deinit can access these from its unisolated context.
    // The cleanup in deinit is safe in practice: the object is being torn down, so no
    // concurrent main-actor access can occur.
    
    @ObservationIgnored nonisolated(unsafe) private var hidDevice: IOHIDDevice?
    @ObservationIgnored nonisolated(unsafe) private var isDeviceOpen = false
    @ObservationIgnored nonisolated(unsafe) private var timer: Timer?
    
    // MARK: Velocity Calculation State
    
    @ObservationIgnored private var lastAngle = Double.zero
    @ObservationIgnored private var smoothedAngle = Double.zero
    @ObservationIgnored private var smoothedVelocity = Double.zero
    @ObservationIgnored private var lastUpdateTime: TimeInterval = 0
    @ObservationIgnored private var lastMovementTime: TimeInterval = 0
    @ObservationIgnored private var isFirstUpdate = true
    
    // MARK: Constants
    //
    // nonisolated so the static let is accessible from deinit and static methods.
    
    nonisolated private static let noOptions = IOOptionBits(kIOHIDOptionsTypeNone)
    private static let angleSmoothingFactor = 0.05
    private static let velocitySmoothingFactor = 0.3
    private static let movementThreshold = 0.5
    private static let movementTimeout: TimeInterval = 0.05
    private static let velocityDecay = 0.5
    private static let additionalDecay = 0.8
    
    // MARK: Lifecycle
    
    init() {
        let diag = LASDiagnostic.run()
        diagnostic = diag
        
        if case .foundStandard(let device) = diag.probeResult {
            hidDevice = device
            isAvailable = true
            // Device is opened in start(), not here. Temporary LidAngleSensor instances
            // that SwiftUI creates (and discards) as @State initial-value expressions must
            // never touch the device handle; otherwise their deinit would close it out from
            // under the real sensor instance.
        }
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
        if isDeviceOpen, let device = hidDevice {
            IOHIDDeviceClose(device, Self.noOptions)
        }
    }
    
    // MARK: Control
    
    func start() {
        guard isAvailable, timer == nil, let device = hidDevice else { return }
        guard IOHIDDeviceOpen(device, Self.noOptions) == kIOReturnSuccess else { return }
        isDeviceOpen = true
        timer = .scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            // The timer is scheduled on the main run loop, so this callback fires
            // on the main thread — safe to assume main-actor isolation.
            MainActor.assumeIsolated { self?.poll() }
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        if isDeviceOpen, let device = hidDevice {
            IOHIDDeviceClose(device, Self.noOptions)
            isDeviceOpen = false
        }
    }
    
    // MARK: Polling
    
    private func poll() {
        guard let device = hidDevice else { return }
        
        var report = [UInt8](repeating: 0, count: 8)
        var length = CFIndex(report.count)
        
        let result = IOHIDDeviceGetReport(
            device,
            kIOHIDReportTypeFeature,
            1,
            &report,
            &length
        )
        
        guard result == kIOReturnSuccess, length >= 3 else { return }
        
        let rawValue = UInt16(report[2]) << 8 | UInt16(report[1])
        let rawAngle = Double(rawValue)
        
        updateVelocity(from: rawAngle)
        angle = rawAngle
        tick &+= 1
    }
    
    // MARK: Velocity Calculation
    
    private func updateVelocity(from rawAngle: Double) {
        let now = CACurrentMediaTime()
        
        guard !isFirstUpdate else {
            lastAngle = rawAngle
            smoothedAngle = rawAngle
            lastUpdateTime = now
            lastMovementTime = now
            isFirstUpdate = false
            return
        }
        
        let dt = now - lastUpdateTime
        guard dt > 0, dt < 1.0 else {
            lastUpdateTime = now
            return
        }
        
        smoothedAngle =
        Self.angleSmoothingFactor * rawAngle
        + (1 - Self.angleSmoothingFactor) * smoothedAngle
        
        let delta = smoothedAngle - lastAngle
        let instantVelocity: Double
        
        if abs(delta) < Self.movementThreshold {
            instantVelocity = 0
        } else {
            instantVelocity = abs(delta / dt)
            lastAngle = smoothedAngle
        }
        
        if instantVelocity > 0 {
            smoothedVelocity =
            Self.velocitySmoothingFactor * instantVelocity
            + (1 - Self.velocitySmoothingFactor) * smoothedVelocity
            lastMovementTime = now
        } else {
            smoothedVelocity *= Self.velocityDecay
        }
        
        if now - lastMovementTime > Self.movementTimeout {
            smoothedVelocity *= Self.additionalDecay
        }
        
        lastUpdateTime = now
        velocity = smoothedVelocity
    }
    
}
