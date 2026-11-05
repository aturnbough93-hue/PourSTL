import XCTest
@testable import Pour

final class UnitConversionTests: XCTestCase {

    // MARK: - Core conversion math

    func testOuncesToMilliliters() {
        let m = Measure(amount: 2, unit: .ounce)
        XCTAssertEqual(m.milliliters!, 59.147, accuracy: 0.001)
    }

    func testMillilitersToOunces() {
        let m = Measure(amount: 45, unit: .milliliter)
        XCTAssertEqual(m.ounces!, 1.5216, accuracy: 0.001)
    }

    func testDashToOunces() {
        // 1 dash = 1/32 oz
        XCTAssertEqual(Measure(amount: 2, unit: .dash).ounces!, 0.0625, accuracy: 0.0001)
    }

    func testBarspoonToMilliliters() {
        XCTAssertEqual(Measure(amount: 1, unit: .barspoon).milliliters!, 5.0, accuracy: 0.001)
    }

    func testTablespoonIsHalfOunce() {
        XCTAssertEqual(Measure(amount: 2, unit: .tablespoon).ounces!, 1.0, accuracy: 0.0001)
    }

    // MARK: - Preference conversion (what displays)

    func testConvertedOzToMl() {
        let converted = Measure(amount: 1.5, unit: .ounce).converted(to: .ml)
        XCTAssertEqual(converted.unit, .milliliter)
        XCTAssertEqual(converted.amount, 44.3603, accuracy: 0.001)
    }

    func testConvertedMlToOz() {
        let converted = Measure(amount: 45, unit: .milliliter).converted(to: .oz)
        XCTAssertEqual(converted.unit, .ounce)
        XCTAssertEqual(converted.amount, 1.5216, accuracy: 0.001)
    }

    func testDashesStayNative() {
        // Bartenders keep dashes — converting to oz would be meaningless.
        let converted = Measure(amount: 2, unit: .dash).converted(to: .ml)
        XCTAssertEqual(converted.unit, .dash)
        XCTAssertEqual(converted.amount, 2)
    }

    func testPartsStayNative() {
        let converted = Measure(amount: 3, unit: .part).converted(to: .oz)
        XCTAssertEqual(converted.unit, .part)
        XCTAssertEqual(converted.amount, 3)
    }

    func testCountablesStayNative() {
        XCTAssertEqual(Measure(amount: 1, unit: .cube).converted(to: .ml).unit, .cube)
        XCTAssertEqual(Measure(amount: 8, unit: .leaf).converted(to: .oz).unit, .leaf)
    }

    // MARK: - Scaling & batch

    func testScaling() {
        let scaled = Measure(amount: 0.75, unit: .ounce).scaled(by: 4)
        XCTAssertEqual(scaled.amount, 3.0, accuracy: 0.0001)
        XCTAssertEqual(scaled.unit, .ounce)
    }

    func testScaledAndConverted() {
        let scaled = Measure(amount: 1.5, unit: .ounce).scaled(by: 2).converted(to: .ml)
        XCTAssertEqual(scaled.amount, 88.72, accuracy: 0.01)
        XCTAssertEqual(scaled.unit, .milliliter)
    }

    func testScalingParts() {
        let scaled = Measure(amount: 1, unit: .part).scaled(by: 3)
        XCTAssertEqual(scaled.amount, 3)
        XCTAssertEqual(scaled.unit, .part)
    }

    // MARK: - Display formatting

    func testFormattedOuncesSnapToQuarters() {
        XCTAssertEqual(Measure(amount: 1.5, unit: .ounce).formatted(for: .oz), "1.5 oz")
        XCTAssertEqual(Measure(amount: 0.74, unit: .ounce).formatted(for: .oz), "0.75 oz")
        XCTAssertEqual(Measure(amount: 2, unit: .ounce).formatted(for: .oz), "2 oz")
    }

    func testFormattedMilliliters() {
        XCTAssertEqual(Measure(amount: 45, unit: .milliliter).formatted(for: .ml), "45 ml")
        XCTAssertEqual(Measure(amount: 7.4, unit: .milliliter).formatted(for: .ml), "7.5 ml")
    }

    func testFormattedDashesPluralize() {
        XCTAssertEqual(Measure(amount: 1, unit: .dash).formatted(for: .oz), "1 dash")
        XCTAssertEqual(Measure(amount: 3, unit: .dash).formatted(for: .ml), "3 dashes")
    }

    func testFormattedLeavesAndTopUp() {
        XCTAssertEqual(Measure(amount: 8, unit: .leaf).formatted(for: .oz), "8 leaves")
        XCTAssertEqual(Measure(amount: 0, unit: .topUp).formatted(for: .oz), "to top")
    }

    func testFormattedConvertedMl() {
        // 2 oz → ml → rounded for display
        XCTAssertEqual(Measure(amount: 2, unit: .ounce).formatted(for: .ml), "59 ml")
    }

    // MARK: - Unit parsing

    func testParseCommonUnits() {
        XCTAssertEqual(BarUnit.parse("oz"), .ounce)
        XCTAssertEqual(BarUnit.parse("ounces"), .ounce)
        XCTAssertEqual(BarUnit.parse("fl oz"), .ounce)
        XCTAssertEqual(BarUnit.parse("ml"), .milliliter)
        XCTAssertEqual(BarUnit.parse("dashes"), .dash)
        XCTAssertEqual(BarUnit.parse("bar spoon"), .barspoon)
        XCTAssertEqual(BarUnit.parse("tsp"), .teaspoon)
        XCTAssertEqual(BarUnit.parse("tbsp"), .tablespoon)
        XCTAssertEqual(BarUnit.parse("parts"), .part)
        XCTAssertEqual(BarUnit.parse("sugar cube"), .cube)
        XCTAssertEqual(BarUnit.parse("to top"), .topUp)
        XCTAssertEqual(BarUnit.parse("rinse"), .rinse)
        XCTAssertEqual(BarUnit.parse("leaves"), .leaf)
    }
    func testRecipeAmountsRejectNegativeAndNonfiniteValues() {
        for value in [-1.0, Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertFalse(Measure(amount: value, unit: .ounce).isValidRecipeAmount)
        }
        XCTAssertFalse(Measure(amount: 0, unit: .ounce).isValidRecipeAmount)
        XCTAssertTrue(Measure(amount: 0.25, unit: .ounce).isValidRecipeAmount)
        XCTAssertTrue(Measure(amount: 0, unit: .topUp).isValidRecipeAmount)
        XCTAssertTrue(Measure(amount: 0, unit: .rinse).isValidRecipeAmount)
    }

}
