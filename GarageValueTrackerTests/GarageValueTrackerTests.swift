//
//  GarageValueTrackerTests.swift
//  GarageValueTrackerTests
//
//  Created by raama srivatsan on 12/11/25.
//

import XCTest
import SwiftData
@testable import GarageValueTracker

final class GarageValueTrackerTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUpWithError() throws {
        // Create in-memory model container for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: VehicleEntity.self,
            CostEntryEntity.self,
            ValuationSnapshotEntity.self,
            UserSettingsEntity.self,
            configurations: config
        )
        modelContext = ModelContext(modelContainer)
    }
    
    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
    }
    
    // MARK: - Vehicle Entity Tests
    
    func testVehicleEntityCreation() throws {
        let vehicle = VehicleEntity(
            ownershipType: .owned,
            year: 2022,
            make: "Toyota",
            model: "GR86",
            trim: "Premium",
            transmission: "Manual",
            mileageCurrent: 32000,
            zip: "95126",
            purchasePrice: 32000,
            purchaseDate: Date(),
            purchaseMileage: 15000
        )
        
        XCTAssertEqual(vehicle.year, 2022)
        XCTAssertEqual(vehicle.make, "Toyota")
        XCTAssertEqual(vehicle.model, "GR86")
        XCTAssertEqual(vehicle.ownershipType, .owned)
        XCTAssertEqual(vehicle.displayName, "2022 Toyota GR86 Premium")
    }
    
    func testVehicleEntityPersistence() throws {
        let vehicle = VehicleEntity(
            ownershipType: .owned,
            year: 2024,
            make: "Mazda",
            model: "MX-5 Miata",
            trim: "Club",
            transmission: "Manual",
            mileageCurrent: 5000,
            zip: "94102",
            purchasePrice: 33000,
            purchaseDate: Date(),
            purchaseMileage: 2000
        )
        
        modelContext.insert(vehicle)
        try modelContext.save()
        
        let fetchDescriptor = FetchDescriptor<VehicleEntity>()
        let vehicles = try modelContext.fetch(fetchDescriptor)
        
        XCTAssertEqual(vehicles.count, 1)
        XCTAssertEqual(vehicles.first?.make, "Mazda")
        XCTAssertEqual(vehicles.first?.model, "MX-5 Miata")
    }
    
    // MARK: - Cost Entry Tests
    
    func testCostEntryCreation() throws {
        let cost = CostEntryEntity(
            date: Date(),
            category: .maintenance,
            amount: 150.00,
            notes: "Oil change"
        )
        
        XCTAssertEqual(cost.category, .maintenance)
        XCTAssertEqual(cost.amount, 150.00)
        XCTAssertEqual(cost.notes, "Oil change")
    }
    
    func testCostEntryVehicleRelationship() throws {
        let vehicle = VehicleEntity(
            ownershipType: .owned,
            year: 2022,
            make: "Toyota",
            model: "GR86",
            trim: "Premium",
            transmission: "Manual",
            mileageCurrent: 32000,
            zip: "95126"
        )
        
        let cost1 = CostEntryEntity(
            date: Date(),
            category: .maintenance,
            amount: 150.00,
            notes: "Oil change"
        )
        
        let cost2 = CostEntryEntity(
            date: Date(),
            category: .insurance,
            amount: 1200.00,
            notes: "Annual premium"
        )
        
        cost1.vehicle = vehicle
        cost2.vehicle = vehicle
        
        modelContext.insert(vehicle)
        modelContext.insert(cost1)
        modelContext.insert(cost2)
        try modelContext.save()
        
        XCTAssertEqual(vehicle.costEntries?.count, 2)
        
        let totalCosts = vehicle.costEntries?.reduce(0) { $0 + $1.amount } ?? 0
        XCTAssertEqual(totalCosts, 1350.00)
    }
    
    func testCostCategoryIcons() {
        XCTAssertEqual(CostCategory.maintenance.icon, "wrench.and.screwdriver")
        XCTAssertEqual(CostCategory.repairs.icon, "hammer")
        XCTAssertEqual(CostCategory.insurance.icon, "shield")
        XCTAssertEqual(CostCategory.registration.icon, "doc.text")
        XCTAssertEqual(CostCategory.mods.icon, "sparkles")
        XCTAssertEqual(CostCategory.fuel.icon, "fuelpump")
        XCTAssertEqual(CostCategory.other.icon, "ellipsis.circle")
    }
    
    // MARK: - Valuation Snapshot Tests
    
    func testValuationSnapshotCreation() throws {
        let snapshot = ValuationSnapshotEntity(
            date: Date(),
            low: 27000,
            mid: 29000,
            high: 31200,
            confidence: .medium,
            sampleSize: 18,
            momentum90d: -4.1,
            liquidityScore: 0.62,
            recommendation: .hold
        )
        
        XCTAssertEqual(snapshot.low, 27000)
        XCTAssertEqual(snapshot.mid, 29000)
        XCTAssertEqual(snapshot.high, 31200)
        XCTAssertEqual(snapshot.confidence, .medium)
        XCTAssertEqual(snapshot.recommendation, .hold)
    }
    
    func testRecommendationColors() {
        XCTAssertEqual(Recommendation.hold.color, "green")
        XCTAssertEqual(Recommendation.considerSelling.color, "orange")
        XCTAssertEqual(Recommendation.strongSell.color, "red")
    }
    
    // MARK: - User Settings Tests
    
    func testUserSettingsDefaults() throws {
        let settings = UserSettingsEntity()
        
        XCTAssertEqual(settings.hoursPerWeekActiveListing, 1.5)
        XCTAssertEqual(settings.hoursPerTestDrive, 1.0)
        XCTAssertEqual(settings.hoursPerPriceChange, 0.5)
        XCTAssertEqual(settings.currencySymbol, "$")
    }
    
    func testUserSettingsPersistence() throws {
        let settings = UserSettingsEntity(
            hoursPerWeekActiveListing: 2.0,
            hoursPerTestDrive: 1.5,
            hoursPerPriceChange: 0.75,
            defaultZipCode: "94102",
            currencySymbol: "$"
        )
        
        modelContext.insert(settings)
        try modelContext.save()
        
        let fetchDescriptor = FetchDescriptor<UserSettingsEntity>()
        let savedSettings = try modelContext.fetch(fetchDescriptor)
        
        XCTAssertEqual(savedSettings.count, 1)
        XCTAssertEqual(savedSettings.first?.hoursPerWeekActiveListing, 2.0)
        XCTAssertEqual(savedSettings.first?.defaultZipCode, "94102")
    }
    
    // MARK: - API Model Tests
    
    func testVehicleNormalizeRequest() throws {
        let request = VehicleNormalizeRequest(
            vin: "1HGBH41JXMN109186",
            year: 2022,
            make: "Toyota",
            model: "GR86",
            trim: "Premium",
            transmission: "Manual",
            mileage: 32000,
            zip: "95126"
        )
        
        XCTAssertEqual(request.vin, "1HGBH41JXMN109186")
        XCTAssertEqual(request.year, 2022)
        XCTAssertEqual(request.make, "Toyota")
    }
    
    func testPnLComputeLogic() throws {
        // Simulate P&L calculation
        let purchasePrice: Double = 32000
        let totalCosts: Double = 2050
        let currentMarketMid: Double = 29000
        
        let basis = purchasePrice + totalCosts
        let unrealizedPnL = currentMarketMid - basis
        let cumulativeDepreciation = purchasePrice - currentMarketMid
        
        XCTAssertEqual(basis, 34050)
        XCTAssertEqual(unrealizedPnL, -5050)
        XCTAssertEqual(cumulativeDepreciation, 3000)
    }
    
    func testDealCheckerPriceVsMid() throws {
        let mid: Double = 29000
        let askPrice: Double = 30500
        let priceVsMidPct = ((askPrice - mid) / mid) * 100
        
        XCTAssertEqual(priceVsMidPct, 5.172413793103448, accuracy: 0.01)
    }
    
    // MARK: - Ownership Type Tests
    
    func testOwnershipTypeRawValues() {
        XCTAssertEqual(OwnershipType.owned.rawValue, "owned")
        XCTAssertEqual(OwnershipType.watchlist.rawValue, "watchlist")
    }
    
    // MARK: - NHTSA API Tests
    
    func testVehicleAPIServiceExists() {
        let service = VehicleAPIService.shared
        XCTAssertNotNil(service)
    }
    
    func testMarketAPIServiceExists() {
        let service = MarketAPIService.shared
        XCTAssertNotNil(service)
    }
    
    // MARK: - Mock Data Tests
    
    func testMockValuationEstimate() async throws {
        let request = ValuationEstimateRequest(
            vehicleId: UUID().uuidString,
            mileage: 32000,
            zip: "95126"
        )
        
        let response = try await MarketAPIService.shared.getValuationEstimate(request)
        
        XCTAssertGreaterThan(response.mid, 0)
        XCTAssertLessThan(response.low, response.mid)
        XCTAssertGreaterThan(response.high, response.mid)
        XCTAssertGreaterThan(response.sampleSize, 0)
    }
    
    func testMockDealChecker() async throws {
        let request = DealCheckRequest(
            vehicleId: UUID().uuidString,
            mileage: 32000,
            zip: "95126",
            askPrice: 30500,
            hassleModel: HassleModel(
                hoursPerWeekActiveListing: 1.5,
                hoursPerTestDrive: 1.0,
                hoursPerPriceChange: 0.5
            )
        )
        
        let response = try await MarketAPIService.shared.checkDeal(request)
        
        XCTAssertNotNil(response.fairValue)
        XCTAssertNotNil(response.currentPricing)
        XCTAssertNotNil(response.sellOutlook)
        XCTAssertFalse(response.scenarios.isEmpty)
    }
    
    func testMockSwapInsight() async throws {
        let request = SwapInsightRequest(
            currentVehicleId: UUID().uuidString,
            altVehicleId: UUID().uuidString,
            currentMarketMid: 29000,
            altEntryPrice: 32000,
            regionBucket: "bay_area"
        )
        
        let response = try await MarketAPIService.shared.getSwapInsight(request)
        
        XCTAssertNotNil(response.current)
        XCTAssertNotNil(response.alt)
        XCTAssertNotNil(response.verdict)
    }
    
    func testMockUpgradePath() async throws {
        let request = UpgradePathRequest(
            currentVehicleId: UUID().uuidString,
            currentMarketMid: 29000,
            targetBudget: 50000,
            timeframe: 12,
            annualMileage: 12000,
            regionBucket: "bay_area"
        )
        
        let response = try await MarketAPIService.shared.getUpgradePath(request)
        
        XCTAssertFalse(response.recommendedMoves.isEmpty)
        XCTAssertLessThanOrEqual(response.recommendedMoves.count, 3)
    }
    
    // MARK: - Performance Tests
    
    func testVehicleCreationPerformance() throws {
        measure {
            for _ in 0..<100 {
                _ = VehicleEntity(
                    ownershipType: .owned,
                    year: 2022,
                    make: "Toyota",
                    model: "GR86",
                    trim: "Premium",
                    transmission: "Manual",
                    mileageCurrent: 32000,
                    zip: "95126"
                )
            }
        }
    }
    
    func testCostEntryBulkCreation() throws {
        let vehicle = VehicleEntity(
            ownershipType: .owned,
            year: 2022,
            make: "Toyota",
            model: "GR86",
            trim: "Premium",
            transmission: "Manual",
            mileageCurrent: 32000,
            zip: "95126"
        )
        
        modelContext.insert(vehicle)
        
        measure {
            for i in 0..<50 {
                let cost = CostEntryEntity(
                    date: Date().addingTimeInterval(Double(-i * 86400)),
                    category: CostCategory.allCases.randomElement() ?? .maintenance,
                    amount: Double.random(in: 50...500),
                    notes: "Test cost \(i)"
                )
                cost.vehicle = vehicle
                modelContext.insert(cost)
            }
            
            try? modelContext.save()
        }
    }
}
