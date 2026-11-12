import Foundation

/// Debug-only launch switches for the simulator QA pass.
///
/// `-demoInventory` remains the seeding path in `SeedData`. `-uiTesting` does not
/// add bottles. It skips onboarding and, when asked, feeds `BarcodeCameraPolicy`
/// a simulated authorization. Neither flag changes a normal launch.
enum LaunchConfiguration {
    static func cameraStatus(in arguments: [String]) -> CameraAuthorizationState? {
        guard let raw = arguments.first(where: { $0.hasPrefix("-cameraStatus=") }) else { return nil }
        switch String(raw.dropFirst("-cameraStatus=".count)) {
        case "denied": return .denied
        case "restricted": return .restricted
        case "authorized": return .authorized
        case "notDetermined": return .notDetermined
        default: return nil
        }
    }

    /// A simulated authorization is only applied for `-uiTesting`. The policy still
    /// decides the screen, and a normal launch always gets `nil` here.
    static func simulatedReadiness(arguments: [String], uiTesting: Bool) -> BarcodeCameraReadiness? {
        guard uiTesting, let status = cameraStatus(in: arguments) else { return nil }
        return BarcodeCameraPolicy.readiness(hardwarePresent: true, authorization: status)
    }

    static var isUITesting: Bool { debugFlag("-uiTesting") }

    /// UI tests launch clean so `-demoInventory` can seed the empty store.
    static var usesEphemeralStore: Bool { isUITesting }

    static func simulatedReadiness() -> BarcodeCameraReadiness? {
        simulatedReadiness(arguments: ProcessInfo.processInfo.arguments, uiTesting: isUITesting)
    }

    private static func debugFlag(_ name: String) -> Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains(name)
        #else
        return false
        #endif
    }
}
