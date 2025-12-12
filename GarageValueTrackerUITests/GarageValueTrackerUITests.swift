//
//  GarageValueTrackerUITests.swift
//  GarageValueTrackerUITests
//
//  Created by raama srivatsan on 12/11/25.
//

import XCTest

final class GarageValueTrackerUITests: XCTestCase {
    
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - App Launch Tests
    
    @MainActor
    func testAppLaunches() throws {
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    @MainActor
    func testTabBarExists() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        
        // Verify all tabs exist
        XCTAssertTrue(app.tabBars.buttons["Garage"].exists)
        XCTAssertTrue(app.tabBars.buttons["Watchlist"].exists)
        XCTAssertTrue(app.tabBars.buttons["Deal Check"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    }
    
    // MARK: - Garage Tab Tests
    
    @MainActor
    func testGarageEmptyState() throws {
        let garageTab = app.tabBars.buttons["Garage"]
        XCTAssertTrue(garageTab.waitForExistence(timeout: 2))
        garageTab.tap()
        
        // Check for empty state elements
        let emptyStateText = app.staticTexts["No Vehicles Yet"]
        XCTAssertTrue(emptyStateText.waitForExistence(timeout: 2))
    }
    
    @MainActor
    func testAddVehicleButtonExists() throws {
        let garageTab = app.tabBars.buttons["Garage"]
        garageTab.tap()
        
        // Check for add button in navigation bar
        let addButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
    }
    
    @MainActor
    func testAddVehicleFlowManualEntry() throws {
        let garageTab = app.tabBars.buttons["Garage"]
        garageTab.tap()
        
        // Tap add button (either in empty state or nav bar)
        if app.buttons["Add Vehicle"].exists {
            app.buttons["Add Vehicle"].tap()
        } else {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        
        // Wait for sheet to appear
        let addVehicleSheet = app.navigationBars["Add to Garage"]
        XCTAssertTrue(addVehicleSheet.waitForExistence(timeout: 2))
        
        // Select manual entry
        if app.buttons["Manual Entry"].exists {
            app.buttons["Manual Entry"].tap()
        }
        
        // Verify form fields exist
        XCTAssertTrue(app.textFields["Make"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["Model"].exists)
        XCTAssertTrue(app.textFields["Trim"].exists)
    }
    
    // MARK: - Watchlist Tab Tests
    
    @MainActor
    func testWatchlistTabNavigation() throws {
        let watchlistTab = app.tabBars.buttons["Watchlist"]
        XCTAssertTrue(watchlistTab.waitForExistence(timeout: 2))
        watchlistTab.tap()
        
        // Verify navigation bar
        let watchlistNavBar = app.navigationBars["Watchlist"]
        XCTAssertTrue(watchlistNavBar.waitForExistence(timeout: 2))
    }
    
    @MainActor
    func testWatchlistEmptyState() throws {
        let watchlistTab = app.tabBars.buttons["Watchlist"]
        watchlistTab.tap()
        
        let emptyStateText = app.staticTexts["No Watchlist Items"]
        XCTAssertTrue(emptyStateText.waitForExistence(timeout: 2))
    }
    
    // MARK: - Deal Checker Tab Tests
    
    @MainActor
    func testDealCheckerTabNavigation() throws {
        let dealCheckerTab = app.tabBars.buttons["Deal Check"]
        XCTAssertTrue(dealCheckerTab.waitForExistence(timeout: 2))
        dealCheckerTab.tap()
        
        let dealCheckerNavBar = app.navigationBars["Deal Checker"]
        XCTAssertTrue(dealCheckerNavBar.waitForExistence(timeout: 2))
    }
    
    @MainActor
    func testDealCheckerFormFields() throws {
        let dealCheckerTab = app.tabBars.buttons["Deal Check"]
        dealCheckerTab.tap()
        
        // Verify form fields exist
        XCTAssertTrue(app.textFields["Make (e.g., Toyota)"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["Model (e.g., GR86)"].exists)
        XCTAssertTrue(app.textFields["Trim (e.g., Premium)"].exists)
        XCTAssertTrue(app.textFields["Mileage"].exists)
        XCTAssertTrue(app.textFields["Zip Code"].exists)
        XCTAssertTrue(app.textFields["Asking Price"].exists)
    }
    
    @MainActor
    func testDealCheckerButtonDisabledWhenEmpty() throws {
        let dealCheckerTab = app.tabBars.buttons["Deal Check"]
        dealCheckerTab.tap()
        
        let checkButton = app.buttons["Check Deal"]
        XCTAssertTrue(checkButton.waitForExistence(timeout: 2))
        XCTAssertFalse(checkButton.isEnabled)
    }
    
    // MARK: - Settings Tab Tests
    
    @MainActor
    func testSettingsTabNavigation() throws {
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 2))
        settingsTab.tap()
        
        let settingsNavBar = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNavBar.waitForExistence(timeout: 2))
    }
    
    @MainActor
    func testSettingsAdvancedFeatures() throws {
        let settingsTab = app.tabBars.buttons["Settings"]
        settingsTab.tap()
        
        // Verify advanced features section
        XCTAssertTrue(app.buttons["Swap Insight"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Upgrade Path"].exists)
    }
    
    @MainActor
    func testSettingsHassleModelSection() throws {
        let settingsTab = app.tabBars.buttons["Settings"]
        settingsTab.tap()
        
        // Scroll to find hassle model section
        let hassleModelHeader = app.staticTexts["Hassle Model Assumptions"]
        if !hassleModelHeader.isHittable {
            app.swipeUp()
        }
        
        XCTAssertTrue(hassleModelHeader.exists)
    }
    
    @MainActor
    func testSwapInsightModal() throws {
        let settingsTab = app.tabBars.buttons["Settings"]
        settingsTab.tap()
        
        let swapInsightButton = app.buttons["Swap Insight"]
        XCTAssertTrue(swapInsightButton.waitForExistence(timeout: 2))
        swapInsightButton.tap()
        
        // Verify modal appears
        let swapInsightNavBar = app.navigationBars["Swap Insight"]
        XCTAssertTrue(swapInsightNavBar.waitForExistence(timeout: 2))
        
        // Close modal
        let closeButton = app.buttons["Close"]
        XCTAssertTrue(closeButton.exists)
        closeButton.tap()
    }
    
    @MainActor
    func testUpgradePathModal() throws {
        let settingsTab = app.tabBars.buttons["Settings"]
        settingsTab.tap()
        
        let upgradePathButton = app.buttons["Upgrade Path"]
        XCTAssertTrue(upgradePathButton.waitForExistence(timeout: 2))
        upgradePathButton.tap()
        
        // Verify modal appears
        let upgradePathNavBar = app.navigationBars["Upgrade Path"]
        XCTAssertTrue(upgradePathNavBar.waitForExistence(timeout: 2))
        
        // Close modal
        let closeButton = app.buttons["Close"]
        XCTAssertTrue(closeButton.exists)
        closeButton.tap()
    }
    
    // MARK: - Tab Switching Tests
    
    @MainActor
    func testTabSwitching() throws {
        // Start at Garage
        let garageTab = app.tabBars.buttons["Garage"]
        garageTab.tap()
        XCTAssertTrue(app.navigationBars["Garage"].waitForExistence(timeout: 2))
        
        // Switch to Watchlist
        let watchlistTab = app.tabBars.buttons["Watchlist"]
        watchlistTab.tap()
        XCTAssertTrue(app.navigationBars["Watchlist"].waitForExistence(timeout: 2))
        
        // Switch to Deal Checker
        let dealCheckerTab = app.tabBars.buttons["Deal Check"]
        dealCheckerTab.tap()
        XCTAssertTrue(app.navigationBars["Deal Checker"].waitForExistence(timeout: 2))
        
        // Switch to Settings
        let settingsTab = app.tabBars.buttons["Settings"]
        settingsTab.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        
        // Back to Garage
        garageTab.tap()
        XCTAssertTrue(app.navigationBars["Garage"].waitForExistence(timeout: 2))
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    
    @MainActor
    func testTabSwitchingPerformance() throws {
        measure {
            app.tabBars.buttons["Garage"].tap()
            app.tabBars.buttons["Watchlist"].tap()
            app.tabBars.buttons["Deal Check"].tap()
            app.tabBars.buttons["Settings"].tap()
            app.tabBars.buttons["Garage"].tap()
        }
    }
    
    // MARK: - Accessibility Tests
    
    @MainActor
    func testTabBarAccessibility() throws {
        let garageTab = app.tabBars.buttons["Garage"]
        XCTAssertTrue(garageTab.isAccessibilityElement)
        
        let watchlistTab = app.tabBars.buttons["Watchlist"]
        XCTAssertTrue(watchlistTab.isAccessibilityElement)
        
        let dealCheckerTab = app.tabBars.buttons["Deal Check"]
        XCTAssertTrue(dealCheckerTab.isAccessibilityElement)
        
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.isAccessibilityElement)
    }
    
    // MARK: - Screenshot Tests
    
    @MainActor
    func testScreenshotGarageEmptyState() throws {
        let garageTab = app.tabBars.buttons["Garage"]
        garageTab.tap()
        
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Garage Empty State"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    
    @MainActor
    func testScreenshotAllTabs() throws {
        let tabs = ["Garage", "Watchlist", "Deal Check", "Settings"]
        
        for tabName in tabs {
            let tab = app.tabBars.buttons[tabName]
            tab.tap()
            
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "\(tabName) Tab"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
