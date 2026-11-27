import Foundation
import SwiftData

/// Result of matching one recipe against current inventory.
struct RecipeMatch {
    let recipe: Recipe
    /// Required ingredients not in stock.
    let missing: [IngredientLine]
    /// Optional/garnish ingredients not in stock.
    let missingOptional: [IngredientLine]
    let stockedForSwaps: Set<String>

    var canMake: Bool { missing.isEmpty }
    /// Missing one or two required items — "almost there".
    var isAlmost: Bool { !canMake && missing.count <= 2 }
    var canMakeWithSwaps: Bool { isAlmost && missing.allSatisfy { substitute(for: $0) != nil } }

    func substitute(for line: IngredientLine) -> String? {
        guard BarUnit.primaryVolumeUnits.contains(line.measure.unit) || line.measure.unit == .teaspoon else { return nil }
        let swaps = [
            "lemon juice": "Lime juice", "lime juice": "Lemon juice",
            "simple syrup": "Demerara syrup", "demerara syrup": "Simple syrup",
        ]
        guard let swap = swaps[line.canonicalName],
              stockedForSwaps.contains(IngredientNormalizer.canonicalName(for: swap)) else { return nil }
        return swap
    }
}

/// The recipe screen also offers an extended range to Pro subscribers.
enum RecipeScaling {
    static let minimumServings = 1
    static let maximumServings = 24
    static let proMaximumServings = 200
}

struct IngredientPackagePrice: Codable {
    let price: Decimal
    let yield: Decimal

    func cost(for quantity: Decimal) -> Decimal? {
        guard !price.isNaN, !yield.isNaN, !quantity.isNaN,
              price >= 0, yield > 0, quantity > 0 else { return nil }
        let cost = price / yield * quantity
        return cost.isNaN ? nil : cost
    }
}

struct RecipeCostLine {
    let ingredient: IngredientLine

    // These names refer to the same product, unlike the interchangeable
    // ingredients grouped together by the inventory matcher.
    private static let productAliases = [
        "angostura": "angostura bitters",
        "ango": "angostura bitters",
        "peychauds": "peychauds bitters",
    ]

    private var volumeInMilliliters: Double? {
        let unit = ingredient.measure.unit
        guard BarUnit.primaryVolumeUnits.contains(unit) || unit == .teaspoon else { return nil }
        if unit == .milliliter { return ingredient.amount }
        return ingredient.measure.milliliters
    }

    var usesVolume: Bool { volumeInMilliliters != nil }

    var unit: String {
        if usesVolume { return "ml" }
        let unit = ingredient.measure.unit
        return unit == .each ? "units" : Measure.pluralized(unit, amount: 2)
    }

    var quantity: Decimal? {
        let amount = volumeInMilliliters ?? ingredient.amount
        let unit = ingredient.measure.unit
        guard amount.isFinite, amount > 0, amount <= 1_000_000_000,
              unit != .topUp, unit != .part else { return nil }
        return Decimal(amount)
    }

    func priceKey(currency: String) -> String {
        "\(currency)|\(unit)|\(Self.productName(ingredient.name))"
    }

    static func productName(_ name: String) -> String {
        let normalized = IngredientNormalizer.normalize(name)
        return productAliases[normalized] ?? normalized
    }

    static func packageUnits(for name: String, currency: String, prices: [String: IngredientPackagePrice]) -> [String] {
        prices.keys.compactMap { key -> String? in
            let parts = key.split(separator: "|", maxSplits: 2)
            guard parts.count == 3, parts[0] == currency, parts[2] == productName(name) else { return nil }
            return String(parts[1])
        }.sorted()
    }

    func cost(in prices: [String: IngredientPackagePrice], currency: String) -> Decimal? {
        guard let quantity else { return nil }
        return prices[priceKey(currency: currency)]?.cost(for: quantity)
    }
}

enum BatchPrepSheet {
    static func csv(for recipe: Recipe, servings: Int, unit: UnitPreference) -> String {
        let header = ["Recipe", "Servings", "Ingredient", "Batch measure", "Optional", "Ingredient note"]
        let rows = recipe.sortedIngredients.map { line in
            [
                recipe.name, String(servings), line.name,
                prepMeasure(line.measure.scaled(by: Double(servings)).converted(to: unit)),
                line.isOptional ? "Yes" : "No", line.note ?? "",
            ]
        }
        return csv(header: header, rows: rows)
    }

    static func csv(header: [String], rows: [[String]]) -> String {
        ([header] + rows).map { $0.map(cell).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    static func prepMeasure(_ measure: Measure) -> String {
        if isUnmeasured(measure) { return measure.unit.displayName }
        let format = FloatingPointFormatStyle<Double>(locale: Locale(identifier: "en_US_POSIX"))
            .grouping(.never).precision(.fractionLength(0...12))
        let amount = measure.amount.formatted(format)
        let label = Measure.pluralized(measure.unit, amount: measure.amount)
        return label.isEmpty ? amount : "\(amount) \(label)"
    }

    static func isUnmeasured(_ measure: Measure) -> Bool {
        measure.unit == .topUp || (measure.unit == .rinse && measure.amount == 0)
    }

    private static func cell(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let needsPrefix = trimmed.first.map { "=+-@".contains($0) } ?? false
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(needsPrefix ? "'" : "")\(escaped)\""
    }
}

struct MenuPriceEstimate {
    let price: Decimal
    let ingredientMargin: Decimal

    init?(cost: Decimal, targetPercent: Int) {
        guard !cost.isNaN, cost > 0, (1...100).contains(targetPercent) else { return nil }
        var rawPrice = cost * 100 / Decimal(targetPercent)
        guard !rawPrice.isNaN else { return nil }
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &rawPrice, 0, .up)
        price = rounded
        ingredientMargin = (rounded - cost) / rounded
    }
}

struct EventPrepPlan {
    struct Batch {
        let recipe: Recipe
        let servings: Int
    }

    struct Ingredient: Identifiable {
        struct Key: Hashable {
            let product: String
            let unit: BarUnit
            let optional: Bool
            let unmeasured: Bool
            let relativeRecipe: Int?
        }

        let id: Key
        let name: String
        var measure: Measure
        var recipes: [String]
        let isStocked: Bool

        var isOptional: Bool { id.optional }
    }

    let batches: [Batch]
    let ingredients: [Ingredient]
    var shopping: [Ingredient] { ingredients.filter { !$0.isOptional && !$0.isStocked } }

    init(recipes: [Recipe], guests: Int, drinksPerGuest: Int, inventory: [InventoryItem]) {
        guard !recipes.isEmpty, (1...RecipeScaling.proMaximumServings).contains(guests), (1...5).contains(drinksPerGuest) else {
            batches = []
            ingredients = []
            return
        }
        let total = guests * drinksPerGuest
        batches = recipes.enumerated().compactMap { index, recipe in
            let count = total / recipes.count + (index < total % recipes.count ? 1 : 0)
            return count > 0 ? Batch(recipe: recipe, servings: count) : nil
        }
        let stocked = Set(inventory.filter(\.isInStock).map(\.canonicalName))
        var entries: [Ingredient.Key: Ingredient] = [:]
        for (index, batch) in batches.enumerated() {
            for line in batch.recipe.sortedIngredients {
                let measure = line.measure.scaled(by: Double(batch.servings)).converted(to: .ml)
                let key = Ingredient.Key(product: RecipeCostLine.productName(line.name), unit: measure.unit,
                                         optional: line.isOptional, unmeasured: BatchPrepSheet.isUnmeasured(measure),
                                         relativeRecipe: measure.unit == .part ? index : nil)
                var entry = entries[key] ?? Ingredient(id: key, name: line.name, measure: Measure(amount: 0, unit: measure.unit),
                                                       recipes: [], isStocked: RecipeEngine.isStocked(line, in: stocked))
                entry.measure.amount += measure.amount
                if !entry.recipes.contains(batch.recipe.name) { entry.recipes.append(batch.recipe.name) }
                entries[key] = entry
            }
        }
        ingredients = entries.values.sorted {
            ($0.name, $0.measure.unit.rawValue, $0.isOptional ? 1 : 0, $0.id.unmeasured ? 1 : 0, $0.id.relativeRecipe ?? -1) <
            ($1.name, $1.measure.unit.rawValue, $1.isOptional ? 1 : 0, $1.id.unmeasured ? 1 : 0, $1.id.relativeRecipe ?? -1)
        }
    }

    func csv(unit: UnitPreference) -> String {
        let batchRows = batches.flatMap { batch in
            batch.recipe.sortedIngredients.map { line in
                ["Batch", batch.recipe.name, String(batch.servings), line.name,
                 BatchPrepSheet.prepMeasure(line.measure.scaled(by: Double(batch.servings)).converted(to: unit)),
                 "", line.isOptional ? "Yes" : "No", line.note ?? ""]
            }
        }
        let ingredientRows = ingredients.map { entry in
            ["Ingredient", entry.recipes.joined(separator: ", "), "", entry.name,
             BatchPrepSheet.prepMeasure(entry.measure.converted(to: unit)),
             entry.isStocked ? "In My Bar" : "Not in My Bar", entry.isOptional ? "Yes" : "No", ""]
        }
        return BatchPrepSheet.csv(header: ["Row", "Recipes", "Servings", "Ingredient", "Amount", "Stock", "Optional", "Note"],
                                  rows: batchRows + ingredientRows)
    }
}

struct ReorderPlan {
    struct Line: Identifiable {
        let id: PersistentIdentifier
        let name: String
        let onHand: Int
        let par: Int
        let cost: Decimal?
        var packages: Int { par - onHand }
    }

    let lines: [Line]
    var pricedSubtotal: Decimal { lines.compactMap(\.cost).reduce(0, +) }

    init(items: [InventoryItem], prices: [String: IngredientPackagePrice], currency: String) {
        lines = items.compactMap { item in
            guard let par = item.lowStockThreshold, (1...999).contains(par), par.rounded() == par,
                  let quantity = item.quantity, (0...999).contains(quantity), quantity.rounded() == quantity else { return nil }
            let onHand = item.isInStock ? Int(quantity) : 0
            guard Int(par) > onHand else { return nil }
            let chosen = item.reorderPackageUnit
            let available = RecipeCostLine.packageUnits(for: item.name, currency: currency, prices: prices)
            let unit = chosen ?? (available.count == 1 ? available.first : nil)
            let price = unit.flatMap { prices["\(currency)|\($0)|\(RecipeCostLine.productName(item.name))"] }
            let cost = price.flatMap { package -> Decimal? in
                guard !package.price.isNaN, package.price >= 0, !package.yield.isNaN, package.yield > 0 else { return nil }
                return package.price * Decimal(Int(par) - onHand)
            }
            return Line(id: item.persistentModelID, name: item.name, onHand: onHand, par: Int(par), cost: cost)
        }
    }

    func csv(currency: String) -> String {
        BatchPrepSheet.csv(header: ["Ingredient", "On hand", "Par", "Packages to order", "Estimated cost", "Currency"],
                           rows: lines.map { [$0.name, String($0.onHand), String($0.par), String($0.packages),
                                               $0.cost.map { NSDecimalNumber(decimal: $0).stringValue } ?? "", currency] })
    }
}

enum RecipeEngine {

    static func isStocked(_ line: IngredientLine, in stocked: Set<String>) -> Bool {
        let canonical = line.canonicalName
        return IngredientNormalizer.assumedAvailable.contains(canonical)
            || stocked.contains(canonical)
            || stocked.contains(IngredientNormalizer.normalize(line.name))
    }

    static func match(_ recipe: Recipe, inventory: [InventoryItem]) -> RecipeMatch {
        let inStock = inventory.filter(\.isInStock)
        let stocked = Set(inStock.map(\.canonicalName))
        var missing: [IngredientLine] = []
        var missingOptional: [IngredientLine] = []
        for line in recipe.sortedIngredients {
            if isStocked(line, in: stocked) { continue }
            if line.isOptional {
                missingOptional.append(line)
            } else {
                missing.append(line)
            }
        }
        let citrusJuices: Set<String> = ["lemon juice", "lime juice"]
        let stockedForSwaps = Set(inStock.compactMap { item -> String? in
            let canonical = item.canonicalName
            if citrusJuices.contains(canonical),
               !IngredientNormalizer.normalize(item.name).hasSuffix(canonical) { return nil }
            return canonical
        })
        return RecipeMatch(recipe: recipe, missing: missing, missingOptional: missingOptional, stockedForSwaps: stockedForSwaps)
    }

    /// All recipes matched against inventory, sorted can-make first then fewest missing.
    static func rankedMatches(recipes: [Recipe], inventory: [InventoryItem]) -> [RecipeMatch] {
        recipes
            .map { match($0, inventory: inventory) }
            .sorted { lhs, rhs in
                if lhs.canMake != rhs.canMake { return lhs.canMake }
                if lhs.missing.count != rhs.missing.count { return lhs.missing.count < rhs.missing.count }
                return lhs.recipe.name < rhs.recipe.name
            }
    }

    /// Real-time search across drink name, ingredient raw/canonical names, and tags.
    /// The query itself is normalized so "Beefeater" finds gin drinks and
    /// "Cointreau" finds orange-liqueur drinks.
    static func search(recipes: [Recipe], query: String, tag: String? = nil) -> [Recipe] {
        let q = IngredientNormalizer.normalize(query)
        let canonicalQuery = IngredientNormalizer.canonicalName(for: query)
        return recipes.filter { recipe in
            if let tag, !recipe.tags.contains(where: { IngredientNormalizer.normalize($0) == IngredientNormalizer.normalize(tag) }) {
                return false
            }
            if q.isEmpty { return true }
            if IngredientNormalizer.normalize(recipe.name).contains(q) { return true }
            if recipe.tags.contains(where: { IngredientNormalizer.normalize($0).contains(q) }) { return true }
            return recipe.ingredients.contains { line in
                IngredientNormalizer.normalize(line.name).contains(q)
                    || line.canonicalName.contains(q)
                    || (!q.isEmpty && line.canonicalName == canonicalQuery)
            }
        }
    }
}

/// Plan shopping additions by canonical ingredient, preserving the displayed name.
/// Purchased entries stay as history; only pending entries suppress another purchase.
enum ShoppingListPlanner {
    static func shareText(_ items: [ShoppingListItem]) -> String {
        let groups = Dictionary(grouping: items.filter { !$0.isPurchased }) {
            IngredientNormalizer.category(for: $0.name)
        }
        return (["PourSTL Shopping List"] + InventoryCategory.allCases.compactMap { category in
            guard let entries = groups[category] else { return nil }
            let lines = entries.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }.map { item in
                let recipes = item.sourceRecipeNames.sorted().joined(separator: ", ")
                return recipes.isEmpty ? "• \(item.name)" : "• \(item.name) — for \(recipes)"
            }
            return ([category.displayName] + lines).joined(separator: "\n")
        }).joined(separator: "\n\n")
    }

    static func ingredientsToAdd(_ lines: [IngredientLine], existing: [ShoppingListItem]) -> [IngredientLine] {
        var pending = Set(existing.filter { !$0.isPurchased }.map { $0.canonicalName })
        return lines.filter { pending.insert($0.canonicalName).inserted }
    }
}
