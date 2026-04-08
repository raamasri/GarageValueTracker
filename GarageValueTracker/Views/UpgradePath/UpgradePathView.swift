import SwiftUI

struct UpgradePathView: View {
    let vehicle: VehicleEntity?
    
    @State private var budget = ""
    @State private var suggestions: [UpgradeSuggestion] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let vehicle = vehicle {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Vehicle")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text(vehicle.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            let formatter = NumberFormatter()
                            Text("Estimated Value: \({ formatter.numberStyle = .currency; formatter.maximumFractionDigits = 0; return formatter.string(from: NSNumber(value: vehicle.currentValue)) ?? "" }())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Additional Budget")
                            .font(.headline)
                        TextField("How much more can you spend?", text: $budget)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                        
                        Button(action: generateSuggestions) {
                            Text("Find Upgrades")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    
                    ForEach(suggestions) { suggestion in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(suggestion.name)
                                .font(.headline)
                            Text(suggestion.segment.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .clipShape(Capsule())
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Est. Value")
                                        .font(.caption).foregroundColor(.secondary)
                                    let formatter = NumberFormatter()
                                    Text({
                                        formatter.numberStyle = .currency
                                        formatter.maximumFractionDigits = 0
                                        return formatter.string(from: NSNumber(value: suggestion.estimatedValue)) ?? ""
                                    }())
                                        .fontWeight(.bold)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Depreciation")
                                        .font(.caption).foregroundColor(.secondary)
                                    Text(String(format: "%.0f%%/yr", suggestion.annualDepreciation))
                                        .fontWeight(.semibold)
                                        .foregroundColor(suggestion.annualDepreciation < 10 ? .green : .orange)
                                }
                            }
                            
                            Text(suggestion.rationale)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                }
                .padding()
            }
            .navigationTitle("Upgrade Path")
        }
    }
    
    private func generateSuggestions() {
        let currentValue = vehicle?.currentValue ?? 0
        let additionalBudget = Double(budget) ?? 0
        let totalBudget = currentValue + additionalBudget
        let currentSegment = vehicle?.resolvedSegment ?? "sedan"
        
        let upgrades: [(String, String, Int, String, String)] = [
            ("Toyota 4Runner", "suv", 2022, "Exceptional value retention. SUVs in this category rarely depreciate more than 6-8% annually.", "suv"),
            ("Porsche Cayman", "sports", 2020, "Strong collector appeal. Manual examples are appreciating in many markets.", "sports"),
            ("Toyota Tacoma", "truck", 2023, "Trucks hold value extremely well, especially in southern and western markets.", "truck"),
            ("Lexus IS", "luxury", 2022, "Luxury reliability. Lower depreciation than German competitors.", "luxury"),
            ("Tesla Model 3", "ev", 2023, "EV market is volatile but stabilizing. Good entry point if battery health is verified.", "ev")
        ]
        
        suggestions = upgrades.compactMap { name, segment, year, rationale, seg in
            let val = ValuationEngine.shared.valuate(
                make: name.components(separatedBy: " ").first ?? "",
                model: name.components(separatedBy: " ").dropFirst().joined(separator: " "),
                year: year, mileage: (2026 - year) * 12000
            )
            
            guard val.mid <= totalBudget * 1.2 else { return nil }
            guard segment != currentSegment else { return nil }
            
            return UpgradeSuggestion(
                name: "\(year) \(name)",
                segment: seg,
                estimatedValue: val.mid,
                annualDepreciation: val.baseMSRP > 0 ? ((val.baseMSRP - val.mid) / val.baseMSRP / Double(2026 - year)) * 100 : 10,
                rationale: rationale
            )
        }
    }
}

struct UpgradeSuggestion: Identifiable {
    let id = UUID()
    let name: String
    let segment: String
    let estimatedValue: Double
    let annualDepreciation: Double
    let rationale: String
}
