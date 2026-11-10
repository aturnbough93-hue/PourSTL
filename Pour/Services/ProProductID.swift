import Foundation

/// Placeholder StoreKit product identifiers for local testing.
/// Change them here when App Store Connect products exist. Do not copy the IDs elsewhere.
enum ProProductID {
    static let monthly = "com.devin.pour.pro.monthly"
    static let yearly = "com.devin.pour.pro.yearly"

    /// Display order: monthly, then yearly.
    static let ordered: [String] = [monthly, yearly]
    static var all: Set<String> { Set(ordered) }

    /// Local StoreKit configuration file name, without the extension.
    static let configurationName = "Pour"

    /// Existing site page. There is no terms page on the site, so none is linked.
    static let privacyPolicyURL = URL(string: "https://barpour.pages.dev/privacy.html")!
}
