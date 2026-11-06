import XCTest
@testable import Pour

final class BarcodeScanningTests: XCTestCase {

    // MARK: - Parsing

    func testUPCAAndEAN13NormalizeToTheSameGTIN() {
        let upc = BarcodeParser.parse(payload: "075496000407")
        let ean = BarcodeParser.parse(payload: "0075496000407")
        let spaced = BarcodeParser.parse(payload: "0 75496 00040 7")
        XCTAssertEqual(upc?.normalizedCode, "0075496000407")
        XCTAssertEqual(upc?.symbology, .upca)
        XCTAssertEqual(ean?.normalizedCode, upc?.normalizedCode)
        XCTAssertEqual(spaced?.normalizedCode, upc?.normalizedCode)
        XCTAssertTrue(BarcodeParser.sameProductCode("075496000407", "0075496000407"))
    }

    func testRejectsEmptyPayloadsURLsAndBadCheckDigits() {
        XCTAssertNil(BarcodeParser.parse(payload: ""))
        XCTAssertNil(BarcodeParser.parse(payload: "   "))
        XCTAssertNil(BarcodeParser.parse(payload: "https://example.com/0075496000407"))
        XCTAssertNil(BarcodeParser.parse(payload: "075496000408"))
        XCTAssertEqual(BarcodeParser.interpretManualEntry("  "), .empty)
        XCTAssertEqual(BarcodeParser.interpretManualEntry("075496000408"), .invalid)
    }

    func testUPCEExpandsUsingPublishedExamples() {
        // Wikipedia / barcode references: UPC-E 654321 → UPC-A 065100004327.
        let eight = BarcodeParser.parse(payload: "06543217", metadataType: "org.gs1.UPC-E")
        let six = BarcodeParser.parse(payload: "654321")
        XCTAssertEqual(eight?.symbology, .upce)
        XCTAssertEqual(eight?.normalizedCode, "0065100004327")
        XCTAssertEqual(six?.normalizedCode, eight?.normalizedCode)

        // Barcode Press worked example: body 123456, number system 0 → UPC-A 012345000065.
        let second = BarcodeParser.parse(payload: "01234565")
        XCTAssertEqual(second?.symbology, .upce)
        XCTAssertEqual(second?.normalizedCode, "0012345000065")
    }

    func testEAN8IsNotRewrittenWhenTheCameraNamesIt() {
        let hinted = BarcodeParser.parse(payload: "06543217", metadataType: "org.gs1.EAN-8")
        XCTAssertNil(hinted)

        let ean8 = BarcodeParser.parse(payload: "55123457", metadataType: "org.gs1.EAN-8")
        XCTAssertEqual(ean8?.symbology, .ean8)
        XCTAssertEqual(ean8?.normalizedCode, "55123457")
    }

    func testITF14AndGS1ElementStringResolveToTheConsumerGTIN() {
        let itf = BarcodeParser.parse(payload: "10075496000404", metadataType: "org.gs1.ITF14")
        XCTAssertEqual(itf?.symbology, .itf14)
        XCTAssertEqual(itf?.normalizedCode, "0075496000407")

        let element = BarcodeParser.parse(payload: "(01)00075496000407")
        XCTAssertEqual(element?.normalizedCode, "0075496000407")
        XCTAssertEqual(element?.symbology, .code128)
    }

    func testGroupedUPCFormatting() {
        XCTAssertEqual(BarcodeFormatting.grouped("0075496000407"), "0 75496 00040 7")
    }

    // MARK: - Catalog and confirm

    func testEveryCatalogEntryIsAValidKnownIngredient() {
        var seen = Set<String>()
        for entry in BarcodeCatalog.entries {
            XCTAssertEqual(entry.gtin.count, 13, entry.displayName)
            XCTAssertTrue(BarcodeCheckDigit.isValidGTIN(entry.gtin), entry.displayName)
            XCTAssertTrue(seen.insert(entry.gtin).inserted, "duplicate \(entry.gtin)")
            let parsed = BarcodeParser.parse(payload: entry.gtin)
            XCTAssertEqual(parsed?.normalizedCode, entry.gtin)
            let canonical = IngredientNormalizer.canonicalName(for: entry.displayName)
            XCTAssertNotEqual(
                IngredientNormalizer.category(for: entry.displayName),
                .other,
                "\(entry.displayName) should map onto a known category (\(canonical))"
            )
        }
    }

    func testKnownCodesConfirmAsCanonicalIngredients() {
        let expectations: [(String, String, String, InventoryCategory)] = [
            ("075496000407", "Angostura Bitters", "angostura bitters", .bitters),
            ("721059047500", "Campari", "campari", .liqueurs),
            ("087236565107", "Cointreau", "orange liqueur", .liqueurs),
            ("898804001008", "St-Germain", "elderflower liqueur", .liqueurs),
            ("088004190187", "Peychaud's Bitters", "peychauds bitters", .bitters),
            ("089540122717", "Kahlúa", "coffee liqueur", .liqueurs),
            ("898195001175", "Fever-Tree Tonic", "tonic water", .mixers),
            ("088110110307", "Tanqueray", "gin", .spirits),
            ("619947000020", "Tito's", "vodka", .spirits),
            ("086767210067", "Baileys", "irish cream", .liqueurs),
        ]
        for (code, display, canonical, category) in expectations {
            guard let parsed = BarcodeParser.parse(payload: code) else {
                XCTFail("\(code) did not parse")
                continue
            }
            guard case .add(let draft) = BarcodeResolver.plan(parsed: parsed, stock: []) else {
                XCTFail("\(display) should be a new confirm")
                continue
            }
            XCTAssertEqual(draft.displayName, display)
            XCTAssertTrue(draft.isRecognized)
            let confirmed = BarcodeConfirmedItem.make(name: draft.displayName, barcode: draft.barcode)
            XCTAssertEqual(confirmed?.canonicalName, canonical)
            XCTAssertEqual(confirmed?.category, category)
            XCTAssertEqual(confirmed?.isInStock, true)
            XCTAssertEqual(confirmed?.barcode, parsed.normalizedCode)
        }
    }

    func testUnknownCodeNeedsAManualNameAndStillNormalizes() {
        let parsed = BarcodeParser.parse(payload: "012345678905")
        XCTAssertEqual(parsed?.normalizedCode, "0012345678905")
        guard let parsed else {
            XCTFail("expected a valid unused GTIN")
            return
        }
        XCTAssertEqual(BarcodeResolver.plan(parsed: parsed, stock: []), .needsName(barcode: "0012345678905"))

        let confirmed = BarcodeConfirmedItem.make(name: "Maker's Mark", barcode: "012345678905")
        XCTAssertEqual(confirmed?.name, "Maker's Mark")
        XCTAssertEqual(confirmed?.canonicalName, "bourbon")
        XCTAssertEqual(confirmed?.category, .spirits)
        XCTAssertEqual(confirmed?.barcode, "0012345678905")
        XCTAssertNil(BarcodeConfirmedItem.make(name: "   ", barcode: "012345678905"))
        XCTAssertNil(BarcodeResolver.commit(name: " ", barcode: "012345678905", stock: []))
    }

    func testEditedNameReplacesTheCatalogGuess() {
        guard case .insert(let item) = BarcodeResolver.commit(
            name: "Lime Juice",
            barcode: "088110110307",
            stock: []
        ) else {
            XCTFail("an edited name should still add")
            return
        }
        XCTAssertEqual(item.name, "Lime Juice")
        XCTAssertEqual(item.canonicalName, "lime juice")
        XCTAssertEqual(item.category, .juices)
        XCTAssertEqual(item.barcode, "0088110110307")
    }

    func testExistingBarcodeIsNotAddedTwice() {
        let stock = [
            BarcodeStockSnapshot(name: "Angostura Bitters", barcode: "075496000407", isInStock: true),
        ]
        let parsed = BarcodeParser.parse(payload: "0075496000407")!
        guard case .alreadyInBar(let match) = BarcodeResolver.plan(parsed: parsed, stock: stock) else {
            XCTFail("expected the stocked bottle")
            return
        }
        XCTAssertEqual(match.name, "Angostura Bitters")
        XCTAssertFalse(match.canAttachBarcode)
        XCTAssertEqual(
            BarcodeResolver.existingAction(isInStock: match.isInStock, canAttachBarcode: match.canAttachBarcode),
            .none
        )
    }

    func testOutOfStockBarcodeOffersMarkInStock() {
        let stock = [
            BarcodeStockSnapshot(name: "Campari", barcode: "0721059047500", isInStock: false),
        ]
        let parsed = BarcodeParser.parse(payload: "721059047500")!
        guard case .alreadyInBar(let match) = BarcodeResolver.plan(parsed: parsed, stock: stock) else {
            XCTFail("expected the stocked bottle")
            return
        }
        XCTAssertEqual(
            BarcodeResolver.existingAction(isInStock: match.isInStock, canAttachBarcode: match.canAttachBarcode),
            .markInStock
        )
        XCTAssertEqual(BarcodeExistingAction.markInStock.buttonTitle, "Mark in stock")
    }

    func testKnownBottleWithoutBarcodeSavesTheCode() {
        let stock = [
            BarcodeStockSnapshot(name: "Tanqueray", barcode: nil, isInStock: true),
        ]
        let parsed = BarcodeParser.parse(payload: "088110110307")!
        guard case .alreadyInBar(let match) = BarcodeResolver.plan(parsed: parsed, stock: stock) else {
            XCTFail("expected to attach the code")
            return
        }
        XCTAssertTrue(match.canAttachBarcode)
        XCTAssertEqual(match.scannedCode, "0088110110307")
        XCTAssertEqual(
            BarcodeResolver.existingAction(isInStock: true, canAttachBarcode: true),
            .saveBarcode
        )
    }

    func testOutOfStockKnownBottleMarksInStockAndSavesBarcode() {
        let stock = [
            BarcodeStockSnapshot(name: "Tanqueray", barcode: "", isInStock: false),
        ]
        guard case .alreadyInBar(let match) = BarcodeResolver.commit(
            name: "Tanqueray",
            barcode: "088110110307",
            stock: stock
        ) else {
            XCTFail("expected the existing row")
            return
        }
        XCTAssertEqual(
            BarcodeResolver.existingAction(isInStock: match.isInStock, canAttachBarcode: match.canAttachBarcode),
            .markInStockAndSaveBarcode
        )
        XCTAssertEqual(
            BarcodeExistingAction.markInStockAndSaveBarcode.buttonTitle,
            "Mark in stock and save barcode"
        )
    }

    func testDifferentBarcodeDoesNotOverwriteTheSavedCode() {
        let stock = [
            BarcodeStockSnapshot(name: "Tanqueray", barcode: "0012345678905", isInStock: true),
        ]
        guard case .alreadyInBar(let match) = BarcodeResolver.commit(
            name: "Tanqueray",
            barcode: "088110110307",
            stock: stock
        ) else {
            XCTFail("expected the existing name")
            return
        }
        XCTAssertFalse(match.canAttachBarcode)
        XCTAssertEqual(
            BarcodeResolver.existingAction(isInStock: match.isInStock, canAttachBarcode: match.canAttachBarcode),
            .none
        )
    }

    func testPreviouslyEnteredUnknownCodeIsRecognizedFromTheBar() {
        let stock = [
            BarcodeStockSnapshot(name: "Well Gin", barcode: "0012345678905", isInStock: true),
        ]
        let parsed = BarcodeParser.parse(payload: "012345678905")!
        guard case .alreadyInBar(let match) = BarcodeResolver.plan(parsed: parsed, stock: stock) else {
            XCTFail("a saved barcode should match without the catalog")
            return
        }
        XCTAssertEqual(match.name, "Well Gin")
        XCTAssertFalse(match.canAttachBarcode)
    }

    // MARK: - Camera availability

    func testCameraReadinessMatrix() {
        let cases: [(Bool, CameraAuthorizationState, BarcodeCameraReadiness)] = [
            (false, .authorized, .unavailable),
            (false, .notDetermined, .unavailable),
            (false, .denied, .unavailable),
            (false, .restricted, .unavailable),
            (true, .authorized, .ready),
            (true, .notDetermined, .needsPermission),
            (true, .denied, .denied),
            (true, .restricted, .restricted),
        ]
        for (hardware, authorization, expected) in cases {
            XCTAssertEqual(
                BarcodeCameraPolicy.readiness(hardwarePresent: hardware, authorization: authorization),
                expected
            )
        }
    }

    func testFallbackCopyIsHonest() {
        XCTAssertNil(BarcodeCameraReadiness.ready.fallbackTitle)
        XCTAssertNil(BarcodeCameraReadiness.needsPermission.fallbackTitle)
        XCTAssertFalse(BarcodeCameraReadiness.ready.offersSettings)

        XCTAssertEqual(BarcodeCameraReadiness.unavailable.fallbackTitle, "No camera on this device")
        XCTAssertTrue(BarcodeCameraReadiness.unavailable.fallbackMessage?.contains("Enter the numbers") == true)
        XCTAssertTrue(BarcodeCameraReadiness.unavailable.fallbackMessage?.contains("add the bottle by name") == true)
        XCTAssertFalse(BarcodeCameraReadiness.unavailable.offersSettings)

        XCTAssertEqual(BarcodeCameraReadiness.denied.fallbackTitle, "Camera access is off")
        XCTAssertTrue(BarcodeCameraReadiness.denied.fallbackMessage?.contains("Settings") == true)
        XCTAssertTrue(BarcodeCameraReadiness.denied.offersSettings)

        XCTAssertEqual(BarcodeCameraReadiness.restricted.fallbackTitle, "Camera is restricted")
        XCTAssertFalse(BarcodeCameraReadiness.restricted.offersSettings)
        XCTAssertTrue(BarcodeCameraReadiness.restricted.fallbackMessage?.contains("add the bottle by name") == true)
    }
}
