import SwiftUI
import CoreData

struct TrimComparisonView: View {
    let vehicle: VehicleEntity
    @Environment(\.presentationMode) var presentationMode
    
    @State private var availableTrims: [TrimData] = []
    @State private var selectedTrim: TrimData?
    @State private var currentTrimData: TrimData?
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading trim data...")
                } else if availableTrims.isEmpty {
                    emptyStateView
                } else {
                    comparisonView
                }
            }
            .navigationTitle("Trim Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                loadTrims()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Comparison Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Trim comparison data is not available for this vehicle.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    private var comparisonView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Current trim section
                if let currentTrim = currentTrimData {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Trim")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        CurrentTrimCard(trim: currentTrim)
                    }
                    .padding(.horizontal)
                }
                
                // Picker for other trims
                VStack(alignment: .leading, spacing: 8) {
                    Text("Compare With")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal)
                    
                    Picker("Select Trim", selection: $selectedTrim) {
                        Text("Select a trim").tag(nil as TrimData?)
                        ForEach(availableTrims.filter { $0.trimLevel != vehicle.trim }, id: \.trimLevel) { trim in
                            Text("\(trim.trimLevel) - \(formatPrice(trim.msrp))").tag(trim as TrimData?)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal)
                }
                
                // Comparison details
                if let current = currentTrimData, let selected = selectedTrim {
                    ComparisonDetailView(
                        currentTrim: current,
                        comparedTrim: selected
                    )
                    .padding(.horizontal)
                }
                
                if selectedTrim == nil && currentTrimData != nil {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.up.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text("Select a trim above to see comparison")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 40)
                }
            }
            .padding(.vertical)
        }
    }
    
    private func loadTrims() {
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            availableTrims = TrimDatabaseService.shared.getTrims(
                make: vehicle.make,
                model: vehicle.model,
                year: Int(vehicle.year)
            )
            
            // Try to find current trim
            if let trimName = vehicle.trim {
                currentTrimData = TrimDatabaseService.shared.getTrim(
                    make: vehicle.make,
                    model: vehicle.model,
                    year: Int(vehicle.year),
                    trimLevel: trimName
                )
            }
            
            isLoading = false
        }
    }
    
    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "$\(Int(price))"
    }
}

// MARK: - Current Trim Card
struct CurrentTrimCard: View {
    let trim: TrimData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(trim.trimLevel)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text(formatPrice(trim.msrp))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            if !trim.features.isEmpty {
                Divider()
                
                Text("Included Features")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                ForEach(trim.features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text(feature)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "$\(Int(price))"
    }
}

// MARK: - Comparison Detail View
struct ComparisonDetailView: View {
    let currentTrim: TrimData
    let comparedTrim: TrimData
    
    private var priceDifference: Double {
        comparedTrim.msrp - currentTrim.msrp
    }
    
    private var addedFeatures: [String] {
        let currentSet = Set(currentTrim.features)
        let comparedSet = Set(comparedTrim.features)
        return Array(comparedSet.subtracting(currentSet))
    }
    
    private var removedFeatures: [String] {
        let currentSet = Set(currentTrim.features)
        let comparedSet = Set(comparedTrim.features)
        return Array(currentSet.subtracting(comparedSet))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Price difference card
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Price Difference")
                            .font(.headline)
                        
                        if priceDifference > 0 {
                            Text("\(comparedTrim.trimLevel) costs more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if priceDifference < 0 {
                            Text("\(comparedTrim.trimLevel) costs less")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Same price")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Text(formattedPriceDifference)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(priceDifference > 0 ? .red : (priceDifference < 0 ? .green : .primary))
                }
                
                // Visual comparison bar
                if priceDifference != 0 {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 8)
                                .cornerRadius(4)
                            
                            Rectangle()
                                .fill(priceDifference > 0 ? Color.red : Color.green)
                                .frame(width: barWidth(for: geometry.size.width), height: 8)
                                .cornerRadius(4)
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            // Features comparison
            if !addedFeatures.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                        Text("Additional Features in \(comparedTrim.trimLevel)")
                            .font(.headline)
                    }
                    
                    ForEach(addedFeatures, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Text(feature)
                                .font(.subheadline)
                        }
                        .padding(.leading, 8)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
            
            if !removedFeatures.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.orange)
                        Text("Features Not in \(comparedTrim.trimLevel)")
                            .font(.headline)
                    }
                    
                    ForEach(removedFeatures, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "minus")
                                .font(.caption)
                                .foregroundColor(.orange)
                            
                            Text(feature)
                                .font(.subheadline)
                        }
                        .padding(.leading, 8)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Summary
            VStack(spacing: 8) {
                Text("Summary")
                    .font(.headline)
                
                Text(summaryText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var formattedPriceDifference: String {
        let sign = priceDifference >= 0 ? "+" : ""
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        let amount = formatter.string(from: NSNumber(value: abs(priceDifference))) ?? "$\(Int(abs(priceDifference)))"
        return "\(sign)\(amount)"
    }
    
    private func barWidth(for totalWidth: CGFloat) -> CGFloat {
        let maxDiff = max(abs(priceDifference), 5000.0) // Min 5k for scale
        let percentage = min(abs(priceDifference) / maxDiff, 1.0)
        return totalWidth * CGFloat(percentage)
    }
    
    private var summaryText: String {
        if priceDifference > 0 {
            return "\(comparedTrim.trimLevel) adds \(formattedPriceDifference) and includes \(addedFeatures.count) additional feature\(addedFeatures.count == 1 ? "" : "s")."
        } else if priceDifference < 0 {
            return "\(comparedTrim.trimLevel) saves you \(formattedPriceDifference) but has \(removedFeatures.count) fewer feature\(removedFeatures.count == 1 ? "" : "s")."
        } else {
            return "Both trims have the same MSRP."
        }
    }
}

// MARK: - Preview
struct TrimComparisonView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let vehicle = VehicleEntity(context: context)
        vehicle.make = "Toyota"
        vehicle.model = "Camry"
        vehicle.year = 2024
        vehicle.trim = "LE"
        
        return TrimComparisonView(vehicle: vehicle)
    }
}

