import Foundation

/// Placeholder StoreKit product identifiers for local testing.
/// Change them here when App Store Connect products exist. Do not copy the IDs elsewhere.
enum ProProductID {
    static let monthly = "com.pourstl.app.pro.monthly"
    static let yearly = "com.pourstl.app.pro.yearly"

    /// Display order: monthly, then yearly.
    static let ordered: [String] = [monthly, yearly]
    static var all: Set<String> { Set(ordered) }

    /// Local StoreKit configuration file name, without the extension.
    static let configurationName = "PourSTL"

    /// Existing site page.
    static let privacyPolicyURL = URL(string: "https://pourstl.pages.dev/privacy")!

    /// Apple’s standard Licensed Application End User License Agreement.
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
