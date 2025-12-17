import SwiftUI

struct QualityScoreDetailView: View {
    let score: QualityScoreResult
    let vehicle: VehicleEntity
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Overall Score Card
                    VStack(spacing: 16) {
                        Text(score.grade.emoji)
                            .font(.system(size: 60))
                        
                        Text(score.grade.rawValue)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("\(score.totalScore)")
                            .font(.system(size: 72, weight: .bold))
                            .foregroundColor(gradeColor)
                        
                        Text("out of 850")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Range: \(score.grade.range)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    // Score Breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Score Breakdown")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        ScoreComponentView(
                            title: "Maintenance History",
                            score: score.maintenanceScore,
                            maxScore: 250,
                            color: .blue,
                            icon: "wrench.and.screwdriver"
                        )
                        
                        ScoreComponentView(
                            title: "Condition",
                            score: score.conditionScore,
                            maxScore: 200,
                            color: .green,
                            icon: "checkmark.shield"
                        )
                        
                        ScoreComponentView(
                            title: "Mileage",
                            score: score.mileageScore,
                            maxScore: 150,
                            color: .orange,
                            icon: "gauge"
                        )
                        
                        ScoreComponentView(
                            title: "Age",
                            score: score.ageScore,
                            maxScore: 100,
                            color: .purple,
                            icon: "calendar"
                        )
                        
                        ScoreComponentView(
                            title: "Cost Efficiency",
                            score: score.costEfficiencyScore,
                            maxScore: 100,
                            color: .cyan,
                            icon: "dollarsign.circle"
                        )
                        
                        ScoreComponentView(
                            title: "Market Demand",
                            score: score.marketScore,
                            maxScore: 50,
                            color: .pink,
                            icon: "chart.line.uptrend.xyaxis"
                        )
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    // Insights
                    if !score.insights.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                Text("Key Insights")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            
                            ForEach(score.insights, id: \.self) { insight in
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                    
                                    Text(insight)
                                        .font(.body)
                                    
                                    Spacer()
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                    
                    // How to Improve
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.green)
                            Text("How to Improve")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        ImprovementTip(
                            icon: "wrench",
                            tip: "Maintain regular service intervals to boost maintenance score"
                        )
                        
                        ImprovementTip(
                            icon: "shield.checkered",
                            tip: "Avoid accidents and document all repairs for condition score"
                        )
                        
                        ImprovementTip(
                            icon: "dollarsign.circle",
                            tip: "Track all costs to optimize efficiency and identify savings"
                        )
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Quality Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var gradeColor: Color {
        switch score.grade {
        case .excellent: return .green
        case .veryGood: return .blue
        case .good: return .cyan
        case .fair: return .yellow
        case .poor: return .orange
        }
    }
}

// MARK: - Score Component View
struct ScoreComponentView: View {
    let title: String
    let score: Int
    let maxScore: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(score)/\(maxScore)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(score) / CGFloat(maxScore), height: 8)
                        .cornerRadius(4)
                        .animation(.easeInOut(duration: 0.8), value: score)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Improvement Tip
struct ImprovementTip: View {
    let icon: String
    let tip: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 24)
            
            Text(tip)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

