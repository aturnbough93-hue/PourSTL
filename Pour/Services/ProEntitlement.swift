import Foundation
import StoreKit

/// A verified transaction reduced to the fields that decide Pour Pro access.
struct ProTransactionSnapshot: Equatable, Sendable {
    var productID: String
    var revocationDate: Date?
    var expirationDate: Date?
    var transactionID: UInt64? = nil
    var purchaseDate: Date? = nil
    var isUpgraded: Bool = false
}

/// Pure entitlement rules. StoreKit current entitlements are the source of truth;
/// these checks reject revoked, expired, and unknown products if one slips through.
enum ProEntitlementDecision {
    static func isActive(_ transaction: ProTransactionSnapshot, knownProductIDs: Set<String>, now: Date) -> Bool {
        guard knownProductIDs.contains(transaction.productID) else { return false }
        if transaction.revocationDate != nil { return false }
        if transaction.isUpgraded { return false }
        if let expirationDate = transaction.expirationDate, expirationDate <= now { return false }
        return true
    }

    static func activeProductIDs(in transactions: [ProTransactionSnapshot], knownProductIDs: Set<String>, now: Date) -> Set<String> {
        Set(transactions.compactMap { transaction in
            isActive(transaction, knownProductIDs: knownProductIDs, now: now) ? transaction.productID : nil
        })
    }
}

/// Capabilities that exist in the app today, plus the planned Pro surfaces.
enum PourCapability: String, CaseIterable, Equatable {
    case recipes
    case inventory
    case shoppingList
    case timers
    case customRecipes
    case search
    case settings
    case barcodeScanner
    case venueCheckIn
    case aiAssistant
    case aiVideo
    case costingExport
    case sharedTeams
    case cloudSync
}

struct ProPlannedFeature: Identifiable, Equatable {
    let id: String
    let symbol: String
    let text: String
}

/// What a missing purchase is allowed to hide.
/// Free offline tools, including barcode scanning, stay available.
/// Pro placeholders are not paywalled in this build because they are not shipped.
enum ProGate {
    static let placeholdersArePaywalled = false

    static let freeOffline: Set<PourCapability> = [
        .recipes, .inventory, .shoppingList, .timers, .customRecipes,
        .search, .settings, .barcodeScanner, .venueCheckIn, .aiAssistant,
    ]

    static let proPlaceholders: Set<PourCapability> = [
        .aiVideo, .costingExport, .sharedTeams, .cloudSync,
    ]

    static let plannedFeatures: [ProPlannedFeature] = [
        ProPlannedFeature(id: "video", symbol: "video", text: "AI video generation for technique demos"),
        ProPlannedFeature(id: "costing", symbol: "square.stack.3d.up", text: "Bottle-level tracking, costing and export"),
        ProPlannedFeature(id: "teams", symbol: "person.2", text: "Shared inventory and venue teams"),
        ProPlannedFeature(id: "cloud", symbol: "icloud", text: "CloudKit sync across devices"),
    ]

    static func isLocked(_ capability: PourCapability, isPro: Bool) -> Bool {
        if freeOffline.contains(capability) {
            return false
        }
        guard placeholdersArePaywalled, proPlaceholders.contains(capability) else {
            return false
        }
        return !isPro
    }
}

enum ProProductsState: Equatable {
    case idle
    case loading
    case loaded
    case unavailable
}

/// Only verified StoreKit transactions may enter the entitlement decision.
/// Separating purchase outcomes also lets tests exercise every result without
/// relying on whether an unsigned simulator can present an App Store sheet.
enum ProPurchaseOutcome {
    case verified(ProTransactionSnapshot)
    case unverified
    case pending
    case cancelled
    case unexpected
}

enum ProPurchaseStatus: Equatable {
    case idle
    case inProgress
    case succeeded
    case pending
    case cancelled
    case failed(String)

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }

    var message: String? {
        switch self {
        case .pending: return ProStoreCopy.pending
        case .cancelled: return ProStoreCopy.cancelled
        case .failed(let message): return message
        case .idle, .inProgress, .succeeded: return nil
        }
    }

    var announcement: String? {
        switch self {
        case .succeeded: return ProStoreCopy.proActive
        case .pending, .cancelled, .failed: return message
        case .idle, .inProgress: return nil
        }
    }
}

enum ProRestoreStatus: Equatable {
    case idle
    case inProgress
    case restored
    case nothingToRestore
    case failed(String)

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }

    var message: String? {
        switch self {
        case .nothingToRestore: return ProStoreCopy.nothingToRestore
        case .failed(let message): return message
        case .idle, .inProgress, .restored: return nil
        }
    }

    var announcement: String? {
        switch self {
        case .restored: return ProStoreCopy.restored
        case .nothingToRestore, .failed: return message
        case .idle, .inProgress: return nil
        }
    }
}

enum ProStoreCopy {
    static let pending = "This purchase is waiting for approval. Pour Pro unlocks after the App Store approves it."
    static let cancelled = "Purchase cancelled."
    static let unverified = "The App Store couldn’t verify this purchase."
    static let notIncluded = "This purchase doesn’t include Pour Pro."
    static let unexpected = "The App Store returned an unexpected result."
    static let purchaseFailed = "The purchase didn’t go through. Check your connection and try again."
    static let productMissing = "That subscription is no longer available. Try again."
    static let restored = "Purchases restored. Pour Pro is active."
    static let nothingToRestore = "No Pour Pro subscription was found for this Apple ID."
    static let restoreFailed = "Restore didn’t finish. Try again when you have a connection."
    static let proActive = "Pour Pro is active."
    static let manageUnavailable = "Subscriptions can’t be managed from here."
    static let manageFailed = "Subscriptions couldn’t be opened. Try again from the App Store."
}

enum ProPurchaseInterpreter {
    /// Immediate outcomes that do not need a verified transaction.
    /// A successful purchase returns nil so the caller can verify it first.
    static func status(for result: Product.PurchaseResult) -> ProPurchaseStatus? {
        switch result {
        case .success:
            return nil
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .failed(ProStoreCopy.unexpected)
        }
    }

    static func successStatus(verified: Bool, unlocksPro: Bool) -> ProPurchaseStatus {
        if !verified { return .failed(ProStoreCopy.unverified) }
        if !unlocksPro { return .failed(ProStoreCopy.notIncluded) }
        return .succeeded
    }
}

enum ProRestoreInterpreter {
    static func status(isPro: Bool) -> ProRestoreStatus {
        isPro ? .restored : .nothingToRestore
    }
}

enum ProProductFormatting {
    static func periodText(for product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return "subscription" }
        let count = period.value
        let unit: String
        switch period.unit {
        case .day: unit = count == 1 ? "day" : "days"
        case .week: unit = count == 1 ? "week" : "weeks"
        case .month: unit = count == 1 ? "month" : "months"
        case .year: unit = count == 1 ? "year" : "years"
        @unknown default: unit = "period"
        }
        if count == 1 { return unit }
        return "\(count) \(unit)"
    }

    static func offerTitle(for product: Product) -> String {
        "\(product.displayName), \(product.displayPrice) per \(periodText(for: product))"
    }
}

struct ProProductOffer: Identifiable, Equatable {
    let id: String
    let title: String
}

/// Skips the app-wide StoreKit listener while XCTest is hosting the app,
/// so tests can open their own SKTestSession before any StoreKit call.
enum ProRuntime {
    static var isUnitTestHost: Bool {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return true
        }
        if NSClassFromString("XCTestCase") != nil {
            return true
        }
        return Bundle.allBundles.contains { $0.bundlePath.hasSuffix(".xctest") }
    }
}
