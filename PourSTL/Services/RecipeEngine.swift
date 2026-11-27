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
        let name = IngredientNormalizer.normalize(ingredient.name)
        return "\(currency)|\(unit)|\(Self.productAliases[name] ?? name)"
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
            } else if measure.unit != .topUp {
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
        return ([header] + rows).map { $0.map(cell).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
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
