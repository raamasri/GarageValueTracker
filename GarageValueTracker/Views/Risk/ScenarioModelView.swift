import SwiftUI
import Charts

struct ScenarioModelView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    let vehicle: VehicleEntity
    
    @State private var selectedScenario: ScenarioType = .hold
    @State private var yearsToProject = 3
    @State private var customRate = ""
    @State private var result: ScenarioResult?
    @State private var bullResult: ScenarioResult?
    @State private var bearResult: ScenarioResult?
    @State private var holdResult: ScenarioResult?
    @State private var aiNarrative: String?
    @State private var isGeneratingAI = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    vehicleHeader
                    scenarioPicker
                    
                    if selectedScenario == .custom {
                        customControls
                    }
                    
                    if bullResult != nil && bearResult != nil && holdResult != nil {
                        comparisonChart
                        resultDetails
                    }
                }
                .padding()
            }
            .navigationTitle("Scenario Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .onAppear { runAllScenarios() }
        }
    }
    
    private var vehicleHeader: some View {
        VStack(spacing: 4) {
            Text(vehicle.displayName)
                .font(.headline)
            
            let formatter = NumberFormatter()
            Text("Current Value: \({ formatter.numberStyle = .currency; formatter.maximumFractionDigits = 0; return formatter.string(from: NSNumber(value: vehicle.currentValue)) ?? "" }())")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var scenarioPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scenario")
                .font(.headline)
            
            HStack(spacing: 8) {
                ForEach(ScenarioType.allCases, id: \.self) { type in
                    Button(action: {
                        selectedScenario = type
                        if type != .custom { runAllScenarios() }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(.title3)
                            Text(type.displayName)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedScenario == type ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.08))
                        .cornerRadius(10)
                        .foregroundColor(selectedScenario == type ? .blue : .secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Stepper("Project \(yearsToProject) year\(yearsToProject == 1 ? "" : "s")", value: $yearsToProject, in: 1...10)
                .onChange(of: yearsToProject) { _ in runAllScenarios() }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private var customControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Annual Rate (%)")
                .font(.subheadline)
            
            HStack {
                TextField("e.g. -10 for depreciation, +5 for appreciation", text: $customRate)
                    .keyboardType(.numbersAndPunctuation)
                
                Button("Apply") { runAllScenarios() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private var comparisonChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Projected Value")
                .font(.headline)
            
            if #available(iOS 16.0, *), let bull = bullResult, let bear = bearResult, let hold = holdResult {
                Chart {
                    ForEach(bull.projectedValues) { pv in
                        LineMark(x: .value("Year", pv.year), y: .value("Value", pv.projectedValue))
                            .foregroundStyle(.green)
                    }
                    ForEach(hold.projectedValues) { pv in
                        LineMark(x: .value("Year", pv.year), y: .value("Value", pv.projectedValue))
                            .foregroundStyle(.blue)
                    }
                    ForEach(bear.projectedValues) { pv in
                        LineMark(x: .value("Year", pv.year), y: .value("Value", pv.projectedValue))
                            .foregroundStyle(.red)
                    }
                    
                    RuleMark(y: .value("Purchase Price", vehicle.purchasePrice))
                        .lineStyle(StrokeStyle(dash: [5, 5]))
                        .foregroundStyle(.gray)
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        if let v = value.as(Double.self) {
                            AxisValueLabel {
                                Text("$\(Int(v / 1000))k")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                
                HStack(spacing: 16) {
                    Label("Bull", systemImage: "circle.fill").font(.caption2).foregroundColor(.green)
                    Label("Hold", systemImage: "circle.fill").font(.caption2).foregroundColor(.blue)
                    Label("Bear", systemImage: "circle.fill").font(.caption2).foregroundColor(.red)
                    Label("Purchase", systemImage: "line.diagonal").font(.caption2).foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private var resultDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scenario Results")
                .font(.headline)
            
            if let activeResult = activeScenarioResult {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Final Value")
                            .font(.caption).foregroundColor(.secondary)
                        let finalVal = activeResult.projectedValues.last?.projectedValue ?? 0
                        Text(formatCurrency(finalVal))
                            .font(.title3).fontWeight(.bold)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Annualized Return")
                            .font(.caption).foregroundColor(.secondary)
                        Text(String(format: "%.1f%%", activeResult.annualizedReturn))
                            .font(.title3).fontWeight(.bold)
                            .foregroundColor(activeResult.annualizedReturn >= 0 ? .green : .red)
                    }
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Costs")
                            .font(.caption).foregroundColor(.secondary)
                        Text(formatCurrency(activeResult.totalCostOfOwnership))
                            .font(.subheadline).fontWeight(.semibold)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Net Equity Change")
                            .font(.caption).foregroundColor(.secondary)
                        Text(formatCurrency(activeResult.netEquityChange))
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(activeResult.netEquityChange >= 0 ? .green : .red)
                    }
                }
                
                if aiNarrative != nil || isGeneratingAI {
                    Divider()
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(Color(red: 0.83, green: 0.66, blue: 0.26))
                            .font(.system(size: 12))
                        if isGeneratingAI {
                            HStack(spacing: 6) {
                                ProgressView().scaleEffect(0.7)
                                Text("Generating insight...")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        } else if let narrative = aiNarrative {
                            Text(narrative)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private var activeScenarioResult: ScenarioResult? {
        switch selectedScenario {
        case .bull: return bullResult
        case .bear: return bearResult
        case .hold: return holdResult
        case .custom: return result
        }
    }
    
    private func runAllScenarios() {
        let baseParams = ScenarioParameters(
            yearsToProject: yearsToProject,
            annualMileage: 12000,
            annualMaintenanceCost: 1500,
            annualInsuranceCost: vehicle.insurancePremium
        )
        
        bullResult = RiskScoringEngine.shared.runScenario(vehicle: vehicle, type: .bull, parameters: baseParams)
        bearResult = RiskScoringEngine.shared.runScenario(vehicle: vehicle, type: .bear, parameters: baseParams)
        holdResult = RiskScoringEngine.shared.runScenario(vehicle: vehicle, type: .hold, parameters: baseParams)
        
        if selectedScenario == .custom, let rate = Double(customRate) {
            var customParams = baseParams
            if rate >= 0 {
                customParams.annualAppreciationRate = rate
            } else {
                customParams.annualDepreciationRate = abs(rate)
            }
            result = RiskScoringEngine.shared.runScenario(vehicle: vehicle, type: .custom, parameters: customParams)
        } else {
            result = activeScenarioResult
        }
        
        guard AIServiceWrapper.shared.isAvailable, let active = activeScenarioResult else { return }
        aiNarrative = nil
        isGeneratingAI = true
        let finalVal = active.projectedValues.last?.projectedValue ?? vehicle.currentValue
        Task {
            let narrative = await AIServiceWrapper.shared.generateScenarioNarrative(
                vehicleName: vehicle.displayName,
                scenarioType: selectedScenario.displayName,
                currentValue: vehicle.currentValue,
                projectedValue: finalVal,
                yearsToProject: yearsToProject,
                annualizedReturn: active.annualizedReturn,
                totalCosts: active.totalCostOfOwnership
            )
            await MainActor.run {
                aiNarrative = narrative
                isGeneratingAI = false
            }
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }
}
