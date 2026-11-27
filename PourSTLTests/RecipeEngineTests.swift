import XCTest
import SwiftData
@testable import PourSTL

final class RecipeEngineTests: XCTestCase {

    private func recipe(name: String, lines: [(String, Double, String, Bool)]) -> Recipe {
        let r = Recipe(name: name, glassType: "Coupe", method: "Shaken")
        for (index, line) in lines.enumerated() {
            r.ingredients.append(IngredientLine(name: line.0, amount: line.1, unit: line.2, isOptional: line.3, position: index))
        }
        return r
    }

    private func stock(_ names: [String]) -> [InventoryItem] {
        names.map { InventoryItem(name: $0, category: .other, isInStock: true) }
    }

    func testCanMakeWhenStocked() {
        let negroni = recipe(name: "Negroni", lines: [
            ("Gin", 1, "oz", false),
            ("Campari", 1, "oz", false),
            ("Sweet Vermouth", 1, "oz", false),
        ])
        let match = RecipeEngine.match(negroni, inventory: stock(["Beefeater", "Campari", "Carpano Antica"]))
        XCTAssertTrue(match.canMake)
        XCTAssertTrue(match.missing.isEmpty)
    }

    func testMissingIngredientsReported() {
        let negroni = recipe(name: "Negroni", lines: [
            ("Gin", 1, "oz", false),
            ("Campari", 1, "oz", false),
            ("Sweet Vermouth", 1, "oz", false),
        ])
        let match = RecipeEngine.match(negroni, inventory: stock(["Beefeater"]))
        XCTAssertFalse(match.canMake)
        XCTAssertEqual(match.missing.map(\.canonicalName), ["campari", "sweet vermouth"])
        XCTAssertTrue(match.isAlmost)
    }

    func testOptionalIngredientsDontBlock() {
        let martini = recipe(name: "Martini", lines: [
            ("London Dry Gin", 2.5, "oz", false),
            ("Dry Vermouth", 0.5, "oz", false),
            ("Orange Bitters", 1, "dashes", true),
        ])
        let match = RecipeEngine.match(martini, inventory: stock(["Tanqueray", "Noilly Prat"]))
        XCTAssertTrue(match.canMake)
        XCTAssertEqual(match.missingOptional.count, 1)
    }

    func testIceAndWaterNeverBlock() {
        let mule = recipe(name: "Mule", lines: [
            ("Vodka", 2, "oz", false),
            ("Ice", 1, "scoop", false),
            ("Water", 4, "oz", false),
        ])
        let match = RecipeEngine.match(mule, inventory: stock(["Smirnoff"]))
        XCTAssertTrue(match.canMake)
    }

    func testOutOfStockDoesntMatch() {
        let inventory = stock(["Beefeater"])
        inventory[0].isInStock = false
        let r = recipe(name: "Gimlet", lines: [("Gin", 2, "oz", false)])
        XCTAssertFalse(RecipeEngine.match(r, inventory: inventory).canMake)
    }

    func testCanonicalOverride() {
        let item = InventoryItem(name: "My Weird Bottle", category: .other, isInStock: true)
        item.canonicalOverride = "gin"
        let r = recipe(name: "Martini", lines: [("Gin", 2.5, "oz", false)])
        XCTAssertTrue(RecipeEngine.match(r, inventory: [item]).canMake)
    }

    func testRankedOrdering() {
        let negroni = recipe(name: "Negroni", lines: [
            ("Gin", 1, "oz", false), ("Campari", 1, "oz", false), ("Sweet Vermouth", 1, "oz", false),
        ])
        let martini = recipe(name: "Martini", lines: [
            ("Gin", 2.5, "oz", false), ("Dry Vermouth", 0.5, "oz", false),
        ])
        let ranked = RecipeEngine.rankedMatches(recipes: [negroni, martini], inventory: stock(["Gin", "Dry Vermouth"]))
        XCTAssertEqual(ranked[0].recipe.name, "Martini")
        XCTAssertTrue(ranked[0].canMake)
        XCTAssertFalse(ranked[1].canMake)
    }

    func testSearchMatchesNameIngredientAndTag() {
        let negroni = recipe(name: "Negroni", lines: [("Campari", 1, "oz", false)])
        negroni.tags = ["bitter", "stirred"]
        let margarita = recipe(name: "Margarita", lines: [("Tequila", 2, "oz", false)])
        let recipes = [negroni, margarita]

        XCTAssertEqual(RecipeEngine.search(recipes: recipes, query: "negr").count, 1)
        XCTAssertEqual(RecipeEngine.search(recipes: recipes, query: "campari").count, 1)
        XCTAssertEqual(RecipeEngine.search(recipes: recipes, query: "bitter").count, 1)
        // Normalized query: searching a brand finds the canonical ingredient.
        XCTAssertEqual(RecipeEngine.search(recipes: recipes, query: "tequila").count, 1)
        XCTAssertEqual(RecipeEngine.search(recipes: recipes, query: "casamigos").count, 1)
        XCTAssertEqual(RecipeEngine.search(recipes: recipes, query: "").count, 2)
        XCTAssertEqual(RecipeEngine.search(recipes: recipes, query: "", tag: "stirred").count, 1)
    }
    func testShoppingPlannerDeduplicatesAliasesAndPendingPurchases() {
        let r = recipe(name: "Test", lines: [
            ("Gin", 1, "oz", false), ("Beefeater", 1, "oz", false),
            ("Campari", 1, "oz", false), ("Sweet Vermouth", 1, "oz", false),
        ])
        let existing = ShoppingListItem(name: "Tanqueray")
        let purchased = ShoppingListItem(name: "Campari")
        purchased.isPurchased = true
        XCTAssertEqual(ShoppingListPlanner.ingredientsToAdd(r.sortedIngredients, existing: [existing, purchased]).map(\.canonicalName), ["campari", "sweet vermouth"])
        XCTAssertEqual(ShoppingListPlanner.ingredientsToAdd(r.sortedIngredients, existing: []).map(\.canonicalName), ["gin", "campari", "sweet vermouth"])
    }

}

final class DeepLinkRouterTests: XCTestCase {
    func testRecipeLinkSwitchesToHomeAndDecodesName() {
        let router = DeepLinkRouter()
        router.pendingTab = .shopping
        router.handle(URL(string: "pourstl://recipe?name=Old%20Fashioned")!)
        XCTAssertEqual(router.pendingTab, .home)
        XCTAssertEqual(router.pendingRecipeName, "Old Fashioned")
    }

    func testPrimaryAndLegacySchemesOpenTheSameTab() {
        for scheme in ["pourstl", "pour"] {
            let router = DeepLinkRouter()
            router.handle(URL(string: "\(scheme)://tab/shopping")!)
            XCTAssertEqual(router.pendingTab, .shopping)
        }
    }

    func testLegacyRecipeLinksRemainSupported() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "pour://recipe?name=Negroni")!)
        XCTAssertEqual(router.pendingTab, .home)
        XCTAssertEqual(router.pendingRecipeName, "Negroni")
    }

    func testPrimaryAndLegacySchemesAreRegistered() {
        let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
        let schemes = urlTypes?.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        XCTAssertEqual(schemes, ["pourstl", "pour"])
    }

    func testUnsupportedLinksDoNotNavigate() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "https://recipe?name=Negroni")!)
        router.handle(URL(string: "pourstl://tab/unknown")!)
        router.handle(URL(string: "pour://tab/unknown")!)
        XCTAssertNil(router.pendingTab)
        XCTAssertNil(router.pendingRecipeName)
    }
}

final class SeedDataTests: XCTestCase {
    @MainActor
    func testSeedingTwicePreservesExistingLibraryWithoutDuplicates() throws {
        let schema = Schema([Recipe.self, IngredientLine.self, InventoryItem.self, ShoppingListItem.self, Venue.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        try SeedData.seedIfNeeded(in: context)
        let firstCount = try context.fetchCount(FetchDescriptor<Recipe>())
        XCTAssertGreaterThan(firstCount, 0)
        let custom = Recipe(name: "My House Drink", isCustom: true)
        context.insert(custom)
        try context.save()
        try SeedData.seedIfNeeded(in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Recipe>()), firstCount + 1)
        XCTAssertEqual(custom.name, "My House Drink")
    }
}

final class RecipeVariationTests: XCTestCase {
    @MainActor
    func testVariationEditsAndDeletionLeaveOriginalIntact() throws {
        let schema = Schema([Recipe.self, IngredientLine.self, InventoryItem.self, ShoppingListItem.self, Venue.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let classic = Recipe(name: "House Classic", glassType: "Coupe", method: "Stirred", instructions: "Stir with ice.", garnish: "Orange twist", tags: ["classic"])
        classic.isFavorite = true
        classic.remoteID = "bundled-classic"
        classic.notes = "Original notes"
        classic.createdAt = Date(timeIntervalSince1970: 1)
        classic.ingredients = [
            IngredientLine(name: "Orange Bitters", amount: 2, unit: "dash", note: "optional garnish", isOptional: true, position: 1),
            IngredientLine(name: "Gin", amount: 2, unit: "oz", position: 0),
        ]
        context.insert(classic)
        try context.save()
        let originalID = classic.persistentModelID

        let variation = classic.makeVariation(named: "My House Classic")
        XCTAssertNil(variation.modelContext, "A draft must stay unpersisted until Save")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Recipe>()), 1)
        XCTAssertTrue(variation.isCustom)
        XCTAssertFalse(variation.isFavorite)
        XCTAssertNil(variation.remoteID)
        XCTAssertNil(variation.venue)
        XCTAssertNotEqual(variation.createdAt, classic.createdAt)
        XCTAssertEqual(variation.notes, classic.notes)
        XCTAssertEqual(variation.garnish, classic.garnish)
        XCTAssertEqual(variation.instructions, classic.instructions)
        XCTAssertEqual(variation.sortedIngredients.map(\.position), [0, 1])
        XCTAssertEqual(variation.sortedIngredients[1].note, "optional garnish")
        XCTAssertTrue(variation.sortedIngredients[1].isOptional)
        XCTAssertFalse(variation.sortedIngredients[0] === classic.sortedIngredients[0])

        context.insert(variation)
        try context.save()
        variation.sortedIngredients[0].amount = 3
        variation.tags.append("my variation")
        try context.save()
        XCTAssertEqual(classic.sortedIngredients[0].amount, 2)
        XCTAssertEqual(classic.tags, ["classic"])
        XCTAssertFalse(classic.isCustom)
        XCTAssertTrue(classic.sortedIngredients.allSatisfy { $0.recipe === classic })

        context.delete(variation)
        try context.save()
        let retained = try XCTUnwrap(context.fetch(FetchDescriptor<Recipe>()).first)
        XCTAssertEqual(retained.persistentModelID, originalID)
        XCTAssertEqual(retained.ingredients.count, 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<IngredientLine>()), 2)
        XCTAssertTrue(retained.isFavorite)
        XCTAssertEqual(retained.remoteID, "bundled-classic")
    }
}

final class BatchPlannerTests: XCTestCase {

    private func recipe(method: String, lines: [(String, Double, String)]) -> Recipe {
        let r = Recipe(name: "Batch test", glassType: "Coupe", method: method)
        for (index, line) in lines.enumerated() {
            r.ingredients.append(IngredientLine(name: line.0, amount: line.1, unit: line.2, position: index))
        }
        return r
    }

    func testMethodInference() {
        XCTAssertEqual(DilutionProfile.forMethod("Shaken"), .shaken)
        XCTAssertEqual(DilutionProfile.forMethod("stirred"), .stirred)
        XCTAssertEqual(DilutionProfile.forMethod("Built"), .built)
        XCTAssertEqual(DilutionProfile.forMethod("Muddled"), .muddled)
        XCTAssertEqual(DilutionProfile.forMethod("Blended"), .blended)
        XCTAssertEqual(DilutionProfile.forMethod("Layered"), .layered)
        XCTAssertEqual(DilutionProfile.forMethod("Hot"), .hot)
        XCTAssertNil(DilutionProfile.forMethod("Rolled"))
        XCTAssertNil(DilutionProfile.forMethod(""))
    }

    func testStirredBatchWaterAndYield() {
        let negroni = recipe(method: "Stirred", lines: [
            ("Gin", 1, "oz"), ("Campari", 1, "oz"), ("Sweet Vermouth", 1, "oz"),
        ])
        let plan = BatchPlanner.plan(for: negroni, servings: 20)
        XCTAssertEqual(plan?.profile, .stirred)
        XCTAssertFalse(plan?.excludesNonVolumeLines ?? true)
        // 60 oz measured; stirred assumes 20% water.
        XCTAssertEqual(plan?.measuredMilliliters ?? 0, 1774.41, accuracy: 0.001)
        XCTAssertEqual(plan?.waterMilliliters ?? 0, 354.882, accuracy: 0.001)
        XCTAssertEqual(plan?.totalMilliliters ?? 0, 2129.292, accuracy: 0.001)
        XCTAssertEqual(plan?.perServingMilliliters ?? 0, 106.4646, accuracy: 0.001)
    }

    func testShakenAssumesMoreWaterThanStirred() {
        let margarita = recipe(method: "Shaken", lines: [
            ("Tequila", 2, "oz"), ("Orange Liqueur", 1, "oz"), ("Lime Juice", 1, "oz"),
        ])
        let plan = BatchPlanner.plan(for: margarita, servings: 1)
        XCTAssertEqual(plan?.waterMilliliters ?? 0, 29.5735, accuracy: 0.001)
        XCTAssertEqual(plan?.totalMilliliters ?? 0, 147.8675, accuracy: 0.001)
    }

    func testBuiltAddsNoWaterButKeepsYield() throws {
        let mule = recipe(method: "Built", lines: [
            ("Vodka", 2, "oz"), ("Ginger Beer", 0, "top up"),
        ])
        let plan = try XCTUnwrap(BatchPlanner.plan(for: mule, servings: 10))
        XCTAssertEqual(plan.profile, .built)
        // Built drinks dilute in the glass: a zero water addition, not no answer.
        XCTAssertEqual(plan.waterMilliliters ?? -1, 0, accuracy: 0.0001)
        XCTAssertNotNil(plan.waterMilliliters)
        XCTAssertFalse(plan.excludesNonVolumeLines, "Top-ups are excluded by design, not a caveat")
        XCTAssertEqual(plan.measuredMilliliters, 591.47, accuracy: 0.001)
        XCTAssertEqual(plan.totalMilliliters, 591.47, accuracy: 0.001)
    }

    func testUnknownMethodSkipsDilutionAssumption() {
        let punch = recipe(method: "", lines: [("Rum", 2, "oz")])
        let plan = BatchPlanner.plan(for: punch, servings: 4)
        XCTAssertNil(plan?.profile)
        XCTAssertNil(plan?.waterMilliliters)
        XCTAssertEqual(plan?.measuredMilliliters ?? 0, 236.588, accuracy: 0.001)
        XCTAssertEqual(plan?.totalMilliliters ?? 0, 236.588, accuracy: 0.001)
    }

    func testPartsAndCountablesAreExcludedAndFlagged() {
        let drink = recipe(method: "Shaken", lines: [
            ("Gin", 2, "oz"), ("Simple Syrup", 1, "part"), ("Sugar", 1, "cube"),
        ])
        let plan = BatchPlanner.plan(for: drink, servings: 1)
        XCTAssertTrue(plan?.excludesNonVolumeLines ?? false)
        XCTAssertEqual(plan?.measuredMilliliters ?? 0, 59.147, accuracy: 0.001)
    }

    func testOnlyCountablesMeansNoPlan() {
        let garnishOnly = recipe(method: "Shaken", lines: [("Lemon", 1, "wedge")])
        XCTAssertNil(BatchPlanner.plan(for: garnishOnly, servings: 1))
    }

    func testDisplayMeasureRoundsLikeBarPortions() {
        let ml = BatchPlanner.displayMeasure(milliliters: 1774.41, unit: .ml)
        XCTAssertEqual(ml.unit, .milliliter)
        XCTAssertEqual(ml.amount, 1774, accuracy: 0.0001)
        let oz = BatchPlanner.displayMeasure(milliliters: 1774.41, unit: .oz)
        XCTAssertEqual(oz.unit, .ounce)
        XCTAssertEqual(oz.amount, 60, accuracy: 0.0001)
        // Quarter-ounce snapping applies to odd amounts.
        let snapped = BatchPlanner.displayMeasure(milliliters: 106.4646, unit: .oz)
        XCTAssertEqual(snapped.amount, 3.5, accuracy: 0.0001)
    }
}

final class MenuPricingTests: XCTestCase {

    func testPourCostPercent() {
        XCTAssertEqual(MenuPricing.pourCostPercent(cost: 1.5, menuPrice: 12) ?? 0, 12.5, accuracy: 0.0001)
        XCTAssertEqual(MenuPricing.pourCostPercent(cost: 0, menuPrice: 12) ?? -1, 0, accuracy: 0.0001)
        XCTAssertNil(MenuPricing.pourCostPercent(cost: 1.5, menuPrice: 0))
        XCTAssertNil(MenuPricing.pourCostPercent(cost: 1.5, menuPrice: -5))
        XCTAssertNil(MenuPricing.pourCostPercent(cost: -1, menuPrice: 12))
    }

    func testProfitPerDrink() {
        XCTAssertEqual(MenuPricing.profitPerDrink(cost: 1.5, menuPrice: 12), Decimal(string: "10.5"))
        XCTAssertNil(MenuPricing.profitPerDrink(cost: -1, menuPrice: 12))
    }

    func testSuggestedPriceRoundsUpToHalfSteps() {
        // Exact half-step results stay put.
        XCTAssertEqual(MenuPricing.suggestedMenuPrice(cost: 1.5, targetPercent: 20), Decimal(string: "7.5"))
        XCTAssertEqual(MenuPricing.suggestedMenuPrice(cost: 2, targetPercent: 25), Decimal(string: "8"))
        // Anything between steps rounds up, never down.
        XCTAssertEqual(MenuPricing.suggestedMenuPrice(cost: 1.55, targetPercent: 20), Decimal(string: "8"))
        XCTAssertEqual(MenuPricing.suggestedMenuPrice(cost: 0.04, targetPercent: 20), Decimal(string: "0.5"))
        XCTAssertNil(MenuPricing.suggestedMenuPrice(cost: 0, targetPercent: 20))
        XCTAssertNil(MenuPricing.suggestedMenuPrice(cost: 1.5, targetPercent: 0))
    }

    func testVariationCopiesMenuPrice() {
        let classic = Recipe(name: "House Classic", glassType: "Coupe", method: "Stirred")
        classic.menuPrice = 9.5
        let variation = classic.makeVariation(named: "My House Classic")
        XCTAssertEqual(variation.menuPrice, 9.5)
        variation.menuPrice = 12
        XCTAssertEqual(classic.menuPrice, 9.5)
        variation.menuPrice = nil
        XCTAssertEqual(classic.menuPrice, 9.5)
    }

    func testTargetPourCostPersists() throws {
        let suite = "PourSTLTests.TargetPourCost.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.targetPourCostPercent, MenuPricing.defaultTargetPercent)
        settings.targetPourCostPercent = 22.5

        let reloaded = AppSettings(defaults: try XCTUnwrap(UserDefaults(suiteName: suite)))
        XCTAssertEqual(reloaded.targetPourCostPercent, 22.5)
    }

    func testTargetPourCostFallsBackWhenStoredValueIsOutOfRange() throws {
        let suite = "PourSTLTests.TargetPourCostInvalid.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(300.0, forKey: "pour.targetPourCostPercent")
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.targetPourCostPercent, MenuPricing.defaultTargetPercent)
    }
}

final class InventoryOperationsTests: XCTestCase {

    private func item(name: String, cost: Double? = nil, quantity: Double? = nil, inStock: Bool = true) -> InventoryItem {
        let item = InventoryItem(name: name, category: .other, isInStock: inStock)
        item.bottleCost = cost
        item.quantity = quantity
        return item
    }

    func testValuationSumsPricedInStockBottles() {
        let items = [
            item(name: "Gin", cost: 30),
            item(name: "Campari", cost: 20, quantity: 2),
            item(name: "Vermouth", cost: 12, quantity: 0),
            item(name: "Orange Bitters"),
        ]
        // 30×1 + 20×2 + 12×0 = 70; unpriced items are skipped.
        XCTAssertEqual(InventoryOperations.valuation(items: items), Decimal(string: "70"))
    }

    func testValuationIgnoresOutOfStockAndUnpriced() {
        XCTAssertNil(InventoryOperations.valuation(items: [item(name: "Gin")]))
        XCTAssertNil(InventoryOperations.valuation(items: [item(name: "Gin", cost: 30, inStock: false)]))
        XCTAssertNil(InventoryOperations.valuation(items: [item(name: "Gin", cost: 0)]))
        XCTAssertNil(InventoryOperations.valuation(items: []))
    }

    func testEffectiveLowStock() {
        let flagged = item(name: "Gin")
        flagged.isLowStock = true
        XCTAssertTrue(InventoryOperations.isEffectivelyLow(flagged))

        let atThreshold = item(name: "Campari", quantity: 1)
        atThreshold.lowStockThreshold = 1
        XCTAssertTrue(InventoryOperations.isEffectivelyLow(atThreshold))

        let aboveThreshold = item(name: "Vermouth", quantity: 3)
        aboveThreshold.lowStockThreshold = 1
        XCTAssertFalse(InventoryOperations.isEffectivelyLow(aboveThreshold))

        let noThreshold = item(name: "Rum", quantity: 1)
        XCTAssertFalse(InventoryOperations.isEffectivelyLow(noThreshold))

        let negative = item(name: "Tequila", quantity: -2)
        negative.lowStockThreshold = 1
        XCTAssertFalse(InventoryOperations.isEffectivelyLow(negative))
    }
}

final class ShoppingInsightsTests: XCTestCase {

    private func recipe(name: String, lines: [(String, Double, String, Bool)]) -> Recipe {
        let r = Recipe(name: name, glassType: "Coupe", method: "Shaken")
        for (index, line) in lines.enumerated() {
            r.ingredients.append(IngredientLine(name: line.0, amount: line.1, unit: line.2, isOptional: line.3, position: index))
        }
        return r
    }

    func testRanksSingleMissingIngredientByUnlockCount() {
        let recipes = [
            recipe(name: "Alpha", lines: [("Gin", 2, "oz", false), ("Campari", 1, "oz", false)]),
            recipe(name: "Beta", lines: [("Gin", 2, "oz", false), ("Sweet Vermouth", 1, "oz", false)]),
            recipe(name: "Delta", lines: [("Gin", 2.5, "oz", false), ("Campari", 1, "oz", false)]),
            recipe(name: "Gamma", lines: [("Campari", 1, "oz", false), ("Sweet Vermouth", 1, "oz", false)]),
        ]
        let inventory = [InventoryItem(name: "Gin", category: .other, isInStock: true)]
        let candidates = ShoppingInsights.bestNextPurchases(recipes: recipes, inventory: inventory)
        // Gamma misses two bottles, so no single purchase completes it.
        XCTAssertEqual(candidates.map(\.canonicalName), ["campari", "sweet vermouth"])
        XCTAssertEqual(candidates[0].unlockCount, 2)
        XCTAssertEqual(candidates[0].displayName, "Campari")
        XCTAssertEqual(candidates[1].unlockCount, 1)
    }

    func testOptionalIngredientsNeverCount() {
        let recipes = [
            recipe(name: "Martini", lines: [("Gin", 2.5, "oz", false), ("Orange Bitters", 1, "dashes", true)]),
        ]
        let inventory = [InventoryItem(name: "Gin", category: .other, isInStock: true)]
        XCTAssertTrue(ShoppingInsights.bestNextPurchases(recipes: recipes, inventory: inventory).isEmpty)
    }

    func testLimitAndEmptyCases() {
        let recipes = [
            recipe(name: "Alpha", lines: [("Gin", 2, "oz", false), ("Campari", 1, "oz", false)]),
            recipe(name: "Beta", lines: [("Gin", 2, "oz", false), ("Sweet Vermouth", 1, "oz", false)]),
        ]
        let inventory = [InventoryItem(name: "Gin", category: .other, isInStock: true)]
        XCTAssertEqual(ShoppingInsights.bestNextPurchases(recipes: recipes, inventory: inventory, limit: 1).count, 1)
        XCTAssertTrue(ShoppingInsights.bestNextPurchases(recipes: recipes, inventory: inventory, limit: 0).isEmpty)
        // Everything makeable → no candidates.
        let stocked = [
            InventoryItem(name: "Gin", category: .other, isInStock: true),
            InventoryItem(name: "Campari", category: .other, isInStock: true),
            InventoryItem(name: "Sweet Vermouth", category: .other, isInStock: true),
        ]
        XCTAssertTrue(ShoppingInsights.bestNextPurchases(recipes: recipes, inventory: stocked).isEmpty)
    }
}

final class PersistentStoreControllerTests: XCTestCase {
    @MainActor
    func testRetryReopensSameStoreAndRetainsExistingData() throws {
        enum TemporaryOpenError: Error { case unavailable }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let schema = Schema([Recipe.self, IngredientLine.self, InventoryItem.self, ShoppingListItem.self, Venue.self])
        let configuration = ModelConfiguration(schema: schema, url: directory.appendingPathComponent("bar.store"))
        do {
            let initial = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(initial)
            context.insert(Recipe(name: "Personal recipe", isCustom: true))
            context.insert(InventoryItem(name: "My saved bottle"))
            try context.save()
        }
        var attempts = 0
        let store = PersistentStoreController(openContainer: {
            attempts += 1
            if attempts == 1 { throw TemporaryOpenError.unavailable }
            return try ModelContainer(for: schema, configurations: [configuration])
        })
        store.openIfNeeded()
        XCTAssertTrue(store.hasAttemptedOpen)
        XCTAssertNil(store.container)
        store.openIfNeeded()
        XCTAssertEqual(attempts, 1, "A failed open waits for an explicit Retry")

        store.retry()
        let container = try XCTUnwrap(store.container)
        let context = ModelContext(container)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Recipe>()).map(\.name), ["Personal recipe"])
        XCTAssertEqual(try context.fetch(FetchDescriptor<InventoryItem>()).map(\.name), ["My saved bottle"])
        store.retry()
        XCTAssertEqual(attempts, 2, "Retry must not replace an already open store")
        XCTAssertTrue(store.container === container)
    }
}
