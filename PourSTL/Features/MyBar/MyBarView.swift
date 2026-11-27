import SwiftUI
import SwiftData
import UIKit

struct MyBarView: View {
    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(ProEntitlementStore.self) private var pro

    @State private var showSaveError = false
    @State private var searchText = ""
    @State private var filter: StockFilter = .all
    @State private var showAdd = false
    @State private var showScanner = false
    @State private var showReorder = false
    @State private var showReorderUpsell = false
    @State private var editingItem: InventoryItem? = nil

    enum StockFilter: String, CaseIterable {
        case all = "All", inStock = "In stock", out = "Out", low = "Low"
    }

    private var filtered: [InventoryItem] {
        let q = IngredientNormalizer.normalize(searchText)
        return items.filter { item in
            let matchesQuery = q.isEmpty
                || IngredientNormalizer.normalize(item.name).contains(q)
                || item.canonicalName.contains(q)
            let matchesFilter: Bool = {
                switch filter {
                case .all: return true
                case .inStock: return item.isAvailable
                case .out: return !item.isAvailable
                case .low: return showsLowStock(for: item)
                }
            }()
            return matchesQuery && matchesFilter
        }
    }

    private var grouped: [(InventoryCategory, [InventoryItem])] {
        var groups: [InventoryCategory: [InventoryItem]] = [:]
        for item in filtered { groups[item.inventoryCategory, default: []].append(item) }
        return InventoryCategory.allCases
            .filter { !(groups[$0] ?? []).isEmpty }
            .map { ($0, groups[$0]!.sorted { $0.name < $1.name }) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    EmptyStateView(
                        symbol: "square.stack.3d.up",
                        title: "Your bar is empty",
                        message: "Add bottles and staples so PourSTL can tell you what you can make.",
                        actionTitle: "Add your first item"
                    ) {
                        showAdd = true
                    }
                } else if filtered.isEmpty {
                    EmptyStateView(symbol: "magnifyingglass", title: "No ingredients found", message: "Try another name or stock filter.", actionTitle: "Clear filters") {
                        searchText = ""
                        filter = .all
                    }
                } else {
                    List {
                        inventoryOperationsSection
                        ForEach(grouped, id: \.0) { category, categoryItems in
                            Section {
                                ForEach(categoryItems) { item in
                                    inventoryRow(item)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                modelContext.delete(item)
                                                saveChanges()
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            } header: {
                                Label("\(category.displayName) (\(categoryItems.count))", systemImage: category.symbol)
                                    .foregroundStyle(PourColor.textSecondary)
                                    .accessibilityLabel("\(category.displayName), \(categoryItems.count) ingredients")
                                    .accessibilityAddTraits(.isHeader)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(PourColor.background)
            .navigationTitle("My Bar")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search ingredients")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if ProGate.isLocked(.parReorder, isPro: pro.isPro) { showReorderUpsell = true }
                        else { showReorder = true }
                    } label: {
                        Image(systemName: pro.isPro ? "shippingbox" : "lock")
                    }
                    .accessibilityLabel("Par Levels & Reorder")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                            .foregroundStyle(PourColor.textSecondary)
                    }
                    .accessibilityLabel("Scan barcode to add ingredient")
                    .accessibilityAddTraits(.isButton)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingItem = nil
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(PourColor.accent)
                    }
                    .accessibilityLabel("Add inventory item")
                    .accessibilityAddTraits(.isButton)
                }
            }
            .safeAreaInset(edge: .top) { filterChips }
            .sheet(isPresented: $showAdd) { InventoryEditSheet(item: nil) }
            .sheet(item: $editingItem) { item in InventoryEditSheet(item: item) }
            .sheet(isPresented: $showScanner) { BarcodeScannerView() }
            .sheet(isPresented: $showReorder) { ParReorderSheet() }
            .sheet(isPresented: $showReorderUpsell) { ProUpsellView() }
            .alert("Bar wasn’t updated", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Check available device storage and try again.")
            }
        }
    }

    private var filterChips: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                StockFilterFlow(spacing: 8) { stockFilterButtons }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) { stockFilterButtons }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                }
            }
        }
        .background(PourColor.background)
    }

    private var stockFilterButtons: some View {
        ForEach(StockFilter.allCases, id: \.self) { option in
            let selected = filter == option
            Button {
                filter = option
                Haptics.selection()
            } label: {
                Text(option.rawValue)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(selected ? .black : PourColor.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(selected ? PourColor.accentFill : PourColor.surface, in: Capsule())
            }
            .accessibilityLabel("\(option.rawValue), \(selected ? "selected" : "not selected")")
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        }
    }

    private var inventoryOperationsSection: some View {
        let lowCount = items.filter { $0.isAvailable && showsLowStock(for: $0) }.count
        let outCount = items.filter { !$0.isAvailable }.count
        let valuation = InventoryOperations.valuation(items: items)
        return Group {
            if pro.isPro && (valuation != nil || lowCount > 0 || outCount > 0) {
                Section {
                    if let valuation {
                        LabeledContent("Bar value at cost", value: moneyText(valuation))
                            .accessibilityIdentifier("inventory-valuation")
                            .listRowBackground(PourColor.card)
                    }
                    if lowCount > 0 {
                        LabeledContent("Low stock", value: String(lowCount))
                            .listRowBackground(PourColor.card)
                    }
                    if outCount > 0 {
                        LabeledContent("Out of stock", value: String(outCount))
                            .listRowBackground(PourColor.card)
                    }
                } header: {
                    Text("Inventory operations")
                } footer: {
                    if valuation != nil {
                        Text("Value counts in-stock items with a saved bottle cost. Bottles on hand count as one when no quantity is recorded.")
                    }
                }
            }
        }
    }

    private func moneyText(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: locale.currency?.identifier ?? "USD").locale(locale))
    }

    static func rowSubtitle(for item: InventoryItem) -> String? {
        let canonicalName = item.canonicalName
        return canonicalName == IngredientNormalizer.normalize(item.name) ? nil : canonicalName
    }

    private func inventoryRow(_ item: InventoryItem) -> some View {
        HStack(spacing: 12) {
            Button {
                item.setAvailability(!item.isAvailable)
                if saveChanges() {
                    item.isAvailable ? Haptics.mediumTap() : Haptics.lightTick()
                }
            } label: {
                Image(systemName: item.isAvailable ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isAvailable ? PourColor.canMake : PourColor.textTertiary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("\(item.name), \(item.isAvailable ? "in stock" : "not in stock")")
            .accessibilityAddTraits(item.isAvailable ? [.isButton, .isSelected] : .isButton)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    inventoryNameButton(item)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    lowStockButton(item)
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                inventoryNameButton(item)
                Spacer()
                lowStockButton(item)
            }
        }
        .frame(minHeight: 52)
        .buttonStyle(.borderless)
        .listRowBackground(PourColor.card)
    }

    private func inventoryNameButton(_ item: InventoryItem) -> some View {
        Button {
            editingItem = item
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .foregroundStyle(item.isAvailable ? PourColor.textPrimary : PourColor.textSecondary)
                if let subtitle = Self.rowSubtitle(for: item) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(PourColor.textTertiary)
                }
            }
        }
        .accessibilityLabel("Edit \(item.name)")
        .accessibilityAddTraits(.isButton)
    }

    private func showsLowStock(for item: InventoryItem) -> Bool {
        item.isLowStock || (pro.isPro && item.isAvailable && InventoryOperations.isEffectivelyLow(item))
    }

    @ViewBuilder
    private func lowStockButton(_ item: InventoryItem) -> some View {
        if showsLowStock(for: item) {
            Button {
                if item.isLowStock {
                    item.isLowStock = false
                    saveChanges()
                } else {
                    editingItem = item
                }
            } label: {
                StatusPill(kind: .lowStock)
            }
            .accessibilityLabel("\(item.name), low stock")
            .accessibilityHint(item.isLowStock ? "Clears the manual low-stock flag." : "Opens quantity and the stock alert level.")
            .accessibilityAddTraits(.isButton)
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
}

private struct StockFilterFlow: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let frames = chipFrames(in: width, subviews: subviews)
        return CGSize(width: width.isFinite ? width : (frames.map(\.maxX).max() ?? 0),
                      height: frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, frame) in zip(subviews, chipFrames(in: bounds.width, subviews: subviews)) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          anchor: .topLeading, proposal: ProposedViewSize(frame.size))
        }
    }

    private func chipFrames(in width: CGFloat, subviews: Subviews) -> [CGRect] {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        return subviews.map { subview in
            let idealSize = subview.sizeThatFits(.unspecified)
            let size = idealSize.width <= width ? idealSize
                : subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            let frame = CGRect(origin: CGPoint(x: x, y: y), size: size)
            x = frame.maxX + spacing
            rowHeight = max(rowHeight, size.height)
            return frame
        }
    }
}

/// Prefill for the existing add sheet when a scan needs a name, or when the
/// bartender already knows which bottle a code belongs to.
struct InventorySeed: Equatable {
    var name: String = ""
    var barcode: String?
    var scanNote: String?
}

enum InventoryEditResult: Equatable {
    case saved
    case alreadyInBar(ExistingBarcodeMatch)
}

// MARK: - Add / edit item sheet

struct InventoryEditSheet: View {
    let item: InventoryItem?
    var seed: InventorySeed?
    var onFinished: ((InventoryEditResult) -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(ProEntitlementStore.self) private var pro
    @Query private var recipes: [Recipe]
    @Query private var inventory: [InventoryItem]

    @State private var showSaveError = false
    @State private var duplicateOffer: ExistingBarcodeMatch?
    @State private var name = ""
    @State private var category: InventoryCategory = .other
    @State private var isInStock = true
    @State private var isLowStock = false
    @State private var canonicalOverride = ""
    @State private var barcode = ""
    @State private var amounts = AmountInputs()
    @State private var initialAmounts: AmountInputs?
    @State private var showInvalidAmounts = false
    @State private var showPro = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case canonical
    }

    private struct AmountInputs {
        var bottleCost = ""
        var bottlesOnHand = ""
        var lowStockThreshold = ""
    }

    private enum AmountEdit {
        case unchanged
        case set(Double?)

        var hasChange: Bool {
            if case .set = self { return true }
            return false
        }

        func apply(to item: InventoryItem, at field: ReferenceWritableKeyPath<InventoryItem, Double?>) {
            if case .set(let value) = self { item[keyPath: field] = value }
        }
    }

    private struct AmountEdits {
        var bottleCost: AmountEdit = .unchanged
        var bottlesOnHand: AmountEdit = .unchanged
        var lowStockThreshold: AmountEdit = .unchanged

        var hasChanges: Bool {
            bottleCost.hasChange || bottlesOnHand.hasChange || lowStockThreshold.hasChange
        }

        func apply(to item: InventoryItem) {
            bottleCost.apply(to: item, at: \.bottleCost)
            bottlesOnHand.apply(to: item, at: \.quantity)
            lowStockThreshold.apply(to: item, at: \.lowStockThreshold)
        }
    }

    /// Canonical ingredients required by recipes but not in inventory — one-tap add.
    private var suggestedMissing: [String] {
        var missing: [String] = []
        var seen = Set<String>()
        for match in RecipeEngine.rankedMatches(recipes: recipes, inventory: inventory) {
            for line in match.missing {
                if seen.insert(line.canonicalName).inserted {
                    missing.append(line.name)
                }
            }
            if missing.count >= 6 { break }
        }
        return missing
    }

    init(item: InventoryItem?, seed: InventorySeed? = nil, onFinished: ((InventoryEditResult) -> Void)? = nil) {
        self.item = item
        self.seed = seed
        self.onFinished = onFinished
        _name = State(initialValue: item?.name ?? seed?.name ?? "")
        _category = State(initialValue: item?.inventoryCategory ?? IngredientNormalizer.category(for: seed?.name ?? ""))
        _isInStock = State(initialValue: item?.isAvailable ?? true)
        _isLowStock = State(initialValue: item?.isLowStock ?? false)
        _canonicalOverride = State(initialValue: item?.canonicalOverride ?? "")
        _barcode = State(initialValue: item?.barcode ?? seed?.barcode ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                if let note = seed?.scanNote {
                    Section {
                        Label(note, systemImage: "barcode.viewfinder")
                            .font(.subheadline)
                            .foregroundStyle(PourColor.textSecondary)
                            .accessibilityLabel(note)
                    }
                }
                Section("Item") {
                    TextField("Name (e.g. London Dry Gin)", text: $name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.done)
                        .onSubmit { dismissKeyboardFocus() }
                        .onChange(of: name) { _, new in
                            if item == nil {
                                category = IngredientNormalizer.category(for: new)
                            }
                        }
                    Picker("Category", selection: $category) {
                        ForEach(InventoryCategory.allCases, id: \.self) {
                            Label($0.displayName, systemImage: $0.symbol).tag($0)
                        }
                    }
                    .accessibilityLabel("Category")
                    Toggle("In stock", isOn: $isInStock)
                        .accessibilityLabel("In stock, \(isInStock ? "on" : "off")")
                        .accessibilityIdentifier("inventory.inStock")
                    Toggle("Flag low stock manually", isOn: $isLowStock)
                        .accessibilityLabel("Low stock, \(isLowStock ? "on" : "off")")
                        .accessibilityIdentifier("inventory.lowStock")
                }
                Section {
                    TextField("Canonical ingredient (optional)", text: $canonicalOverride)
                        .focused($focusedField, equals: .canonical)
                        .submitLabel(.done)
                        .onSubmit { dismissKeyboardFocus() }
                        .autocorrectionDisabled()
                } header: {
                    Text("Matching")
                } footer: {
                    Text("Maps to “\(canonicalOverride.isEmpty ? IngredientNormalizer.canonicalName(for: name) : IngredientNormalizer.normalize(canonicalOverride))” for matching. Leave blank to use the auto-detected canonical name.")
                }
                Section {
                    if ProGate.isLocked(.inventoryOperations, isPro: pro.isPro) {
                        Button {
                            showPro = true
                        } label: {
                            Label("Track bottle cost, quantity, and low-stock alerts with Pro", systemImage: "lock")
                                .font(.subheadline)
                                .foregroundStyle(PourColor.textSecondary)
                        }
                        .accessibilityLabel("Cost and stock tracking requires PourSTL Pro")
                        .accessibilityAddTraits(.isButton)
                    } else {
                        TextField("Bottle cost (\(currencyIdentifier))", text: $amounts.bottleCost)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("inventory.bottleCost")
                        TextField("Bottles on hand", text: $amounts.bottlesOnHand)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("inventory.quantity")
                        TextField("Low-stock alert at (bottles)", text: $amounts.lowStockThreshold)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("inventory.lowStockThreshold")
                    }
                } header: {
                    Text("Cost & quantity")
                } footer: {
                    if !ProGate.isLocked(.inventoryOperations, isPro: pro.isPro) {
                        Text("Partial bottles are fine. Zero bottles marks an item out of stock. In-stock items are flagged low at or below their alert level.")
                    }
                }
                if !barcode.isEmpty {
                    Section("Barcode") {
                        Text(BarcodeFormatting.grouped(barcode))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(PourColor.textPrimary)
                            .accessibilityLabel("Barcode \(BarcodeFormatting.spokenDigits(barcode))")
                            .speechSpellsOutCharacters()
                    }
                }
                if !suggestedMissing.isEmpty && item == nil {
                    Section("Missing from recipes") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestedMissing, id: \.self) { suggestion in
                                    Button {
                                        name = suggestion
                                        category = IngredientNormalizer.category(for: suggestion)
                                        Haptics.selection()
                                    } label: {
                                        Text(suggestion)
                                            .font(.subheadline)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(PourColor.surface, in: Capsule())
                                    }
                                    .accessibilityLabel("Add \(suggestion)")
                                    .accessibilityAddTraits(.isButton)
                                }
                            }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .scrollContentBackground(.hidden)
            .background(PourColor.background)
            .alert("Item wasn’t saved", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your edits are still here. Check available device storage and try again.")
            }
            .alert("Check inventory amounts", isPresented: $showInvalidAmounts) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Enter a number of zero or more for each value, or leave it blank.")
            }
            .sheet(item: $duplicateOffer) { match in
                BarcodeExistingSheet(match: match, appliesInventoryDetails: validatedAmountEdits?.hasChanges == true) {
                    applyDuplicateOffer(match)
                }
            }
            .onAppear(perform: loadInitialAmounts)
            .sheet(isPresented: $showPro) { ProUpsellView() }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboardFocus() }
                        .accessibilityLabel("Dismiss inventory keyboard")
                        .accessibilityHint("Closes the keyboard and keeps your edits.")
                        .accessibilityIdentifier("inventory.keyboard.done")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel")
                        .accessibilityAddTraits(.isButton)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(item == nil && seed?.barcode != nil ? "Add to My Bar" : "Save") { save() }
                        .disabled(IngredientNormalizer.normalize(name).isEmpty)
                        .accessibilityLabel(saveAccessibilityLabel)
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
    }

    private func dismissKeyboardFocus() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var currencyIdentifier: String { locale.currency?.identifier ?? "USD" }

    private func loadInitialAmounts() {
        guard initialAmounts == nil else { return }
        let format = FloatingPointFormatStyle<Double>(locale: locale)
            .grouping(.never)
            .precision(.significantDigits(1...17))
        let original = AmountInputs(
            bottleCost: item?.bottleCost.map { $0.formatted(format) } ?? "",
            bottlesOnHand: item?.quantity.map { $0.formatted(format) } ?? "",
            lowStockThreshold: item?.lowStockThreshold.map { $0.formatted(format) } ?? ""
        )
        amounts = original
        initialAmounts = original
    }

    private var validatedAmountEdits: AmountEdits? {
        guard !ProGate.isLocked(.inventoryOperations, isPro: pro.isPro),
              let initialAmounts else { return AmountEdits() }
        guard let cost = amountEdit(amounts.bottleCost, original: initialAmounts.bottleCost),
              let quantity = amountEdit(amounts.bottlesOnHand, original: initialAmounts.bottlesOnHand),
              let threshold = amountEdit(amounts.lowStockThreshold, original: initialAmounts.lowStockThreshold) else {
            return nil
        }
        return AmountEdits(bottleCost: cost, bottlesOnHand: quantity, lowStockThreshold: threshold)
    }

    private func amountEdit(_ text: String, original: String) -> AmountEdit? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == original { return .unchanged }
        if trimmed.isEmpty { return .set(nil) }

        let parts = trimmed.components(separatedBy: locale.decimalSeparator ?? ".")
        let digits = parts.joined()
        guard parts.count <= 2, !digits.isEmpty, digits.allSatisfy({ $0.isNumber }) else { return nil }
        let strategy = FloatingPointFormatStyle<Double>(locale: locale).grouping(.never).parseStrategy
        guard let value = try? strategy.parse(trimmed), value.isFinite, value >= 0 else { return nil }
        return .set(value)
    }

    private var navigationTitle: String {
        if item != nil { return "Edit item" }
        if seed?.barcode != nil { return "Confirm item" }
        return "Add item"
    }

    private var saveAccessibilityLabel: String {
        if item != nil { return "Save item" }
        if seed?.barcode != nil { return "Add to My Bar" }
        return "Add inventory item"
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let amountEdits = validatedAmountEdits else {
            showInvalidAmounts = true
            return
        }
        let override = IngredientNormalizer.normalize(canonicalOverride)
        let cleanedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        let rows = inventory.map { row in
            (row, BarcodeStockSnapshot(item: row))
        }
        let stock = rows.map { $0.1 }
        if let item {
            item.name = trimmed
            item.category = category.rawValue
            if amountEdits.bottlesOnHand.hasChange {
                // Apply the toggle alongside the replacement count so a previous zero
                // can't mask the old flag or clear an explicitly entered zero.
                item.isInStock = isInStock
            } else if isInStock != item.isAvailable {
                item.setAvailability(isInStock)
            }
            item.isLowStock = isLowStock
            item.canonicalOverride = override.isEmpty ? nil : override
            if !cleanedBarcode.isEmpty {
                item.barcode = cleanedBarcode
            }
            amountEdits.apply(to: item)
        } else if !cleanedBarcode.isEmpty {
            switch BarcodeResolver.saveUnknownCode(
                name: trimmed,
                barcode: cleanedBarcode,
                isInStock: isInStock,
                stock: stock
            ) {
            case .insert(let confirmed):
                let new = InventoryItem(name: confirmed.name, category: category, isInStock: confirmed.isInStock)
                new.isLowStock = isLowStock
                new.canonicalOverride = override.isEmpty ? nil : override
                new.barcode = confirmed.barcode
                amountEdits.apply(to: new)
                modelContext.insert(new)
            case .update(let match, let mutation):
                guard let index = BarcodeResolver.locate(match, stock: stock) else {
                    offerExisting(match, hasAmountEdits: amountEdits.hasChanges)
                    return
                }
                mutation.applyStockAndBarcode(to: rows[index].0)
                amountEdits.apply(to: rows[index].0)
            case .offerExisting(let match):
                offerExisting(match, hasAmountEdits: amountEdits.hasChanges)
                return
            case .rejected:
                return
            }
        } else {
            let new = InventoryItem(name: trimmed, category: category, isInStock: isInStock)
            new.isLowStock = isLowStock
            new.canonicalOverride = override.isEmpty ? nil : override
            amountEdits.apply(to: new)
            modelContext.insert(new)
        }
        do {
            try modelContext.save()
            Haptics.success()
            finish(.saved)
        } catch {
            modelContext.rollback()
            showSaveError = true
        }
    }

    private func offerExisting(_ match: ExistingBarcodeMatch, hasAmountEdits: Bool) {
        Haptics.warning()
        if onFinished != nil && !hasAmountEdits {
            finish(.alreadyInBar(match))
        } else {
            duplicateOffer = match
        }
    }

    private func applyDuplicateOffer(_ match: ExistingBarcodeMatch) {
        let rows = inventory.map { row in
            (row, BarcodeStockSnapshot(item: row))
        }
        let stock = rows.map { $0.1 }
        guard let index = BarcodeResolver.locate(match, stock: stock),
              let amountEdits = validatedAmountEdits else { return }
        let mutation = BarcodeResolver.mutation(match: match, row: stock[index], update: .confirmedSheet)
        guard mutation.didChange || amountEdits.hasChanges else {
            duplicateOffer = nil
            return
        }
        if mutation.didChange {
            mutation.applyStockAndBarcode(to: rows[index].0)
        }
        amountEdits.apply(to: rows[index].0)
        do {
            try modelContext.save()
            Haptics.success()
            duplicateOffer = nil
            finish(.saved)
        } catch {
            modelContext.rollback()
            duplicateOffer = nil
            showSaveError = true
        }
    }

    private func finish(_ result: InventoryEditResult) {
        if let onFinished {
            onFinished(result)
        } else {
            dismiss()
        }
    }
}
