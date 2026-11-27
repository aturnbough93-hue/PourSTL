import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct VoiceSearchPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "mic")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(PourColor.accent)
                    .accessibilityHidden(true)
                Text("Voice search")
                    .font(.pourTitle2)
                    .foregroundStyle(PourColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Voice search is coming soon. For now, type a drink, ingredient, or brand into search on Home.")
                    .font(.body)
                    .foregroundStyle(PourColor.textSecondary)
                    .multilineTextAlignment(.center)
                Button("OK") { dismiss() }
                    .buttonStyle(PourPrimaryButtonStyle())
                    .padding(.top, 12)
                    .accessibilityLabel("OK")
                    .accessibilityAddTraits(.isButton)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PourColor.background)
            .navigationTitle("Voice Search")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ProUpsellView: View {
    @Environment(ProEntitlementStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    featureList
                    purchaseSection
                    statusMessages
                    legalLinks
                    Button("Not now", action: { dismiss() })
                        .buttonStyle(PourSecondaryButtonStyle())
                        .accessibilityLabel("Not now")
                        .accessibilityAddTraits(.isButton)
                }
                .padding(32)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PourColor.background)
            .navigationTitle("PourSTL Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Done")
                        .accessibilityAddTraits(.isButton)
                }
            }
            .task {
                store.resetTransientStatus()
                await store.refreshEntitlements()
                await store.loadProducts()
            }
            .onChange(of: store.purchaseStatus.announcement) { _, message in
                announce(message)
            }
            .onChange(of: store.restoreStatus.announcement) { _, message in
                announce(message)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(PourColor.gold)
                .accessibilityHidden(true)
            Text("PourSTL Pro")
                .font(.pourTitle)
                .foregroundStyle(PourColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Price your menu, plan event batches, and know what to reorder for your next service.")
                .font(.body)
                .foregroundStyle(PourColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(ProGate.features) { feature in
                Label {
                    Text(feature.text)
                } icon: {
                    Image(systemName: feature.symbol)
                        .accessibilityHidden(true)
                }
                .font(.subheadline)
                .foregroundStyle(PourColor.textSecondary)
                .accessibilityLabel(feature.text)
            }
            Text("Recipes, inventory, shopping, timers, and scaling up to 24 servings are included free.")
                .font(.caption)
                .foregroundStyle(PourColor.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var purchaseSection: some View {
        VStack(spacing: 12) {
            if store.isPro {
                Label(ProStoreCopy.proActive, systemImage: "checkmark.circle.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(PourColor.canMake)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityLabel(ProStoreCopy.proActive)
                Button("Manage subscription") {
                    Task { await store.manageSubscriptions() }
                }
                .buttonStyle(PourSecondaryButtonStyle())
                .accessibilityLabel("Manage subscription")
                .accessibilityAddTraits(.isButton)
            } else if store.productsState == .loaded {
                ForEach(store.offers) { offer in
                    Button {
                        Task { await store.purchase(productID: offer.id) }
                    } label: {
                        Text(offer.title)
                            .multilineTextAlignment(.center)
                    }
                    .buttonStyle(PourPrimaryButtonStyle())
                    .disabled(controlsDisabled)
                    .opacity(controlsDisabled ? 0.6 : 1)
                    .accessibilityLabel(offer.title)
                    .accessibilityHint("Starts a PourSTL Pro subscription through the App Store.")
                    .accessibilityAddTraits(.isButton)
                }
            } else if store.productsState == .unavailable {
                Text("Subscriptions aren’t available right now. PourSTL still works offline. Try again when you can reach the App Store.")
                    .font(.body)
                    .foregroundStyle(PourColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Subscriptions aren’t available right now. PourSTL still works offline.")
                Button("Try again") {
                    Task { await store.loadProducts() }
                }
                .buttonStyle(PourPrimaryButtonStyle())
                .disabled(controlsDisabled)
                .accessibilityLabel("Try again")
                .accessibilityAddTraits(.isButton)
            } else {
                ProgressView("Loading subscriptions")
                    .tint(PourColor.accent)
                    .foregroundStyle(PourColor.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .accessibilityLabel("Loading subscriptions")
            }

            Button {
                Task { await store.restore() }
            } label: {
                if store.restoreStatus == .inProgress {
                    ProgressView()
                        .tint(PourColor.accent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Text("Restore purchases")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(PourColor.accent)
            .disabled(controlsDisabled)
            .opacity(controlsDisabled ? 0.6 : 1)
            .accessibilityLabel(store.restoreStatus == .inProgress ? "Restoring purchases" : "Restore purchases")
            .accessibilityAddTraits(.isButton)
        }
    }

    @ViewBuilder
    private var statusMessages: some View {
        VStack(spacing: 8) {
            if let message = store.purchaseStatus.message {
                statusText(message, isFailure: store.purchaseStatus.isFailure)
            }
            if let message = store.restoreStatus.message {
                statusText(message, isFailure: store.restoreStatus.isFailure)
            }
            if let notice = store.notice {
                statusText(notice, isFailure: true)
            }
        }
    }

    private func statusText(_ message: String, isFailure: Bool) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(isFailure ? PourColor.destructive : PourColor.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(message)
    }

    private var legalLinks: some View {
        VStack(spacing: 8) {
            Text("Payment is processed by the App Store. A subscription renews until you cancel it there.")
                .font(.caption)
                .foregroundStyle(PourColor.textTertiary)
                .multilineTextAlignment(.center)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 24) {
                    privacyLink
                    termsOfUseLink
                }
                VStack(spacing: 4) {
                    privacyLink
                    termsOfUseLink
                }
            }
        }
    }

    private var privacyLink: some View {
        Link(destination: ProProductID.privacyPolicyURL) {
            Text("Privacy")
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
        }
        .accessibilityLabel("Privacy")
    }

    private var termsOfUseLink: some View {
        Link(destination: ProProductID.termsOfUseURL) {
            Text("Terms of Use")
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
        }
        .accessibilityLabel("Terms of Use")
    }

    private var controlsDisabled: Bool {
        store.purchaseStatus == .inProgress || store.restoreStatus == .inProgress
    }

    private func announce(_ message: String?) {
        guard let message else { return }
        AccessibilityNotification.Announcement(message).post()
    }
}

private struct PourSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(PourColor.accent)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                PourColor.surface.opacity(configuration.isPressed ? 0.7 : 1),
                in: RoundedRectangle(cornerRadius: 14)
            )
    }
}

/// Minimal local venue check-in (no cloud): create a venue, check in, check out.
/// House specs and team features are Pro seams.
struct EventPlannerSheet: View {
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @Query private var inventory: [InventoryItem]
    @Environment(ProEntitlementStore.self) private var pro
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var selected = Set<PersistentIdentifier>()
    @State private var guests = 10
    @State private var drinksPerGuest = 2
    @State private var showRecipes = false
    @State private var exporting = false
    @State private var exportError = false

    private var unlocked: Bool { !ProGate.isLocked(.eventPlanner, isPro: pro.isPro) }
    private var plan: EventPrepPlan {
        EventPrepPlan(recipes: recipes.filter { selected.contains($0.persistentModelID) },
                      guests: guests, drinksPerGuest: drinksPerGuest, inventory: inventory)
    }

    var body: some View {
        let plan = plan
        NavigationStack {
            Form {
                if unlocked {
                    Section {
                        Stepper("Guests: \(guests)", value: $guests, in: 1...RecipeScaling.proMaximumServings)
                        Stepper("Drinks per guest: \(drinksPerGuest)", value: $drinksPerGuest, in: 1...5)
                        LabeledContent("Total drinks", value: (guests * drinksPerGuest).formatted())
                        DisclosureGroup("Choose recipes (\(selected.count))", isExpanded: $showRecipes) {
                            ForEach(recipes) { recipe in
                                Toggle(recipe.name, isOn: recipeSelection(recipe.persistentModelID))
                            }
                        }
                    } footer: {
                        Text("Drinks are split evenly. Any extra servings go to the first recipes alphabetically.")
                    }
                    if !plan.batches.isEmpty {
                        Section("Batches") {
                            ForEach(plan.batches, id: \.recipe.persistentModelID) { batch in
                                LabeledContent(batch.recipe.name, value: batch.servings.formatted())
                            }
                            Button("Export event prep (CSV)", systemImage: "square.and.arrow.up") { exporting = true }
                        }
                        Section("Combined ingredients") {
                            ForEach(plan.ingredients) { entry in
                                LabeledContent {
                                    Text(BatchPrepSheet.prepMeasure(entry.measure.converted(to: settings.unit)))
                                } label: {
                                    Text(entry.name)
                                    Text(entry.recipes.joined(separator: ", ") + (entry.isOptional ? " · optional" : ""))
                                }
                            }
                        }
                        Section {
                            if plan.shopping.isEmpty {
                                Text("All required ingredients are marked in stock.")
                            }
                            ForEach(plan.shopping) { entry in
                                LabeledContent(entry.name, value: BatchPrepSheet.prepMeasure(entry.measure.converted(to: settings.unit)))
                            }
                        } header: {
                            Text("Shopping list")
                        } footer: {
                            Text("Shows required ingredients not marked in stock. Check that you have enough of the ingredients already in My Bar.")
                        }
                    }
                }
            }
            .navigationTitle("Event Planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onChange(of: unlocked) { _, active in if !active { dismiss() } }
            .fileExporter(isPresented: $exporting,
                          document: unlocked ? BatchPrepDocument(content: plan.csv(unit: settings.unit)) : nil,
                          contentType: .commaSeparatedText, defaultFilename: "PourSTL Event Prep") { result in
                if case .failure = result { exportError = true }
            }
            .alert("Event prep couldn’t be exported", isPresented: $exportError) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func recipeSelection(_ id: PersistentIdentifier) -> Binding<Bool> {
        Binding(get: { selected.contains(id) }, set: { active in
            if active { selected.insert(id) } else { selected.remove(id) }
        })
    }
}

struct ParReorderSheet: View {
    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]
    @Environment(ProEntitlementStore.self) private var pro
    @Environment(AppSettings.self) private var settings
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @State private var exporting = false
    @State private var exportError = false
    @State private var showItems = false

    private var currency: String { locale.currency?.identifier ?? "USD" }
    private var unlocked: Bool { !ProGate.isLocked(.parReorder, isPro: pro.isPro) }

    var body: some View {
        let plan = ReorderPlan(items: items, prices: settings.ingredientPrices, currency: currency)
        NavigationStack {
            Form {
                if unlocked {
                    Section {
                        if items.isEmpty {
                            Text("Add ingredients in My Bar before setting par levels.")
                        } else {
                            DisclosureGroup("Set par levels", isExpanded: $showItems) {
                                ForEach(items) { item in
                                    NavigationLink {
                                        ParLevelEditor(item: item)
                                    } label: {
                                        LabeledContent(item.name, value: item.lowStockThreshold?.formatted() ?? "Not set")
                                    }
                                }
                            }
                        }
                    } footer: {
                        Text("Enter the number of packages on hand and the minimum you want to keep. Keep package counts up to date after stocking My Bar. Out-of-stock items count as zero.")
                    }
                    Section {
                        if plan.lines.isEmpty {
                            Text("No items are below par.")
                        } else {
                            ForEach(plan.lines) { line in
                                LabeledContent {
                                    Text(line.cost.map(money) ?? "Unpriced")
                                } label: {
                                    Text(line.name)
                                    Text("Order \(line.packages) · \(line.onHand) on hand · par \(line.par)")
                                }
                            }
                            let pricedCount = plan.lines.compactMap(\.cost).count
                            if pricedCount > 0 {
                                LabeledContent(pricedCount == plan.lines.count ? "Estimated total" : "Priced subtotal",
                                               value: money(plan.pricedSubtotal))
                            }
                            Button("Export reorder (CSV)", systemImage: "square.and.arrow.up") { exporting = true }
                        }
                    } header: {
                        Text("Reorder list")
                    } footer: {
                        Text("Estimates use saved package prices for the same ingredient. Unpriced items aren’t included in the total.")
                    }
                }
            }
            .navigationTitle("Par Levels & Reorder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onChange(of: unlocked) { _, active in if !active { dismiss() } }
            .fileExporter(isPresented: $exporting,
                          document: unlocked ? BatchPrepDocument(content: plan.csv(currency: currency)) : nil,
                          contentType: .commaSeparatedText, defaultFilename: "PourSTL Reorder") { result in
                if case .failure = result { exportError = true }
            }
            .alert("Reorder list couldn’t be exported", isPresented: $exportError) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func money(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: currency).locale(locale))
    }
}

private struct ParLevelEditor: View {
    let item: InventoryItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(AppSettings.self) private var settings
    @Environment(ProEntitlementStore.self) private var pro
    @State private var onHand: Int
    @State private var par: Int
    @State private var packageUnit: String?
    @State private var saveError = false

    init(item: InventoryItem) {
        self.item = item
        _onHand = State(initialValue: Self.packageCount(item.quantity))
        _par = State(initialValue: Self.packageCount(item.lowStockThreshold))
        _packageUnit = State(initialValue: item.reorderPackageUnit)
    }

    private static func packageCount(_ value: Double?) -> Int {
        guard let value, (0...999).contains(value) else { return 0 }
        return Int(value)
    }

    private var unlocked: Bool { !ProGate.isLocked(.parReorder, isPro: pro.isPro) }

    var body: some View {
        let units = RecipeCostLine.packageUnits(for: item.name, currency: locale.currency?.identifier ?? "USD",
                                                prices: settings.ingredientPrices)
        Form {
            if unlocked {
                Section {
                    TextField("Packages on hand", value: $onHand, format: .number).keyboardType(.numberPad)
                    TextField("Par (minimum packages)", value: $par, format: .number).keyboardType(.numberPad)
                } footer: {
                    Text("Use whole packages from 0 to 999. Set par to 0 to stop tracking this item.")
                }
                Section {
                    Picker("Saved package price", selection: $packageUnit) {
                        Text("Automatic").tag(nil as String?)
                        ForEach(units, id: \.self) { unit in
                            Text("Yield in \(unit)").tag(Optional(unit))
                        }
                        if let packageUnit, !units.contains(packageUnit) {
                            Text("Price unavailable").tag(Optional(packageUnit))
                        }
                    }
                } footer: {
                    Text("Automatic uses a saved price when there’s exactly one match. Enter package prices under Costing & Batch Prep in a recipe.")
                }
            }
        }
        .navigationTitle(item.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(!unlocked || !(0...999).contains(onHand) || !(0...999).contains(par))
            }
        }
        .alert("Par level couldn’t be saved", isPresented: $saveError) {
            Button("OK", role: .cancel) {}
        }
    }

    private func save() {
        guard unlocked, (0...999).contains(onHand), (0...999).contains(par) else { return }
        item.quantity = Double(onHand)
        item.lowStockThreshold = par > 0 ? Double(par) : nil
        item.reorderPackageUnit = packageUnit
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = true
        }
    }
}

struct VenueSheet: View {
    @Query private var venues: [Venue]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var newVenueName = ""
    @State private var showSaveError = false

    var body: some View {
        NavigationStack {
            List {
                if venues.isEmpty {
                    Section {
                        Text("No venues yet. Add your workplace to check in and surface its menu during a shift.")
                            .font(.subheadline)
                            .foregroundStyle(PourColor.textSecondary)
                            .listRowBackground(PourColor.card)
                    }
                } else {
                    Section("Venues") {
                        ForEach(venues) { venue in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(venue.name)
                                        .font(.body)
                                        .foregroundStyle(PourColor.textPrimary)
                                    if venue.isCheckedIn {
                                        Text("Checked in")
                                            .font(.caption)
                                            .foregroundStyle(PourColor.canMake)
                                    }
                                }
                                Spacer()
                                Button(venue.isCheckedIn ? "Check out" : "Check in") {
                                    toggleCheckIn(venue)
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PourColor.accent)
                                .accessibilityLabel(venue.isCheckedIn ? "Check out of \(venue.name)" : "Check in to \(venue.name)")
                                .accessibilityAddTraits(.isButton)
                            }
                            .frame(minHeight: 52)
                            .listRowBackground(PourColor.card)
                        }
                        .onDelete { offsets in
                            for index in offsets { modelContext.delete(venues[index]) }
                            saveChanges()
                        }
                    }
                }
                Section("Add a venue") {
                    HStack(spacing: 10) {
                        TextField("Venue name", text: $newVenueName)
                            .accessibilityLabel("Venue name")
                        Button("Add") {
                            let trimmed = newVenueName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            modelContext.insert(Venue(name: trimmed))
                            if saveChanges() {
                                newVenueName = ""
                                Haptics.success()
                            }
                        }
                        .disabled(IngredientNormalizer.normalize(newVenueName).isEmpty)
                        .foregroundStyle(PourColor.accent)
                        .accessibilityLabel("Add venue")
                        .accessibilityAddTraits(.isButton)
                    }
                    .listRowBackground(PourColor.card)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PourColor.background)
            .alert("Venue wasn’t saved", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Check available device storage and try again.")
            }
            .navigationTitle("Venue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Done")
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
    }

    @discardableResult
    private func saveChanges() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            showSaveError = true
            return false
        }
    }

    private func toggleCheckIn(_ venue: Venue) {
        if venue.isCheckedIn {
            venue.isCheckedIn = false
            Haptics.lightTick()
        } else {
            for other in venues { other.isCheckedIn = false }
            venue.isCheckedIn = true
            Haptics.success()
        }
        saveChanges()
    }
}
