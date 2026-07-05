import Foundation
import ApplicationServices
import AVFoundation
import ScreenCaptureKit

public enum PermissionState: String, Codable, Sendable, Equatable {
    case notRequested
    case granted
    case denied
    case restricted
}

public enum PermissionType: String, Codable, Sendable, CaseIterable {
    case accessibility
    case screenRecording
    case microphone
    case notifications
    case fullDiskAccess
}

public actor PermissionsManager {
    public static let shared = PermissionsManager()

    private var cachedStates: [PermissionType: PermissionState] = [:]

    private init() {}

    // MARK: - Public API

    public func requestAll() async -> [PermissionType: PermissionState] {
        var results: [PermissionType: PermissionState] = [:]
        for type in PermissionType.allCases {
            results[type] = await request(type)
        }
        return results
    }

    public func request(_ type: PermissionType) async -> PermissionState {
        let state = await requestImpl(type)
        cachedStates[type] = state
        return state
    }

    public func currentState(_ type: PermissionType) -> PermissionState {
        cachedStates[type] ?? checkCached(type)
    }

    public func refreshAll() {
        for type in PermissionType.allCases {
            cachedStates[type] = checkCached(type)
        }
    }

    // MARK: - Status Check

    public func checkAccessibility() -> PermissionState {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: false]
        return AXIsProcessTrustedWithOptions(options) ? .granted : .notRequested
    }

    public func checkScreenRecording() -> PermissionState {
        if #available(macOS 14, *) {
            return CGPreflightScreenCaptureAccess() ? .granted : .notRequested
        } else {
            return .notRequested
        }
    }

    public func checkMicrophone() -> PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notRequested
        @unknown default: return .notRequested
        }
    }

    // MARK: - Private

    private func requestImpl(_ type: PermissionType) async -> PermissionState {
        switch type {
        case .accessibility:
            return requestAccessibility()
        case .screenRecording:
            return await requestScreenRecording()
        case .microphone:
            return await requestMicrophone()
        case .notifications:
            return .notRequested
        case .fullDiskAccess:
            return checkFullDiskAccess()
        }
    }

    private func checkCached(_ type: PermissionType) -> PermissionState {
        switch type {
        case .accessibility: return checkAccessibility()
        case .screenRecording: return checkScreenRecording()
        case .microphone: return checkMicrophone()
        case .notifications: return .notRequested
        case .fullDiskAccess: return checkFullDiskAccess()
        }
    }

    private func requestAccessibility() -> PermissionState {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        return AXIsProcessTrustedWithOptions(options) ? .granted : .denied
    }

    private func requestScreenRecording() async -> PermissionState {
        if #available(macOS 14, *) {
            CGRequestScreenCaptureAccess()
            return checkScreenRecording()
        } else {
            return .notRequested
        }
    }

    private func requestMicrophone() async -> PermissionState {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted ? .granted : .denied)
            }
        }
    }

    private func checkFullDiskAccess() -> PermissionState {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let testPath = home.appendingPathComponent(".full-disk-access-test").path
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return .granted
        } catch {
            return .denied
        }
    }

    // MARK: - Open Settings

    public nonisolated static func openPrivacySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
    }

    public nonisolated static func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    public nonisolated static func openScreenRecordingSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }

    public static func requiredPermissionsMet() async -> Bool {
        let states = await shared.requestAll()
        return states[.accessibility] == .granted
    }
}
