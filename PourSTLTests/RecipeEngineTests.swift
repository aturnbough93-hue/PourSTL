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
    func testStockedSwapsDoNotChangeTheOriginalMatch() {
        let drink = recipe(name: "Sour", lines: [
            ("Lime juice", 1, "oz", false), ("Simple syrup", 1, "oz", false),
        ])
        let match = RecipeEngine.match(drink, inventory: stock(["Lemon juice", "Demerara syrup"]))
        XCTAssertFalse(match.canMake)
        XCTAssertTrue(match.canMakeWithSwaps)
        XCTAssertEqual(match.missing.compactMap { match.substitute(for: $0) }, ["Lemon juice", "Demerara syrup"])
        XCTAssertFalse(RecipeEngine.match(drink, inventory: stock(["Lemon juice"])).canMakeWithSwaps)
    }

    func testCitrusSwapRequiresStockedJuiceRatherThanAPeel() {
        let drink = recipe(name: "Sour", lines: [("Lime juice", 1, "oz", false)])
        let garnishMatch = RecipeEngine.match(drink, inventory: stock(["Lemon peel"]))
        XCTAssertFalse(garnishMatch.canMakeWithSwaps)
        XCTAssertNil(garnishMatch.missing.first.flatMap { garnishMatch.substitute(for: $0) })
        XCTAssertTrue(RecipeEngine.match(drink, inventory: stock(["Fresh lemon juice"])).canMakeWithSwaps)
    }

    func testShoppingShareGroupsPendingItemsAndAllRecipeSources() {
        let gin = ShoppingListItem(name: "Gin", sourceRecipeName: "Negroni")
        gin.addSourceRecipe("Martini")
        gin.addSourceRecipe("Martini")
        let purchased = ShoppingListItem(name: "Campari")
        purchased.isPurchased = true
        let text = ShoppingListPlanner.shareText([gin, ShoppingListItem(name: "Lime juice"), purchased])
        XCTAssertEqual(text, "PourSTL Shopping List\n\nSpirits\n• Gin — for Martini, Negroni\n\nJuices\n• Lime juice")
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

    func testEventPlanAllocatesServingsAndCombinesVolumesButNotOptionalIngredients() throws {
        let first = recipe(name: "=First", lines: [("Gin", 1, "oz", false), ("Lime juice", 1, "oz", false)])
        let second = recipe(name: "Second", lines: [("Gin", 29.5735, "ml", false), ("Lime juice", 1, "oz", true)])
        let plan = EventPrepPlan(recipes: [first, second], guests: 5, drinksPerGuest: 1, inventory: stock(["Gin"]))
        XCTAssertEqual(plan.batches.map(\.servings), [3, 2])
        let gin = try XCTUnwrap(plan.ingredients.first { $0.name == "Gin" })
        XCTAssertEqual(gin.measure.amount, 5 * Measure.millilitersPerOunce, accuracy: 0.0001)
        XCTAssertEqual(gin.recipes, ["=First", "Second"])
        XCTAssertEqual(plan.shopping.map(\.name), ["Lime juice"])
        XCTAssertEqual(plan.ingredients.filter { $0.name == "Lime juice" }.count, 2)
        XCTAssertTrue(plan.csv(unit: .oz).contains("\"Batch\",\"'=First\",\"3\",\"Gin\",\"3 oz\""))
    }

    func testEventPlanDoesNotMixPartsFromDifferentRecipes() {
        let recipes = ["First", "Second"].map { recipe(name: $0, lines: [("Gin", 1, "part", false)]) }
        let plan = EventPrepPlan(recipes: recipes, guests: 3, drinksPerGuest: 2, inventory: [])
        XCTAssertEqual(plan.ingredients.map(\.recipes), [["First"], ["Second"]])
        XCTAssertEqual(plan.ingredients.map(\.measure.amount), [3, 3])
        let short = EventPrepPlan(recipes: recipes, guests: 1, drinksPerGuest: 1, inventory: [])
        XCTAssertEqual(short.batches.map(\.recipe.name), ["First"])
    }

    func testEventShoppingRecognizesStockOverrideMatchingTheRecipeLabel() {
        let drink = recipe(name: "Martini", lines: [("Beefeater", 1, "oz", false)])
        let bottle = InventoryItem(name: "House bottle")
        bottle.canonicalOverride = "beefeater"
        XCTAssertTrue(RecipeEngine.match(drink, inventory: [bottle]).canMake)
        let plan = EventPrepPlan(recipes: [drink], guests: 1, drinksPerGuest: 1, inventory: [bottle])
        XCTAssertEqual(plan.ingredients.map(\.isStocked), [true])
        XCTAssertTrue(plan.shopping.isEmpty)
    }

    func testPrepSheetsKeepUnmeasuredAndCountedRinsesSeparate() {
        let first = recipe(name: "First", lines: [("Absinthe", 0, "rinse", false)])
        let second = recipe(name: "Second", lines: [("Absinthe", 1, "rinse", false)])
        XCTAssertTrue(BatchPrepSheet.csv(for: first, servings: 2, unit: .oz).contains("\"Absinthe\",\"rinse\""))
        let plan = EventPrepPlan(recipes: [first, second], guests: 4, drinksPerGuest: 1, inventory: [])
        XCTAssertEqual(plan.ingredients.map { BatchPrepSheet.prepMeasure($0.measure) }, ["2 rinses", "rinse"])
        XCTAssertEqual(plan.ingredients.map(\.recipes), [["Second"], ["First"]])
        XCTAssertFalse(plan.csv(unit: .oz).contains("0 rinses"))
    }

    func testMenuPricingRoundsUpAndReportsMarginAtTheSuggestedPrice() throws {
        let estimate = try XCTUnwrap(MenuPriceEstimate(cost: Decimal(string: "2.04")!, targetPercent: 25))
        XCTAssertEqual(estimate.price, 9)
        XCTAssertEqual(NSDecimalNumber(decimal: estimate.ingredientMargin).doubleValue, 0.773333, accuracy: 0.000001)
        XCTAssertNil(MenuPriceEstimate(cost: 2, targetPercent: 0))
        XCTAssertNil(MenuPriceEstimate(cost: 0, targetPercent: 25))
    }

    func testReorderPlanUsesSavedProductPriceAndShowsUnpricedItems() {
        let items = stock(["Gin", "Beefeater", "+Other"])
        for item in items {
            item.quantity = 1
            item.lowStockThreshold = 3
        }
        items[1].quantity = 3
        items[2].isInStock = false
        let prices = ["USD|ml|gin": IngredientPackagePrice(price: 19, yield: 750)]
        let plan = ReorderPlan(items: items, prices: prices, currency: "USD")
        XCTAssertEqual(plan.lines.map(\.packages), [2, 3])
        XCTAssertEqual(plan.lines[0].cost, 38)
        XCTAssertNil(plan.lines[1].cost)
        XCTAssertEqual(plan.pricedSubtotal, 38)
        XCTAssertTrue(plan.csv(currency: "USD").contains("\"'+Other\",\"0\",\"3\",\"3\",\"\",\"USD\""))
    }

    func testEnteringPackagesOnHandRestocksItemForReorder() {
        let item = InventoryItem(name: "Gin", isInStock: false)
        item.setParLevel(onHand: 2, minimum: 3, packageUnit: "ml")
        let plan = ReorderPlan(items: [item], prices: [:], currency: "USD")
        XCTAssertTrue(item.isInStock)
        XCTAssertEqual(plan.lines.map(\.onHand), [2])
        XCTAssertEqual(plan.lines.map(\.packages), [1])
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
