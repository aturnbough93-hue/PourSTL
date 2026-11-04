import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Query(sort: \ShoppingListItem.createdAt) private var items: [ShoppingListItem]
    @Environment(\.modelContext) private var modelContext
    @Environment(DeepLinkRouter.self) private var router
    @State private var showAdd = false
    @State private var newItemName = ""

    private var pending: [ShoppingListItem] { items.filter { !$0.isPurchased } }
    private var purchased: [ShoppingListItem] { items.filter { $0.isPurchased } }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
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
                            _ = modelContext.saveIfNeeded(operation: "clearing purchased shopping items")
                        }
                        .accessibilityLabel("Clear purchased items")
                        .accessibilityAddTraits(.isButton)
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
                    if !trimmed.isEmpty {
                        modelContext.insert(ShoppingListItem(name: trimmed))
                        _ = modelContext.saveIfNeeded(operation: "adding shopping list item")
                    }
                    newItemName = ""
                }
                Button("Cancel", role: .cancel) { newItemName = "" }
            }
        }
    }

    private func shoppingRow(_ item: ShoppingListItem) -> some View {
        HStack(spacing: 12) {
            Button {
                item.isPurchased.toggle()
                item.isPurchased ? Haptics.success() : Haptics.lightTick()
            } label: {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isPurchased ? PourColor.canMake : PourColor.textTertiary)
            }
            .accessibilityLabel("\(item.name), \(item.isPurchased ? "purchased" : "to buy")")
            .accessibilityAddTraits(item.isPurchased ? [.isButton, .isSelected] : .isButton)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .foregroundStyle(item.isPurchased ? PourColor.textTertiary : PourColor.textPrimary)
                    .strikethrough(item.isPurchased, color: PourColor.textTertiary)
                if let source = item.sourceRecipeName {
                    Text("for \(source)")
                        .font(.caption)
                        .foregroundStyle(PourColor.textTertiary)
                }
            }
            Spacer()
        }
        .frame(minHeight: 52)
        .listRowBackground(PourColor.card)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                modelContext.delete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
