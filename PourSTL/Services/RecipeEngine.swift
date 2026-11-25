import Foundation

/// Result of matching one recipe against current inventory.
struct RecipeMatch {
    let recipe: Recipe
    /// Required ingredients not in stock.
    let missing: [IngredientLine]
    /// Optional/garnish ingredients not in stock.
    let missingOptional: [IngredientLine]

    var canMake: Bool { missing.isEmpty }
    /// Missing one or two required items — "almost there".
    var isAlmost: Bool { !canMake && missing.count <= 2 }
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
              unit != .topUp, unit != .part, unit != .rinse else { return nil }
        return Decimal(amount)
    }

    func priceKey(currency: String) -> String {
        // Stock matching groups brands by spirit. Costing must preserve brand identity.
        "\(currency)|\(unit)|\(IngredientNormalizer.normalize(ingredient.name))"
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
        return ([header] + rows).map { $0.map(cell).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    private static func prepMeasure(_ measure: Measure) -> String {
        if measure.unit == .topUp { return measure.unit.displayName }
        let format = FloatingPointFormatStyle<Double>(locale: Locale(identifier: "en_US_POSIX"))
            .grouping(.never).precision(.fractionLength(0...12))
        let amount = measure.amount.formatted(format)
        let label = Measure.pluralized(measure.unit, amount: measure.amount)
        return label.isEmpty ? amount : "\(amount) \(label)"
    }

    private static func cell(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let needsPrefix = trimmed.first.map { "=+-@".contains($0) } ?? false
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(needsPrefix ? "'" : "")\(escaped)\""
    }
}

enum RecipeEngine {

    static func match(_ recipe: Recipe, inventory: [InventoryItem]) -> RecipeMatch {
        let stocked = Set(inventory.filter { $0.isInStock }.map { $0.canonicalName })
        var missing: [IngredientLine] = []
        var missingOptional: [IngredientLine] = []
        for line in recipe.sortedIngredients {
            let canonical = line.canonicalName
            if IngredientNormalizer.assumedAvailable.contains(canonical) { continue }
            if stocked.contains(canonical) { continue }
            // Fallback: normalized raw name match (e.g. user typed something unusual).
            if stocked.contains(IngredientNormalizer.normalize(line.name)) { continue }
            if line.isOptional {
                missingOptional.append(line)
            } else {
                missing.append(line)
            }
        }
        return RecipeMatch(recipe: recipe, missing: missing, missingOptional: missingOptional)
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
    static func ingredientsToAdd(_ lines: [IngredientLine], existing: [ShoppingListItem]) -> [IngredientLine] {
        var pending = Set(existing.filter { !$0.isPurchased }.map { $0.canonicalName })
        return lines.filter { pending.insert($0.canonicalName).inserted }
    }
}
