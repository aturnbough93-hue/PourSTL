import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    @Bindable var recipe: Recipe
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Query private var inventory: [InventoryItem]

    @State private var servings: Int = 1
    /// Per-screen unit override; nil follows the global preference.
    @State private var unitOverride: UnitPreference? = nil
    @State private var showTimer = false
    @State private var showEdit = false
    @State private var addedToList = false
    @State private var showSaveError = false
    @State private var saveErrorTitle = "Changes weren’t saved"

    private var effectiveUnit: UnitPreference { unitOverride ?? settings.unit }
    private var match: RecipeMatch { RecipeEngine.match(recipe, inventory: inventory) }
    private var scaleFactor: Double { Double(servings) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    metadataPills
                    scalingControls.id("scaling")
                    ingredientsList
                    instructionsSection
                    if !recipe.isCustom { variationAction }
                    shoppingAction
                }
                .padding(.horizontal)
                .padding(.bottom, 90)
            }
            .background(PourColor.background)
            .overlay(alignment: .bottom) { actionBar(proxy: proxy) }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if recipe.isCustom {
                    Button {
                        showEdit = true
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(PourColor.textSecondary)
                    }
                    .accessibilityLabel("Edit recipe")
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
        .sheet(isPresented: $showTimer) { TimerSheet(recipeName: recipe.name) }
        .sheet(isPresented: $showEdit) {
            RecipeEditorView(recipe: recipe, makingVariation: !recipe.isCustom)
        }
        .alert(saveErrorTitle, isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check available device storage and try again.")
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(PourColor.surface)
                .overlay {
                    Image(systemName: GlassIcon.fillSymbol(for: recipe.glassType))
                        .font(.system(size: 96, weight: .regular))
                        .foregroundStyle(PourColor.accent.opacity(0.25))
                        .accessibilityHidden(true)
                }
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(PourColor.border))
                .frame(height: 180)

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.pourTitle)
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                if let garnish = recipe.garnish, !garnish.isEmpty {
                    Label(garnish, systemImage: "leaf")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(16)
        }
    }

    // MARK: - Metadata pills

    private var metadataPills: some View {
        HStack(spacing: 8) {
            metaPill(recipe.glassType, symbol: GlassIcon.symbol(for: recipe.glassType))
                .accessibilityLabel("Served in a \(recipe.glassType)")
            if !recipe.method.isEmpty {
                metaPill(recipe.method, symbol: "drop")
            }
            if match.canMake {
                metaPill("Can make", symbol: "checkmark.circle.fill", tint: PourColor.canMake)
            } else {
                metaPill(
                    "Missing \(match.missing.count)",
                    symbol: "exclamationmark.triangle",
                    tint: PourColor.almost
                )
            }
            Spacer()
        }
        .accessibilityElement(children: .contain)
    }

    private func metaPill(_ text: String, symbol: String, tint: Color = PourColor.textSecondary) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
    }

    // MARK: - Scaling + unit toggle

    private var scalingControls: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(servings == 1 ? "Servings" : "Batch of \(servings)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PourColor.textSecondary)
                HStack(spacing: 4) {
                    Button {
                        if servings > RecipeScaling.minimumServings { servings -= 1 }
                        Haptics.selection()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(servings > RecipeScaling.minimumServings ? PourColor.accent : PourColor.textTertiary)
                    }
                    .disabled(servings <= RecipeScaling.minimumServings)
                    .accessibilityLabel("Decrease servings")
                    .accessibilityAddTraits(.isButton)

                    Text("\(servings)")
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(PourColor.textPrimary)
                        .frame(minWidth: 32)
                        .accessibilityLabel("Servings, \(servings)")
                        .accessibilityAddTraits(.updatesFrequently)

                    Button {
                        if servings < RecipeScaling.maximumServings { servings += 1 }
                        Haptics.selection()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(servings < RecipeScaling.maximumServings ? PourColor.accent : PourColor.textTertiary)
                    }
                    .disabled(servings >= RecipeScaling.maximumServings)
                    .accessibilityLabel("Increase servings")
                    .accessibilityAddTraits(.isButton)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Units")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PourColor.textSecondary)
                Picker("Display units", selection: unitBinding) {
                    ForEach(UnitPreference.allCases, id: \.self) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
                .accessibilityLabel("Display units, \(effectiveUnit.rawValue)")
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(14)
        .background(PourColor.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(PourColor.border))
    }

    private var unitBinding: Binding<UnitPreference> {
        Binding(
            get: { effectiveUnit },
            set: { unitOverride = $0 }
        )
    }

    // MARK: - Ingredients

    private var ingredientsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            PourSectionHeader(title: "Ingredients")
                .padding(.bottom, 8)
            ForEach(recipe.sortedIngredients, id: \.persistentModelID) { line in
                ingredientRow(line)
                if line.persistentModelID != recipe.sortedIngredients.last?.persistentModelID {
                    Divider().overlay(PourColor.border)
                }
            }
        }
        .padding(14)
        .background(PourColor.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(PourColor.border))
    }

    private func ingredientRow(_ line: IngredientLine) -> some View {
        let isMissing = match.missing.contains { $0.persistentModelID == line.persistentModelID }
            || match.missingOptional.contains { $0.persistentModelID == line.persistentModelID }
        let measure = line.measure.scaled(by: scaleFactor).formatted(for: effectiveUnit)
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(line.name)
                        .font(.body)
                        .foregroundStyle(PourColor.textPrimary)
                    if isMissing {
                        StatusPill(kind: .missing)
                    }
                    if line.isOptional {
                        Text("optional")
                            .font(.caption)
                            .foregroundStyle(PourColor.textTertiary)
                    }
                }
                if let note = line.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(PourColor.textTertiary)
                }
            }
            Spacer(minLength: 8)
            Text(measure)
                .font(.pourMeasure)
                .foregroundStyle(PourColor.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(measure) \(line.name)\(isMissing ? ", missing" : "")")
    }

    // MARK: - Instructions

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            PourSectionHeader(title: "Method")
            Text(recipe.instructions)
                .font(.body)
                .foregroundStyle(PourColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PourColor.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(PourColor.border))
    }

    private var variationAction: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("A classic, with room for your signature", systemImage: "square.on.square")
                .font(.headline)
                .foregroundStyle(PourColor.textPrimary)
            Text("Keep this recipe and save your own version alongside it.")
                .font(.subheadline)
                .foregroundStyle(PourColor.textSecondary)
            Button("Make a variation") { showEdit = true }
                .buttonStyle(PourPrimaryButtonStyle())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PourColor.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(PourColor.border))
    }

    // MARK: - Shopping

    @ViewBuilder
    private var shoppingAction: some View {
        if !match.missing.isEmpty {
            Button {
                addMissingToShoppingList()
            } label: {
                Label(addedToList ? "Added to shopping list" : "Add missing ingredients to shopping list",
                      systemImage: addedToList ? "checkmark.circle.fill" : "cart.badge.plus")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(addedToList ? PourColor.canMake : .black)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(addedToList ? PourColor.canMake.opacity(0.15) : PourColor.accentFill,
                                in: RoundedRectangle(cornerRadius: 14))
            }
            .disabled(addedToList)
            .accessibilityLabel("Add missing ingredients to shopping list")
            .accessibilityAddTraits(.isButton)
        }
    }

    private func addMissingToShoppingList() {
        do {
            let existing = try modelContext.fetch(FetchDescriptor<ShoppingListItem>())
            for line in ShoppingListPlanner.ingredientsToAdd(match.missing + match.missingOptional, existing: existing) {
                modelContext.insert(ShoppingListItem(name: line.name, sourceRecipeName: recipe.name))
            }
            try modelContext.save()
            Haptics.success()
            withAnimation { addedToList = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { addedToList = false }
        } catch {
            modelContext.rollback()
            saveErrorTitle = "Shopping list wasn’t updated"
            showSaveError = true
        }
    }

    // MARK: - Sticky action bar

    private func actionBar(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 12) {
            actionButton(
                recipe.isFavorite ? "heart.fill" : "heart",
                label: recipe.isFavorite ? "Unfavorite" : "Favorite",
                selected: recipe.isFavorite
            ) {
                toggleFavorite()
            }
            actionButton("square.resize", label: "Scale") {
                withAnimation { proxy.scrollTo("scaling", anchor: .top) }
            }
            actionButton("timer", label: "Start timer") {
                showTimer = true
            }
            ShareLink(
                item: shareText,
                preview: SharePreview(recipe.name)
            ) {
                actionBarLabel("square.and.arrow.up", text: "Share")
            }
            .accessibilityLabel("Share recipe")
            .accessibilityAddTraits(.isButton)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().fill(PourColor.border).frame(height: 0.5), alignment: .top)
    }

    private func toggleFavorite() {
        recipe.isFavorite.toggle()
        do {
            try modelContext.save()
            recipe.isFavorite ? Haptics.mediumTap() : Haptics.lightTick()
        } catch {
            modelContext.rollback()
            saveErrorTitle = "Favorite wasn’t saved"
            showSaveError = true
        }
    }

    private var shareText: String {
        let lines = recipe.sortedIngredients.map {
            "• \($0.measure.scaled(by: scaleFactor).formatted(for: effectiveUnit)) \($0.name)"
        }
        return """
        \(recipe.name) — serves \(servings)
        \(lines.joined(separator: "\n"))

        \(recipe.instructions)
        """
    }

    private func actionButton(_ symbol: String, label: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            actionBarLabel(symbol, text: label, selected: selected)
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func actionBarLabel(_ symbol: String, text: String, selected: Bool = false) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
            Text(text)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(selected ? PourColor.accent : PourColor.textSecondary)
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
    }
}
