import XCTest
@testable import Pour

final class IngredientNormalizationTests: XCTestCase {

    // MARK: - Normalization mechanics

    func testNormalizeFoldsDiacritics() {
        XCTAssertEqual(IngredientNormalizer.normalize("Crème de Violette"), "creme de violette")
        XCTAssertEqual(IngredientNormalizer.normalize("Bénédictine"), "benedictine")
        XCTAssertEqual(IngredientNormalizer.normalize("Jägermeister"), "jagermeister")
    }

    func testNormalizeStripsPunctuation() {
        XCTAssertEqual(IngredientNormalizer.normalize("Peychaud's Bitters"), "peychauds bitters")
        XCTAssertEqual(IngredientNormalizer.normalize("St-Germain"), "st germain")
        XCTAssertEqual(IngredientNormalizer.normalize("Pimm's No. 1"), "pimms no 1")
    }

    func testNormalizeCollapsesWhitespaceAndCase() {
        XCTAssertEqual(IngredientNormalizer.normalize("  Sweet   VERMOUTH "), "sweet vermouth")
    }

    // MARK: - Alias mapping (spec examples)

    func testGinAliases() {
        for name in ["Gin", "London Dry Gin", "Beefeater", "Tanqueray", "Bombay Sapphire", "Hendrick's", "Plymouth Gin"] {
            XCTAssertEqual(IngredientNormalizer.canonicalName(for: name), "gin", "\(name) should map to gin")
        }
    }

    func testSweetVermouthAliases() {
        for name in ["Sweet Vermouth", "Vermouth Rosso", "Carpano Antica", "Dolin Rouge", "Red Vermouth"] {
            XCTAssertEqual(IngredientNormalizer.canonicalName(for: name), "sweet vermouth", "\(name)")
        }
    }

    func testOrangeLiqueurAliases() {
        for name in ["Triple Sec", "Cointreau", "Grand Marnier", "Orange Curaçao", "Dry Curaçao"] {
            XCTAssertEqual(IngredientNormalizer.canonicalName(for: name), "orange liqueur", "\(name)")
        }
    }

    func testSpiritBrandAliases() {
        XCTAssertEqual(IngredientNormalizer.canonicalName(for: "Absolut"), "vodka")
        XCTAssertEqual(IngredientNormalizer.canonicalName(for: "Grey Goose"), "vodka")
        XCTAssertEqual(IngredientNormalizer.canonicalName(for: "Bacardi"), "white rum")
        XCTAssertEqual(IngredientNormalizer.canonicalName(for: "Maker's Mark"), "bourbon")
        XCTAssertEqual(IngredientNormalizer.canonicalName(for: "Rittenhouse"), "rye whiskey")
        XCTAssertEqual(IngredientNormalizer.canonicalName(for: "Hennessy"), "cognac")
        XCTAssertEqual(IngredientNormalizer.canonicalName(for: "Patrón Silver"), "tequila")
        XCTAssertEqual(IngredientNormalizer.canonicalName(for: "Jameson"), "irish whiskey")
        XCTAssertEqual(IngredientNormalizer.canonicalName(for: "Del Maguey Vida"), "mezcal")
    }

    func testMixerAndModifierAliases() {
        XCTAssertEqual(IngredientNormalizer.canonicalName(for: "Club Soda"), "soda water")
        XCTAssertEqual(IngredientNormalizer.canonicalName(for: "Tonic"), "tonic water")
        XCTAssertEqual(IngredientNormalizer.canonicalName(for: "Sugar Syrup"), "simple syrup")
        XCTAssertEqual(IngredientNormalizer.canonicalName(for: "Gomme"), "simple syrup")
        XCTAssertEqual(IngredientNormalizer.canonicalName(for: "Angostura"), "angostura bitters")
        XCTAssertEqual(IngredientNormalizer.canonicalName(for: "Peychaud's"), "peychauds bitters")
    }

    func testProduceAliases() {
        XCTAssertEqual(IngredientNormalizer.canonicalName(for: "Fresh Lime Juice"), "lime juice")
        XCTAssertEqual(IngredientNormalizer.canonicalName(for: "Lime Wedge"), "lime juice")
        XCTAssertEqual(IngredientNormalizer.canonicalName(for: "Maraschino Cherry"), "cherry")
        XCTAssertEqual(IngredientNormalizer.canonicalName(for: "Mint Sprig"), "mint")
        XCTAssertEqual(IngredientNormalizer.canonicalName(for: "Orange Twist"), "orange")
    }

    func testAssumedAvailable() {
        XCTAssertTrue(IngredientNormalizer.assumedAvailable.contains("ice"))
        XCTAssertTrue(IngredientNormalizer.assumedAvailable.contains("water"))
    }

    func testUnknownNamesNormalizeThemselves() {
        XCTAssertEqual(IngredientNormalizer.canonicalName(for: "Dragonfruit Soda"), "dragonfruit soda")
        XCTAssertEqual(IngredientNormalizer.canonicalName(for: "Smoked Sea Salt"), "smoked sea salt")
    }

    func testCategoryForCanonical() {
        XCTAssertEqual(IngredientNormalizer.category(for: "Beefeater"), .spirits)
        XCTAssertEqual(IngredientNormalizer.category(for: "Cointreau"), .liqueurs)
        XCTAssertEqual(IngredientNormalizer.category(for: "Sweet Vermouth"), .vermouthWine)
        XCTAssertEqual(IngredientNormalizer.category(for: "Angostura Bitters"), .bitters)
        XCTAssertEqual(IngredientNormalizer.category(for: "Club Soda"), .mixers)
        XCTAssertEqual(IngredientNormalizer.category(for: "Lime Juice"), .juices)
        XCTAssertEqual(IngredientNormalizer.category(for: "Mint"), .produce)
        XCTAssertEqual(IngredientNormalizer.category(for: "Egg White"), .dairy)
        XCTAssertEqual(IngredientNormalizer.category(for: "Completely Unknown Syrup"), .other)
    }
}
