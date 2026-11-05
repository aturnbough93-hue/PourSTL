import SwiftUI
import SwiftData

enum AppTab: String {
    case home, bar, shopping, favorites
}

/// Routes `pour://` deep links (seam for App Intents / Spotlight later):
/// - pour://tab/bar, pour://tab/shopping, pour://tab/favorites
/// - pour://recipe?name=Negroni
@Observable
final class DeepLinkRouter {
    var pendingTab: AppTab? = nil
    var pendingRecipeName: String? = nil

    func handle(_ url: URL) {
        guard url.scheme == "pour" else { return }
        switch url.host {
        case "tab":
            if let raw = url.pathComponents.dropFirst().first,
               let tab = AppTab(rawValue: raw) {
                pendingTab = tab
            }
        case "recipe":
            if let name = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "name" })?.value,
               !name.isEmpty {
                pendingTab = .home
                pendingRecipeName = name
            } else if let raw = url.pathComponents.dropFirst().first {
                pendingTab = .home
                pendingRecipeName = raw.removingPercentEncoding
            }
        default:
            break
        }
    }
}

@main
struct PourApp: App {
    let container: ModelContainer
    @State private var settings = AppSettings()
    @State private var router = DeepLinkRouter()

    init() {
        let schema = Schema([
            Recipe.self,
            IngredientLine.self,
            InventoryItem.self,
            ShoppingListItem.self,
            Venue.self,
        ])
        // Local-only today; a CloudKit ModelConfiguration can be added for Pro sync.
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .environment(settings)
                .environment(router)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
    }
}
