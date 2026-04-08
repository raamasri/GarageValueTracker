import Foundation
import CoreData

class SignalEngine {
    static let shared = SignalEngine()
    
    private var segmentProfiles: [String: SegmentProfile] = [:]
    
    private init() {
        loadSegmentProfiles()
    }
    
    // MARK: - Generate All Signals
    
    func generateSignals(vehicles: [VehicleEntity], context: NSManagedObjectContext) -> [Signal] {
        var signals: [Signal] = []
        
        for vehicle in vehicles {
            signals.append(contentsOf: generateVehicleSignals(vehicle: vehicle, context: context))
        }
        
        signals.append(contentsOf: generatePortfolioSignals(vehicles: vehicles, context: context))
        
        return signals
    }
    
    // MARK: - Per-Vehicle Signals
    
    func generateVehicleSignals(vehicle: VehicleEntity, context: NSManagedObjectContext) -> [Signal] {
        var signals: [Signal] = []
        let segment = vehicle.resolvedSegment
        let valuation = ValuationEngine.shared.valuate(
            make: vehicle.make, model: vehicle.model,
            year: Int(vehicle.year), mileage: Int(vehicle.mileage),
            trim: vehicle.trim, msrp: vehicle.trimMSRP > 0 ? vehicle.trimMSRP : nil,
            location: vehicle.location, condition: vehicle.conditionTier
        )
        
        if let signal = checkDepreciationCliff(vehicle: vehicle) {
            signals.append(signal)
        }
        
        if let signal = checkSeasonalTiming(vehicle: vehicle, segment: segment) {
            signals.append(signal)
        }
        
        if let signal = checkEquityErosion(vehicle: vehicle, valuation: valuation) {
            signals.append(signal)
        }
        
        if let signal = checkValueAnomaly(vehicle: vehicle, valuation: valuation) {
            signals.append(signal)
        }
        
        if let signal = checkMileageMilestone(vehicle: vehicle) {
            signals.append(signal)
        }
        
        return signals
    }
    
    // MARK: - Depreciation Cliff Detection
    
    private func checkDepreciationCliff(vehicle: VehicleEntity) -> Signal? {
        let mileage = Int(vehicle.mileage)
        let thresholds = [50000, 75000, 100000, 150000]
        
        for threshold in thresholds {
            let distance = threshold - mileage
            if distance > 0 && distance <= 5000 {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                let thresholdStr = formatter.string(from: NSNumber(value: threshold)) ?? "\(threshold)"
                let distanceStr = formatter.string(from: NSNumber(value: distance)) ?? "\(distance)"
                
                return Signal(
                    title: "Approaching \(thresholdStr) Miles",
                    body: "Your \(vehicle.displayName) is \(distanceStr) miles from the \(thresholdStr)-mile mark. Vehicles crossing this threshold typically see a 5-8% value reduction. Consider selling before this milestone if you're planning to.",
                    category: .timing,
                    severity: distance <= 2000 ? .action : .warning,
                    actionType: .sell,
                    vehicleID: vehicle.id
                )
            }
        }
        
        let currentYear = Calendar.current.component(.year, from: Date())
        let age = currentYear - Int(vehicle.year)
        let warrantyYears = [3, 4, 5]
        for wy in warrantyYears {
            if age == wy - 1 {
                return Signal(
                    title: "Warranty Expiring Soon",
                    body: "Your \(vehicle.displayName) is approaching the typical \(wy)-year warranty expiration. Post-warranty vehicles often see accelerated depreciation as buyers factor in potential repair costs.",
                    category: .timing,
                    severity: .warning,
                    actionType: .sell,
                    vehicleID: vehicle.id
                )
            }
        }
        
        let currentMonth = Calendar.current.component(.month, from: Date())
        if currentMonth >= 9 && currentMonth <= 10 {
            return Signal(
                title: "Model Year Rollover Period",
                body: "New model year vehicles are arriving at dealers. Your \(vehicle.displayName) will become one year older in market perception, which can accelerate depreciation by 3-5%.",
                category: .timing,
                severity: .info,
                actionType: .sell,
                vehicleID: vehicle.id
            )
        }
        
        return nil
    }
    
    // MARK: - Seasonal Timing
    
    private func checkSeasonalTiming(vehicle: VehicleEntity, segment: String) -> Signal? {
        let currentMonth = Calendar.current.component(.month, from: Date())
        
        if segment == "sports" && (currentMonth == 2 || currentMonth == 3) {
            return Signal(
                title: "Peak Selling Season Approaching",
                body: "Sports cars and convertibles historically sell for 8-12% more in March through May. Your \(vehicle.displayName) is entering its peak selling season.",
                category: .timing,
                severity: .action,
                actionType: .sell,
                vehicleID: vehicle.id
            )
        }
        
        if segment == "suv" || segment == "truck" {
            if currentMonth == 8 || currentMonth == 9 {
                return Signal(
                    title: "Strong Demand Season",
                    body: "SUVs and trucks see increased demand heading into fall and winter. Your \(vehicle.displayName) may command a premium right now.",
                    category: .timing,
                    severity: .info,
                    actionType: .sell,
                    vehicleID: vehicle.id
                )
            }
        }
        
        return nil
    }
    
    // MARK: - Equity Erosion
    
    private func checkEquityErosion(vehicle: VehicleEntity, valuation: ValuationResult) -> Signal? {
        let purchasePrice = vehicle.purchasePrice
        guard purchasePrice > 0 else { return nil }
        
        let currentValue = valuation.mid
        let lostPercent = ((purchasePrice - currentValue) / purchasePrice) * 100
        
        if lostPercent > 50 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.maximumFractionDigits = 0
            let lostStr = formatter.string(from: NSNumber(value: purchasePrice - currentValue)) ?? ""
            
            return Signal(
                title: "Significant Value Loss",
                body: "Your \(vehicle.displayName) has lost approximately \(lostStr) (\(Int(lostPercent))%) from your purchase price. At this depreciation level, the vehicle may be better to hold as a long-term asset rather than sell at a steep loss.",
                category: .portfolio,
                severity: .warning,
                actionType: .hold,
                vehicleID: vehicle.id
            )
        }
        
        if lostPercent < 0 {
            return Signal(
                title: "Vehicle Appreciation Detected",
                body: "Your \(vehicle.displayName) is estimated above your purchase price. This is uncommon and suggests strong market demand or collector interest. Consider whether now is a good time to realize this gain.",
                category: .anomaly,
                severity: .action,
                actionType: .sell,
                vehicleID: vehicle.id
            )
        }
        
        return nil
    }
    
    // MARK: - Value Anomaly
    
    private func checkValueAnomaly(vehicle: VehicleEntity, valuation: ValuationResult) -> Signal? {
        let storedValue = vehicle.currentValue
        guard storedValue > 0 else { return nil }
        
        let difference = ((valuation.mid - storedValue) / storedValue) * 100
        
        if abs(difference) > 15 {
            let direction = difference > 0 ? "above" : "below"
            return Signal(
                title: "Valuation Shift Detected",
                body: "Your \(vehicle.displayName)'s estimated value is \(Int(abs(difference)))% \(direction) its previously recorded value. This may reflect market movement or a needed reappraisal.",
                category: .anomaly,
                severity: .info,
                vehicleID: vehicle.id
            )
        }
        
        return nil
    }
    
    // MARK: - Mileage Milestone
    
    private func checkMileageMilestone(vehicle: VehicleEntity) -> Signal? {
        let mileage = Int(vehicle.mileage)
        if mileage > 0 && mileage < 1000 {
            return Signal(
                title: "Low Mileage Premium",
                body: "Your \(vehicle.displayName) has very low mileage (\(mileage) mi). Low-mileage examples in this category often command significant premiums. Keep mileage low if you plan to maximize resale value.",
                category: .portfolio,
                severity: .info,
                actionType: .hold,
                vehicleID: vehicle.id
            )
        }
        return nil
    }
    
    // MARK: - Portfolio-Level Signals
    
    func generatePortfolioSignals(vehicles: [VehicleEntity], context: NSManagedObjectContext) -> [Signal] {
        guard vehicles.count >= 2 else { return [] }
        var signals: [Signal] = []
        
        var segmentCounts: [String: Int] = [:]
        for v in vehicles {
            let seg = v.resolvedSegment
            segmentCounts[seg, default: 0] += 1
        }
        
        if let dominant = segmentCounts.max(by: { $0.value < $1.value }),
           Double(dominant.value) / Double(vehicles.count) > 0.7,
           vehicles.count >= 3 {
            let profile = segmentProfiles[dominant.key]
            let segName = profile?.displayName ?? dominant.key.capitalized
            signals.append(Signal(
                title: "High Concentration Risk",
                body: "Your garage has \(Int(Double(dominant.value) / Double(vehicles.count) * 100))% concentration in \(segName). A market downturn in this segment would impact your entire portfolio. Consider diversifying across segments.",
                category: .portfolio,
                severity: .warning
            ))
        }
        
        let ages = vehicles.map { Calendar.current.component(.year, from: Date()) - Int($0.year) }
        let approachingCliff = ages.filter { $0 >= 4 && $0 <= 6 }.count
        if approachingCliff >= 2 {
            signals.append(Signal(
                title: "Multiple Vehicles at Depreciation Inflection",
                body: "\(approachingCliff) of your vehicles are in the 4-6 year age range, which is a common depreciation inflection point. Review your hold/sell strategy for each.",
                category: .timing,
                severity: .warning
            ))
        }
        
        let totalValue = vehicles.reduce(0.0) { $0 + $1.currentValue }
        let totalCost = vehicles.reduce(0.0) { $0 + $1.purchasePrice }
        if totalCost > 0 {
            let portfolioReturn = ((totalValue - totalCost) / totalCost) * 100
            if portfolioReturn > 0 {
                signals.append(Signal(
                    title: "Portfolio in Positive Territory",
                    body: "Your garage is estimated at \(formatPercent(portfolioReturn)) above total cost basis. This is uncommon and suggests favorable market conditions or well-chosen vehicles.",
                    category: .portfolio,
                    severity: .info
                ))
            }
        }
        
        return signals
    }
    
    // MARK: - Hold/Sell Signal for a Single Vehicle
    
    func holdSellSignal(vehicle: VehicleEntity, context: NSManagedObjectContext) -> Signal {
        let segment = vehicle.resolvedSegment
        let valuation = ValuationEngine.shared.valuate(
            make: vehicle.make, model: vehicle.model,
            year: Int(vehicle.year), mileage: Int(vehicle.mileage),
            trim: vehicle.trim, location: vehicle.location, condition: vehicle.conditionTier
        )
        
        let age = Calendar.current.component(.year, from: Date()) - Int(vehicle.year)
        let retained = vehicle.purchasePrice > 0 ? (valuation.mid / vehicle.purchasePrice) * 100 : 100
        let currentMonth = Calendar.current.component(.month, from: Date())
        
        var sellScore = 50
        
        if retained > 80 { sellScore += 15 }
        else if retained > 60 { sellScore += 10 }
        else if retained < 40 { sellScore -= 10 }
        
        if age >= 3 && age <= 5 { sellScore += 10 }
        else if age > 8 { sellScore -= 5 }
        
        if (segment == "sports" && (3...5).contains(currentMonth)) ||
           (segment == "truck" && (8...10).contains(currentMonth)) ||
           (segment == "suv" && (8...10).contains(currentMonth)) {
            sellScore += 10
        }
        
        let mileage = Int(vehicle.mileage)
        if mileage > 95000 && mileage < 100000 { sellScore += 15 }
        else if mileage > 70000 && mileage < 75000 { sellScore += 10 }
        
        sellScore = max(min(sellScore, 100), 0)
        
        if sellScore >= 70 {
            return Signal(
                title: "Favorable Sell Window",
                body: "Market conditions and vehicle profile suggest this is a good time to sell your \(vehicle.displayName). Retained value and seasonal factors are aligned.",
                category: .timing,
                severity: .action,
                actionType: .sell,
                vehicleID: vehicle.id
            )
        } else if sellScore >= 45 {
            return Signal(
                title: "Monitor and Prepare",
                body: "Your \(vehicle.displayName) is in a neutral position. No urgent action needed, but watch for seasonal peaks or approaching mileage milestones.",
                category: .timing,
                severity: .info,
                actionType: .wait,
                vehicleID: vehicle.id
            )
        } else {
            return Signal(
                title: "Hold Recommended",
                body: "Current conditions favor holding your \(vehicle.displayName). The vehicle's value trend, segment dynamics, or negative equity suggest waiting for a better window.",
                category: .timing,
                severity: .info,
                actionType: .hold,
                vehicleID: vehicle.id
            )
        }
    }
    
    // MARK: - Persist Signals
    
    func persistSignals(_ signals: [Signal], context: NSManagedObjectContext) {
        for signal in signals {
            let request = SignalEntity.fetchRequest()
            request.predicate = NSPredicate(format: "title == %@ AND vehicleID == %@", signal.title, (signal.vehicleID ?? UUID()) as CVarArg)
            request.fetchLimit = 1
            
            if let existing = try? context.fetch(request), !existing.isEmpty {
                continue
            }
            
            _ = SignalEntity(context: context, signal: signal, vehicleID: signal.vehicleID)
        }
        
        try? context.save()
    }
    
    // MARK: - Helpers
    
    private func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }
    
    // MARK: - Macro Context
    
    func generateMacroContext() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        let dateStr = dateFormatter.string(from: Date())
        
        let currentMonth = Calendar.current.component(.month, from: Date())
        
        let seasonalNote: String
        switch currentMonth {
        case 3...5:
            seasonalNote = "Spring selling season is active — convertibles and sports cars command seasonal premiums of 5-12%. Dealers are restocking for summer demand."
        case 6...8:
            seasonalNote = "Summer demand is peaking for sports cars and convertibles. SUV and truck inventory is building ahead of fall."
        case 9...11:
            seasonalNote = "Fall transition period — SUVs and trucks see increased demand. Sports car premiums are softening as weather cools."
        default:
            seasonalNote = "Winter market conditions — lower overall transaction volume. Buyers have negotiating leverage. AWD and 4WD vehicles see regional premiums."
        }
        
        var segments: [String] = []
        for (key, profile) in segmentProfiles.prefix(4) {
            let trend = profile.peakMultiplier > 1.15 ? "appreciating" : "depreciating"
            segments.append("\(profile.displayName) segment is \(trend) (\(key))")
        }
        let segmentNote = segments.isEmpty ? "" : " " + segments.joined(separator: ". ") + "."
        
        return "\(seasonalNote) Auction volume remains elevated year-over-year; private party days-on-market compressed for desirable specifications. Generational demand shift continuing — millennial collectors entering peak earning years, driving premium on 1990s-2000s Japanese and European sports cars.\(segmentNote)"
    }
    
    private func loadSegmentProfiles() {
        guard let url = Bundle.main.url(forResource: "segment_profiles", withExtension: "json") else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(SegmentProfilesFile.self, from: data)
            self.segmentProfiles = decoded.segments
        } catch {
            print("Error loading segment profiles: \(error)")
        }
    }
}

// MARK: - Segment Profile (from JSON)

struct SegmentProfile: Codable {
    let displayName: String
    let icon: String
    let cyclicalityScore: Int
    let provenancePremium: Int
    let basePopularity: Int
    let peakMultiplier: Double
    let troughMultiplier: Double
    let topModels: [String]
    let description: String
}

private struct SegmentProfilesFile: Codable {
    let segments: [String: SegmentProfile]
}
