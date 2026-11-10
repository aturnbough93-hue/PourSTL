import XCTest
@testable import Pour

@MainActor
final class BartenderAssistantTests: XCTestCase {

    private func recipe(name: String, lines: [(String, Double, String, Bool)]) -> Recipe {
        let drink = Recipe(name: name, glassType: "Coupe", method: "Shaken")
        for (index, line) in lines.enumerated() {
            drink.ingredients.append(IngredientLine(name: line.0, amount: line.1, unit: line.2, isOptional: line.3, position: index))
        }
        return drink
    }

    private func stock(_ names: [String]) -> [InventoryItem] {
        names.map { InventoryItem(name: $0, category: .other, isInStock: true) }
    }

    private func assertOnDevice(_ reply: AssistantReply, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(reply.sourceNote, AssistantReply.onDeviceNote, file: file, line: line)
        XCTAssertFalse(reply.text.localizedCaseInsensitiveContains("http"), file: file, line: line)
        for follow in reply.followUps {
            switch AssistantQuestionParser.intent(for: follow) {
            case .unrecognized, .empty:
                XCTFail("Follow-up was not understood: \(follow)", file: file, line: line)
            default:
                break
            }
        }
    }

    // MARK: - Intent parsing

    func testParsesWhatCanIMakeQuestions() {
        XCTAssertEqual(AssistantQuestionParser.intent(for: "What can I make?"), .whatCanIMake(focus: nil))
        XCTAssertEqual(AssistantQuestionParser.intent(for: "What can I make with gin?"), .whatCanIMake(focus: "gin"))
        XCTAssertEqual(AssistantQuestionParser.intent(for: "What can I make with Beefeater?"), .whatCanIMake(focus: "beefeater"))
        XCTAssertEqual(AssistantQuestionParser.intent(for: "What can I make for 4 people?"), .whatCanIMake(focus: nil))
        XCTAssertEqual(AssistantQuestionParser.intent(for: "What am I missing for a Negroni?"), .missingIngredients(recipeQuery: "negroni"))
    }

    func testParsesSubstitutionQuestions() {
        XCTAssertEqual(
            AssistantQuestionParser.intent(for: "What can I substitute for Campari?"),
            .substitution(ingredient: "campari", recipeName: nil)
        )
        XCTAssertEqual(
            AssistantQuestionParser.intent(for: "I don't have Cointreau in a Margarita"),
            .substitution(ingredient: "cointreau", recipeName: "margarita")
        )
        XCTAssertEqual(
            AssistantQuestionParser.intent(for: "What can I substitute for Beefeater in a Martini?"),
            .substitution(ingredient: "beefeater", recipeName: "martini")
        )
    }

    func testParsesScalingQuestions() {
        XCTAssertEqual(
            AssistantQuestionParser.intent(for: "Scale the Negroni for 4"),
            .scale(recipeQuery: "negroni", servings: 4)
        )
        XCTAssertEqual(
            AssistantQuestionParser.intent(for: "Double the Daiquiri"),
            .scale(recipeQuery: "daiquiri", servings: 2)
        )
        XCTAssertEqual(
            AssistantQuestionParser.intent(for: "Half the Old Fashioned"),
            .scale(recipeQuery: "old fashioned", servings: 0.5)
        )
        XCTAssertEqual(
            AssistantQuestionParser.intent(for: "Batch the Negroni for 8"),
            .scale(recipeQuery: "negroni", servings: 8)
        )
        XCTAssertEqual(
            AssistantQuestionParser.intent(for: "Scale the Hemingway Daiquiri for 2"),
            .scale(recipeQuery: "hemingway daiquiri", servings: 2)
        )
    }

    func testParsesPrivacyHelpAndEmpty() {
        XCTAssertEqual(AssistantQuestionParser.intent(for: "   "), .empty)
        XCTAssertEqual(AssistantQuestionParser.intent(for: "Do you upload my bar?"), .privacy)
        XCTAssertEqual(AssistantQuestionParser.intent(for: "What can you do?"), .help)
        XCTAssertEqual(AssistantQuestionParser.intent(for: "Tell me a joke"), .unrecognized)
        XCTAssertEqual(AssistantQuestionParser.intent(for: "How do I make a Negroni?"), .recipe(recipeQuery: "negroni"))
    }

    // MARK: - What can I make

    func testWhatCanIMakeUsesInventoryMatching() async throws {
        let martini = recipe(name: "Martini", lines: [
            ("London Dry Gin", 2.5, "oz", false),
            ("Dry Vermouth", 0.5, "oz", false),
            ("Orange Bitters", 1, "dash", true),
        ])
        let negroni = recipe(name: "Negroni", lines: [
            ("Gin", 1, "oz", false),
            ("Campari", 1, "oz", false),
            ("Sweet Vermouth", 1, "oz", false),
        ])
        let daiquiri = recipe(name: "Daiquiri", lines: [
            ("White Rum", 2, "oz", false),
            ("Lime Juice", 1, "oz", false),
            ("Simple Syrup", 0.75, "oz", false),
        ])
        let library = AssistantLibrary(
            recipes: [martini, negroni, daiquiri],
            inventory: stock(["Beefeater", "Noilly Prat"]),
            preferredUnit: .oz
        )
        let reply = try await LocalBartenderAssistant().answer("What can I make?", in: library)
        assertOnDevice(reply)
        XCTAssertTrue(reply.text.contains("You can make 1 drink from My Bar:"))
        XCTAssertTrue(reply.text.contains("Martini"))
        XCTAssertTrue(reply.text.contains("Negroni - missing Campari, Sweet Vermouth"))
        XCTAssertFalse(reply.text.contains("Daiquiri"))
    }

    func testWhatCanIMakeIgnoresOutOfStockBottles() async throws {
        let negroni = recipe(name: "Negroni", lines: [
            ("Gin", 1, "oz", false),
            ("Campari", 1, "oz", false),
            ("Sweet Vermouth", 1, "oz", false),
        ])
        var gin = stock(["Beefeater"])[0]
        gin.isInStock = false
        let library = AssistantLibrary(
            recipes: [negroni],
            inventory: [gin] + stock(["Campari", "Sweet Vermouth"]),
            preferredUnit: .oz
        )
        let reply = try await LocalBartenderAssistant().answer("What can I make?", in: library)
        assertOnDevice(reply)
        XCTAssertFalse(reply.text.contains("You can make"))
        XCTAssertTrue(reply.text.contains("Negroni - missing Gin"))
    }

    func testWhatCanIMakeWithBrandFocus() async throws {
        let martini = recipe(name: "Martini", lines: [
            ("Gin", 2, "oz", false),
            ("Dry Vermouth", 0.5, "oz", false),
        ])
        let daiquiri = recipe(name: "Daiquiri", lines: [
            ("White Rum", 2, "oz", false),
            ("Lime Juice", 0.75, "oz", false),
            ("Simple Syrup", 0.75, "oz", false),
        ])
        let library = AssistantLibrary(
            recipes: [martini, daiquiri],
            inventory: stock(["Tanqueray", "Noilly Prat", "Bacardi", "Lime Juice", "Simple Syrup"]),
            preferredUnit: .oz
        )
        let reply = try await LocalBartenderAssistant().answer("What can I make with Beefeater?", in: library)
        assertOnDevice(reply)
        XCTAssertTrue(reply.text.contains("Martini"))
        XCTAssertFalse(reply.text.contains("Daiquiri"))
    }

    func testWhatCanIMakeWhenBarIsEmpty() async throws {
        let library = AssistantLibrary(
            recipes: [recipe(name: "Martini", lines: [("Gin", 2, "oz", false)])],
            inventory: [],
            preferredUnit: .oz
        )
        let reply = try await LocalBartenderAssistant().answer("What can I make?", in: library)
        assertOnDevice(reply)
        XCTAssertTrue(reply.text.contains("My Bar is empty"))
        XCTAssertFalse(reply.text.contains("You can make"))
    }

    // MARK: - Substitution

    func testSubstitutionUsesInStockStandIn() async throws {
        let negroni = recipe(name: "Negroni", lines: [
            ("Gin", 1, "oz", false),
            ("Campari", 1, "oz", false),
            ("Sweet Vermouth", 1, "oz", false),
        ])
        let aperol = InventoryItem(name: "Bitter Bottle", category: .other, isInStock: true)
        aperol.canonicalOverride = "aperol"
        let library = AssistantLibrary(recipes: [negroni], inventory: [aperol], preferredUnit: .oz)
        let reply = try await LocalBartenderAssistant().answer("What can I substitute for Campari in a Negroni?", in: library)
        assertOnDevice(reply)
        XCTAssertTrue(reply.text.contains("Negroni uses Campari."))
        XCTAssertTrue(reply.text.contains("Aperol - in your bar"))
        XCTAssertTrue(reply.text.contains("Campari is not in your bar."))
    }

    func testSubstitutionTreatsAliasesAsTheSameIngredient() async throws {
        let library = AssistantLibrary(recipes: [], inventory: [], preferredUnit: .oz)
        let reply = try await LocalBartenderAssistant().answer("What can I substitute for Cointreau?", in: library)
        assertOnDevice(reply)
        XCTAssertTrue(reply.text.localizedCaseInsensitiveContains("orange liqueur"))
        XCTAssertTrue(reply.text.localizedCaseInsensitiveContains("triple sec"))
        XCTAssertTrue(reply.text.contains("Cointreau already counts as Orange Liqueur"))
    }

    func testSubstitutionMatchesAliasInsideTheRecipe() async throws {
        let martini = recipe(name: "Martini", lines: [
            ("London Dry Gin", 2, "oz", false),
            ("Dry Vermouth", 1, "oz", false),
        ])
        let library = AssistantLibrary(recipes: [martini], inventory: [], preferredUnit: .oz)
        let reply = try await LocalBartenderAssistant().answer("What can I substitute for Beefeater in a Martini?", in: library)
        assertOnDevice(reply)
        XCTAssertTrue(reply.text.contains("Martini uses Gin."))
        XCTAssertTrue(reply.text.contains("Beefeater already counts as Gin"))
        XCTAssertTrue(reply.text.contains("Vodka"))
    }

    // MARK: - Scaling

    func testScalingUsesMeasureMath() async throws {
        let negroni = recipe(name: "Negroni", lines: [
            ("Gin", 1, "oz", false),
            ("Campari", 1, "oz", false),
            ("Sweet Vermouth", 1, "oz", false),
        ])
        let library = AssistantLibrary(recipes: [negroni], inventory: [], preferredUnit: .oz)
        let reply = try await LocalBartenderAssistant().answer("Scale the Negroni for 4", in: library)
        assertOnDevice(reply)
        let expected = Measure(amount: 1, unit: .ounce).scaled(by: 4).formatted(for: .oz)
        XCTAssertEqual(expected, "4 oz")
        XCTAssertTrue(reply.text.contains("\(expected) Gin"))
        XCTAssertTrue(reply.text.contains("\(expected) Campari"))
        XCTAssertTrue(reply.text.contains("\(expected) Sweet Vermouth"))
        XCTAssertTrue(reply.text.contains("4 servings"))
    }

    func testScalingKeepsNativeBarUnits() async throws {
        let drink = recipe(name: "Old Fashioned", lines: [
            ("Bourbon", 2, "oz", false),
            ("Angostura Bitters", 2, "dash", false),
        ])
        let library = AssistantLibrary(recipes: [drink], inventory: [], preferredUnit: .ml)
        let reply = try await LocalBartenderAssistant().answer("Scale the Old Fashioned for 4", in: library)
        assertOnDevice(reply)
        let spirit = Measure(amount: 2, unit: .ounce).scaled(by: 4).formatted(for: .ml)
        let bitters = Measure(amount: 2, unit: .dash).scaled(by: 4).formatted(for: .ml)
        XCTAssertEqual(bitters, "8 dashes")
        XCTAssertTrue(reply.text.contains("\(spirit) Bourbon"))
        XCTAssertTrue(reply.text.contains(bitters))
        XCTAssertFalse(reply.text.contains("oz"))
    }

    func testDoubleAndHalfUseTheWrittenSpec() async throws {
        let daiquiri = recipe(name: "Daiquiri", lines: [("White Rum", 2, "oz", false)])
        let library = AssistantLibrary(recipes: [daiquiri], inventory: [], preferredUnit: .oz)
        let doubled = try await LocalBartenderAssistant().answer("Double the Daiquiri", in: library)
        let halved = try await LocalBartenderAssistant().answer("Half the Daiquiri", in: library)
        assertOnDevice(doubled)
        assertOnDevice(halved)
        XCTAssertTrue(doubled.text.contains("4 oz White Rum"))
        XCTAssertFalse(doubled.text.contains("2 oz"))
        XCTAssertTrue(halved.text.contains("1 oz White Rum"))
        XCTAssertTrue(halved.text.contains("half the written spec"))
    }

    func testScalingChoosesTheLongerRecipeName() async throws {
        let daiquiri = recipe(name: "Daiquiri", lines: [("White Rum", 2, "oz", false)])
        let hemingway = recipe(name: "Hemingway Daiquiri", lines: [
            ("White Rum", 2, "oz", false),
            ("Maraschino", 0.5, "oz", false),
        ])
        let library = AssistantLibrary(recipes: [daiquiri, hemingway], inventory: [], preferredUnit: .oz)
        let reply = try await LocalBartenderAssistant().answer("Scale the Hemingway Daiquiri for 2", in: library)
        assertOnDevice(reply)
        XCTAssertTrue(reply.text.contains("Hemingway Daiquiri for 2 servings:"))
        XCTAssertTrue(reply.text.contains("1 oz Maraschino"))
        XCTAssertFalse(reply.text.hasPrefix("Daiquiri"))
    }

    func testScalingClampsToRecipeScreenMaximum() async throws {
        let negroni = recipe(name: "Negroni", lines: [("Gin", 1, "oz", false)])
        let library = AssistantLibrary(recipes: [negroni], inventory: [], preferredUnit: .oz)
        let reply = try await LocalBartenderAssistant().answer("Scale the Negroni for 40", in: library)
        assertOnDevice(reply)
        let expected = Measure(amount: 1, unit: .ounce).scaled(by: Double(RecipeScaling.maximumServings)).formatted(for: .oz)
        XCTAssertTrue(reply.text.contains("recipe screen"))
        XCTAssertTrue(reply.text.contains("\(RecipeScaling.maximumServings) servings"))
        XCTAssertTrue(reply.text.contains("\(expected) Gin"))
    }

    func testScalingUnknownDrinkDoesNotInventASpec() async throws {
        let library = AssistantLibrary(recipes: [], inventory: [], preferredUnit: .oz)
        let reply = try await LocalBartenderAssistant().answer("Scale the Unicorn for 2", in: library)
        assertOnDevice(reply)
        XCTAssertTrue(reply.text.contains("Unicorn"))
        XCTAssertTrue(reply.text.localizedCaseInsensitiveContains("could not find"))
        XCTAssertFalse(reply.text.contains("oz"))
    }

    func testNonFiniteMeasureFailsClosed() async {
        let broken = recipe(name: "Broken", lines: [("Gin", .nan, "oz", false)])
        let library = AssistantLibrary(recipes: [broken], inventory: [], preferredUnit: .oz)
        do {
            _ = try await LocalBartenderAssistant().answer("Scale Broken for 2", in: library)
            XCTFail("Expected the assistant to fail closed")
        } catch AssistantAnswerError.couldNotAnswer {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Privacy and empty

    func testPrivacyQuestionStaysOnDevice() async throws {
        let library = AssistantLibrary(recipes: [], inventory: [], preferredUnit: .oz)
        let reply = try await LocalBartenderAssistant().answer("Do you upload my bar?", in: library)
        assertOnDevice(reply)
        XCTAssertTrue(reply.text.localizedCaseInsensitiveContains("on this device"))
        XCTAssertTrue(reply.text.localizedCaseInsensitiveContains("nothing is sent"))
        XCTAssertTrue(reply.text.localizedCaseInsensitiveContains("remote model"))
    }

    func testEmptyQuestionAsksForABarQuestion() async throws {
        let library = AssistantLibrary(recipes: [], inventory: [], preferredUnit: .oz)
        let reply = try await LocalBartenderAssistant().answer("   ", in: library)
        assertOnDevice(reply)
        XCTAssertTrue(reply.text.localizedCaseInsensitiveContains("what you can make"))
    }
}
