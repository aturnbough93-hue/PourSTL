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

/// Dilution assumptions for pre-batched cocktails, by preparation method.
/// Shaking or stirring with ice both chills and dilutes; a pre-batch that skips
/// that step needs measured water instead. Rates follow professional batching
/// guidance: shaken ≈ 25% water, stirred ≈ 20%, built drinks dilute in the
/// glass. Always a starting point — the copy tells the bartender to adjust.
enum DilutionProfile: String, Equatable {
    case shaken, stirred, muddled
    case built, blended, layered, hot

    /// Fraction of the measured liquid volume to add as water. Zero for methods
    /// where dilution happens in the glass or ice is blended into the drink.
    var waterFraction: Double {
        switch self {
        case .shaken, .muddled: return 0.25
        case .stirred: return 0.20
        case .built, .blended, .layered, .hot: return 0
        }
    }

    var assumption: String {
        switch self {
        case .shaken:
            return "Assumes shaking with ice adds about 25% water. Adjust to taste — or leave the water out and shake each pour with ice instead."
        case .muddled:
            return "Muddled drinks are usually finished like a shaken drink, so this assumes about 25% water. Adjust to taste."
        case .stirred:
            return "Assumes stirring with ice adds about 20% water. Adjust to taste — or leave the water out and stir each pour with ice instead."
        case .built:
            return "Built drinks dilute in the glass — the ice and topper do the work, so no water is added to the batch."
        case .blended:
            return "Blended drinks take their dilution from the ice in the blender, so no water is added to the batch."
        case .layered:
            return "Layered drinks are poured without ice dilution, so no water is added to the batch."
        case .hot:
            return "Hot drinks are diluted by their hot water or mixer at service, so no water is added to the batch."
        }
    }

    /// Infer the profile from a freeform method label ("Shaken", "stirred", …).
    static func forMethod(_ method: String) -> DilutionProfile? {
        let normalized = IngredientNormalizer.normalize(method)
        guard !normalized.isEmpty else { return nil }
        if normalized.contains("shak") { return .shaken }
        if normalized.contains("stir") { return .stirred }
        if normalized.contains("mudd") { return .muddled }
        if normalized.contains("buil") { return .built }
        if normalized.contains("blend") { return .blended }
        if normalized.contains("layer") { return .layered }
        if normalized.contains("hot") { return .hot }
        return nil
    }
}

/// Volume math for a pre-batched recipe: measured liquid volume, dilution
/// water, ready-to-pour yield, and the pour per serving.
struct BatchPlan: Equatable {
    let servings: Int
    /// Total ml of all oz/ml-convertible ingredient lines for the whole batch.
    let measuredMilliliters: Double
    let profile: DilutionProfile?
    /// True when some lines (parts, countables, rinses) are not
    /// volume-measurable and are excluded from the totals. Top-ups are excluded
    /// by design — mixers and soda stay out of the batch — and do not flag this.
    let excludesNonVolumeLines: Bool

    /// Water to add for dilution. Zero for built/blended/hot methods; nil when
    /// the method is unrecognized and no dilution assumption applies.
    var waterMilliliters: Double? {
        profile.map { measuredMilliliters * $0.waterFraction }
    }
    var totalMilliliters: Double { measuredMilliliters + (waterMilliliters ?? 0) }
    var perServingMilliliters: Double {
        servings > 0 ? totalMilliliters / Double(servings) : totalMilliliters
    }
}

enum BatchPlanner {
    static func plan(for recipe: Recipe, servings: Int) -> BatchPlan? {
        let factor = Double(max(servings, 1))
        var milliliters = 0.0
        var excludesNonVolume = false
        for line in recipe.sortedIngredients {
            let measure = line.measure
            guard measure.amount.isFinite, measure.amount > 0 else { continue }
            if let volume = measure.scaled(by: factor).milliliters {
                milliliters += volume
            } else if !BatchPrepSheet.isUnmeasured(measure) {
                excludesNonVolume = true
            }
        }
        guard milliliters > 0 else { return nil }
        return BatchPlan(
            servings: servings,
            measuredMilliliters: milliliters,
            profile: DilutionProfile.forMethod(recipe.method),
            excludesNonVolumeLines: excludesNonVolume
        )
    }

    /// Round a volume the way bartenders portion it: quarter-ounce steps or
    /// whole milliliters, matching measure display rounding elsewhere.
    static func displayMeasure(milliliters: Double, unit preference: UnitPreference) -> Measure {
        let converted = Measure(amount: milliliters, unit: .milliliter).converted(to: preference)
        return Measure(amount: Measure.displayAmount(converted.amount, for: converted.unit), unit: converted.unit)
    }
}

/// Pour-cost and menu-price math for the Pro costing sheet.
enum MenuPricing {
    /// Bartenders set menu prices in half-steps; rounding up never under-prices.
    static let priceStep = 0.5
    static let targetPercentRange = 5.0...50.0
    static let defaultTargetPercent = 20.0

    /// Ingredient cost as a percentage of the menu price.
    static func pourCostPercent(cost: Decimal, menuPrice: Decimal) -> Double? {
        guard !cost.isNaN, !menuPrice.isNaN, cost >= 0, menuPrice > 0 else { return nil }
        return NSDecimalNumber(decimal: cost / menuPrice * 100).doubleValue
    }

    static func profitPerDrink(cost: Decimal, menuPrice: Decimal) -> Decimal? {
        guard !cost.isNaN, !menuPrice.isNaN, cost >= 0, menuPrice >= 0 else { return nil }
        return menuPrice - cost
    }

    /// Price that hits the target pour cost, rounded up to the nearest
    /// half unit of currency. The tiny epsilon keeps exact half-step results
    /// from floating-point overshoot without suppressing a real round-up.
    static func suggestedMenuPrice(cost: Decimal, targetPercent: Double) -> Decimal? {
        guard !cost.isNaN, cost > 0,
              targetPercent.isFinite, targetPercent > 0 else { return nil }
        let raw = NSDecimalNumber(decimal: cost).doubleValue / (targetPercent / 100)
        guard raw.isFinite, raw > 0, raw < 1_000_000 else { return nil }
        let rounded = (raw / priceStep - 1e-9).rounded(.up) * priceStep
        return Decimal(rounded)
    }

    /// Ingredient cost as a fraction of the menu price (1 − pour cost %).
    static func ingredientMargin(cost: Decimal, price: Decimal) -> Decimal? {
        guard !cost.isNaN, !price.isNaN, cost >= 0, price > 0 else { return nil }
        return (price - cost) / price
    }
}

/// Bottle-level stock and cost operations for Pro.
enum InventoryOperations {
    /// Manual low-stock flag, or a recorded bottle count at/below the saved threshold.
    static func isEffectivelyLow(_ item: InventoryItem) -> Bool {
        if item.isLowStock { return true }
        guard let quantity = item.quantity, let threshold = item.lowStockThreshold,
              quantity.isFinite, threshold.isFinite, quantity >= 0, threshold >= 0 else { return false }
        return quantity <= threshold
    }

    /// Replacement cost of in-stock bottles. A stocked bottle with no recorded
    /// quantity counts as one. Returns nil when no in-stock item has a bottle cost.
    static func valuation(items: [InventoryItem]) -> Decimal? {
        var total = Decimal.zero
        var anyPriced = false
        for item in items where item.isInStock {
            guard let cost = item.bottleCost, cost.isFinite, cost > 0 else { continue }
            let bottles = max(item.quantity ?? 1, 0)
            guard bottles.isFinite else { continue }
            total += Decimal(cost) * Decimal(bottles)
            anyPriced = true
        }
        return anyPriced ? total : nil
    }
}

/// A single bottle that would complete otherwise-blocked recipes.
struct UnlockCandidate: Identifiable, Equatable {
    let canonicalName: String
    let displayName: String
    let unlockCount: Int
    var id: String { canonicalName }
}

enum ShoppingInsights {
    /// Rank ingredients by how many recipes become makeable when that one
    /// missing required ingredient is stocked. Optional ingredients never count,
    /// and recipes missing two or more required ingredients need more than one
    /// bottle, so they contribute no vote.
    static func bestNextPurchases(recipes: [Recipe], inventory: [InventoryItem], limit: Int = 3) -> [UnlockCandidate] {
        var votes: [String: (displayName: String, count: Int)] = [:]
        for recipe in recipes.sorted(by: { $0.name < $1.name }) {
            let match = RecipeEngine.match(recipe, inventory: inventory)
            guard match.missing.count == 1, let line = match.missing.first else { continue }
            let key = line.canonicalName
            guard !key.isEmpty else { continue }
            let entry = votes[key] ?? (line.name, 0)
            votes[key] = (entry.displayName, entry.count + 1)
        }
        return votes
            .map { UnlockCandidate(canonicalName: $0.key, displayName: $0.value.displayName, unlockCount: $0.value.count) }
            .sorted { lhs, rhs in
                lhs.unlockCount != rhs.unlockCount ? lhs.unlockCount > rhs.unlockCount : lhs.displayName < rhs.displayName
            }
            .prefix(max(limit, 0))
            .map { $0 }
    }
}

enum BatchPrepSheet {
    static func csv(for recipe: Recipe, servings: Int, unit: UnitPreference) -> String {
        let header = ["Recipe", "Servings", "Ingredient", "Batch measure", "Optional", "Ingredient note"]
        // Batchable liquids first in build order; garnishes and other optional
        // lines are grouped last so they are prepped separately.
        let sorted = recipe.sortedIngredients
        let ordered = sorted.filter { !$0.isOptional } + sorted.filter { $0.isOptional }
        var rows = ordered.map { line in
            [
                recipe.name, String(servings), line.name,
                prepMeasure(line.measure.scaled(by: Double(servings)).converted(to: unit)),
                line.isOptional ? "Yes" : "No", line.note ?? "",
            ]
        }
        if let plan = BatchPlanner.plan(for: recipe, servings: servings) {
            rows += summaryRows(for: recipe, servings: servings, plan: plan, unit: unit)
        }
        return csv(header: header, rows: rows)
    }

    private static func summaryRows(for recipe: Recipe, servings: Int, plan: BatchPlan, unit: UnitPreference) -> [[String]] {
        func volumeRow(_ label: String, _ milliliters: Double, _ note: String) -> [String] {
            [
                recipe.name, String(servings), label,
                prepMeasure(BatchPlanner.displayMeasure(milliliters: milliliters, unit: unit)),
                "", note,
            ]
        }
        var rows: [[String]] = []
        if let water = plan.waterMilliliters, water > 0, let profile = plan.profile {
            rows.append(volumeRow("Water (dilution)", water, profile.assumption))
        }
        let exclusionNote = plan.excludesNonVolumeLines
            ? " Lines measured in parts or countables are not included in volume totals."
            : ""
        rows.append(volumeRow(
            "Total batch volume", plan.totalMilliliters,
            "Measured ingredients plus dilution water. Chill the batch; shake the sealed bottle before pouring.\(exclusionNote)"
        ))
        rows.append(volumeRow("Pour per serving", plan.perServingMilliliters, "Ready-to-pour measure per drink."))
        return rows
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
        var isStocked: Bool
        var missingMeasure: Measure
        var missingRecipes: [String]
        var hasMissingRequirements: Bool

        var isOptional: Bool { id.optional }
    }

    struct ShoppingItem: Identifiable {
        let id: String
        let name: String
        let requirements: [Ingredient]
    }

    let batches: [Batch]
    let ingredients: [Ingredient]
    var shopping: [ShoppingItem] {
        let missing = ingredients.filter { !$0.isOptional && $0.hasMissingRequirements }
        return Dictionary(grouping: missing, by: \.id.product).compactMap { product, entries in
            let requirements = entries.map { entry -> Ingredient in
                var requirement = entry
                requirement.measure = entry.missingMeasure
                requirement.recipes = entry.missingRecipes
                requirement.isStocked = false
                return requirement
            }
            return requirements.first.map { ShoppingItem(id: product, name: $0.name, requirements: requirements) }
        }.sorted { ($0.name, $0.id) < ($1.name, $1.id) }
    }

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
                let scaled = line.measure.scaled(by: Double(batch.servings))
                let measure: Measure
                if scaled.unit == .teaspoon, let milliliters = scaled.milliliters {
                    measure = Measure(amount: milliliters, unit: .milliliter)
                } else {
                    measure = scaled.converted(to: .ml)
                }
                let key = Ingredient.Key(product: RecipeCostLine.productName(line.name), unit: measure.unit,
                                         optional: line.isOptional, unmeasured: BatchPrepSheet.isUnmeasured(measure),
                                         relativeRecipe: measure.unit == .part ? index : nil)
                let isStocked = RecipeEngine.isStocked(line, in: stocked)
                var entry = entries[key] ?? Ingredient(id: key, name: line.name, measure: Measure(amount: 0, unit: measure.unit),
                                                       recipes: [], isStocked: isStocked,
                                                       missingMeasure: Measure(amount: 0, unit: measure.unit),
                                                       missingRecipes: [], hasMissingRequirements: false)
                entry.isStocked = entry.isStocked && isStocked
                entry.measure.amount += measure.amount
                if !isStocked {
                    entry.hasMissingRequirements = true
                    entry.missingMeasure.amount += measure.amount
                    if !entry.missingRecipes.contains(batch.recipe.name) { entry.missingRecipes.append(batch.recipe.name) }
                }
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
