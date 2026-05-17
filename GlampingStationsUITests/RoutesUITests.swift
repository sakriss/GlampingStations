//
//  RoutesUITests.swift
//  GlampingStationsUITests
//

import XCTest

final class RoutesUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testRoutesWarningFixtureShowsRiskMarkerAndControls() throws {
        launch(arguments: ["UITestRoutesWarning"])
        openRoutesTab()

        XCTAssertTrue(app.staticTexts["routesWarningChip"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["routesWarningChip"].label, "1 risk")
        XCTAssertTrue(app.buttons["routesOpenMapsButton"].isEnabled)
        XCTAssertTrue(app.buttons["routesReportIssueButton"].isEnabled)
        XCTAssertTrue(app.descendants(matching: .any)["routeWarningMarker_risk"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Low Clearance Test Bridge"].waitForExistence(timeout: 5))

        app.staticTexts["Low Clearance Test Bridge"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Type: Low clearance")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "OSM way #1001")).firstMatch.exists)

        app.descendants(matching: .any)["routeWarningMarker_risk"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "The listed clearance is lower")).firstMatch.waitForExistence(timeout: 5))
    }

    func testRoutesNoWarningsFixtureDoesNotShowRiskMarker() throws {
        launch(arguments: ["UITestRoutesNoWarnings"])
        openRoutesTab()

        XCTAssertTrue(app.staticTexts["routesWarningChip"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["routesWarningChip"].label, "Advisory")
        XCTAssertFalse(app.descendants(matching: .any)["routeWarningMarker_risk"].exists)
        XCTAssertTrue(app.staticTexts["No known clearance conflicts found"].waitForExistence(timeout: 5))
    }

    func testEmptyDestinationShowsValidationMessage() throws {
        launch()
        openRoutesTab()

        let field = app.textFields["routesDestinationField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("\n")

        XCTAssertTrue(app.staticTexts["Enter a destination to preview a route."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["routesOpenMapsButton"].isEnabled)
        XCTAssertFalse(app.descendants(matching: .any)["routeWarningMarker_risk"].exists)
    }

    func testRouteStopsShowFuelAndDumpStationsForI5Location() throws {
        launch(arguments: ["UITestRoutesI5Stops"])
        openRoutesTab()
        openStops()

        XCTAssertTrue(app.staticTexts["Pilot Flying J #584 (Aurora)"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Gee Creek Rest Area (I-5 NB)"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["SeaTac Rest Area (I-5 NB)"].waitForExistence(timeout: 5))
    }

    func testRouteStopsShowFuelAndDumpStationsForI90Location() throws {
        launch(arguments: ["UITestRoutesI90Stops"])
        openRoutesTab()
        openStops()

        XCTAssertTrue(app.staticTexts["TA Seattle East"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Indian John Hill Rest Area (I-90 EB/WB)"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Schrag Rest Area (I-90 WB)"].waitForExistence(timeout: 5))
    }

    func testRouteStopsShowFuelAndDumpStationsForNonInterstateCoastLocation() throws {
        launch(arguments: ["UITestRoutesCoastStops"])
        openRoutesTab()
        openStops()

        XCTAssertTrue(app.staticTexts["Sinclair"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["William M. Tugman State Park"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Reedsport"].waitForExistence(timeout: 5))
    }

    func testRouteStopsShowFuelAndDumpStationsForArizonaLocation() throws {
        launch(arguments: ["UITestRoutesArizonaStops"])
        openRoutesTab()
        openStops()

        XCTAssertTrue(app.staticTexts["Phoenix RV Fuel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Phoenix RV Dump"].waitForExistence(timeout: 5))
    }

    func testRouteStopsShowFuelAndDumpStationsForMontanaLocation() throws {
        launch(arguments: ["UITestRoutesMontanaStops"])
        openRoutesTab()
        openStops()

        XCTAssertTrue(app.staticTexts["Billings RV Fuel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Billings RV Dump"].waitForExistence(timeout: 5))
    }

    func testRouteStopsShowFuelAndDumpStationsForNebraskaLocation() throws {
        launch(arguments: ["UITestRoutesNebraskaStops"])
        openRoutesTab()
        openStops()

        XCTAssertTrue(app.staticTexts["Kearney RV Fuel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Kearney RV Dump"].waitForExistence(timeout: 5))
    }

    func testMapTabShowsFuelAndDumpMarkersForArizonaLocation() throws {
        launch(arguments: ["UITestMapArizona"])
        openMapTab()

        XCTAssertTrue(app.descendants(matching: .any)["mapFuelMarker"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["mapDumpMarker"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["Phoenix RV Fuel"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["Phoenix RV Dump"].exists)
    }

    func testMapTabShowsFuelAndDumpMarkersForMontanaLocation() throws {
        launch(arguments: ["UITestMapMontana"])
        openMapTab()

        XCTAssertTrue(app.descendants(matching: .any)["mapFuelMarker"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["mapDumpMarker"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["Billings RV Fuel"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["Billings RV Dump"].exists)
    }

    func testMapTabShowsFuelAndDumpMarkersForNebraskaLocation() throws {
        launch(arguments: ["UITestMapNebraska"])
        openMapTab()

        XCTAssertTrue(app.descendants(matching: .any)["mapFuelMarker"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["mapDumpMarker"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["Kearney RV Fuel"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["Kearney RV Dump"].exists)
    }

    func testDumpTabShowsArizonaDumpStations() throws {
        launch(arguments: ["UITestDumpArizona"])
        openDumpTab()

        assertDumpTableContains("Phoenix RV Dump")
    }

    func testDumpTabShowsMontanaDumpStations() throws {
        launch(arguments: ["UITestDumpMontana"])
        openDumpTab()

        assertDumpTableContains("Billings RV Dump")
    }

    func testDumpTabShowsNebraskaDumpStations() throws {
        launch(arguments: ["UITestDumpNebraska"])
        openDumpTab()

        assertDumpTableContains("Kearney RV Dump")
    }

    private func launch(arguments: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = arguments
        if let scenario = arguments.first {
            app.launchEnvironment["UITestScenario"] = scenario
        }
        app.launch()
    }

    private func openRoutesTab() {
        let routesTab = app.tabBars.buttons["Routes"]
        XCTAssertTrue(routesTab.waitForExistence(timeout: 8))
        routesTab.tap()
    }

    private func openMapTab() {
        let mapTab = app.tabBars.buttons["Map"]
        XCTAssertTrue(mapTab.waitForExistence(timeout: 8))
        mapTab.tap()
    }

    private func openDumpTab() {
        let dumpTab = app.tabBars.buttons["Dump"]
        XCTAssertTrue(dumpTab.waitForExistence(timeout: 8))
        dumpTab.tap()
    }

    private func assertDumpTableContains(_ name: String) {
        let table = app.tables["dumpStationTable"]
        XCTAssertTrue(table.waitForExistence(timeout: 5))
        let predicate = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", name, name)
        expectation(for: predicate, evaluatedWith: table)
        waitForExpectations(timeout: 5)
    }

    private func openStops() {
        let stopsSegment = app.segmentedControls["routesDetailsSegment"].buttons["Stops"]
        XCTAssertTrue(stopsSegment.waitForExistence(timeout: 5))
        stopsSegment.tap()
    }
}
