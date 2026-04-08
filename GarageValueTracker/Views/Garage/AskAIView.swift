import SwiftUI

struct AskAIView: View {
    let vehicle: VehicleEntity
    @Environment(\.presentationMode) var presentationMode

    @State private var question = ""
    @State private var conversations: [(question: String, answer: String)] = []
    @State private var isThinking = false
    @State private var aiAvailable = AIServiceWrapper.shared.isAvailable
    @State private var liveMarketContext: String = ""

    private var vehicleContext: String {
        let val = ValuationEngine.shared.valuate(
            make: vehicle.make, model: vehicle.model,
            year: Int(vehicle.year), mileage: Int(vehicle.mileage),
            trim: vehicle.trim, condition: vehicle.conditionTier
        )
        let risk = RiskScoringEngine.shared.scoreVehicle(vehicle)
        let segment = vehicle.resolvedSegment

        return """
        Vehicle: \(vehicle.displayName)
        Year: \(vehicle.year), Make: \(vehicle.make), Model: \(vehicle.model)
        Trim: \(vehicle.trim ?? "N/A")
        Segment: \(segment)
        Mileage: \(vehicle.mileage) miles
        Condition: \(vehicle.conditionTier.rawValue)
        Purchase price: $\(Int(vehicle.purchasePrice))
        Current estimated value: $\(Int(val.mid)) (range: $\(Int(val.low)) - $\(Int(val.high)))
        Gain/loss: \(val.mid - vehicle.purchasePrice >= 0 ? "+" : "")$\(Int(val.mid - vehicle.purchasePrice))
        Volatility: \(risk.volatility)/100, Liquidity: \(risk.liquidity)/100
        VIN: \(vehicle.vin ?? "Unknown")
        Location: \(vehicle.location ?? "Unknown")
        \(liveMarketContext)
        """
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !aiAvailable {
                            unavailableCard
                        }

                        if conversations.isEmpty {
                            suggestionsView
                        }

                        ForEach(Array(conversations.enumerated()), id: \.offset) { _, conv in
                            ConversationBubble(question: conv.question, answer: conv.answer)
                        }

                        if isThinking {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(GIQ.accent)
                                Text("Thinking...")
                                    .font(.mono(13))
                                    .foregroundColor(GIQ.secondaryText)
                            }
                            .padding()
                        }
                    }
                    .padding()
                }

                Divider().background(GIQ.divider)

                inputBar
            }
            .themeBackground()
            .navigationTitle("Ask AI")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadLiveContext() }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(GIQ.accent)
                }
            }
        }
    }

    private var unavailableCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("On-Device AI Unavailable")
                    .font(.mono(12, weight: .semibold))
                    .foregroundColor(.white)
                Text(AIServiceWrapper.shared.unavailableReason ?? "Requires iOS 26+ with Apple Intelligence")
                    .font(.mono(11))
                    .foregroundColor(GIQ.secondaryText)
            }
        }
        .themeCard(border: .yellow.opacity(0.3))
    }

    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ask anything about your \(vehicle.make) \(vehicle.model)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            let suggestions = [
                "When is the best time to sell this car?",
                "What maintenance should I prioritize at \(vehicle.mileage) miles?",
                "How does this compare to similar cars in the market?",
                "What are common issues with this model?",
                "Is this car likely to appreciate or depreciate?"
            ]

            ForEach(suggestions, id: \.self) { suggestion in
                Button(action: {
                    question = suggestion
                    ask()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundColor(GIQ.accent)
                        Text(suggestion)
                            .font(.mono(13))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(GIQ.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(GIQ.divider, lineWidth: 1)
                    )
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask about your vehicle...", text: $question)
                .font(.mono(14))
                .foregroundColor(.white)
                .padding(10)
                .background(GIQ.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Button(action: ask) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(question.isEmpty || isThinking ? GIQ.secondaryText : GIQ.accent)
            }
            .disabled(question.isEmpty || isThinking)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(GIQ.background)
    }

    private func ask() {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        question = ""
        isThinking = true

        Task {
            let answer: String
            if let aiAnswer = await AIServiceWrapper.shared.askQuestion(about: vehicleContext, question: q) {
                answer = aiAnswer
            } else {
                answer = generateFallbackAnswer(for: q)
            }

            await MainActor.run {
                conversations.append((question: q, answer: answer))
                isThinking = false
            }
        }
    }

    private func loadLiveContext() async {
        var parts: [String] = []

        if MarketCheckService.shared.isConfigured {
            if let stats = await MarketCheckService.shared.getMarketStats(
                make: vehicle.make, model: vehicle.model, year: Int(vehicle.year)
            ) {
                parts.append("LIVE MARKET DATA: \(stats.listingCount) active listings found. Median asking price: $\(Int(stats.medianPrice)). Range: $\(Int(stats.lowPrice)) - $\(Int(stats.highPrice)).")
                if let dom = stats.averageDaysOnMarket {
                    parts.append("Average days on market: \(dom).")
                }
            }
        }

        if let summary = await NHTSAComplaintsService.shared.getComplaintSummary(
            make: vehicle.make, model: vehicle.model, modelYear: Int(vehicle.year)
        ) {
            parts.append("NHTSA COMPLAINTS: \(summary.totalComplaints) owner complaints filed. \(summary.crashRelated) crash-related. Top components: \(summary.topComponents.prefix(3).map { "\($0.component) (\($0.count))" }.joined(separator: ", ")).")
        }

        await MainActor.run {
            liveMarketContext = parts.joined(separator: "\n")
        }
    }

    private func generateFallbackAnswer(for question: String) -> String {
        let lower = question.lowercased()
        if lower.contains("sell") || lower.contains("time") {
            return "Based on the current valuation model, your \(vehicle.displayName) is in a \(vehicle.resolvedSegment) segment. Check the AI Signal on the vehicle detail page for a specific hold/sell recommendation based on seasonality, mileage milestones, and depreciation trajectory."
        }
        if lower.contains("maintain") || lower.contains("maintenance") {
            return "At \(vehicle.mileage) miles, prioritize oil change, tire rotation, and brake inspection. Check your maintenance scheduler for vehicle-specific intervals."
        }
        if lower.contains("value") || lower.contains("worth") || lower.contains("depreciat") {
            let val = ValuationEngine.shared.valuate(
                make: vehicle.make, model: vehicle.model,
                year: Int(vehicle.year), mileage: Int(vehicle.mileage),
                trim: vehicle.trim, condition: vehicle.conditionTier
            )
            return "Your \(vehicle.displayName) is estimated at \(giqCurrency(val.mid)) (range: \(giqCurrency(val.low)) - \(giqCurrency(val.high))). This is based on segment depreciation curves, mileage, condition, and seasonal factors."
        }
        return "On-device AI is not available right now. Check that Apple Intelligence is enabled in Settings. In the meantime, explore the vehicle's AI Signal, Risk Profile, and Scenario tools for detailed insights."
    }
}

struct ConversationBubble: View {
    let question: String
    let answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Text(question)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(GIQ.accent.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundColor(GIQ.accent)
                    .padding(.top, 2)

                Text(answer)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(GIQ.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(GIQ.cardBorder, lineWidth: 1)
            )
        }
    }
}
