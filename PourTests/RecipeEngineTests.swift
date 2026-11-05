import XCTest
import SwiftData
@testable import Pour

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
        router.handle(URL(string: "pour://recipe?name=Old%20Fashioned")!)
        XCTAssertEqual(router.pendingTab, .home)
        XCTAssertEqual(router.pendingRecipeName, "Old Fashioned")
    }

    func testUnsupportedLinksDoNotNavigate() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "https://recipe?name=Negroni")!)
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
