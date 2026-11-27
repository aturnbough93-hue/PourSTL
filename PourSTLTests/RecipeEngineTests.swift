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

    func testEventPlanCombinesTeaspoonsWithMillilitersButKeepsCountsSeparate() throws {
        let first = recipe(name: "First", lines: [("Sugar", 2, "tsp", false)])
        let second = recipe(name: "Second", lines: [("Sugar", 5, "ml", false), ("Sugar", 1, "cube", false)])
        let plan = EventPrepPlan(recipes: [first, second], guests: 4, drinksPerGuest: 1, inventory: [])
        XCTAssertEqual(plan.ingredients.map(\.measure.unit), [.cube, .milliliter])
        let volume = try XCTUnwrap(plan.ingredients.first { $0.measure.unit == .milliliter })
        XCTAssertEqual(volume.measure.amount, 4 * 4.92892 + 10, accuracy: 0.0001)
        XCTAssertEqual(volume.recipes, ["First", "Second"])
        XCTAssertTrue(plan.csv(unit: .ml).contains(#""Batch","First","2","Sugar","4 tsp""#))
    }

    func testEventShoppingIncludesMergedProductIfAnyLabelIsMissing() throws {
        let first = recipe(name: "First", lines: [("Ango", 1, "dash", false)])
        let second = recipe(name: "Second", lines: [("Angostura bitters", 1, "dash", false)])
        let bottle = InventoryItem(name: "House bottle")
        bottle.canonicalOverride = "ango"
        XCTAssertTrue(RecipeEngine.match(first, inventory: [bottle]).canMake)
        XCTAssertFalse(RecipeEngine.match(second, inventory: [bottle]).canMake)
        for recipes in [[first, second], [second, first]] {
            let plan = EventPrepPlan(recipes: recipes, guests: 2, drinksPerGuest: 1, inventory: [bottle])
            XCTAssertEqual(plan.ingredients.map(\.isStocked), [false])
            XCTAssertEqual(plan.shopping.map(\.id), ["angostura bitters"])
            XCTAssertEqual(plan.shopping.first?.requirements.count, 1)
            let requirement = try XCTUnwrap(plan.shopping.first?.requirements.first)
            XCTAssertEqual(requirement.measure.amount, 1)
            XCTAssertEqual(requirement.recipes, ["Second"])
            XCTAssertTrue(plan.csv(unit: .oz).contains(#""Shopping","Second","","Angostura bitters","1 dash""#))
        }
    }

    func testEventShoppingUsesCanonicalProductAcrossMissingAliasUnits() throws {
        let first = recipe(name: "First", lines: [("Ango", 1, "dash", false)])
        let second = recipe(name: "Second", lines: [("Angostura bitters", 1, "drop", false)])
        for recipes in [[first, second], [second, first]] {
            let plan = EventPrepPlan(recipes: recipes, guests: 2, drinksPerGuest: 1, inventory: [])
            let item = try XCTUnwrap(plan.shopping.first)
            XCTAssertEqual(plan.shopping.count, 1)
            XCTAssertEqual(item.name, "Angostura bitters")
            XCTAssertTrue(plan.csv(unit: .oz).contains(#""Shopping","First","","Angostura bitters","1 dash""#))
            XCTAssertTrue(plan.csv(unit: .oz).contains(#""Shopping","Second","","Angostura bitters","1 drop""#))
        }
    }

    func testEventShoppingFallbackPreservesAliasPunctuation() {
        let drink = recipe(name: "First", lines: [("Peychaud’s", 1, "dash", false)])
        let plan = EventPrepPlan(recipes: [drink], guests: 1, drinksPerGuest: 1, inventory: [])
        XCTAssertEqual(plan.shopping.first?.name, "Peychaud’s")
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
        XCTAssertEqual(plan.shopping.map(\.name), ["Absinthe"])
        XCTAssertEqual(plan.shopping.first?.requirements.map(\.recipes), [["Second"], ["First"]])
        XCTAssertFalse(plan.csv(unit: .oz).contains("0 rinses"))
    }

    func testMenuPricingRoundsUpAndReportsMarginAtTheSuggestedPrice() throws {
        let cost = Decimal(string: "2.04")!
        let price = try XCTUnwrap(MenuPricing.suggestedMenuPrice(cost: cost, targetPercent: 25))
        XCTAssertEqual(price, Decimal(string: "8.5"))
        let margin = try XCTUnwrap(MenuPricing.ingredientMargin(cost: cost, price: price))
        XCTAssertEqual(NSDecimalNumber(decimal: margin).doubleValue, 0.76, accuracy: 0.000001)
        XCTAssertNil(MenuPricing.suggestedMenuPrice(cost: 2, targetPercent: 0))
        XCTAssertNil(MenuPricing.suggestedMenuPrice(cost: 0, targetPercent: 25))
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

    func testParOnlySavePreservesStockUntilZeroIsEntered() {
        let item = InventoryItem(name: "Gin")
        XCTAssertNil(item.stockedPackageQuantity)
        for par in [3, 4] {
            item.setParLevel(onHand: 0, minimum: par, packageUnit: nil, updateStockStatus: false)
            XCTAssertTrue(item.isAvailable)
            XCTAssertNil(item.quantity)
            XCTAssertEqual(ReorderPlan(items: [item], prices: [:], currency: "USD").lines.map(\.packages), [par])
        }
        item.setParLevel(onHand: 0, minimum: 4, packageUnit: nil)
        XCTAssertFalse(item.isInStock)
        let drink = recipe(name: "Martini", lines: [("Gin", 1, "oz", false)])
        XCTAssertFalse(RecipeEngine.match(drink, inventory: [item]).canMake)
    }

    func testParSavePreservesUneditedFractionalThresholdAndCanClearIt() {
        let item = InventoryItem(name: "Gin")
        item.lowStockThreshold = 0.5

        item.setParLevel(onHand: 2, minimum: nil, packageUnit: "ml")
        XCTAssertEqual(item.lowStockThreshold, 0.5)

        item.setParLevel(onHand: 0, minimum: 0, packageUnit: "ml", updateStockStatus: false)
        XCTAssertNil(item.lowStockThreshold)
        XCTAssertEqual(item.quantity, 2)
    }

    func testReorderUsesZeroForUnavailableItemsAndRoundsUpFractionalDeficits() {
        let unknown = InventoryItem(name: "Gin", isInStock: false)
        unknown.lowStockThreshold = 3
        let unavailable = InventoryItem(name: "Campari", isInStock: false)
        unavailable.quantity = 1.5
        unavailable.lowStockThreshold = 3
        let stocked = InventoryItem(name: "Vermouth")
        stocked.quantity = 1.5
        stocked.lowStockThreshold = 4
        let partialPar = InventoryItem(name: "Port")
        partialPar.quantity = 1.2
        partialPar.lowStockThreshold = 2.2
        let items = [unknown, unavailable, stocked, partialPar]
        let plan = ReorderPlan(items: items, prices: [:], currency: "USD")
        XCTAssertEqual(plan.lines.map(\.onHand), [0, 0, 1.5, 1.2])
        XCTAssertEqual(plan.lines.map(\.packages), [3, 3, 3, 1])
        XCTAssertTrue(plan.csv(currency: "USD").contains(#""Vermouth","1.5","4","3""#))
    }

    func testZeroQuantityDoesNotCountAsStockUntilRestocked() {
        let gin = InventoryItem(name: "Gin")
        gin.quantity = 0
        let drink = recipe(name: "Martini", lines: [("Gin", 1, "oz", false)])
        XCTAssertFalse(RecipeEngine.match(drink, inventory: [gin]).canMake)
        XCTAssertEqual(EventPrepPlan(recipes: [drink], guests: 1, drinksPerGuest: 1, inventory: [gin]).shopping.count, 1)
        XCTAssertFalse(BarcodeStockSnapshot(item: gin).isInStock)
        gin.setAvailability(true)
        XCTAssertNil(gin.quantity)
        XCTAssertTrue(RecipeEngine.match(drink, inventory: [gin]).canMake)
    }

    func testParLevelSaveTreatsClearedPackageCountAsExplicitZero() {
        XCTAssertEqual(ParLevelSavePolicy.parsedOnHand(""), 0)
        XCTAssertEqual(ParLevelSavePolicy.parsedOnHand("  "), 0)
        XCTAssertEqual(ParLevelSavePolicy.parsedOnHand("2"), 2)
        XCTAssertNil(ParLevelSavePolicy.parsedOnHand("abc"))
        XCTAssertNil(ParLevelSavePolicy.parsedOnHand("2.5"))
        XCTAssertNil(ParLevelSavePolicy.parsedOnHand("1000"))
        let cleared = ParLevelSavePolicy.values(enteredOnHand: 0, initialOnHand: 2, didEditOnHand: true)
        XCTAssertEqual(cleared.onHand, 0)
        XCTAssertTrue(cleared.updateStockStatus)
        let untouched = ParLevelSavePolicy.values(enteredOnHand: 0, initialOnHand: 2, didEditOnHand: false)
        XCTAssertEqual(untouched.onHand, 2)
        XCTAssertFalse(untouched.updateStockStatus)
    }

    func testEditingParDoesNotRestockAnItemWithAStalePackageCount() throws {
        let item = InventoryItem(name: "Gin", isInStock: false)
        item.quantity = 2
        let onHand = try XCTUnwrap(item.stockedPackageQuantity)
        XCTAssertEqual(onHand, 0)
        item.setParLevel(onHand: Int(onHand), minimum: 4, packageUnit: nil)
        XCTAssertFalse(item.isInStock)
        let plan = ReorderPlan(items: [item], prices: [:], currency: "USD")
        XCTAssertEqual(plan.lines.map(\.packages), [4])
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

    func testPerServingMeasureDoesNotRoundUp() throws {
        let daiquiri = recipe(method: "Shaken", lines: [
            ("Rum", 2.5, "oz"), ("Lime Juice", 0.75, "oz"), ("Simple Syrup", 0.5, "oz"),
        ])
        let plan = try XCTUnwrap(BatchPlanner.plan(for: daiquiri, servings: 100))
        let locale = Locale(identifier: "en_US_POSIX")
        XCTAssertEqual(BatchPlanner.pourMeasure(milliliters: plan.perServingMilliliters, unit: .oz, locale: locale), "4.68 oz")
        XCTAssertEqual(BatchPlanner.pourMeasure(milliliters: 100.19, unit: .ml, locale: locale), "100.1 ml")
        XCTAssertTrue(BatchPrepSheet.csv(for: daiquiri, servings: 100, unit: .oz).contains(#""Pour per serving","4.68 oz""#))
    }

    func testMeasuredToppersAndOptionalLiquidsStayOutOfDilution() throws {
        let french75 = recipe(method: "Shaken", lines: [
            ("Gin", 1, "oz"), ("Lemon Juice", 0.5, "oz"), ("Simple Syrup", 0.5, "oz"),
        ])
        french75.ingredients.append(IngredientLine(name: "Champagne", amount: 2, unit: "oz", note: "to top", position: 3))
        french75.ingredients.append(IngredientLine(name: "Bitters", amount: 0.25, unit: "oz", isOptional: true, position: 4))
        let plan = try XCTUnwrap(BatchPlanner.plan(for: french75, servings: 10))
        XCTAssertEqual(plan.measuredMilliliters, 20 * Measure.millilitersPerOunce, accuracy: 0.0001)
        XCTAssertEqual(plan.waterMilliliters ?? 0, 5 * Measure.millilitersPerOunce, accuracy: 0.0001)
        XCTAssertTrue(plan.hasServiceToppers)
        XCTAssertTrue(plan.hasOptionalIngredients)
        XCTAssertFalse(plan.excludesNonVolumeLines)
        let csv = BatchPrepSheet.csv(for: french75, servings: 10, unit: .oz)
        XCTAssertTrue(csv.contains(#""Champagne","20 oz","No","Add at service · to top""#))
        XCTAssertTrue(csv.contains(#""Pour per serving","2.5 oz""#))
    }

    func testOptionalIngredientFollowsRecipeInsteadOfTopperInstructions() throws {
        let sour = recipe(method: "Shaken", lines: [("Bourbon", 2, "oz")])
        sour.ingredients.append(IngredientLine(name: "Egg White", amount: 1, unit: "each", isOptional: true, position: 1))
        let plan = try XCTUnwrap(BatchPlanner.plan(for: sour, servings: 4))
        XCTAssertTrue(plan.hasOptionalIngredients)
        XCTAssertFalse(plan.hasServiceToppers)
        let csv = BatchPrepSheet.csv(for: sour, servings: 4, unit: .oz)
        XCTAssertTrue(csv.contains(#""Egg White","4","Yes","Follow the recipe if using""#))
        XCTAssertFalse(csv.contains("Add toppers to each glass"))
    }

    func testBatchCSVDoesNotDuplicateGarnishAliasesAndKeepsCompoundGuidance() {
        let manhattan = recipe(method: "Stirred", lines: [("Rye Whiskey", 2, "oz")])
        manhattan.garnish = "Cocktail cherry"
        manhattan.ingredients.append(IngredientLine(name: "Maraschino Cherry", amount: 1, unit: "each", isOptional: true, position: 1))
        let single = BatchPrepSheet.csv(for: manhattan, servings: 2, unit: .oz)
        XCTAssertTrue(single.contains(#""Maraschino Cherry","2","Yes""#))
        XCTAssertFalse(single.contains("Cocktail cherry"))

        manhattan.garnish = "Cocktail cherry and orange twist"
        let compound = BatchPrepSheet.csv(for: manhattan, servings: 2, unit: .oz)
        XCTAssertTrue(compound.contains(#""Cocktail cherry and orange twist","","Yes","Garnish at service""#))
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
        let justAbove = Decimal(string: "1.600000000001")!
        XCTAssertEqual(MenuPricing.suggestedMenuPrice(cost: justAbove, targetPercent: 20), Decimal(string: "8.5"))
        XCTAssertEqual(MenuPricing.suggestedMenuPrice(cost: 2, targetPercent: 100), 2)
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

    func testRepeatedCanonicalIngredientVotesOnceAndExclusionsApplyBeforeLimit() {
        let recipes = [
            recipe(name: "Alpha", lines: [("Campari", 2, "oz", false), ("Campari", 1, "oz", false)]),
            recipe(name: "Beta", lines: [("Campari", 1, "oz", false)]),
            recipe(name: "Gamma", lines: [("Sweet Vermouth", 1, "oz", false)]),
        ]
        let best = ShoppingInsights.bestNextPurchases(recipes: recipes, inventory: [], limit: 1)
        XCTAssertEqual(best.map(\.canonicalName), ["campari"])
        XCTAssertEqual(best.map(\.unlockCount), [2])
        let next = ShoppingInsights.bestNextPurchases(recipes: recipes, inventory: [], excluding: ["campari"], limit: 1)
        XCTAssertEqual(next.map(\.canonicalName), ["sweet vermouth"])
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
