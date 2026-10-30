import SwiftUI
import SwiftData

struct MyBarView: View {
    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var filter: StockFilter = .all
    @State private var showAdd = false
    @State private var showScanner = false
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
                case .inStock: return item.isInStock
                case .out: return !item.isInStock
                case .low: return item.isLowStock
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
                        message: "Add bottles and staples so Pour can tell you what you can make.",
                        actionTitle: "Add your first item"
                    ) {
                        showAdd = true
                    }
                } else {
                    List {
                        ForEach(grouped, id: \.0) { category, categoryItems in
                            Section {
                                ForEach(categoryItems) { item in
                                    inventoryRow(item)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                modelContext.delete(item)
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
            .sheet(isPresented: $showScanner) { BarcodeScannerPlaceholderView() }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
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
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .background(PourColor.background)
    }

    private func inventoryRow(_ item: InventoryItem) -> some View {
        HStack(spacing: 12) {
            Button {
                item.isInStock.toggle()
                item.isInStock ? Haptics.mediumTap() : Haptics.lightTick()
            } label: {
                Image(systemName: item.isInStock ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isInStock ? PourColor.canMake : PourColor.textTertiary)
            }
            .accessibilityLabel("\(item.name), \(item.isInStock ? "in stock" : "not in stock")")
            .accessibilityAddTraits(item.isInStock ? [.isButton, .isSelected] : .isButton)

            Button {
                editingItem = item
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .foregroundStyle(item.isInStock ? PourColor.textPrimary : PourColor.textSecondary)
                    HStack(spacing: 6) {
                        Text(item.inventoryCategory.displayName)
                        if item.canonicalName != IngredientNormalizer.normalize(item.name) {
                            Text("·")
                            Text(item.canonicalName)
                                .foregroundStyle(PourColor.textTertiary)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(PourColor.textTertiary)
                }
            }
            .accessibilityLabel("Edit \(item.name)")
            .accessibilityAddTraits(.isButton)

            Spacer()

            if item.isLowStock {
                Button {
                    item.isLowStock = false
                } label: {
                    StatusPill(kind: .lowStock)
                }
                .accessibilityLabel("\(item.name), low stock")
                .accessibilityAddTraits(.isButton)
            }
        }
        .frame(minHeight: 52)
        .listRowBackground(PourColor.card)
    }
}

// MARK: - Add / edit item sheet

struct InventoryEditSheet: View {
    let item: InventoryItem?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var recipes: [Recipe]
    @Query private var inventory: [InventoryItem]

    @State private var name = ""
    @State private var category: InventoryCategory = .other
    @State private var isInStock = true
    @State private var isLowStock = false
    @State private var canonicalOverride = ""

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

    init(item: InventoryItem?) {
        self.item = item
        _name = State(initialValue: item?.name ?? "")
        _category = State(initialValue: item?.inventoryCategory ?? .other)
        _isInStock = State(initialValue: item?.isInStock ?? true)
        _isLowStock = State(initialValue: item?.isLowStock ?? false)
        _canonicalOverride = State(initialValue: item?.canonicalOverride ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name (e.g. London Dry Gin)", text: $name)
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
                    Toggle("Low stock", isOn: $isLowStock)
                        .accessibilityLabel("Low stock, \(isLowStock ? "on" : "off")")
                }
                Section {
                    TextField("Canonical ingredient (optional)", text: $canonicalOverride)
                        .autocorrectionDisabled()
                } header: {
                    Text("Matching")
                } footer: {
                    Text("Maps to “\(canonicalOverride.isEmpty ? IngredientNormalizer.canonicalName(for: name) : IngredientNormalizer.normalize(canonicalOverride))” for matching. Leave blank to use the auto-detected canonical name.")
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
            .scrollContentBackground(.hidden)
            .background(PourColor.background)
            .navigationTitle(item == nil ? "Add item" : "Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel")
                        .accessibilityAddTraits(.isButton)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(IngredientNormalizer.normalize(name).isEmpty)
                        .accessibilityLabel(item == nil ? "Add inventory item" : "Save item")
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let override = IngredientNormalizer.normalize(canonicalOverride)
        if let item {
            item.name = trimmed
            item.category = category.rawValue
            item.isInStock = isInStock
            item.isLowStock = isLowStock
            item.canonicalOverride = override.isEmpty ? nil : override
        } else {
            let new = InventoryItem(name: trimmed, category: category, isInStock: isInStock)
            new.isLowStock = isLowStock
            new.canonicalOverride = override.isEmpty ? nil : override
            modelContext.insert(new)
        }
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }
}
