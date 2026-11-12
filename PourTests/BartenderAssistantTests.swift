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
        XCTAssertEqual(AssistantQuestionParser.intent(for: "What can I make with my bar?"), .whatCanIMake(focus: nil))
        XCTAssertEqual(AssistantQuestionParser.intent(for: "What can I make with the bar?"), .whatCanIMake(focus: nil))
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

    func testScalingPreservesSignedDecimalQuantities() {
        for (quantity, expected) in [("1.5", 1.5), (".5", 0.5), ("-2", -2.0), ("−0.5", -0.5), ("0", 0.0)] {
            XCTAssertEqual(
                AssistantQuestionParser.intent(for: "Scale the Negroni for \(quantity)"),
                .scale(recipeQuery: "negroni", servings: expected)
            )
        }
    }

    func testRecipeQuestionsPreserveRequestedServings() {
        for question in ["How do I make a Negroni for 4?", "Recipe for a Negroni for 4", "How to make a Negroni for 4 people"] {
            XCTAssertEqual(AssistantQuestionParser.intent(for: question), .recipe(recipeQuery: "negroni", servings: 4))
        }
    }

    func testInventoryAndRecipeAvailabilityQuestionsDoNotBecomeSubstitutions() {
        XCTAssertEqual(AssistantQuestionParser.intent(for: "What's out of stock?"), .inventory)
        XCTAssertEqual(AssistantQuestionParser.intent(for: "What do I have in stock?"), .inventory)
        XCTAssertEqual(AssistantQuestionParser.intent(for: "Show my bar please"), .inventory)
        XCTAssertEqual(AssistantQuestionParser.intent(for: "My inventory"), .inventory)
        XCTAssertEqual(AssistantQuestionParser.intent(for: "What do I have to make a Negroni?"), .missingIngredients(recipeQuery: "negroni"))
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

    func testGinFocusDoesNotMatchGingerBeerOrRecipeName() async throws {
        let martini = recipe(name: "Martini", lines: [("London Dry Gin", 2, "oz", false)])
        let mule = recipe(name: "Moscow Mule", lines: [("Ginger Beer", 4, "oz", false)])
        let misleadingName = recipe(name: "Gin in the title", lines: [("Vodka", 2, "oz", false)])
        let library = AssistantLibrary(recipes: [martini, mule, misleadingName], inventory: stock(["Beefeater", "Ginger Beer", "Vodka"]), preferredUnit: .oz)
        for focus in ["gin", "Beefeater"] {
            let reply = try await LocalBartenderAssistant().answer("What can I make with \(focus)?", in: library)
            assertOnDevice(reply)
            XCTAssertTrue(reply.text.contains("You can make 1 drink"))
            XCTAssertTrue(reply.text.contains("Martini"))
            XCTAssertFalse(reply.text.contains("Moscow Mule"))
            XCTAssertFalse(reply.text.contains("Gin in the title"))
        }
    }

    func testAvailabilityQuestionChecksRecipeInsteadOfListingInventory() async throws {
        let negroni = recipe(name: "Negroni", lines: [("Gin", 1, "oz", false), ("Campari", 1, "oz", false)])
        let library = AssistantLibrary(recipes: [negroni], inventory: stock(["Gin"]), preferredUnit: .oz)
        let reply = try await LocalBartenderAssistant().answer("What do I have to make a Negroni?", in: library)
        XCTAssertTrue(reply.text.contains("Negroni still needs Campari"))
        XCTAssertFalse(reply.text.contains("In stock ("))
    }

    func testOutOfStockQuestionListsMarkedOutBottles() async throws {
        let campari = InventoryItem(name: "Campari", category: .other, isInStock: false)
        let library = AssistantLibrary(recipes: [], inventory: stock(["Gin"]) + [campari], preferredUnit: .oz)
        let reply = try await LocalBartenderAssistant().answer("What's out of stock?", in: library)
        assertOnDevice(reply)
        XCTAssertTrue(reply.text.contains("Marked out (1): Campari"))
        XCTAssertFalse(reply.text.contains("stand-in"))
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

    func testDecimalScalingAndNonpositiveServings() async throws {
        let negroni = recipe(name: "Negroni", lines: [("Gin", 2, "oz", false)])
        let library = AssistantLibrary(recipes: [negroni], inventory: [], preferredUnit: .oz)
        let decimal = try await LocalBartenderAssistant().answer("Scale Negroni for 1.5", in: library)
        XCTAssertTrue(decimal.text.contains("3 oz Gin"))
        for question in ["Scale Negroni for -2", "Scale Negroni for 0", "How do I make Negroni for -0.5?"] {
            let reply = try await LocalBartenderAssistant().answer(question, in: library)
            XCTAssertTrue(reply.text.contains("greater than zero"), question)
            XCTAssertFalse(reply.text.contains("oz Gin"), question)
        }
    }

    func testRecipeQuestionScalesIngredientsAndIncludesInstructions() async throws {
        let negroni = recipe(name: "Negroni", lines: [("Gin", 1, "oz", false)])
        negroni.instructions = "Stir with ice and strain."
        let library = AssistantLibrary(recipes: [negroni], inventory: [], preferredUnit: .oz)
        for question in ["How do I make a Negroni for 4?", "Recipe for a Negroni for 4"] {
            let reply = try await LocalBartenderAssistant().answer(question, in: library)
            assertOnDevice(reply)
            XCTAssertTrue(reply.text.contains("Negroni for 4 servings"))
            XCTAssertTrue(reply.text.contains("4 oz Gin"))
            XCTAssertTrue(reply.text.contains(negroni.instructions))
        }
        let capped = try await LocalBartenderAssistant().answer("How do I make a Negroni for 40?", in: library)
        XCTAssertTrue(capped.text.contains("\(RecipeScaling.maximumServings) oz Gin"))
        XCTAssertTrue(capped.text.contains("stops there"))
    }

    func testDuplicateRecipeNamesRequireRenamingInsteadOfChoosingFirst() async throws {
        let first = recipe(name: "Negroni", lines: [("Gin", 1, "oz", false)])
        let second = recipe(name: "Négroni", lines: [("Vodka", 2, "oz", false)])
        let library = AssistantLibrary(recipes: [first, second], inventory: stock(["Gin"]), preferredUnit: .oz)
        for question in ["Scale Negroni for 4", "How do I make a Negroni?", "What am I missing for a Negroni?", "What can I substitute for gin in a Negroni?"] {
            let reply = try await LocalBartenderAssistant().answer(question, in: library)
            assertOnDevice(reply)
            XCTAssertTrue(reply.text.contains("distinct names"), question)
            XCTAssertTrue(reply.text.contains("haven't selected a recipe"), question)
            XCTAssertFalse(reply.text.contains("oz Gin"), question)
            XCTAssertFalse(reply.text.contains("oz Vodka"), question)
            XCTAssertEqual(Set(reply.followUps).count, reply.followUps.count)
        }
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

    func testOverflowingScaledMeasureFailsClosed() async {
        for (amount, unit, question) in [
            (Double.greatestFiniteMagnitude, UnitPreference.oz, "Scale Broken for 2"),
            (1e308, UnitPreference.ml, "How do I make Broken?"),
            (Double.greatestFiniteMagnitude, UnitPreference.oz, "How do I make Broken?"),
        ] {
            let broken = recipe(name: "Broken", lines: [("Gin", amount, "oz", false)])
            let library = AssistantLibrary(recipes: [broken], inventory: [], preferredUnit: unit)
            do {
                _ = try await LocalBartenderAssistant().answer(question, in: library)
                XCTFail("Expected scaling, conversion, and display overflow to fail closed")
            } catch AssistantAnswerError.couldNotAnswer {
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testAllergyAndDietaryRequestsDoNotRecommendUncheckedStandIns() async throws {
        let library = AssistantLibrary(recipes: [], inventory: stock(["Milk", "Cream"]), preferredUnit: .oz)
        let questions = [
            "I'm allergic to milk, what can I substitute for cream?",
            "What can I substitute for cream? I need it dairy-free.",
            "What can I make that's vegan?",
            "What can I make that's alcohol-free?",
            "I can't have milk. What can I substitute for cream?",
        ]
        for question in questions {
            let reply = try await LocalBartenderAssistant().answer(question, in: library)
            XCTAssertEqual(AssistantQuestionParser.intent(for: question), .unsupportedDietaryRequest)
            XCTAssertTrue(reply.text.contains("can't verify allergies"), question)
            XCTAssertFalse(reply.text.contains("• Milk"), question)
            XCTAssertTrue(reply.followUps.isEmpty, question)
        }
    }

    // MARK: - Privacy and empty

    func testPrivacyQuestionStaysOnDevice() async throws {
        let library = AssistantLibrary(recipes: [], inventory: [], preferredUnit: .oz)
        let reply = try await LocalBartenderAssistant().answer("Do you upload my bar?", in: library)
        assertOnDevice(reply)
        XCTAssertTrue(reply.text.localizedCaseInsensitiveContains("on this device"))
        XCTAssertTrue(reply.text.localizedCaseInsensitiveContains("does not use an AI model"))
        XCTAssertTrue(reply.text.localizedCaseInsensitiveContains("send questions anywhere"))
        XCTAssertTrue(reply.text.localizedCaseInsensitiveContains("cleared when you close"))
    }

    func testEmptyQuestionAsksForABarQuestion() async throws {
        let library = AssistantLibrary(recipes: [], inventory: [], preferredUnit: .oz)
        let reply = try await LocalBartenderAssistant().answer("   ", in: library)
        assertOnDevice(reply)
        XCTAssertTrue(reply.text.localizedCaseInsensitiveContains("what you can make"))
    }
}
