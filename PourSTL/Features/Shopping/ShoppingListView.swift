import SwiftUI
import SwiftData
import UIKit

struct ShoppingListView: View {
    @Query(sort: \ShoppingListItem.createdAt) private var items: [ShoppingListItem]
    @Query private var inventory: [InventoryItem]
    @Query private var recipes: [Recipe]
    @Environment(\.modelContext) private var modelContext
    @Environment(DeepLinkRouter.self) private var router
    @Environment(ProEntitlementStore.self) private var pro
    @State private var showAdd = false
    @State private var showSaveError = false
    @State private var showPro = false
    @State private var newItemName = ""
    @State private var recentlyStocked = Set<PersistentIdentifier>()

    private var pending: [ShoppingListItem] { items.filter { !$0.isPurchased } }
    private var purchased: [ShoppingListItem] { items.filter { $0.isPurchased } }

    /// Bottles that would each complete otherwise-blocked recipes, excluding
    /// anything already waiting on the list.
    private var shoppingCandidates: [UnlockCandidate] {
        let pendingCanonicals = Set(pending.map(\.canonicalName))
        return ShoppingInsights.bestNextPurchases(recipes: recipes, inventory: inventory, excluding: pendingCanonicals)
    }

    var body: some View {
        let candidates = shoppingCandidates

        NavigationStack {
            Group {
                if items.isEmpty && candidates.isEmpty {
                    EmptyStateView(
                        symbol: "cart",
                        title: "Shopping list is empty",
                        message: "Missing ingredients land here when you tap “Add missing” on a recipe.",
                        actionTitle: "Browse drinks"
                    ) {
                        router.pendingTab = .home
                    }
                } else {
                    List {
                        shoppingInsightSection(candidates)
                        if !pending.isEmpty {
                            Section("To buy (\(pending.count))") {
                                ForEach(pending) { item in
                                    shoppingRow(item)
                                }
                            }
                        }
                        if !purchased.isEmpty {
                            Section("Purchased (\(purchased.count))") {
                                ForEach(purchased) { item in
                                    shoppingRow(item)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(PourColor.background)
            .navigationTitle("Shopping List")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if purchased.isEmpty { EmptyView() }
                    else {
                        Button("Clear purchased") {
                            for item in purchased { modelContext.delete(item) }
                            saveChanges()
                        }
                        .accessibilityLabel("Clear purchased items")
                        .accessibilityAddTraits(.isButton)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !pending.isEmpty {
                        ShareLink(item: ShoppingListPlanner.shareText(pending)) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Share shopping list")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(PourColor.accent)
                    }
                    .accessibilityLabel("Add shopping item")
                    .accessibilityAddTraits(.isButton)
                }
            }
            .alert("Add item", isPresented: $showAdd) {
                TextField("Ingredient name", text: $newItemName)
                Button("Add") {
                    let trimmed = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let canonical = IngredientNormalizer.canonicalName(for: trimmed)
                    if !canonical.isEmpty && !pending.contains(where: { $0.canonicalName == canonical }) {
                        modelContext.insert(ShoppingListItem(name: trimmed))
                        saveChanges()
                    }
                    newItemName = ""
                }
                Button("Cancel", role: .cancel) { newItemName = "" }
            }
            .alert("Shopping list wasn’t updated", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Check available device storage and try again.")
            }
            .sheet(isPresented: $showPro) { ProUpsellView() }
        }
    }

    /// Pro: the single bottles that complete the most otherwise-blocked drinks.
    /// Free users see a lock row only when such a bottle exists.
    @ViewBuilder
    private func shoppingInsightSection(_ candidates: [UnlockCandidate]) -> some View {
        if !candidates.isEmpty {
            Section {
                if ProGate.isLocked(.shoppingInsights, isPro: pro.isPro) {
                    Button {
                        showPro = true
                    } label: {
                        Label("Pro ranks the single bottle that unlocks the most drinks", systemImage: "lock")
                            .font(.subheadline)
                            .foregroundStyle(PourColor.textSecondary)
                    }
                    .accessibilityLabel("Smart shopping insights require PourSTL Pro")
                    .accessibilityAddTraits(.isButton)
                    .listRowBackground(PourColor.card)
                } else {
                    ForEach(candidates) { candidate in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.displayName)
                                    .font(.body)
                                    .foregroundStyle(PourColor.textPrimary)
                                Text(candidate.unlockCount == 1 ? "Unlocks 1 drink" : "Unlocks \(candidate.unlockCount) drinks")
                                    .font(.caption)
                                    .foregroundStyle(PourColor.textSecondary)
                            }
                            Spacer()
                            Button("Add") { addCandidate(candidate) }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PourColor.accent)
                                .frame(minHeight: 44)
                                .accessibilityLabel("Add \(candidate.displayName) to shopping list")
                                .accessibilityAddTraits(.isButton)
                        }
                        .frame(minHeight: 52)
                        .buttonStyle(.borderless)
                        .listRowBackground(PourColor.card)
                    }
                }
            } header: {
                Text("Best next bottle")
            } footer: {
                if !ProGate.isLocked(.shoppingInsights, isPro: pro.isPro) {
                    Text("Ranked by how many recipes need only that one ingredient. Optional garnishes never count.")
                }
            }
        }
    }

    private func addCandidate(_ candidate: UnlockCandidate) {
        guard !pending.contains(where: { $0.canonicalName == candidate.canonicalName }) else { return }
        modelContext.insert(ShoppingListItem(name: candidate.displayName))
        if saveChanges() { Haptics.success() }
    }

    private func shoppingRow(_ item: ShoppingListItem) -> some View {
        HStack(spacing: 12) {
            Button {
                item.isPurchased.toggle()
                if saveChanges() {
                    item.isPurchased ? Haptics.success() : Haptics.lightTick()
                }
            } label: {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isPurchased ? PourColor.canMake : PourColor.textTertiary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("\(item.name), \(item.isPurchased ? "purchased" : "to buy")")
            .accessibilityAddTraits(item.isPurchased ? [.isButton, .isSelected] : .isButton)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .foregroundStyle(item.isPurchased ? PourColor.textTertiary : PourColor.textPrimary)
                    .strikethrough(item.isPurchased, color: PourColor.textTertiary)
                if !item.sourceRecipeNames.isEmpty {
                    Text("for \(item.sourceRecipeNames.sorted().joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(PourColor.textTertiary)
                }
            }
            Spacer()
            if item.isPurchased {
                let stocked = inventory.contains { $0.canonicalName == item.canonicalName && $0.isAvailable && !$0.isLowStock }
                let justStocked = recentlyStocked.contains(item.persistentModelID)
                Button {
                    stockBar(with: item)
                } label: {
                    Label(justStocked ? "Stocked" : (stocked ? "In My Bar" : "Stock bar"), systemImage: stocked || justStocked ? "checkmark" : "shippingbox")
                        .font(.caption.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .disabled(stocked || justStocked)
                .accessibilityLabel(justStocked ? "\(item.name), added to My Bar" : (stocked ? "\(item.name), in My Bar" : "Add \(item.name) to My Bar"))
            }
        }
        .frame(minHeight: 52)
        .buttonStyle(.borderless)
        .listRowBackground(PourColor.card)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                modelContext.delete(item)
                saveChanges()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    /// Explicitly stocking a purchased item keeps shopping history and inventory
    /// connected without silently changing the user's bar when checking a row.
    private func stockBar(with item: ShoppingListItem) {
        do {
            let currentInventory = try modelContext.fetch(FetchDescriptor<InventoryItem>())
            if let existing = currentInventory.first(where: { $0.canonicalName == item.canonicalName }) {
                existing.setAvailability(true)
                existing.isLowStock = false
            } else {
                modelContext.insert(InventoryItem(name: item.name, category: IngredientNormalizer.category(for: item.name)))
            }
            try modelContext.save()
            let itemID = item.persistentModelID
            recentlyStocked.insert(itemID)
            UIAccessibility.post(notification: .announcement, argument: "\(item.name) added to My Bar")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                recentlyStocked.remove(itemID)
            }
            Haptics.success()
        } catch {
            modelContext.rollback()
            showSaveError = true
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
