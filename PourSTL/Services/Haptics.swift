import UIKit

/// Calibrated haptic patterns: timer milestones (10s, 5s, completion), success,
/// warning and confirmation. All respect system haptic settings automatically.
enum Haptics {
    static func lightTick() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
    }

    static func mediumTap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 1.0)
    }

    static func rigidTap() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
