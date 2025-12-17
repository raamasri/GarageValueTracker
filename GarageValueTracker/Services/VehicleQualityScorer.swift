import Foundation
import CoreData

class VehicleQualityScorer {
    static let shared = VehicleQualityScorer()
    
    private init() {}
    
    // MARK: - Quality Score Calculation
    
    /// Calculate comprehensive quality score for a vehicle (300-850 range like credit score)
    func calculateQualityScore(for vehicle: VehicleEntity, costEntries: [CostEntryEntity]) -> QualityScoreResult {
        
        // Calculate individual components
        let maintenanceScore = calculateMaintenanceScore(costEntries: costEntries, vehicle: vehicle)
        let conditionScore = calculateConditionScore(vehicle: vehicle)
        let mileageScore = calculateMileageScore(vehicle: vehicle)
        let ageScore = calculateAgeScore(vehicle: vehicle)
        let costEfficiencyScore = calculateCostEfficiencyScore(costEntries: costEntries, vehicle: vehicle)
        let marketScore = calculateMarketDemandScore(vehicle: vehicle)
        
        // Calculate total (out of 850)
        let totalScore = maintenanceScore + conditionScore + mileageScore + ageScore + costEfficiencyScore + marketScore
        
        // Determine grade
        let grade = determineGrade(score: totalScore)
        
        // Generate insights
        let insights = generateInsights(
            maintenanceScore: maintenanceScore,
            conditionScore: conditionScore,
            mileageScore: mileageScore,
            costEfficiencyScore: costEfficiencyScore,
            vehicle: vehicle,
            costEntries: costEntries
        )
        
        return QualityScoreResult(
            totalScore: totalScore,
            grade: grade,
            maintenanceScore: maintenanceScore,
            conditionScore: conditionScore,
            mileageScore: mileageScore,
            ageScore: ageScore,
            costEfficiencyScore: costEfficiencyScore,
            marketScore: marketScore,
            insights: insights
        )
    }
    
    // MARK: - Component Calculations
    
    /// Maintenance History Score (max 250 points)
    private func calculateMaintenanceScore(costEntries: [CostEntryEntity], vehicle: VehicleEntity) -> Int {
        guard !costEntries.isEmpty else { return 150 } // Neutral score if no data
        
        let maintenanceEntries = costEntries.filter {
            $0.category == "Maintenance" || $0.category == "Repair"
        }
        
        // Calculate maintenance frequency
        let monthsOwned = max(Calendar.current.dateComponents([.month], from: vehicle.purchaseDate, to: Date()).month ?? 1, 1)
        let maintenancePerMonth = Double(maintenanceEntries.count) / Double(monthsOwned)
        
        var score = 125 // Base score
        
        // Regular maintenance gets bonus points
        if maintenancePerMonth >= 0.5 { // At least bi-monthly maintenance
            score += 100
        } else if maintenancePerMonth >= 0.33 { // Quarterly
            score += 75
        } else if maintenancePerMonth >= 0.25 { // Every 4 months
            score += 50
        } else {
            score += 25 // Minimal maintenance
        }
        
        // Recent maintenance bonus
        if let lastMaintenance = maintenanceEntries.first?.date {
            let daysSince = Calendar.current.dateComponents([.day], from: lastMaintenance, to: Date()).day ?? 999
            if daysSince <= 30 {
                score += 25 // Very recent
            } else if daysSince <= 90 {
                score += 15 // Recent
            }
        }
        
        return min(score, 250)
    }
    
    /// Condition Score (max 200 points)
    private func calculateConditionScore(vehicle: VehicleEntity) -> Int {
        var score = 200 // Start with perfect
        
        // Deduct for accidents
        if vehicle.hasAccidentHistory {
            let accidents = vehicle.accidentRecords
            for accident in accidents {
                switch accident.severity {
                case .minor:
                    score -= 30
                case .moderate:
                    score -= 60
                case .major:
                    score -= 100
                case .structural:
                    score -= 150
                }
            }
        }
        
        return max(score, 0)
    }
    
    /// Mileage Score (max 150 points)
    private func calculateMileageScore(vehicle: VehicleEntity) -> Int {
        let currentYear = Calendar.current.component(.year, from: Date())
        let yearsOld = currentYear - Int(vehicle.year)
        let expectedMileage = yearsOld * 12000
        
        let actualMileage = Int(vehicle.mileage)
        let difference = actualMileage - expectedMileage
        let percentDiff = Double(difference) / Double(max(expectedMileage, 1))
        
        var score: Int
        if percentDiff <= -0.4 { // 40% below average
            score = 150
        } else if percentDiff <= -0.2 { // 20% below
            score = 135
        } else if percentDiff <= -0.1 { // 10% below
            score = 120
        } else if percentDiff <= 0.1 { // Within 10%
            score = 105
        } else if percentDiff <= 0.3 { // 30% above
            score = 75
        } else if percentDiff <= 0.5 { // 50% above
            score = 45
        } else { // Very high mileage
            score = 15
        }
        
        return score
    }
    
    /// Age Score (max 100 points)
    private func calculateAgeScore(vehicle: VehicleEntity) -> Int {
        let currentYear = Calendar.current.component(.year, from: Date())
        let yearsOld = currentYear - Int(vehicle.year)
        
        var score: Int
        if yearsOld <= 2 {
            score = 100
        } else if yearsOld <= 5 {
            score = 85
        } else if yearsOld <= 8 {
            score = 70
        } else if yearsOld <= 12 {
            score = 50
        } else if yearsOld <= 15 {
            score = 30
        } else {
            score = 10
        }
        
        // Well-maintained older cars get bonus
        if yearsOld > 10 && !vehicle.hasAccidentHistory {
            score += 15
        }
        
        return min(score, 100)
    }
    
    /// Cost Efficiency Score (max 100 points)
    private func calculateCostEfficiencyScore(costEntries: [CostEntryEntity], vehicle: VehicleEntity) -> Int {
        guard !costEntries.isEmpty else { return 75 } // Neutral if no data
        
        let totalCosts = costEntries.reduce(0.0) { $0 + $1.amount }
        let monthsOwned = max(Calendar.current.dateComponents([.month], from: vehicle.purchaseDate, to: Date()).month ?? 1, 1)
        let costPerMonth = totalCosts / Double(monthsOwned)
        
        // Score based on monthly cost
        var score: Int
        if costPerMonth <= 50 {
            score = 100 // Very economical
        } else if costPerMonth <= 100 {
            score = 85 // Economical
        } else if costPerMonth <= 150 {
            score = 70 // Average
        } else if costPerMonth <= 250 {
            score = 50 // Above average
        } else if costPerMonth <= 400 {
            score = 30 // High
        } else {
            score = 10 // Very high
        }
        
        return score
    }
    
    /// Market Demand Score (max 50 points)
    private func calculateMarketDemandScore(vehicle: VehicleEntity) -> Int {
        let popularMakes = ["Toyota", "Honda", "Lexus", "Subaru", "Mazda"]
        let luxuryMakes = ["BMW", "Mercedes-Benz", "Audi", "Porsche", "Lexus"]
        
        var score = 25 // Base score
        
        if popularMakes.contains(vehicle.make) {
            score += 25 // Excellent resale
        } else if luxuryMakes.contains(vehicle.make) {
            score += 15 // Good resale
        } else {
            score += 10 // Average
        }
        
        return min(score, 50)
    }
    
    // MARK: - Grade Determination
    
    private func determineGrade(score: Int) -> QualityGrade {
        switch score {
        case 750...850: return .excellent
        case 650..<750: return .veryGood
        case 550..<650: return .good
        case 450..<550: return .fair
        default: return .poor
        }
    }
    
    // MARK: - Insights Generation
    
    private func generateInsights(
        maintenanceScore: Int,
        conditionScore: Int,
        mileageScore: Int,
        costEfficiencyScore: Int,
        vehicle: VehicleEntity,
        costEntries: [CostEntryEntity]
    ) -> [String] {
        var insights: [String] = []
        
        // Maintenance insights
        if maintenanceScore >= 225 {
            insights.append("Exceptional maintenance record")
        } else if maintenanceScore >= 200 {
            insights.append("Excellent maintenance history")
        } else if maintenanceScore < 150 {
            insights.append("Maintenance could be improved")
        }
        
        // Condition insights
        if conditionScore == 200 {
            insights.append("Perfect condition - no accidents")
        } else if conditionScore >= 150 {
            insights.append("Good condition with minor history")
        } else if conditionScore < 100 {
            insights.append("Condition concerns present")
        }
        
        // Mileage insights
        if mileageScore >= 135 {
            insights.append("Low mileage for vehicle age")
        } else if mileageScore < 75 {
            insights.append("High mileage for year")
        }
        
        // Cost efficiency insights
        if costEfficiencyScore >= 85 {
            insights.append("Very economical to maintain")
        } else if costEfficiencyScore < 50 {
            insights.append("Higher than average maintenance costs")
        }
        
        // Overall insight
        let totalCosts = costEntries.reduce(0.0) { $0 + $1.amount }
        let monthsOwned = max(Calendar.current.dateComponents([.month], from: vehicle.purchaseDate, to: Date()).month ?? 1, 1)
        insights.append("$\(Int(totalCosts / Double(monthsOwned)))/month average cost")
        
        return insights
    }
}

// MARK: - Result Structures

struct QualityScoreResult {
    let totalScore: Int // 300-850
    let grade: QualityGrade
    let maintenanceScore: Int // /250
    let conditionScore: Int // /200
    let mileageScore: Int // /150
    let ageScore: Int // /100
    let costEfficiencyScore: Int // /100
    let marketScore: Int // /50
    let insights: [String]
}

enum QualityGrade: String {
    case excellent = "Excellent"
    case veryGood = "Very Good"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .veryGood: return "blue"
        case .good: return "cyan"
        case .fair: return "yellow"
        case .poor: return "orange"
        }
    }
    
    var emoji: String {
        switch self {
        case .excellent: return "⭐"
        case .veryGood: return "✨"
        case .good: return "👍"
        case .fair: return "👌"
        case .poor: return "📉"
        }
    }
    
    var range: String {
        switch self {
        case .excellent: return "750-850"
        case .veryGood: return "650-749"
        case .good: return "550-649"
        case .fair: return "450-549"
        case .poor: return "300-449"
        }
    }
}

