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
        var inventory = stock(["Beefeater"])
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
