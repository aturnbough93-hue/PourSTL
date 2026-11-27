import SwiftUI
import SwiftData
import UniformTypeIdentifiers

private struct RecipeServiceTools: View {
    let recipe: Recipe
    @Binding var servings: Int
    let unit: UnitPreference
    let opensMenuPricing: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(ProEntitlementStore.self) private var entitlement
    @State private var exporting = false
    @State private var exportError = false
    @State private var showSaveError = false
    @State private var showMenuPricing: Bool

    init(recipe: Recipe, servings: Binding<Int>, unit: UnitPreference, opensMenuPricing: Bool) {
        self.recipe = recipe
        _servings = servings
        self.unit = unit
        self.opensMenuPricing = opensMenuPricing
        _showMenuPricing = State(initialValue: opensMenuPricing)
    }

    private var currency: String { locale.currency?.identifier ?? "USD" }
    private var activeServings: Int { min(max(servings, 1), RecipeScaling.proMaximumServings) }
    private var batchSize: Binding<Int> {
        Binding(get: { activeServings }, set: { servings = $0 })
    }
    private var batchPlan: BatchPlan? { BatchPlanner.plan(for: recipe, servings: activeServings) }

    var body: some View {
        NavigationStack {
            Form {
                if entitlement.isPro {
                    if opensMenuPricing { menuPricingSection }
                    batchSection
                    costingSection
                    if !opensMenuPricing { menuPricingSection }
                }
            }
            .navigationTitle(opensMenuPricing ? "Menu Pricing" : "Costing & Batch Prep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fileExporter(
                isPresented: $exporting,
                document: entitlement.isPro ? BatchPrepDocument(
                    content: BatchPrepSheet.csv(for: recipe, servings: activeServings, unit: unit)
                ) : nil,
                contentType: .commaSeparatedText,
                defaultFilename: "PourSTL Batch Prep"
            ) { result in
                if case .failure = result { exportError = true }
            }
            .alert("Prep sheet couldn’t be exported", isPresented: $exportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Choose another location and try again.")
            }
            .alert("Menu price wasn’t saved", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Check available device storage and try again.")
            }
        }
    }

    private func applySuggestedPrice(_ price: Decimal) {
        recipe.menuPrice = NSDecimalNumber(decimal: price).doubleValue
        do {
            try modelContext.save()
            Haptics.success()
        } catch {
            modelContext.rollback()
            showSaveError = true
        }
    }

    private var batchSection: some View {
        Section {
            Picker("Servings", selection: batchSize) {
                ForEach(RecipeScaling.minimumServings...RecipeScaling.proMaximumServings, id: \.self) { count in
                    Text(count.formatted()).tag(count)
                }
            }
            .pickerStyle(.navigationLink)
            .accessibilityIdentifier("pro-batch-servings")
            if let plan = batchPlan {
                LabeledContent("Measured volume", value: volumeText(plan.measuredMilliliters))
                if let water = plan.waterMilliliters, water > 0 {
                    LabeledContent("Water to add", value: volumeText(water))
                        .accessibilityIdentifier("pro-batch-water")
                }
                LabeledContent("Ready-to-pour yield", value: volumeText(plan.totalMilliliters))
                LabeledContent("Pour per serving", value: volumeText(plan.perServingMilliliters))
            }
            if !ProGate.isLocked(.batchExport, isPro: entitlement.isPro) {
                Button("Export prep sheet (CSV)", systemImage: "square.and.arrow.up") { exporting = true }
                    .disabled(recipe.sortedIngredients.isEmpty)
            }
        } header: {
            Text("Batch prep")
        } footer: {
            Text(batchFooter)
        }
    }

    private var batchFooter: String {
        var text = "The prep sheet includes scaled ingredient measures, optional ingredients, and ingredient notes."
        if let plan = batchPlan {
            if let profile = plan.profile { text += " \(profile.assumption)" }
            if plan.excludesNonVolumeLines {
                text += " Lines measured in parts or countables aren’t included in volume totals."
            }
        }
        return text
    }

    private func volumeText(_ milliliters: Double) -> String {
        Measure(amount: milliliters, unit: .milliliter).formatted(for: unit)
    }

    private var costingSection: some View {
        @Bindable var settings = settings
        let ingredients = recipe.sortedIngredients
        let costs = ingredients.compactMap { RecipeCostLine(ingredient: $0).cost(in: settings.ingredientPrices, currency: currency) }
        let perDrink = costs.reduce(Decimal.zero, +)
        let isComplete = !ingredients.isEmpty && costs.count == ingredients.count
        let pricedPerDrink: Decimal? = costs.isEmpty ? nil : perDrink
        return Section {
            if !costs.isEmpty {
                LabeledContent(isComplete ? "Per drink" : "Priced per drink", value: money(perDrink))
                LabeledContent(isComplete ? "Batch total" : "Priced batch subtotal", value: money(perDrink * Decimal(activeServings)))
            }
            if !isComplete {
                Text("\(costs.count) of \(ingredients.count) ingredient lines priced")
                    .foregroundStyle(.secondary)
            }
            NavigationLink {
                MenuPriceEditor(recipe: recipe, currency: currency)
            } label: {
                LabeledContent("Menu price", value: recipe.menuPrice.map { money(Decimal($0)) } ?? "Set price")
            }
            .accessibilityIdentifier("menu-price")
            if let menuPrice = recipe.menuPrice, menuPrice > 0, let pricedPerDrink {
                let menuPriceDecimal = Decimal(menuPrice)
                if let percent = MenuPricing.pourCostPercent(cost: pricedPerDrink, menuPrice: menuPriceDecimal) {
                    LabeledContent(
                        isComplete ? "Pour cost" : "Priced pour cost",
                        value: percent.formatted(.number.precision(.fractionLength(1))) + "%"
                    )
                }
                if let profit = MenuPricing.profitPerDrink(cost: pricedPerDrink, menuPrice: menuPriceDecimal) {
                    LabeledContent("Profit per drink", value: money(profit))
                    LabeledContent(isComplete ? "Profit per batch" : "Priced profit per batch", value: money(profit * Decimal(activeServings)))
                }
            }
            if let pricedPerDrink, pricedPerDrink > 0,
               let suggested = MenuPricing.suggestedMenuPrice(cost: pricedPerDrink, targetPercent: settings.targetPourCostPercent) {
                LabeledContent("Suggested menu price", value: money(suggested))
                if abs((recipe.menuPrice ?? 0) - NSDecimalNumber(decimal: suggested).doubleValue) >= 0.005 {
                    Button("Use suggested price") { applySuggestedPrice(suggested) }
                        .accessibilityIdentifier("use-suggested-price")
                }
            }
            Stepper(
                "Target pour cost: \(settings.targetPourCostPercent.formatted(.number.precision(.fractionLength(0))))%",
                value: $settings.targetPourCostPercent,
                in: MenuPricing.targetPercentRange,
                step: 1
            )
            .accessibilityIdentifier("target-pour-cost")
            ForEach(ingredients) { ingredient in
                let line = RecipeCostLine(ingredient: ingredient)
                if line.quantity != nil {
                    let key = line.priceKey(currency: currency)
                    NavigationLink {
                        IngredientPriceEditor(line: line, currency: currency, existing: settings.ingredientPrices[key])
                    } label: {
                        LabeledContent(ingredient.name, value: line.cost(in: settings.ingredientPrices, currency: currency)
                            .map(money) ?? "Add price")
                    }
                    .accessibilityIdentifier("costing-ingredient-\(ingredient.position)")
                } else {
                    LabeledContent(ingredient.name, value: "Unmeasured")
                }
            }
        } header: {
            Text("Ingredient costing")
        } footer: {
            Text("Enter what you paid for each package and its usable yield. Prices are saved on this device and reused in recipes with the same ingredient and unit. Estimates cover priced ingredient lines, including optional ones when priced. Add labor, waste, and unlisted garnishes separately.")
        }
    }

    private func money(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: currency).locale(locale))
    }

    private var menuPricingSection: some View {
        @Bindable var settings = settings
        let required = recipe.sortedIngredients.filter { !$0.isOptional }
        let costs = required.compactMap { RecipeCostLine(ingredient: $0).cost(in: settings.ingredientPrices, currency: currency) }
        let completeCost = !required.isEmpty && required.count == costs.count ? costs.reduce(0, +) : nil
        let estimate = completeCost.flatMap {
            MenuPricing.suggestedMenuPrice(cost: $0, targetPercent: settings.targetPourCostPercent)
        }
        return Section {
            Button {
                if ProGate.isLocked(.menuPricing, isPro: entitlement.isPro) { showMenuPricing = false }
                else { showMenuPricing.toggle() }
            } label: {
                Label(showMenuPricing ? "Hide menu price estimate" : "Estimate menu price", systemImage: "percent")
            }
            if showMenuPricing && !ProGate.isLocked(.menuPricing, isPro: entitlement.isPro) {
                Stepper(
                    "Target pour cost: \(settings.targetPourCostPercent.formatted(.number.precision(.fractionLength(0))))%",
                    value: $settings.targetPourCostPercent,
                    in: MenuPricing.targetPercentRange,
                    step: 1
                )
                if let estimate, let completeCost {
                    LabeledContent("Suggested price", value: money(estimate))
                    if let margin = MenuPricing.ingredientMargin(cost: completeCost, price: estimate) {
                        LabeledContent("Ingredient margin", value: margin.formatted(.percent.precision(.fractionLength(1))))
                    }
                } else if completeCost == 0 {
                    Text("Required ingredients cost nothing. A target pour cost doesn’t determine a menu price for this recipe.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Enter prices and measures for all required ingredients to estimate a menu price.")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Menu pricing")
        } footer: {
            Text("Rounds the suggestion up to the next half unit of currency. Ingredient margin excludes optional items, labor, tax, and other overhead.")
        }
    }
}

private struct IngredientPriceEditor: View {
    let line: RecipeCostLine
    let currency: String
    let existing: IngredientPackagePrice?

    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var price = ""
    @State private var yield = ""

    private var package: IngredientPackagePrice? {
        let strategy = Decimal.FormatStyle(locale: locale).parseStrategy
        guard let price = try? strategy.parse(price), let yield = try? strategy.parse(yield),
              (0...1_000_000_000).contains(price), (0.000001...1_000_000_000).contains(yield) else { return nil }
        return IngredientPackagePrice(price: price, yield: yield)
    }

    var body: some View {
        Form {
            Section {
                TextField("Package price (\(currency))", text: $price)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("ingredient-package-price")
                TextField("Package yield (\(line.unit))", text: $yield)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("ingredient-package-yield")
            } footer: {
                if line.usesVolume {
                    Text("Enter the usable package volume in milliliters. A standard 750 ml bottle has a yield of 750.")
                } else {
                    Text("Enter how many \(line.unit) you get from the package.")
                }
            }
            if existing != nil {
                Button("Remove saved price", role: .destructive) {
                    settings.ingredientPrices.removeValue(forKey: line.priceKey(currency: currency))
                    dismiss()
                }
            }
        }
        .navigationTitle(line.ingredient.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let package else { return }
                    settings.ingredientPrices[line.priceKey(currency: currency)] = package
                    dismiss()
                }
                .disabled(package == nil)
            }
        }
        .onAppear {
            guard let existing else { return }
            let format = Decimal.FormatStyle(locale: locale).grouping(.never).precision(.fractionLength(0...12))
            price = existing.price.formatted(format)
            yield = existing.yield.formatted(format)
        }
    }
}

private struct MenuPriceEditor: View {
    let recipe: Recipe
    let currency: String

    @Environment(\ توسعه.modelContext) private var modelContext
    @Environment(\ توسعه.dismiss) private var dismiss
    @Environment(\ توسعه.locale) private var locale
    @State private var price = ""
    @State private var showSaveError = false

    private var parsed: Decimal? {
        let strategy = Decimal.FormatStyle(locale: locale).parseStrategy
        guard let value = try? strategy.parse(price), (0...1_000_000).contains(value) else { return nil }
        return value
    }

    var body: some View {
        Form {
            Section {
                TextField("Menu price (\(currency))", text: $price)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("menu-price-field")
            } footer: {
                Text("What a guest pays for one serving. Pour cost and profit use priced ingredient lines.")
            }
            if recipe.menuPrice != nil {
                Button("Remove menu price", role: .destructive) {
                    recipe.menuPrice = nil
                    saveAndDismiss()
                }
                .accessibilityIdentifier("remove-menu-price")
            }
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let parsed else { return }
                    recipe.menuPrice = NSDecimalNumber(decimal: parsed).doubleValue
                    saveAndDismiss()
                }
                .disabled(parsed == nil)
            }
        }
        .onAppear {
            guard let existing = recipe.menuPrice else { return }
            let format = Decimal.FormatStyle(locale: locale).grouping(.never).precision(.fractionLength(0...12))
            price = Decimal(existing).formatted(format)
        }
        .alert("Menu price wasn’t saved", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your edits are still here. Check available device storage and try again.")
        }
    }

    private func saveAndDismiss() {
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            showSaveError = true
        }
    }
}

struct BatchPrepDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.commaSeparatedText]
    let content: String

    init(content: String) {
        self.content = content
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let content = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadCorruptFile) }
        self.content = content
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(content.utf8))
    }
}

struct RecipeDetailView: View {
    @Bindable var recipe: Recipe
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(ProEntitlementStore.self) private var entitlement
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var inventory: [InventoryItem]

    @State private var servings: Int = 1
    /// Per-screen unit override; nil follows the global preference.
    @State private var unitOverride: UnitPreference? = nil
    @State private var showTimer = false
    @State private var showEdit = false
    @State private var showServiceTools = false
    @State private var openMenuPricing = false
    @State private var showPro = false
    @State private var addedToList = false
    @State private var shoppingConfirmationTask: Task<Void, Never>?
    @State private var showSaveError = false
    @State private var saveErrorTitle = "Changes weren’t saved"

    private var effectiveUnit: UnitPreference { unitOverride ?? settings.unit }
    private var match: RecipeMatch { RecipeEngine.match(recipe, inventory: inventory) }
    private var maximumServings: Int {
        ProGate.isLocked(.largeBatches, isPro: entitlement.isPro)
            ? RecipeScaling.maximumServings : RecipeScaling.proMaximumServings
    }
    private var activeServings: Int { min(servings, maximumServings) }
    private var scaleFactor: Double { Double(activeServings) }
    private var adaptiveRow: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    metadataPills
                    if dynamicTypeSize.isAccessibilitySize {
                        actionBar(proxy: proxy)
                    }
                    scalingControls.id("scaling")
                    ingredientsList
                    instructionsSection
                    if !recipe.isCustom { variationAction }
                    shoppingAction
                    serviceToolsAction
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .background(PourColor.background)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !dynamicTypeSize.isAccessibilitySize {
                    actionBar(proxy: proxy)
                }
            }
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
        .sheet(isPresented: $showServiceTools) {
            RecipeServiceTools(recipe: recipe, servings: $servings, unit: effectiveUnit, opensMenuPricing: openMenuPricing)
        }
        .sheet(isPresented: $showPro) { ProUpsellView() }
        .onChange(of: maximumServings) { _, limit in
            servings = min(servings, limit)
            if !entitlement.isPro { showServiceTools = false }
        }
        .alert(saveErrorTitle, isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check available device storage and try again.")
        }
        .onDisappear {
            shoppingConfirmationTask?.cancel()
            shoppingConfirmationTask = nil
            addedToList = false
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
                .frame(minHeight: 180)

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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                metadataLabels
            }
            .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 8) {
                metadataLabels
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var metadataLabels: some View {
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
        adaptiveRow {
            VStack(alignment: .leading, spacing: 4) {
                Text(activeServings == 1 ? "Servings" : "Batch of \(activeServings)")
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
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(servings <= RecipeScaling.minimumServings)
                    .accessibilityLabel("Decrease servings")
                    .accessibilityAddTraits(.isButton)

                    Text("\(activeServings)")
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(PourColor.textPrimary)
                        .frame(minWidth: 32)
                        .accessibilityLabel("Servings, \(activeServings)")
                        .accessibilityAddTraits(.updatesFrequently)

                    Button {
                        if servings < maximumServings { servings += 1 }
                        Haptics.selection()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(servings < maximumServings ? PourColor.accent : PourColor.textTertiary)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(servings >= maximumServings)
                    .accessibilityLabel("Increase servings")
                    .accessibilityAddTraits(.isButton)
                }
            }

            if !dynamicTypeSize.isAccessibilitySize { Spacer() }

            VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 4) {
                Text("Units")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PourColor.textSecondary)
                AdaptiveSegmentedPicker(
                    title: "Display units",
                    selection: unitBinding,
                    options: UnitPreference.allCases,
                    optionTitle: { $0.rawValue }
                )
                .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 110)
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
        let isMissingRequired = match.missing.contains { $0.persistentModelID == line.persistentModelID }
        let swap = isMissingRequired ? match.substitute(for: line) : nil
        let isMissingOptional = match.missingOptional.contains { $0.persistentModelID == line.persistentModelID }
        let measure = line.measure.scaled(by: scaleFactor).formatted(for: effectiveUnit)
        let accessibilityStatus = if isMissingRequired {
            swap.map { ", missing; try \($0) to taste" } ?? ", missing"
        } else if isMissingOptional {
            ", optional, not stocked"
        } else if line.isOptional {
            ", optional"
        } else {
            ""
        }
        return adaptiveRow {
            VStack(alignment: .leading, spacing: 2) {
                Text(line.name)
                    .font(.body)
                    .foregroundStyle(PourColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if isMissingRequired {
                    StatusPill(kind: .missing)
                        .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
                    if let swap {
                        Text("Try \(swap) to taste")
                            .font(.caption)
                            .foregroundStyle(PourColor.textSecondary)
                    }
                } else if line.isOptional {
                    Text(isMissingOptional ? "Optional · not stocked" : "Optional")
                        .font(.caption)
                        .foregroundStyle(PourColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let note = line.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(PourColor.textTertiary)
                }
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Text(measure)
                .font(.pourMeasure)
                .foregroundStyle(PourColor.textPrimary)
                .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
        }
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(measure) \(line.name)\(accessibilityStatus)")
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
            let missing = match.missing + match.missingOptional
            let missingNames = Set(missing.map(\.canonicalName))
            for item in existing where !item.isPurchased && missingNames.contains(item.canonicalName) {
                item.addSourceRecipe(recipe.name)
            }
            for line in ShoppingListPlanner.ingredientsToAdd(missing, existing: existing) {
                modelContext.insert(ShoppingListItem(name: line.name, sourceRecipeName: recipe.name))
            }
            try modelContext.save()
            Haptics.success()
            withAnimation { addedToList = true }
            shoppingConfirmationTask?.cancel()
            shoppingConfirmationTask = Task { @MainActor in
                do {
                    try await Task.sleep(for: .milliseconds(2500))
                    addedToList = false
                } catch is CancellationError {
                    // The screen disappeared or a new confirmation replaced it.
                } catch {
                    addedToList = false
                }
            }
        } catch {
            modelContext.rollback()
            saveErrorTitle = "Shopping list wasn’t updated"
            showSaveError = true
        }
    }

    // MARK: - Sticky action bar

    private func actionBar(proxy: ScrollViewProxy) -> some View {
        adaptiveRow {
            actionButton(
                recipe.isFavorite ? "heart.fill" : "heart",
                label: recipe.isFavorite ? "Unfavorite" : "Favorite",
                selected: recipe.isFavorite
            ) {
                toggleFavorite()
            }
            actionButton("square.resize", label: "Scale") {
                withAnimation(reduceMotion ? nil : .default) {
                    proxy.scrollTo("scaling", anchor: .top)
                }
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
        .buttonStyle(.plain)
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
        \(recipe.name) — serves \(activeServings)
        \(lines.joined(separator: "\n"))

        \(recipe.instructions)
        """
    }

    private var serviceToolsAction: some View {
        VStack(spacing: 8) {
            serviceButton("Costing & Batch Prep", symbol: "chart.bar", capability: .recipeCosting)
            serviceButton("Menu Pricing", symbol: "percent", capability: .menuPricing)
        }
        .buttonStyle(.bordered)
        .tint(PourColor.accent)
    }

    private func serviceButton(_ title: String, symbol: String, capability: PourCapability) -> some View {
        let locked = ProGate.isLocked(capability, isPro: entitlement.isPro)
        return Button {
            if locked { showPro = true }
            else {
                openMenuPricing = capability == .menuPricing
                showServiceTools = true
            }
        } label: {
            Label(title, systemImage: locked ? "lock" : symbol)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .accessibilityHint(locked ? "Requires PourSTL Pro" : "Opens service tools")
    }

    private func actionButton(_ symbol: String, label: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            actionBarLabel(symbol, text: label, selected: selected)
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func actionBarLabel(_ symbol: String, text: String, selected: Bool = false) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
            : AnyLayout(VStackLayout(spacing: 4))
        return layout {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
            Text(text)
                .font(dynamicTypeSize.isAccessibilitySize ? .body.weight(.medium) : .caption2.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(selected ? PourColor.accent : PourColor.textSecondary)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center)
        .contentShape(Rectangle())
    }
}
