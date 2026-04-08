import SwiftUI
import CoreData

struct RiskInvestorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \VehicleEntity.year, ascending: false)]
    )
    private var vehicles: FetchedResults<VehicleEntity>
    
    @State private var portfolioRisk: PortfolioRisk?
    @State private var vehicleScores: [(VehicleEntity, RiskScore)] = []
    @State private var selectedVehicle: VehicleEntity?
    @State private var showingScenario = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let risk = portfolioRisk {
                        portfolioOverviewSection(risk: risk)
                        diversificationSection(risk: risk)
                    }
                    
                    vehicleRiskSection
                }
                .padding()
            }
            .navigationTitle("Risk & Investor")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .onAppear { loadData() }
            .sheet(isPresented: $showingScenario) {
                if let vehicle = selectedVehicle {
                    ScenarioModelView(vehicle: vehicle)
                        .environment(\.managedObjectContext, viewContext)
                }
            }
        }
    }
    
    private func portfolioOverviewSection(risk: PortfolioRisk) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Portfolio Risk")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                RiskDimensionView(label: "Volatility", score: risk.averageRisk.volatility, color: .red)
                RiskDimensionView(label: "Liquidity", score: risk.averageRisk.liquidity, color: .blue)
                RiskDimensionView(label: "Cyclicality", score: risk.averageRisk.cyclicality, color: .orange)
                RiskDimensionView(label: "Provenance", score: risk.averageRisk.provenancePremium, color: .purple)
            }
            
            HStack {
                Text("Overall Risk Level")
                    .font(.subheadline)
                Spacer()
                Text(risk.averageRisk.riskLevel)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(riskLevelColor(risk.averageRisk.riskLevel))
            }
            .padding(.top, 4)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private func diversificationSection(risk: PortfolioRisk) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Diversification")
                    .font(.headline)
                Spacer()
                Text("\(risk.diversificationScore)/100")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(risk.diversificationScore > 60 ? .green : .orange)
            }
            
            if risk.concentrationRisk > 70 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("High concentration in single segment")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            ForEach(Array(risk.segmentBreakdown.sorted { $0.value > $1.value }), id: \.key) { segment, count in
                HStack {
                    Text(segment.capitalized)
                        .font(.subheadline)
                    Spacer()
                    Text("\(count)")
                        .fontWeight(.semibold)
                    
                    let pct = vehicles.count > 0 ? Double(count) / Double(vehicles.count) * 100 : 0
                    Text("(\(Int(pct))%)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private var vehicleRiskSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vehicle Risk Scores")
                .font(.headline)
            
            ForEach(vehicleScores, id: \.0.id) { vehicle, score in
                Button(action: {
                    selectedVehicle = vehicle
                    showingScenario = true
                }) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vehicle.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 8) {
                                ScorePill(label: "Vol", value: score.volatility, color: .red)
                                ScorePill(label: "Liq", value: score.liquidity, color: .blue)
                                ScorePill(label: "Cyc", value: score.cyclicality, color: .orange)
                                ScorePill(label: "Prv", value: score.provenancePremium, color: .purple)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Text("\(score.overallRisk)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(riskLevelColor(score.riskLevel))
                            Text(score.riskLevel)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func loadData() {
        portfolioRisk = RiskScoringEngine.shared.portfolioRisk(vehicles: Array(vehicles))
        vehicleScores = vehicles.map { ($0, RiskScoringEngine.shared.scoreVehicle($0)) }
    }
    
    private func riskLevelColor(_ level: String) -> Color {
        switch level {
        case "High": return .red
        case "Medium": return .orange
        default: return .green
        }
    }
}

struct RiskDimensionView: View {
    let label: String
    let score: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 50, height: 50)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100.0)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                Text("\(score)")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct ScorePill: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text("\(value)")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}
