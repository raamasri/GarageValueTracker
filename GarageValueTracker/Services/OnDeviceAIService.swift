import Foundation
import FoundationModels

@available(iOS 26, *)
@Observable
class OnDeviceAIService {
    static let shared = OnDeviceAIService()
    
    private(set) var isAvailable = false
    private(set) var unavailableReason: String?
    
    private init() {
        checkAvailability()
    }
    
    func checkAvailability() {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            isAvailable = true
            unavailableReason = nil
        case .unavailable(let reason):
            isAvailable = false
            switch reason {
            case .deviceNotEligible:
                unavailableReason = "Device not supported"
            case .appleIntelligenceNotEnabled:
                unavailableReason = "Enable Apple Intelligence in Settings"
            case .modelNotReady:
                unavailableReason = "Model downloading... check back soon"
            @unknown default:
                unavailableReason = "Unavailable"
            }
        @unknown default:
            isAvailable = false
            unavailableReason = "Unknown"
        }
    }
    
    // MARK: - Vehicle Signal Generation
    
    func generateVehicleSignal(
        vehicleName: String,
        make: String,
        model: String,
        year: Int,
        mileage: Int,
        trim: String?,
        segment: String,
        currentValue: Double,
        purchasePrice: Double,
        conditionTier: String,
        trend3m: Double,
        trend12m: Double,
        trend36m: Double,
        riskVolatility: Int,
        riskLiquidity: Int,
        costToHold12m: Double
    ) async -> String? {
        guard isAvailable else { return nil }
        
        let trimStr = trim ?? "base"
        let gainLoss = currentValue - purchasePrice
        let gainLossPercent = purchasePrice > 0 ? (gainLoss / purchasePrice) * 100 : 0
        
        let prompt = """
        You are an expert automotive market analyst writing a concise market signal for a vehicle owner. \
        Write 2-3 sentences of actionable insight. Be specific about the vehicle segment, market timing, and what the owner should do. \
        Use a confident, editorial tone.
        
        Vehicle: \(year) \(make) \(model) \(trimStr)
        Segment: \(segment)
        Mileage: \(mileage) miles
        Condition: \(conditionTier)
        Current estimated value: $\(Int(currentValue))
        Purchase price: $\(Int(purchasePrice))
        Gain/loss: \(gainLoss >= 0 ? "+" : "")\(String(format: "%.1f", gainLossPercent))%
        3-month trend: \(String(format: "%+.1f", trend3m))%
        12-month trend: \(String(format: "%+.1f", trend12m))%
        36-month trend: \(String(format: "%+.1f", trend36m))%
        Volatility score: \(riskVolatility)/100
        Liquidity score: \(riskLiquidity)/100
        Estimated cost to hold 12 more months: $\(Int(costToHold12m))
        """
        
        return await generate(prompt: prompt, instructions: "You are a concise automotive market analyst. Write short, actionable signals about vehicle values and timing. Never use bullet points. Maximum 3 sentences.")
    }
    
    // MARK: - Deal Analysis Insight
    
    func generateDealInsight(
        vehicleDescription: String,
        askingPrice: Double,
        fairValueLow: Double,
        fairValueMid: Double,
        fairValueHigh: Double,
        verdict: String,
        overallScore: Int,
        daysOnMarketEstimate: String,
        regionalContext: String?
    ) async -> String? {
        guard isAvailable else { return nil }
        
        let prompt = """
        You are evaluating a vehicle deal for a buyer. Give a concise 2-3 sentence verdict. \
        Be direct about whether this is a good buy and what the buyer should do next.
        
        Vehicle: \(vehicleDescription)
        Asking price: $\(Int(askingPrice))
        Fair value range: $\(Int(fairValueLow)) - $\(Int(fairValueMid)) - $\(Int(fairValueHigh))
        Verdict: \(verdict)
        Deal score: \(overallScore)/100
        Days on market estimate: \(daysOnMarketEstimate)
        \(regionalContext.map { "Regional context: \($0)" } ?? "")
        """
        
        return await generate(prompt: prompt, instructions: "You are a direct, no-nonsense car buying advisor. Give concise deal verdicts in 2-3 sentences. Include a specific action recommendation.")
    }
    
    // MARK: - Macro Market Context
    
    func generateMacroContext(
        segmentTrends: [(String, Double)],
        vehicleCount: Int,
        portfolioValue: Double,
        portfolioGainLoss: Double
    ) async -> String? {
        guard isAvailable else { return nil }
        
        let currentMonth = Calendar.current.component(.month, from: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        let dateStr = dateFormatter.string(from: Date())
        
        let trendsStr = segmentTrends.map { "\($0.0): \(String(format: "%+.1f", $0.1))% (12m)" }.joined(separator: ", ")
        
        let prompt = """
        Write a 4-5 sentence macro market context paragraph for a car enthusiast's portfolio app. \
        It is \(dateStr). Cover seasonal factors, broader market conditions, and what matters for car values right now. \
        Reference specific segments where relevant.
        
        Current month: \(currentMonth) (1=Jan, 12=Dec)
        Segment trends: \(trendsStr)
        User's portfolio: \(vehicleCount) vehicles worth $\(Int(portfolioValue)), \(portfolioGainLoss >= 0 ? "up" : "down") \(String(format: "%.1f", abs(portfolioGainLoss)))% overall
        """
        
        return await generate(prompt: prompt, instructions: "You are an automotive market analyst writing a monthly macro context note. Write in a confident editorial tone, like a financial newsletter. Reference specific data points. 4-5 sentences maximum.")
    }
    
    // MARK: - Scenario Narrative
    
    func generateScenarioNarrative(
        vehicleName: String,
        scenarioType: String,
        currentValue: Double,
        projectedValue: Double,
        yearsToProject: Int,
        annualizedReturn: Double,
        totalCosts: Double
    ) async -> String? {
        guard isAvailable else { return nil }
        
        let prompt = """
        Write a 2-sentence narrative summary of this scenario projection for a vehicle owner.
        
        Vehicle: \(vehicleName)
        Scenario: \(scenarioType)
        Current value: $\(Int(currentValue))
        Projected value in \(yearsToProject) years: $\(Int(projectedValue))
        Annualized return: \(String(format: "%.1f", annualizedReturn))%
        Total ownership costs over period: $\(Int(totalCosts))
        """
        
        return await generate(prompt: prompt, instructions: "You are a vehicle investment advisor. Write scenario summaries that are clear and actionable. 2 sentences maximum.")
    }
    
    // MARK: - Sell Advisor Narrative
    
    func generateSellAdvisorNarrative(
        vehicleName: String, currentValue: Double, purchasePrice: Double,
        equity: Double, monthlyDepreciation: Double, retainedPercent: Double,
        trend: String, loanBalance: Double?, sweetSpotMonths: Int?,
        costPerMonth: Double, segment: String
    ) async -> String? {
        guard isAvailable else { return nil }
        let loanStr = loanBalance.map { "Remaining loan balance: $\(Int($0))" } ?? "No loan"
        let sweetStr = sweetSpotMonths.map { "Optimal sell window: ~\($0) months from now" } ?? ""
        let prompt = """
        Write a 2-3 sentence sell/hold recommendation for this vehicle owner. Be specific about timing and reasoning.
        
        Vehicle: \(vehicleName)
        Segment: \(segment)
        Current value: $\(Int(currentValue)), Purchase price: $\(Int(purchasePrice))
        Equity: $\(Int(equity))
        \(loanStr)
        Value retained: \(String(format: "%.0f", retainedPercent))%
        Monthly depreciation: $\(Int(monthlyDepreciation))
        Value trend: \(trend)
        Monthly cost of ownership: $\(Int(costPerMonth))
        \(sweetStr)
        """
        return await generate(prompt: prompt, instructions: "You are a concise vehicle sell/hold advisor. Give a direct recommendation with specific timing. 2-3 sentences maximum.")
    }
    
    // MARK: - Maintenance Insights Narrative
    
    func generateMaintenanceNarrative(
        vehicleName: String, make: String, mileage: Int,
        yearlyAverage: Double, typicalYearly: Double, comparisonStatus: String,
        upcomingServices: [String], costTrend: String, totalSpent: Double
    ) async -> String? {
        guard isAvailable else { return nil }
        let upcomingStr = upcomingServices.isEmpty ? "None imminent" : upcomingServices.joined(separator: ", ")
        let prompt = """
        Write a 3-4 sentence maintenance insight for this vehicle owner. Cover their spending pattern, what's coming up, and what to prioritize.
        
        Vehicle: \(vehicleName) (\(make))
        Mileage: \(mileage) miles
        Yearly maintenance spend: $\(Int(yearlyAverage)) (typical for \(make): $\(Int(typicalYearly)))
        Comparison: \(comparisonStatus)
        Cost trend: \(costTrend)
        Total spent so far: $\(Int(totalSpent))
        Upcoming services: \(upcomingStr)
        """
        return await generate(prompt: prompt, instructions: "You are a vehicle maintenance advisor. Be specific about the make/model. Prioritize actionable advice about upcoming service needs. 3-4 sentences.")
    }
    
    // MARK: - Quality Score Narrative
    
    func generateQualityNarrative(
        vehicleName: String, overallScore: Int,
        hasAccidents: Bool, mileage: Int, age: Int,
        condition: String, segment: String
    ) async -> String? {
        guard isAvailable else { return nil }
        let prompt = """
        Write a 2-3 sentence quality assessment summary for this vehicle. Highlight the biggest value drivers and any concerns.
        
        Vehicle: \(vehicleName)
        Quality score: \(overallScore)/100
        Segment: \(segment)
        Age: \(age) years, Mileage: \(mileage) miles
        Condition tier: \(condition)
        Accident history: \(hasAccidents ? "Yes" : "Clean — no accidents")
        """
        return await generate(prompt: prompt, instructions: "You are a vehicle quality assessor. Be specific about what drives the score up or down. 2-3 sentences.")
    }
    
    // MARK: - Known Issues Narrative
    
    func generateKnownIssuesNarrative(
        vehicleName: String, make: String, model: String, year: Int,
        mileage: Int, issues: [String]
    ) async -> String? {
        guard isAvailable else { return nil }
        let issuesStr = issues.isEmpty ? "No known issues found" : issues.joined(separator: "; ")
        let prompt = """
        Write a 2-3 sentence summary of the known issues for this vehicle. Contextualize which ones are relevant at the owner's current mileage.
        
        Vehicle: \(year) \(make) \(model)
        Current mileage: \(mileage) miles
        Known issues: \(issuesStr)
        """
        return await generate(prompt: prompt, instructions: "You are an automotive reliability expert. Contextualize known issues based on the specific mileage and model year. Reassure when appropriate. 2-3 sentences.")
    }
    
    // MARK: - Watchlist Insight
    
    func generateWatchlistInsight(
        vehicleName: String, targetPrice: Double, marketMid: Double,
        vsTarget: Double, segment: String
    ) async -> String? {
        guard isAvailable else { return nil }
        let prompt = """
        Write a 1-2 sentence watchlist insight for a potential buyer tracking this vehicle.
        
        Vehicle: \(vehicleName)
        Segment: \(segment)
        Target price: $\(Int(targetPrice))
        Current market mid: $\(Int(marketMid))
        Difference from target: \(vsTarget >= 0 ? "+" : "")$\(Int(vsTarget))
        """
        return await generate(prompt: prompt, instructions: "You are a brief car buying advisor. One to two sentences about whether to wait or act. Be direct.")
    }
    
    // MARK: - Free-form Question
    
    func askQuestion(about vehicleContext: String, question: String) async -> String? {
        guard isAvailable else { return nil }
        
        let prompt = """
        Context about the user's vehicle:
        \(vehicleContext)
        
        User's question: \(question)
        """
        
        return await generate(prompt: prompt, instructions: "You are a knowledgeable automotive advisor embedded in a garage management app. Answer questions concisely and specifically based on the vehicle context provided. If you don't know something specific, say so rather than guessing. Keep answers to 3-5 sentences unless the question requires more detail.")
    }
    
    // MARK: - Core Generation
    
    private func generate(prompt: String, instructions: String) async -> String? {
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            print("On-device AI generation failed: \(error)")
            return nil
        }
    }
}

// MARK: - Fallback wrapper for pre-iOS 26

class AIServiceWrapper {
    static let shared = AIServiceWrapper()
    
    private var _service: AnyObject?
    
    var isAvailable: Bool {
        if #available(iOS 26, *) {
            return (service as? OnDeviceAIService)?.isAvailable ?? false
        }
        return false
    }
    
    var unavailableReason: String? {
        if #available(iOS 26, *) {
            return (service as? OnDeviceAIService)?.unavailableReason
        }
        return "Requires iOS 26+"
    }
    
    private var service: AnyObject? {
        if _service == nil {
            if #available(iOS 26, *) {
                _service = OnDeviceAIService.shared
            }
        }
        return _service
    }
    
    func generateVehicleSignal(
        vehicleName: String, make: String, model: String, year: Int, mileage: Int,
        trim: String?, segment: String, currentValue: Double, purchasePrice: Double,
        conditionTier: String, trend3m: Double, trend12m: Double, trend36m: Double,
        riskVolatility: Int, riskLiquidity: Int, costToHold12m: Double
    ) async -> String? {
        if #available(iOS 26, *), let svc = service as? OnDeviceAIService {
            return await svc.generateVehicleSignal(
                vehicleName: vehicleName, make: make, model: model, year: year,
                mileage: mileage, trim: trim, segment: segment, currentValue: currentValue,
                purchasePrice: purchasePrice, conditionTier: conditionTier,
                trend3m: trend3m, trend12m: trend12m, trend36m: trend36m,
                riskVolatility: riskVolatility, riskLiquidity: riskLiquidity,
                costToHold12m: costToHold12m
            )
        }
        return nil
    }
    
    func generateDealInsight(
        vehicleDescription: String, askingPrice: Double,
        fairValueLow: Double, fairValueMid: Double, fairValueHigh: Double,
        verdict: String, overallScore: Int, daysOnMarketEstimate: String,
        regionalContext: String?
    ) async -> String? {
        if #available(iOS 26, *), let svc = service as? OnDeviceAIService {
            return await svc.generateDealInsight(
                vehicleDescription: vehicleDescription, askingPrice: askingPrice,
                fairValueLow: fairValueLow, fairValueMid: fairValueMid,
                fairValueHigh: fairValueHigh, verdict: verdict,
                overallScore: overallScore, daysOnMarketEstimate: daysOnMarketEstimate,
                regionalContext: regionalContext
            )
        }
        return nil
    }
    
    func generateMacroContext(
        segmentTrends: [(String, Double)], vehicleCount: Int,
        portfolioValue: Double, portfolioGainLoss: Double
    ) async -> String? {
        if #available(iOS 26, *), let svc = service as? OnDeviceAIService {
            return await svc.generateMacroContext(
                segmentTrends: segmentTrends, vehicleCount: vehicleCount,
                portfolioValue: portfolioValue, portfolioGainLoss: portfolioGainLoss
            )
        }
        return nil
    }
    
    func generateScenarioNarrative(
        vehicleName: String, scenarioType: String, currentValue: Double,
        projectedValue: Double, yearsToProject: Int, annualizedReturn: Double,
        totalCosts: Double
    ) async -> String? {
        if #available(iOS 26, *), let svc = service as? OnDeviceAIService {
            return await svc.generateScenarioNarrative(
                vehicleName: vehicleName, scenarioType: scenarioType,
                currentValue: currentValue, projectedValue: projectedValue,
                yearsToProject: yearsToProject, annualizedReturn: annualizedReturn,
                totalCosts: totalCosts
            )
        }
        return nil
    }
    
    func askQuestion(about vehicleContext: String, question: String) async -> String? {
        if #available(iOS 26, *), let svc = service as? OnDeviceAIService {
            return await svc.askQuestion(about: vehicleContext, question: question)
        }
        return nil
    }
    
    func generateSellAdvisorNarrative(
        vehicleName: String, currentValue: Double, purchasePrice: Double,
        equity: Double, monthlyDepreciation: Double, retainedPercent: Double,
        trend: String, loanBalance: Double?, sweetSpotMonths: Int?,
        costPerMonth: Double, segment: String
    ) async -> String? {
        if #available(iOS 26, *), let svc = service as? OnDeviceAIService {
            return await svc.generateSellAdvisorNarrative(
                vehicleName: vehicleName, currentValue: currentValue,
                purchasePrice: purchasePrice, equity: equity,
                monthlyDepreciation: monthlyDepreciation, retainedPercent: retainedPercent,
                trend: trend, loanBalance: loanBalance, sweetSpotMonths: sweetSpotMonths,
                costPerMonth: costPerMonth, segment: segment
            )
        }
        return nil
    }
    
    func generateMaintenanceNarrative(
        vehicleName: String, make: String, mileage: Int,
        yearlyAverage: Double, typicalYearly: Double, comparisonStatus: String,
        upcomingServices: [String], costTrend: String, totalSpent: Double
    ) async -> String? {
        if #available(iOS 26, *), let svc = service as? OnDeviceAIService {
            return await svc.generateMaintenanceNarrative(
                vehicleName: vehicleName, make: make, mileage: mileage,
                yearlyAverage: yearlyAverage, typicalYearly: typicalYearly,
                comparisonStatus: comparisonStatus, upcomingServices: upcomingServices,
                costTrend: costTrend, totalSpent: totalSpent
            )
        }
        return nil
    }
    
    func generateQualityNarrative(
        vehicleName: String, overallScore: Int,
        hasAccidents: Bool, mileage: Int, age: Int,
        condition: String, segment: String
    ) async -> String? {
        if #available(iOS 26, *), let svc = service as? OnDeviceAIService {
            return await svc.generateQualityNarrative(
                vehicleName: vehicleName, overallScore: overallScore,
                hasAccidents: hasAccidents, mileage: mileage, age: age,
                condition: condition, segment: segment
            )
        }
        return nil
    }
    
    func generateKnownIssuesNarrative(
        vehicleName: String, make: String, model: String, year: Int,
        mileage: Int, issues: [String]
    ) async -> String? {
        if #available(iOS 26, *), let svc = service as? OnDeviceAIService {
            return await svc.generateKnownIssuesNarrative(
                vehicleName: vehicleName, make: make, model: model,
                year: year, mileage: mileage, issues: issues
            )
        }
        return nil
    }
    
    func generateWatchlistInsight(
        vehicleName: String, targetPrice: Double, marketMid: Double,
        vsTarget: Double, segment: String
    ) async -> String? {
        if #available(iOS 26, *), let svc = service as? OnDeviceAIService {
            return await svc.generateWatchlistInsight(
                vehicleName: vehicleName, targetPrice: targetPrice,
                marketMid: marketMid, vsTarget: vsTarget, segment: segment
            )
        }
        return nil
    }
}
