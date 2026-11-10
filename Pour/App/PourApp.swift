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

/// Opens the same persistent store on every attempt. A failed open never creates
/// a replacement store, clears data, or mounts views that could seed new data.
@Observable
final class PersistentStoreController {
    private(set) var container: ModelContainer?
    private(set) var hasAttemptedOpen = false
    private let openContainer: () throws -> ModelContainer

    init(openContainer: @escaping () throws -> ModelContainer) {
        self.openContainer = openContainer
    }

    convenience init() {
        self.init(openContainer: PersistentStoreController.openDefaultContainer)
    }

    func openIfNeeded() {
        guard !hasAttemptedOpen else { return }
        retry()
    }

    func retry() {
        // Keep a successfully loaded store and its active contexts intact.
        guard container == nil else { return }
        do {
            container = try openContainer()
        } catch {
            // Leave the original store untouched so a later attempt can recover.
        }
        hasAttemptedOpen = true
    }

    private static func openDefaultContainer() throws -> ModelContainer {
        let schema = Schema([
            Recipe.self,
            IngredientLine.self,
            InventoryItem.self,
            ShoppingListItem.self,
            Venue.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

@main
struct PourApp: App {
    @State private var store = PersistentStoreController()
    @State private var settings = AppSettings()
    @State private var router = DeepLinkRouter()
    @State private var pro = ProEntitlementStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = store.container {
                    ContentView()
                        .modelContainer(container)
                } else if store.hasAttemptedOpen {
                    StoreRecoveryView { store.retry() }
                } else {
                    ProgressView("Opening your bar…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(PourColor.background)
                }
            }
            .environment(settings)
            .environment(router)
            .environment(pro)
            .preferredColorScheme(settings.appearance.colorScheme)
            .tint(PourColor.accent)
            .task { store.openIfNeeded() }
            .task {
                // XCTest hosts this app. Tests open the StoreKit session themselves.
                guard !ProRuntime.isUnitTestHost else { return }
                await pro.start()
            }
            .onOpenURL { router.handle($0) }
        }
    }
}

private struct StoreRecoveryView: View {
    let retry: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundStyle(PourColor.accent)
                    .accessibilityHidden(true)
                Text("Your bar needs a moment")
                    .font(.pourTitle)
                    .foregroundStyle(PourColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Pour couldn’t open your saved recipes and inventory. Your data has not been erased. Try again, or close and reopen Pour.")
                    .font(.body)
                    .foregroundStyle(PourColor.textSecondary)
                Button("Retry", action: retry)
                    .buttonStyle(PourPrimaryButtonStyle())
                Link("Get help", destination: URL(string: "https://github.com/aturnbough93-hue/pour/issues")!)
                    .font(.body.weight(.semibold))
                    .frame(minHeight: 44)
            }
            .multilineTextAlignment(.center)
            .padding(28)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
            .padding(.top, 72)
        }
        .background(PourColor.background)
    }
}
