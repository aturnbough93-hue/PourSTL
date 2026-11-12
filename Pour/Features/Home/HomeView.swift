import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @Query private var inventory: [InventoryItem]
    @Query private var venues: [Venue]
    @Environment(DeepLinkRouter.self) private var router
    @Environment(AppSettings.self) private var settings

    @State private var searchText = ""
    @State private var selectedTag: String? = nil
    @State private var availability: AvailabilityFilter = .all
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum AvailabilityFilter: String, CaseIterable {
        case all = "All drinks", ready = "Can make", almost = "Almost there"
    }
    @State private var path = NavigationPath()
    @State private var showAssistant = false
    @State private var showVoiceStub = false
    @State private var showSettings = false
    @State private var showVenueSheet = false
    @State private var showNewRecipe = false

    private var checkedInVenue: Venue? { venues.first { $0.isCheckedIn } }

    private var filteredRecipes: [Recipe] {
        let searched = RecipeEngine.search(recipes: recipes, query: searchText, tag: selectedTag)
        guard availability != .all else { return searched }
        let eligible = Set(ranked.filter {
            availability == .ready ? $0.canMake : $0.isAlmost
        }.map { $0.recipe.persistentModelID })
        return searched.filter { eligible.contains($0.persistentModelID) }
    }

    private var ranked: [RecipeMatch] {
        RecipeEngine.rankedMatches(recipes: recipes, inventory: inventory)
    }

    private var makeable: [RecipeMatch] { ranked.filter { $0.canMake } }
    private var almost: [RecipeMatch] { ranked.filter { $0.isAlmost } }

    /// Most frequent tags across the library become filter chips.
    private var filterTags: [String] {
        var counts: [String: Int] = [:]
        for recipe in recipes {
            for tag in recipe.tags { counts[tag, default: 0] += 1 }
        }
        return counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.map(\.key).prefix(12).map { $0 }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let venue = checkedInVenue {
                        venueIndicator(venue)
                    }
                    whatCanIMakeSection
                    availabilityPicker
                    filterChips
                    drinkGrid
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(PourColor.background)
            .refreshable {
                // Recipes are local; a refresh still re-runs matching and
                // gives users the expected pull-to-refresh behavior.
                Haptics.selection()
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search drinks, ingredients, tags")
            .navigationTitle("Pour")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewRecipe = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(PourColor.accent)
                    }
                    .accessibilityLabel("New recipe")
                    .accessibilityAddTraits(.isButton)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showAssistant = true } label: {
                            Label("AI Bartender Assistant", systemImage: "sparkles")
                        }
                        Section("Coming soon") {
                            Button { showVoiceStub = true } label: {
                                Label("Voice search", systemImage: "mic")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(PourColor.textSecondary)
                    }
                    .accessibilityLabel("More features")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(PourColor.textSecondary)
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityAddTraits(.isButton)
                }
            }
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .sheet(isPresented: $showAssistant) { AssistantSheet() }
            .sheet(isPresented: $showVoiceStub) { VoiceSearchPlaceholderView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showVenueSheet) { VenueSheet() }
            .sheet(isPresented: $showNewRecipe) { RecipeEditorView() }
        }
        .onChange(of: router.pendingRecipeName, initial: true) { _, _ in
            openPendingRecipe()
        }
        .onChange(of: recipes.count) { _, _ in
            openPendingRecipe()
        }
    }

    private func openPendingRecipe() {
        guard let name = router.pendingRecipeName, !recipes.isEmpty else { return }
        if let recipe = recipes.first(where: {
            IngredientNormalizer.normalize($0.name) == IngredientNormalizer.normalize(name)
        }) {
            path.append(recipe)
        }
        router.pendingRecipeName = nil
    }

    private var availabilityPicker: some View {
        Picker("Availability", selection: $availability) {
            ForEach(AvailabilityFilter.allCases, id: \.self) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Filter drinks by availability")
    }

    // MARK: - Venue indicator

    private func venueIndicator(_ venue: Venue) -> some View {
        Button {
            showVenueSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(PourColor.accent)
                Text(venue.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PourColor.textPrimary)
                Spacer()
                Text("Checked in")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PourColor.canMake)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(PourColor.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(PourColor.border))
        }
        .accessibilityLabel("Checked in to \(venue.name)")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - What can I make

    @ViewBuilder
    private var whatCanIMakeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PourSectionHeader(
                title: "What can I make",
                trailing: inventory.isEmpty ? nil : "\(makeable.count) drinks"
            )
            .accessibilityLabel("What can I make, \(makeable.count) drinks")

            if inventory.isEmpty {
                moduleCard {
                    HStack(spacing: 12) {
                        Image(systemName: "tray.full")
                            .font(.title2)
                            .foregroundStyle(PourColor.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Stock your bar")
                                .font(.headline)
                                .foregroundStyle(PourColor.textPrimary)
                            Text("Add bottles in My Bar and this fills in instantly.")
                                .font(.subheadline)
                                .foregroundStyle(PourColor.textSecondary)
                        }
                        Spacer()
                        Button {
                            router.pendingTab = .bar
                        } label: {
                            Text("Add items")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(PourColor.accentFill, in: Capsule())
                        }
                        .accessibilityLabel("Add items to My Bar")
                        .accessibilityAddTraits(.isButton)
                    }
                }
            } else if makeable.isEmpty {
                moduleCard {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundStyle(PourColor.almost)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Nothing fully stocked yet")
                                .font(.headline)
                                .foregroundStyle(PourColor.textPrimary)
                            Text("\(almost.count) drinks need only 1–2 ingredients.")
                                .font(.subheadline)
                                .foregroundStyle(PourColor.textSecondary)
                        }
                        Spacer()
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(makeable.prefix(10), id: \.recipe.persistentModelID) { match in
                            Button {
                                path.append(match.recipe)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(PourColor.canMake)
                                    Text(match.recipe.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(PourColor.textPrimary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(PourColor.card, in: Capsule())
                                .overlay(Capsule().stroke(PourColor.border))
                            }
                            .accessibilityLabel("\(match.recipe.name), can make")
                            .accessibilityAddTraits(.isButton)
                        }
                    }
                }
                .frame(minHeight: 44)
            }
        }
    }

    private func moduleCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(PourColor.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(PourColor.border))
    }

    // MARK: - Filter chips

    @ViewBuilder
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filterTags, id: \.self) { tag in
                    let selected = selectedTag == tag
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.3)) {
                            selectedTag = selected ? nil : tag
                        }
                        Haptics.selection()
                    } label: {
                        Text(tag.capitalized)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(selected ? .black : PourColor.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selected ? PourColor.accentFill : PourColor.surface, in: Capsule())
                    }
                    .accessibilityLabel("\(tag), \(selected ? "selected" : "not selected")")
                    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
        .frame(minHeight: 40)
    }

    // MARK: - Grid

    @ViewBuilder
    private var drinkGrid: some View {
        if filteredRecipes.isEmpty {
            EmptyStateView(
                symbol: "wineglass",
                title: searchText.isEmpty ? "No drinks found" : "No results for “\(searchText)”",
                message: searchText.isEmpty ? "Try a different filter." : "Check the spelling or search an ingredient like “gin” or “Campari”.",
                actionTitle: searchText.isEmpty && selectedTag == nil && availability == .all ? nil : "Clear filters",
                action: searchText.isEmpty && selectedTag == nil && availability == .all ? nil : {
                    searchText = ""
                    selectedTag = nil
                    availability = .all
                }
            )
        } else {
            DrinkCardGrid(
                recipes: filteredRecipes,
                inventory: inventory,
                matches: Dictionary(uniqueKeysWithValues: ranked.map { ($0.recipe.persistentModelID, $0) })
            ) { recipe in
                path.append(recipe)
            }
        }
    }
}

// MARK: - Drink cards (shared by Home + Favorites)

struct DrinkCardGrid: View {
    let recipes: [Recipe]
    let inventory: [InventoryItem]
    var matches: [PersistentIdentifier: RecipeMatch]? = nil
    var onSelect: ((Recipe) -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(recipes) { recipe in
                DrinkCard(
                    recipe: recipe,
                    match: matches?[recipe.persistentModelID]
                        ?? RecipeEngine.match(recipe, inventory: inventory),
                    onSelect: onSelect
                )
            }
        }
        .accessibilityLabel("Drinks, \(recipes.count)")
    }
}

struct DrinkCard: View {
    let recipe: Recipe
    let match: RecipeMatch
    var onSelect: ((Recipe) -> Void)? = nil

    var body: some View {
        card.onSelectHandler(onSelect, recipe: recipe)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(PourColor.surface)
                    .overlay {
                        Image(systemName: GlassIcon.fillSymbol(for: recipe.glassType))
                            .font(.system(size: 44, weight: .regular))
                            .foregroundStyle(PourColor.accent.opacity(0.30))
                            .accessibilityHidden(true)
                    }
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.6)],
                            startPoint: .top, endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(PourColor.border))
                    .frame(height: 110)

                Text(recipe.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .padding(10)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: GlassIcon.symbol(for: recipe.glassType))
                        .font(.caption)
                        .foregroundStyle(PourColor.textTertiary)
                        .accessibilityHidden(true)
                    Text(recipe.glassType)
                        .font(.caption)
                        .foregroundStyle(PourColor.textTertiary)
                }
                HStack(spacing: 6) {
                    if match.canMake {
                        StatusPill(kind: .canMake)
                    } else if match.isAlmost {
                        StatusPill(kind: .almost)
                    }
                    if recipe.isCustom {
                        StatusPill(kind: .custom)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(PourColor.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(PourColor.border))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(recipe.name), \(recipe.glassType), \(match.canMake ? "can make" : match.isAlmost ? "missing \(match.missing.count) ingredient\(match.missing.count == 1 ? "" : "s")" : "not stocked")")
    }
}

private extension View {
    @ViewBuilder
    func onSelectHandler(_ onSelect: ((Recipe) -> Void)?, recipe: Recipe) -> some View {
        if let onSelect {
            Button {
                onSelect(recipe)
            } label: {
                self
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityAddTraits(.isButton)
        } else {
            NavigationLink(value: recipe) {
                self
            }
            .buttonStyle(PressScaleStyle())
        }
    }
}

/// Subtle scale-down on press, respects Reduce Motion automatically.
struct PressScaleStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25), value: configuration.isPressed)
    }
}
