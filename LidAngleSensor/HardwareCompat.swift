//
//  HardwareCompat.swift
//  LidAngleSensor
//
//  Created by Sam on 2026-03-22.
//

import Foundation
import IOKit.hid

// MARK: - Hardware Compatibility

/// Known hardware support status for the lid angle sensor.
enum LASHardwareSupport: Equatable, CustomStringConvertible {
    /// This model is known to have LAS hardware.
    case supported(model: String)
    /// This model is known NOT to have LAS hardware.
    case unsupported(reason: String)
    /// Model isn't in our database — runtime probing will decide.
    case unknown(modelIdentifier: String)
    
    var description: String {
        switch self {
        case .supported(let m): "supported (\(m))"
        case .unsupported(let r): "unsupported (\(r))"
        case .unknown(let id): "unknown (\(id))"
        }
    }
}

/// Result of runtime HID probing.
enum LASSensorProbeResult: CustomStringConvertible {
    /// Found sensor on the standard Sensor usage page (0x0020).
    case foundStandard(device: IOHIDDevice)
    /// Found 0x8104 device on vendor-specific usage page (0xFF00).
    /// Hardware exists but we can't read angle data through this interface.
    case foundVendorSpecific
    /// No matching HID device at all.
    case notFound
    
    var description: String {
        switch self {
        case .foundStandard: "found (standard UsagePage 0x0020)"
        case .foundVendorSpecific: "found (vendor-specific UsagePage 0xFF00)"
        case .notFound: "not found"
        }
    }
}

// MARK: - Model Identification

struct MacModelInfo {
    
    /// Raw model identifier, e.g. "MacBookPro18,3" or "Mac16,1".
    let identifier: String
    
    /// Read the current Mac's model identifier via sysctl.
    static func current() -> MacModelInfo {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [UInt8](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let identifier = String(decoding: model.prefix(while: { $0 != 0 }), as: UTF8.self)
        return MacModelInfo(identifier: identifier)
    }
    
    /// Check whether this model is known to have LAS hardware.
    func hardwareSupport() -> LASHardwareSupport {
        if let name = Self.supportedModels[identifier] {
            return .supported(model: name)
        }
        if let reason = Self.unsupportedReason(for: identifier) {
            return .unsupported(reason: reason)
        }
        return .unknown(modelIdentifier: identifier)
    }
    
    // MARK: Supported Models
    
    /// Key: sysctl hw.model value. Value: human-readable name.
    private static let supportedModels: [String: String] = {
        var m: [String: String] = [:]
        
        // ── MacBook Pro 16-inch, 2019 (Intel — only Intel with LAS) ──
        m["MacBookPro16,1"] = "MacBook Pro (16-inch, 2019)"
        m["MacBookPro16,4"] = "MacBook Pro (16-inch, 2019)"
        
        // ── MacBook Pro 14-inch / 16-inch, 2021 (M1 Pro/Max) ──
        m["MacBookPro18,3"] = "MacBook Pro (14-inch, 2021)"
        m["MacBookPro18,4"] = "MacBook Pro (14-inch, 2021)"
        m["MacBookPro18,1"] = "MacBook Pro (16-inch, 2021)"
        m["MacBookPro18,2"] = "MacBook Pro (16-inch, 2021)"
        
        // ── MacBook Pro 14-inch / 16-inch, Jan 2023 (M2 Pro/Max) ──
        m["Mac14,9"]  = "MacBook Pro (14-inch, 2023)"
        m["Mac14,5"]  = "MacBook Pro (14-inch, 2023)"
        m["Mac14,10"] = "MacBook Pro (16-inch, 2023)"
        m["Mac14,6"]  = "MacBook Pro (16-inch, 2023)"
        
        // ── MacBook Pro 14-inch / 16-inch, Nov 2023 (M3) ──
        m["Mac15,3"]  = "MacBook Pro (14-inch, M3, Nov 2023)"
        m["Mac15,6"]  = "MacBook Pro (14-inch, M3 Pro, Nov 2023)"
        m["Mac15,8"]  = "MacBook Pro (14-inch, M3 Max, Nov 2023)"
        m["Mac15,7"]  = "MacBook Pro (16-inch, M3 Pro, Nov 2023)"
        m["Mac15,9"]  = "MacBook Pro (16-inch, M3 Max, Nov 2023)"
        m["Mac15,11"] = "MacBook Pro (16-inch, M3 Max, Nov 2023)"
        
        // ── MacBook Pro 14-inch / 16-inch, 2024 (M4) ──
        m["Mac16,1"]  = "MacBook Pro (14-inch, M4, 2024)"
        m["Mac16,6"]  = "MacBook Pro (14-inch, M4 Pro, 2024)"
        m["Mac16,8"]  = "MacBook Pro (14-inch, M4 Max, 2024)"
        m["Mac16,5"]  = "MacBook Pro (16-inch, M4 Pro, 2024)"
        m["Mac16,7"]  = "MacBook Pro (16-inch, M4 Pro, 2024)"
        m["Mac16,9"]  = "MacBook Pro (16-inch, M4 Max, 2024)"
        m["Mac16,10"] = "MacBook Pro (16-inch, M4 Max, 2024)"
        
        // ── MacBook Air (M2+) ──
        m["Mac14,2"]  = "MacBook Air (M2, 2022)"
        m["Mac14,15"] = "MacBook Air (15-inch, M2, 2023)"
        m["Mac16,12"] = "MacBook Air (13-inch, M4, 2025)"
        m["Mac16,13"] = "MacBook Air (15-inch, M4, 2025)"
        
        // M3 Air identifiers — add when confirmed from user reports
        
        return m
    }()
    
    // MARK: Unsupported Reasons
    
    private static func unsupportedReason(for id: String) -> String? {
        // Desktops
        let desktopPrefixes = ["Macmini", "MacPro", "iMac"]
        if desktopPrefixes.contains(where: { id.hasPrefix($0) }) {
            return "Desktop Macs do not have a lid angle sensor."
        }
        // Mac Studio
        let studioIDs: Set = ["Mac13,1", "Mac13,2", "Mac14,13", "Mac14,14"]
        if studioIDs.contains(id) {
            return "Mac Studio does not have a lid angle sensor."
        }
        // Known desktop-only Mac16 identifiers
        let desktopMac16: Set = ["Mac16,2", "Mac16,3", "Mac16,4", "Mac16,11"]
        if desktopMac16.contains(id) {
            return "Desktop Macs do not have a lid angle sensor."
        }
        
        // 13-inch MacBook Pro — never had LAS
        let mbp13: Set = [
            "MacBookPro17,1", "Mac14,7",
            "MacBookPro15,2", "MacBookPro15,4",
            "MacBookPro16,2", "MacBookPro16,3",
        ]
        if mbp13.contains(id) {
            return "The 13-inch MacBook Pro does not have a lid angle sensor."
        }
        
        // Pre-2019 MacBook Pro
        let oldPrefixes = [
            "MacBookPro15,1", "MacBookPro15,3",
            "MacBookPro14,", "MacBookPro13,",
            "MacBookPro12,", "MacBookPro11,", "MacBookPro10,",
        ]
        if oldPrefixes.contains(where: { id.hasPrefix($0) || id == $0 }) {
            return "This MacBook Pro predates the lid angle sensor (introduced 2019, 16-inch)."
        }
        
        // Pre-M2 MacBook Air
        if id.hasPrefix("MacBookAir") {
            return "Only MacBook Air models from M2 (2022) onward have a lid angle sensor."
        }
        
        // 12-inch MacBook (2015–2019)
        if id.hasPrefix("MacBook") && !id.hasPrefix("MacBookPro") && !id.hasPrefix("MacBookAir") {
            return "The 12-inch MacBook does not have a lid angle sensor."
        }
        
        // MacBook Neo
        if id == "Mac17,5" {
            return "The MacBook Neo does not have a lid angle sensor."
        }
        
        return nil
    }
}

// MARK: - Runtime HID Probing

extension MacModelInfo {
    
    private static let noOptions = IOOptionBits(kIOHIDOptionsTypeNone)
    
    /// Probe HID subsystem for the lid angle sensor.
    static func probeSensor() -> LASSensorProbeResult {
        // Strategy 1: Standard Sensor page (0x0020) + Orientation (0x008A)
        if let device = findHIDDevice(usagePage: 0x0020, usage: 0x008A) {
            return .foundStandard(device: device)
        }
        
        // Strategy 2: Check if 0x8104 exists under any usage page
        if deviceExistsWithProductID(0x8104) {
            return .foundVendorSpecific
        }
        
        return .notFound
    }
    
    private static func findHIDDevice(usagePage: Int, usage: Int) -> IOHIDDevice? {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, noOptions)
        guard IOHIDManagerOpen(manager, noOptions) == kIOReturnSuccess else { return nil }
        defer { IOHIDManagerClose(manager, noOptions) }
        
        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: 0x05AC,
            kIOHIDProductIDKey as String: 0x8104,
            "UsagePage": usagePage,
            "Usage": usage,
        ]
        
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              !devices.isEmpty
        else { return nil }
        
        for device in devices {
            guard IOHIDDeviceOpen(device, noOptions) == kIOReturnSuccess else { continue }
            defer { IOHIDDeviceClose(device, noOptions) }
            
            var report = [UInt8](repeating: 0, count: 8)
            var length = CFIndex(report.count)
            
            let result = IOHIDDeviceGetReport(
                device,
                kIOHIDReportTypeFeature,
                1,
                &report,
                &length
            )
            
            if result == kIOReturnSuccess, length >= 3 {
                return device
            }
        }
        
        return nil
    }
    
    private static func deviceExistsWithProductID(_ productID: Int) -> Bool {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, noOptions)
        guard IOHIDManagerOpen(manager, noOptions) == kIOReturnSuccess else { return false }
        defer { IOHIDManagerClose(manager, noOptions) }
        
        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: 0x05AC,
            kIOHIDProductIDKey as String: productID,
        ]
        
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            return false
        }
        return !devices.isEmpty
    }
}

// MARK: - Diagnostic Report

struct LASDiagnostic {
    let modelInfo: MacModelInfo
    let hardwareSupport: LASHardwareSupport
    let probeResult: LASSensorProbeResult
    
    /// Human-readable status for the UI.
    var statusMessage: String {
        switch probeResult {
        case .foundStandard:
            if case .unknown(let id) = hardwareSupport {
                "Sensor detected. (Model \(id) is not yet in our compatibility database — consider opening a GitHub issue so we can add it!)"
            } else {
                "Sensor detected and ready."
            }
            
        case .foundVendorSpecific:
            if case .supported(let model) = hardwareSupport {
                "Your \(model) has the sensor hardware, but it's exposed under a vendor-specific HID interface that isn't supported yet."
            } else {
                "Found sensor hardware (0x8104) under a vendor-specific HID interface (UsagePage 0xFF00) that isn't supported yet."
            }
            
        case .notFound:
            switch hardwareSupport {
            case .supported(let model):
                "Your \(model) should have a lid angle sensor, but it wasn't detected. Try restarting your Mac."
            case .unsupported(let reason):
                reason
            case .unknown:
                "No lid angle sensor detected on this Mac."
            }
        }
    }
    
    var isSensorUsable: Bool {
        if case .foundStandard = probeResult { return true }
        return false
    }
    
    /// Cached at first access; subsequent calls are free.
    static let shared: LASDiagnostic = {
        let model = MacModelInfo.current()
        let support = model.hardwareSupport()
        let probe = MacModelInfo.probeSensor()
        
        let diag = LASDiagnostic(modelInfo: model, hardwareSupport: support, probeResult: probe)
        
        print("[LAS] Model: \(model.identifier)")
        print("[LAS] Hardware support: \(support)")
        print("[LAS] Probe: \(probe)")
        print("[LAS] Status: \(diag.statusMessage)")
        
        return diag
    }()
    
    static func run() -> LASDiagnostic { shared }
}
