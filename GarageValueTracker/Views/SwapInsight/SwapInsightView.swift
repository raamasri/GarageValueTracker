import SwiftUI
import CoreData

struct SwapInsightView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let vehicle: VehicleEntity?
    
    @State private var targetMake = ""
    @State private var targetModel = ""
    @State private var targetYear = ""
    @State private var targetMileage = ""
    @State private var targetPrice = ""
    @State private var swapResult: SwapResult?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let vehicle = vehicle {
                        currentVehicleSection(vehicle)
                    }
                    
                    targetVehicleSection
                    
                    if let result = swapResult {
                        resultSection(result)
                    }
                    
                    analyzeButton
                }
                .padding()
            }
            .navigationTitle("Swap Insight")
        }
    }
    
    private func currentVehicleSection(_ vehicle: VehicleEntity) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Vehicle")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("\(vehicle.mileage) miles")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                let formatter = NumberFormatter()
                Text({
                    formatter.numberStyle = .currency
                    formatter.maximumFractionDigits = 0
                    return formatter.string(from: NSNumber(value: vehicle.currentValue)) ?? ""
                }())
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private var targetVehicleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Target Vehicle")
                .font(.headline)
                .foregroundColor(.secondary)
            
            TextField("Make", text: $targetMake)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            TextField("Model", text: $targetModel)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            HStack {
                TextField("Year", text: $targetYear)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                TextField("Mileage", text: $targetMileage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
            }
            TextField("Asking Price", text: $targetPrice)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.decimalPad)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private func resultSection(_ result: SwapResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Swap Analysis")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cash Needed")
                        .font(.caption).foregroundColor(.secondary)
                    let formatter = NumberFormatter()
                    Text({
                        formatter.numberStyle = .currency
                        formatter.maximumFractionDigits = 0
                        return formatter.string(from: NSNumber(value: result.cashNeeded)) ?? ""
                    }())
                        .font(.title3).fontWeight(.bold)
                        .foregroundColor(result.cashNeeded > 0 ? .red : .green)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Value Differential")
                        .font(.caption).foregroundColor(.secondary)
                    Text(String(format: "%+.0f%%", result.valueDifferentialPercent))
                        .font(.title3).fontWeight(.bold)
                }
            }
            
            Text(result.recommendation)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private var analyzeButton: some View {
        Button(action: analyze) {
            HStack {
                Image(systemName: "arrow.triangle.swap")
                Text("Analyze Swap")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canAnalyze ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(14)
        }
        .disabled(!canAnalyze)
    }
    
    private var canAnalyze: Bool {
        !targetMake.isEmpty && !targetModel.isEmpty && !targetYear.isEmpty && !targetPrice.isEmpty
    }
    
    private func analyze() {
        guard let year = Int(targetYear), let price = Double(targetPrice) else { return }
        let mileage = Int(targetMileage) ?? 0
        
        let targetValuation = ValuationEngine.shared.valuate(
            make: targetMake, model: targetModel, year: year, mileage: mileage
        )
        
        let currentValue = vehicle?.currentValue ?? 0
        let cashNeeded = price - currentValue
        let valueDiff = targetValuation.mid > 0 ? ((price - targetValuation.mid) / targetValuation.mid) * 100 : 0
        
        let rec: String
        if valueDiff < -10 {
            rec = "The target vehicle appears underpriced relative to market. This swap could be a strong financial move."
        } else if valueDiff > 10 {
            rec = "The target vehicle is priced above estimated market value. Consider negotiating before proceeding."
        } else {
            rec = "The target vehicle is fairly priced. The swap makes sense if it better fits your needs."
        }
        
        swapResult = SwapResult(
            cashNeeded: cashNeeded,
            valueDifferentialPercent: valueDiff,
            recommendation: rec
        )
    }
}

struct SwapResult {
    let cashNeeded: Double
    let valueDifferentialPercent: Double
    let recommendation: String
}
