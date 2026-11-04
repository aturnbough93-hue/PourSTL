import SwiftData
import OSLog

private let persistenceLogger = Logger(subsystem: "com.devin.pour", category: "Persistence")

extension ModelContext {
    @discardableResult
    func saveIfNeeded(operation: String) -> Bool {
        do {
            try save()
            return true
        } catch {
            persistenceLogger.error("Failed to save model context during \(operation): \(error.localizedDescription, privacy: .public)")
            assertionFailure("SwiftData save failed during \(operation): \(error.localizedDescription)")
            return false
        }
    }
}
