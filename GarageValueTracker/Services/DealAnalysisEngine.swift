import Foundation

class DealAnalysisEngine {
    static let shared = DealAnalysisEngine()
    
    private init() {}
    
    // MARK: - Main Analysis Method
    
    /// Analyze a potential vehicle purchase and return comprehensive deal analysis
    func analyzeDeal(
        make: String,
        model: String,
        year: Int,
        trim: String?,
        mileage: Int,
        askingPrice: Double,
        location: String? = nil,
        hasAccidentHistory: Bool = false,
        accidentSeverity: AccidentRecord.AccidentSeverity? = nil
    ) -> DealAnalysisResult {
        
        // Get trim data if available
        let trimData = trim != nil ? TrimDatabaseService.shared.getTrim(
            make: make,
            model: model,
            year: year,
            trimLevel: trim!
        ) : nil
        
        let baseMarketValue = trimData?.msrp ?? askingPrice
        
        // Calculate individual scores
        let priceResult = calculatePriceScore(
            askingPrice: askingPrice,
            marketValue: baseMarketValue,
            year: year
        )
        
        let mileageResult = calculateMileageScore(
            mileage: mileage,
            year: year
        )
        
        let conditionResult = calculateConditionScore(
            hasAccidentHistory: hasAccidentHistory,
            accidentSeverity: accidentSeverity
        )
        
        let marketResult = calculateMarketScore(
            make: make,
            model: model,
            location: location
        )
        
        // Calculate overall score (weighted average)
        let overallScore = calculateOverallScore(
            priceScore: priceResult.score,
            mileageScore: mileageResult.score,
            conditionScore: conditionResult.score,
            marketScore: marketResult.score
        )
        
        // Generate insights
        let insights = generateInsights(
            priceResult: priceResult,
            mileageResult: mileageResult,
            conditionResult: conditionResult,
            marketResult: marketResult,
            overallScore: overallScore
        )
        
        // Generate recommendation
        let recommendation = generateRecommendation(
            overallScore: overallScore,
            askingPrice: askingPrice
        )
        
        // Determine grade
        let grade: DealGrade
        switch overallScore {
        case 90...100: grade = .excellent
        case 75..<90: grade = .good
        case 60..<75: grade = .fair
        case 40..<60: grade = .belowAverage
        default: grade = .poor
        }
        
        return DealAnalysisResult(
            overallScore: overallScore,
            priceScore: priceResult.score,
            mileageScore: mileageResult.score,
            conditionScore: conditionResult.score,
            marketScore: marketResult.score,
            insights: insights,
            recommendation: recommendation,
            grade: grade,
            priceDifference: priceResult.percentDifference,
            expectedMileage: mileageResult.expectedMileage,
            mileageDifference: mileageResult.difference,
            accidentImpact: conditionResult.accidentImpact,
            locationAdjustment: marketResult.locationAdjustment
        )
    }
    
    // MARK: - Price Score Calculation
    
    private func calculatePriceScore(askingPrice: Double, marketValue: Double, year: Int) -> (score: Int, percentDifference: Double, insights: [String]) {
        
        // Adjust market value based on depreciation
        let currentYear = Calendar.current.component(.year, from: Date())
        let yearsOld = currentYear - year
        let depreciationRate = 0.15 // 15% per year average
        let adjustedMarketValue = marketValue * pow(1 - depreciationRate, Double(yearsOld))
        
        let difference = askingPrice - adjustedMarketValue
        let percentDifference = (difference / adjustedMarketValue) * 100
        
        var insights: [String] = []
        
        // Score calculation (inversely proportional to price difference)
        let score: Int
        if percentDifference <= -20 {
            score = 100
            insights.append("Exceptional price - \(Int(abs(percentDifference)))% below market!")
        } else if percentDifference <= -10 {
            score = 90
            insights.append("Great price - \(Int(abs(percentDifference)))% below market")
        } else if percentDifference <= -5 {
            score = 80
            insights.append("Good price - \(Int(abs(percentDifference)))% below market")
        } else if percentDifference <= 0 {
            score = 70
            insights.append("Fair price - at market value")
        } else if percentDifference <= 5 {
            score = 60
            insights.append("Slightly above market (+\(Int(percentDifference))%)")
        } else if percentDifference <= 10 {
            score = 40
            insights.append("Above market price (+\(Int(percentDifference))%)")
        } else if percentDifference <= 20 {
            score = 20
            insights.append("Significantly overpriced (+\(Int(percentDifference))%)")
        } else {
            score = 10
            insights.append("Extremely overpriced (+\(Int(percentDifference))%)")
        }
        
        return (score, percentDifference, insights)
    }
    
    // MARK: - Mileage Score Calculation
    
    private func calculateMileageScore(mileage: Int, year: Int) -> (score: Int, expectedMileage: Int, difference: Int, insights: [String]) {
        
        let currentYear = Calendar.current.component(.year, from: Date())
        let yearsOld = currentYear - year
        let averageMilesPerYear = 12000
        let expectedMileage = yearsOld * averageMilesPerYear
        
        let difference = mileage - expectedMileage
        let percentDifference = Double(difference) / Double(max(expectedMileage, 1)) * 100
        
        var insights: [String] = []
        
        let score: Int
        if percentDifference <= -40 {
            score = 100
            insights.append("Exceptionally low mileage (\(formatMileage(mileage)))")
        } else if percentDifference <= -20 {
            score = 90
            insights.append("Very low mileage for year")
        } else if percentDifference <= -10 {
            score = 80
            insights.append("Below average mileage")
        } else if percentDifference <= 10 {
            score = 70
            insights.append("Average mileage for year")
        } else if percentDifference <= 30 {
            score = 50
            insights.append("Above average mileage")
        } else if percentDifference <= 50 {
            score = 30
            insights.append("High mileage for year")
        } else {
            score = 10
            insights.append("Very high mileage (\(formatMileage(mileage)))")
        }
        
        return (score, expectedMileage, difference, insights)
    }
    
    // MARK: - Condition Score Calculation
    
    private func calculateConditionScore(hasAccidentHistory: Bool, accidentSeverity: AccidentRecord.AccidentSeverity?) -> (score: Int, accidentImpact: Double?, insights: [String]) {
        
        var insights: [String] = []
        var accidentImpact: Double? = nil
        
        let score: Int
        if !hasAccidentHistory {
            score = 100
            insights.append("Clean history - no reported accidents")
        } else if let severity = accidentSeverity {
            switch severity {
            case .minor:
                score = 85
                accidentImpact = 0.075
                insights.append("Minor accident history (-7.5% value impact)")
            case .moderate:
                score = 70
                accidentImpact = 0.15
                insights.append("Moderate accident history (-15% value impact)")
            case .major:
                score = 50
                accidentImpact = 0.25
                insights.append("Major accident history (-25% value impact)")
            case .structural:
                score = 30
                accidentImpact = 0.35
                insights.append("Structural damage history (-35% value impact)")
            }
        } else {
            score = 75
            accidentImpact = 0.10
            insights.append("Accident reported (severity unknown, -10% estimated)")
        }
        
        return (score, accidentImpact, insights)
    }
    
    // MARK: - Market Score Calculation
    
    private func calculateMarketScore(make: String, model: String, location: String?) -> (score: Int, locationAdjustment: Double?, insights: [String]) {
        
        var insights: [String] = []
        var locationAdjustment: Double? = nil
        
        // Popular makes get better resale
        let popularMakes = ["Toyota", "Honda", "Lexus", "Subaru", "Mazda"]
        let luxuryMakes = ["BMW", "Mercedes-Benz", "Audi", "Lexus", "Porsche"]
        
        var score = 70 // Base score
        
        if popularMakes.contains(make) {
            score += 15
            insights.append("\(make) has excellent resale value")
        } else if luxuryMakes.contains(make) {
            score += 10
            insights.append("\(make) luxury brand with strong market")
        }
        
        // Location-based adjustments (simplified)
        if let location = location {
            let locationLower = location.lowercased()
            
            // Trucks in certain regions
            if model.lowercased().contains("f-150") || model.lowercased().contains("silverado") ||
               model.lowercased().contains("ram") {
                if locationLower.contains("texas") || locationLower.contains("montana") ||
                   locationLower.contains("wyoming") {
                    score += 10
                    locationAdjustment = 0.15
                    insights.append("Trucks in high demand in this region (+15%)")
                }
            }
            
            // EVs in California
            if model.lowercased().contains("model") && make.lowercased().contains("tesla") {
                if locationLower.contains("california") || locationLower.contains("ca") {
                    score += 10
                    locationAdjustment = 0.20
                    insights.append("EVs command premium in California (+20%)")
                }
            }
        }
        
        score = min(score, 100)
        
        return (score, locationAdjustment, insights)
    }
    
    // MARK: - Overall Score Calculation
    
    private func calculateOverallScore(priceScore: Int, mileageScore: Int, conditionScore: Int, marketScore: Int) -> Int {
        // Weighted average
        let weighted = Double(priceScore) * 0.30 +
                      Double(mileageScore) * 0.25 +
                      Double(conditionScore) * 0.25 +
                      Double(marketScore) * 0.20
        
        return Int(weighted.rounded())
    }
    
    // MARK: - Insights Generation
    
    private func generateInsights(
        priceResult: (score: Int, percentDifference: Double, insights: [String]),
        mileageResult: (score: Int, expectedMileage: Int, difference: Int, insights: [String]),
        conditionResult: (score: Int, accidentImpact: Double?, insights: [String]),
        marketResult: (score: Int, locationAdjustment: Double?, insights: [String]),
        overallScore: Int
    ) -> [String] {
        
        var allInsights: [String] = []
        
        // Add all individual insights
        allInsights.append(contentsOf: priceResult.insights)
        allInsights.append(contentsOf: mileageResult.insights)
        allInsights.append(contentsOf: conditionResult.insights)
        allInsights.append(contentsOf: marketResult.insights)
        
        // Add summary insight
        if overallScore >= 85 {
            allInsights.append("Overall: This is an excellent opportunity!")
        } else if overallScore >= 70 {
            allInsights.append("Overall: This is a solid deal")
        } else if overallScore >= 55 {
            allInsights.append("Overall: Fair deal, negotiate if possible")
        } else {
            allInsights.append("Overall: Consider looking for better options")
        }
        
        return allInsights
    }
    
    // MARK: - Recommendation Generation
    
    private func generateRecommendation(overallScore: Int, askingPrice: Double) -> String {
        if overallScore >= 90 {
            return "Exceptional Deal! Don't hesitate - this is priced well below market with great fundamentals. Act quickly before someone else does."
        } else if overallScore >= 80 {
            return "Great Deal! This vehicle offers excellent value. The price and condition are both favorable. Recommended purchase."
        } else if overallScore >= 70 {
            return "Good Deal. This is a fair price for the vehicle's condition and mileage. Worth considering seriously."
        } else if overallScore >= 60 {
            return "Fair Deal. The price is reasonable but not exceptional. Try negotiating \(formatCurrency(askingPrice * 0.05)) lower."
        } else if overallScore >= 45 {
            return "Below Average. Significant concerns with price, mileage, or condition. Negotiate heavily or keep looking."
        } else {
            return "Poor Deal. Multiple red flags present. Unless you have specific reasons, we recommend continuing your search."
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatMileage(_ mileage: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: mileage)) ?? "\(mileage)") + " mi"
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
}

