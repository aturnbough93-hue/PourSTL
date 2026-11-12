import XCTest

/// Current-commit simulator QA. The DEBUG-only `-uiTesting` flag skips
/// onboarding, isolates SwiftData, and enables simulated camera policy states.
/// These tests do not exercise a physical camera or real StoreKit billing.
final class QAPassTests: XCTestCase {
    private var app = XCUIApplication()
    private static let screenshotRunID = UUID().uuidString

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-demoInventory"]
    }

    // MARK: - Camera fallback

    func testRevokedOrMissingCameraOffersManualEntry() throws {
        launch()
        openMyBar()
        openScanner()
        let title = waitForScannerFallback()
        note("camera-fallback", title)
        XCTAssertTrue(app.textFields["Barcode number"].exists)
        XCTAssertTrue(app.buttons["Add bottle by name"].exists)
        if title == "Camera access is off" {
            XCTAssertTrue(app.buttons["Open Settings"].exists)
        } else {
            XCTAssertFalse(app.buttons["Open Settings"].exists)
        }
        XCTAssertFalse(app.staticTexts["Waiting for camera access"].exists)
    }

    func testDeniedCameraShowsSettingsFallback() throws {
        launch(extra: ["-cameraStatus=denied"])
        openMyBar()
        openScanner()
        XCTAssertTrue(app.staticTexts["Camera access is off"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "allow access in Settings")).firstMatch.exists
        )
        XCTAssertTrue(app.buttons["Open Settings"].exists)
        XCTAssertTrue(app.textFields["Barcode number"].exists)
        XCTAssertTrue(app.buttons["Add bottle by name"].exists)
        XCTAssertTrue(app.buttons["Look up barcode"].exists)
    }

    func testRestrictedCameraStaysOnTheFallback() throws {
        launch(extra: ["-cameraStatus=restricted"])
        openMyBar()
        openScanner()
        let title = app.staticTexts["Camera is restricted"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Open Settings"].exists)
        XCTAssertTrue(app.textFields["Barcode number"].exists)
        XCTAssertTrue(app.buttons["Add bottle by name"].exists)
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        XCTAssertTrue(title.exists)
        XCTAssertFalse(app.staticTexts["Waiting for camera access"].exists)
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: - Manual barcode entry

    func testKnownUPCShowsConfirmSheetAndDoesNotSaveUntilConfirm() throws {
        launch()
        openMyBar()
        openScanner()
        _ = waitForScannerFallback()
        enterBarcode("088110110307")
        XCTAssertTrue(app.navigationBars["Confirm ingredient"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.textFields["Bottle name"].value as? String, "Tanqueray")
        XCTAssertTrue(app.buttons["Add to My Bar"].exists)
        app.buttons["Cancel"].tap()
        app.buttons["Close scanner"].tap()
        XCTAssertTrue(app.navigationBars["My Bar"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Edit Tanqueray"].exists)
        XCTAssertTrue(app.buttons["Edit Angostura Bitters"].exists)
    }

    func testUnknownCodeSavesOutOfStockWhenToggleIsOff() throws {
        launch()
        openMyBar()
        openScanner()
        _ = waitForScannerFallback()
        enterBarcode("012345678905")
        XCTAssertTrue(app.navigationBars["Confirm item"].waitForExistence(timeout: 8))
        let name = app.textFields["Name (e.g. London Dry Gin)"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Fernet Branca")
        turnOffInStock()
        app.navigationBars["Confirm item"].buttons["Add to My Bar"].tap()
        XCTAssertTrue(app.navigationBars["My Bar"].waitForExistence(timeout: 8))
        filterInventory("Fernet")
        let saved = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Fernet Branca")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 8))
        XCTAssertTrue(saved.label.contains("not in stock"), "Saved row was \(saved.label)")
    }

    func testRescanShowsAlreadyInBarWithoutADuplicate() throws {
        launch()
        openMyBar()
        openScanner()
        _ = waitForScannerFallback()
        enterBarcode("088110110307")
        XCTAssertTrue(app.navigationBars["Confirm ingredient"].waitForExistence(timeout: 8))
        app.buttons["Add to My Bar"].tap()
        XCTAssertTrue(editButtons("Tanqueray").firstMatch.waitForExistence(timeout: 8))
        XCTAssertEqual(editButtons("Tanqueray").count, 1)

        openScanner()
        _ = waitForScannerFallback()
        enterBarcode("088110110307")
        XCTAssertTrue(app.navigationBars["Already in your bar"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Tanqueray is already in your bar with this barcode."].exists)
        XCTAssertTrue(app.buttons["Done"].exists)
        app.buttons["Done"].tap()
        app.buttons["Close scanner"].tap()
        XCTAssertTrue(app.navigationBars["My Bar"].waitForExistence(timeout: 8))
        XCTAssertEqual(editButtons("Tanqueray").count, 1)
    }

    func testSameNameRestockUpdatesOnlyTheScannedRow() throws {
        launch()
        openMyBar()
        addBottle("House Amaro", inStock: false)
        openScanner()
        _ = waitForScannerFallback()
        enterBarcode("012345678905")
        XCTAssertTrue(app.navigationBars["Confirm item"].waitForExistence(timeout: 8))
        let name = app.textFields["Name (e.g. London Dry Gin)"]
        name.tap()
        name.typeText("House Amaro")
        turnOffInStock()
        app.navigationBars["Confirm item"].buttons["Add to My Bar"].tap()
        XCTAssertTrue(app.navigationBars["My Bar"].waitForExistence(timeout: 8))
        filterInventory("House Amaro")
        XCTAssertEqual(editButtons("House Amaro").count, 1)

        addBottle("House Amaro", inStock: true, lowStock: true)
        filterInventory("House Amaro")
        XCTAssertEqual(editButtons("House Amaro").count, 2)
        XCTAssertTrue(app.buttons["House Amaro, not in stock"].exists)
        XCTAssertTrue(app.buttons["House Amaro, low stock"].exists)

        openScanner()
        _ = waitForScannerFallback()
        enterBarcode("012345678905")
        XCTAssertTrue(app.navigationBars["Already in your bar"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Mark in stock"].waitForExistence(timeout: 5))
        app.buttons["Mark in stock"].tap()
        XCTAssertTrue(app.navigationBars["My Bar"].waitForExistence(timeout: 8))
        filterInventory("House Amaro")
        XCTAssertFalse(app.buttons["House Amaro, not in stock"].exists)
        XCTAssertTrue(app.buttons["House Amaro, low stock"].exists)
        XCTAssertEqual(editButtons("House Amaro").count, 2)
    }

    func testAmbiguousEightDigitsShowsThePrintedCode() throws {
        launch()
        openMyBar()
        openScanner()
        _ = waitForScannerFallback()
        enterBarcode("01000009")
        XCTAssertTrue(app.staticTexts["These digits can be an EAN-8 or a UPC-E. Pick the type printed on the bottle."].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Use EAN-8, 01000009"].exists)
        XCTAssertTrue(app.buttons["Use UPC-E, 01000009"].exists)
        XCTAssertFalse(app.navigationBars["Confirm ingredient"].exists)
        XCTAssertFalse(app.navigationBars["Confirm item"].exists)
    }

    func testScannerSurvivesRotation() throws {
        launch()
        openMyBar()
        openScanner()
        let title = waitForScannerFallback()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Barcode number"].exists)
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.staticTexts[title].exists)
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testScannerSurvivesBackgrounding() throws {
        launch()
        openMyBar()
        openScanner()
        let title = waitForScannerFallback()
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Waiting for camera access"].exists)
        enterBarcode("088110110307")
        XCTAssertTrue(app.navigationBars["Confirm ingredient"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.textFields["Bottle name"].value as? String, "Tanqueray")
    }

    func testVoiceOverLabelsOnScannerControls() throws {
        launch(extra: ["-cameraStatus=denied"])
        openMyBar()
        XCTAssertTrue(app.buttons["Scan barcode to add ingredient"].exists)
        openScanner()
        XCTAssertTrue(app.buttons["Open Settings"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Add bottle by name"].exists)
        XCTAssertTrue(app.textFields["Barcode number"].exists)
        enterBarcode("01000009")
        XCTAssertTrue(app.buttons["Use EAN-8, 01000009"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Use UPC-E, 01000009"].exists)
        app.buttons["Use EAN-8, 01000009"].tap()
        XCTAssertTrue(app.navigationBars["Confirm item"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", "In stock")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", "Low stock")).firstMatch.exists)
    }

    // MARK: - Core flows

    func testSearchFiltersTheLocalLibrary() throws {
        launch()
        let search = app.searchFields["Search drinks, ingredients, tags"]
        XCTAssertTrue(search.waitForExistence(timeout: 8))
        search.tap()
        search.typeText("Negroni")
        XCTAssertTrue(app.buttons["Negroni, Rocks, can make"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Margarita, Rocks, missing 2 ingredients"].exists)
    }

    func testWhatCanIMakeListsAStockedDrink() throws {
        launch()
        XCTAssertTrue(labeled("What can I make, 7 drinks").waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Negroni, can make"].exists)
        XCTAssertTrue(app.buttons["Gimlet, can make"].exists)
        XCTAssertFalse(app.staticTexts["Nothing fully stocked yet"].exists)
    }

    func testScalingUpdatesTheMeasure() throws {
        launch()
        // Preferences intentionally survive relaunch, including a previous QA run.
        app.buttons["Settings"].tap()
        let preferred = preferredUnits()
        XCTAssertTrue(preferred.waitForExistence(timeout: 5))
        preferred.buttons["oz"].tap()
        app.buttons["Done"].tap()
        openNegroni()
        XCTAssertTrue(labeled("1 oz Gin").exists)
        app.buttons["Increase servings"].tap()
        XCTAssertTrue(labeled("Servings, 2").waitForExistence(timeout: 3))
        XCTAssertTrue(labeled("2 oz Gin").exists)
        let units = app.segmentedControls["Display units, oz"]
        XCTAssertTrue(units.waitForExistence(timeout: 3))
        units.buttons["ml"].tap()
        XCTAssertTrue(labeled("59 ml Gin").waitForExistence(timeout: 3))
    }

    func testShoppingListAddAndDelete() throws {
        launch()
        app.tabBars.buttons["Shopping"].tap()
        XCTAssertTrue(app.staticTexts["Shopping list is empty"].waitForExistence(timeout: 8))
        app.buttons["Add shopping item"].tap()
        let alert = app.alerts["Add item"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.textFields.firstMatch.typeText("Orange peel")
        alert.buttons["Add"].tap()
        let row = app.staticTexts["Orange peel"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertTrue(row.waitForNonExistence(timeout: 5))
    }

    func testCustomRecipeSaves() throws {
        launch()
        app.buttons["New recipe"].tap()
        XCTAssertTrue(app.navigationBars["New recipe"].waitForExistence(timeout: 5))
        let name = app.textFields["Recipe name"]
        name.tap()
        name.typeText("Shift Special")
        let ingredient = app.textFields["Ingredient name"]
        ingredient.tap()
        ingredient.typeText("Bourbon")
        dismissKeyboard()
        app.navigationBars["New recipe"].buttons["Save recipe"].tap()
        XCTAssertTrue(app.navigationBars["New recipe"].waitForNonExistence(timeout: 8))
        let saved = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Shift Special")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 8))
    }

    func testRecipeDeepLinkOpensTheDrink() throws {
        launch(extra: ["-deepLink=pourstl://recipe?name=Negroni"])
        XCTAssertTrue(app.buttons["Increase servings"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Negroni"].exists)
    }

    func testShoppingDeepLinkSelectsTheTab() throws {
        launch(extra: ["-deepLink=pourstl://tab/shopping"])
        XCTAssertTrue(app.navigationBars["Shopping List"].waitForExistence(timeout: 15))
    }

    func testSettingsUnitsPersistAcrossLaunch() throws {
        launch()
        app.buttons["Settings"].tap()
        let units = preferredUnits()
        XCTAssertTrue(units.waitForExistence(timeout: 5))
        units.buttons["ml"].tap()
        app.buttons["Done"].tap()
        relaunch()
        app.buttons["Settings"].tap()
        let again = preferredUnits()
        XCTAssertTrue(again.waitForExistence(timeout: 5))
        XCTAssertTrue(again.label.contains("ml") || again.buttons["ml"].isSelected)
    }

    func testClassicVariationCanBeCancelledWithoutChangingTheOriginal() throws {
        launch()
        openNegroni()
        let variation = app.buttons["Make a variation"]
        for _ in 0..<5 where !variation.isHittable { app.swipeUp() }
        XCTAssertTrue(variation.isHittable)
        variation.tap()
        let editor = app.navigationBars["Make a variation"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["Recipe name"].value as? String, "Negroni variation")
        XCTAssertTrue(app.buttons["Save variation to your library"].exists)
        editor.buttons["Cancel"].tap()
        XCTAssertTrue(editor.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Edit recipe"].exists, "A classic must remain read-only")
        XCTAssertTrue(app.staticTexts["Negroni"].exists)
    }

    func testAssistantAnswersFromTheDemoBar() throws {
        launch()
        let more = app.buttons["More features"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        XCTAssertFalse(more.frame.isEmpty)
        XCTAssertTrue(app.frame.contains(more.frame))
        // SwiftUI Menu exposes a visible toolbar frame but XCTest cannot compute
        // its AX hit point on iOS 26 with Xcode 16.4. Tap that element's center;
        // the menu, sheet, and actual inventory response must still appear.
        more.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let assistant = app.buttons["Bar Assistant"]
        XCTAssertTrue(assistant.waitForExistence(timeout: 5))
        assistant.tap()
        XCTAssertTrue(app.navigationBars["Bar Assistant"].waitForExistence(timeout: 5))
        let question = app.buttons["What can I make?"]
        XCTAssertTrue(question.waitForExistence(timeout: 5))
        question.tap()
        let answer = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "Assistant:", "Negroni")
        ).firstMatch
        XCTAssertTrue(answer.waitForExistence(timeout: 10), "The local helper should use seeded inventory and recipes")
        app.navigationBars["Bar Assistant"].buttons["Done"].tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].exists)
    }

    func testProSheetCanBeDismissedWithoutPurchasing() throws {
        launch()
        app.buttons["Settings"].tap()
        let upgrade = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "PourSTL Pro")).firstMatch
        XCTAssertTrue(upgrade.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["PourSTL Pro upgrade"].waitForExistence(timeout: 10), "Local StoreKit transactions must be cleared so this test starts on the free tier")
        upgrade.tap()
        let pro = app.navigationBars["PourSTL Pro"]
        XCTAssertTrue(pro.waitForExistence(timeout: 8))
        let restore = app.buttons["Restore purchases"]
        for _ in 0..<4 where !restore.isHittable { app.swipeUp() }
        XCTAssertTrue(restore.exists)
        // Navigation only. Never tap a purchase or restore button here.
        pro.buttons["Done"].tap()
        XCTAssertTrue(pro.waitForNonExistence(timeout: 5))
        XCTAssertTrue(preferredUnits().exists)
        XCTAssertTrue(app.buttons["PourSTL Pro upgrade"].exists, "Opening and dismissing the sheet must not activate Pro")
        app.buttons["Done"].tap()
        openNegroni()
        XCTAssertTrue(app.buttons["Increase servings"].exists, "Core recipes must remain accessible for free")
    }

    func testCaptureTestingScreenshots() throws {
        launch()
        XCTAssertTrue(labeled("What can I make, 7 drinks").waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Negroni, can make"].exists)
        capture("01-home")

        app.buttons["Settings"].tap()
        XCTAssertTrue(preferredUnits().waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["PourSTL Pro"].exists)
        XCTAssertFalse(app.navigationBars["Bar Assistant"].exists)
        XCTAssertFalse(app.navigationBars["Voice Search"].exists)
        capture("08-settings")
        app.buttons["Done"].tap()

        app.segmentedControls["Filter drinks by availability"].buttons["Can make"].tap()
        XCTAssertTrue(app.buttons["Negroni, can make"].waitForExistence(timeout: 5))
        capture("02-what-can-i-make")

        openNegroni()
        capture("03-recipe-detail")

        app.buttons["Start timer"].tap()
        XCTAssertTrue(app.buttons["Start timer"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Negroni"].waitForExistence(timeout: 5))
        capture("07-timer")
        app.buttons["Done"].tap()

        openMyBar()
        XCTAssertTrue(app.buttons["Edit London Dry Gin"].waitForExistence(timeout: 8))
        capture("04-my-bar")

        openScanner()
        _ = waitForScannerFallback()
        enterBarcode("088110110307")
        XCTAssertTrue(app.navigationBars["Confirm ingredient"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.textFields["Bottle name"].value as? String, "Tanqueray")
        dismissKeyboard()
        capture("05-barcode-confirm")
        app.buttons["Cancel"].tap()
        app.buttons["Close scanner"].tap()

        app.tabBars.buttons["Shopping"].tap()
        app.buttons["Add shopping item"].tap()
        let alert = app.alerts["Add item"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.textFields.firstMatch.typeText("Orange peel")
        alert.buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts["Orange peel"].waitForExistence(timeout: 5))
        capture("06-shopping-list")
    }

    // MARK: - Helpers

    private func launch(extra: [String] = []) {
        app.launchArguments.append(contentsOf: extra)
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 25))
        XCTAssertFalse(app.staticTexts["Welcome to PourSTL"].exists)
    }

    private func relaunch() {
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 25))
    }

    private func openNegroni() {
        // The horizontal availability chips can exist outside the viewport.
        // Filter to a visible library card instead of relying on AX scrolling.
        let search = app.searchFields["Search drinks, ingredients, tags"]
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        search.tap()
        let current = (search.value as? String) ?? ""
        if !current.isEmpty && current != "Search drinks, ingredients, tags" {
            search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        search.typeText("Negroni")
        if app.keyboards.buttons["Search"].exists {
            app.keyboards.buttons["Search"].tap()
        }
        let card = app.buttons["Negroni, Rocks, can make"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        for _ in 0..<3 where !card.isHittable { app.swipeUp() }
        XCTAssertTrue(card.isHittable, "The filtered Negroni card must be visible before opening it")
        card.tap()
        XCTAssertTrue(app.buttons["Increase servings"].waitForExistence(timeout: 8))
    }

    private func openMyBar() {
        app.tabBars.buttons["My Bar"].tap()
        XCTAssertTrue(app.navigationBars["My Bar"].waitForExistence(timeout: 8))
    }

    private func openScanner() {
        if !app.buttons["Scan barcode to add ingredient"].waitForExistence(timeout: 2),
           app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tap()
        }
        XCTAssertTrue(app.buttons["Scan barcode to add ingredient"].waitForExistence(timeout: 5))
        app.buttons["Scan barcode to add ingredient"].tap()
        XCTAssertTrue(app.navigationBars["Scan"].waitForExistence(timeout: 8))
    }

    private func waitForScannerFallback() -> String {
        let titles = ["No camera on this device", "Camera access is off", "Camera is restricted"]
        let deadline = Date().addingTimeInterval(12)
        while Date() < deadline {
            for title in titles where app.staticTexts[title].exists {
                return title
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("Scanner fallback did not appear")
        return ""
    }

    private func enterBarcode(_ code: String) {
        let field = app.textFields["Barcode number"]
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        if !field.isHittable {
            app.swipeUp()
        }
        field.tap()
        field.typeText(code)
        let lookup = app.buttons["Look up barcode"]
        if lookup.isHittable {
            lookup.tap()
        } else {
            field.typeText("\n")
        }
    }

    private func turnOffInStock() {
        dismissKeyboard()
        setSwitch(prefix: "In stock", on: false)
    }

    private func setSwitch(prefix: String, on: Bool) {
        let toggle = app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let currentlyOn = toggle.label.hasSuffix("on")
        if currentlyOn != on {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        }
    }

    private func addBottle(_ name: String, inStock: Bool, lowStock: Bool = false) {
        if !app.buttons["Add inventory item"].waitForExistence(timeout: 2) {
            let cancel = app.buttons["Cancel"]
            if cancel.exists {
                cancel.tap()
            }
        }
        XCTAssertTrue(app.buttons["Add inventory item"].waitForExistence(timeout: 5))
        app.buttons["Add inventory item"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Add item"].waitForExistence(timeout: 5))
        let field = app.textFields["Name (e.g. London Dry Gin)"]
        field.tap()
        field.typeText(name)
        dismissKeyboard()
        setSwitch(prefix: "In stock", on: inStock)
        if lowStock {
            setSwitch(prefix: "Low stock", on: true)
        }
        dismissKeyboard()
        app.navigationBars["Add item"].buttons["Add inventory item"].tap()
        XCTAssertTrue(app.navigationBars["My Bar"].waitForExistence(timeout: 8))
    }

    private func editButtons(_ name: String) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label == %@", "Edit \(name)"))
    }

    private func labeled(_ label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func preferredUnits() -> XCUIElement {
        app.segmentedControls.matching(NSPredicate(format: "label BEGINSWITH %@", "Preferred units")).firstMatch
    }

    private func filterInventory(_ query: String) {
        let search = app.searchFields["Search ingredients"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        let current = (search.value as? String) ?? ""
        if current == query { return }
        search.tap()
        if !current.isEmpty && current != "Search ingredients" {
            search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        search.typeText(query)
        if app.keyboards.buttons["Search"].exists {
            app.keyboards.buttons["Search"].tap()
        }
    }

    private func dismissKeyboard() {
        guard app.keyboards.element.exists else { return }
        let titles = ["Confirm item", "Confirm ingredient", "Add item", "Edit item", "New recipe", "Enter code"]
        for title in titles {
            let bar = app.navigationBars[title]
            if bar.exists {
                bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                return
            }
        }
    }

    private func capture(_ name: String) {
        dismissKeyboard()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot, quality: .original)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let directory = screenshotDirectory()
        let url = directory.appendingPathComponent("\(name).png")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: url, options: .atomic)
        } catch {
            XCTFail("Could not write \(name).png: \(error.localizedDescription)")
        }
    }

    private func screenshotDirectory() -> URL {
        if let shared = ProcessInfo.processInfo.environment["SIMULATOR_SHARED_RESOURCES_DIRECTORY"], !shared.isEmpty {
            return URL(fileURLWithPath: shared, isDirectory: true).appendingPathComponent("pourstl-screenshots-\(Self.screenshotRunID)", isDirectory: true)
        }
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("pourstl-screenshots-\(Self.screenshotRunID)", isDirectory: true)
    }

    private func note(_ key: String, _ value: String) {
        let directory = screenshotDirectory()
        let url = directory.appendingPathComponent("observations.txt")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: url.path) {
                try Data().write(to: url)
            }
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            if let data = "\(key)=\(value)\n".data(using: .utf8) {
                handle.write(data)
            }
        } catch {
            XCTFail("Could not record \(key): \(error.localizedDescription)")
        }
    }
}
