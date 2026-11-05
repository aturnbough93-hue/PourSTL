import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(DeepLinkRouter.self) private var router
    @State private var tab: AppTab = .home
    @State private var showSeedError = false

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)
            MyBarView()
                .tabItem { Label("My Bar", systemImage: "square.stack.3d.up") }
                .tag(AppTab.bar)
            ShoppingListView()
                .tabItem { Label("Shopping", systemImage: "cart") }
                .tag(AppTab.shopping)
            FavoritesView()
                .tabItem { Label("Favorites", systemImage: "heart") }
                .tag(AppTab.favorites)
        }
        .tint(PourColor.accent)
        .task {
            seedLibrary()
            #if DEBUG
            // Screenshot/demo seam: `simctl launch … -deepLink pour://…` routes
            // through the same handler as a real URL open.
            if let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-deepLink=") }),
               let url = URL(string: String(arg.dropFirst("-deepLink=".count))) {
                router.handle(url)
            }
            #endif
        }
        .onChange(of: router.pendingTab, initial: true) { _, pending in
            if let pending {
                tab = pending
                router.pendingTab = nil
            }
        }
        .alert("Recipe library couldn’t load", isPresented: $showSeedError) {
            Button("Retry") { seedLibrary() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your existing data has not been replaced. Check available device storage and try again.")
        }
        .sheet(isPresented: onboardingVisible) {
            OnboardingView()
                .interactiveDismissDisabled(false)
        }
    }

    private func seedLibrary() {
        do { try SeedData.seedIfNeeded(in: modelContext) }
        catch { showSeedError = true }
    }

    private var onboardingVisible: Binding<Bool> {
        Binding(
            get: { !settings.hasCompletedOnboarding },
            set: { if !$0 { settings.hasCompletedOnboarding = true } }
        )
    }
}

/// Favorites tab — the seeded/custom library filtered to favorited recipes.
struct FavoritesView: View {
    @Query private var recipes: [Recipe]
    @Query private var inventory: [InventoryItem]
    @Environment(DeepLinkRouter.self) private var router

    private var favorites: [Recipe] { recipes.filter { $0.isFavorite }.sorted { $0.name < $1.name } }

    var body: some View {
        NavigationStack {
            Group {
                if favorites.isEmpty {
                    EmptyStateView(
                        symbol: "heart",
                        title: "No favorites yet",
                        message: "Tap the heart on any recipe to keep it here for quick service."
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        DrinkCardGrid(recipes: favorites, inventory: inventory)
                            .padding()
                    }
                }
            }
            .background(PourColor.background)
            .navigationTitle("Favorites")
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
        }
        .background(PourColor.background)
    }
}
