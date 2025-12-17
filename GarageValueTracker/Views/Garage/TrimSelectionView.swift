import SwiftUI

struct TrimSelectionView: View {
    let make: String
    let model: String
    let year: Int
    @Binding var selectedTrim: TrimData?
    @Environment(\.presentationMode) var presentationMode
    
    @State private var availableTrims: [TrimData] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading trim options...")
                } else if availableTrims.isEmpty {
                    emptyStateView
                } else {
                    trimListView
                }
            }
            .navigationTitle("Select Trim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                if availableTrims.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Skip") {
                            selectedTrim = nil
                            presentationMode.wrappedValue.dismiss()
                        }
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
            Image(systemName: "car.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Trim Data Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Trim information for \(year) \(make) \(model) is not in our database yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Text("You can still add your vehicle without trim details.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }
    
    private var trimListView: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                VStack(spacing: 8) {
                    Text("\(year) \(make) \(model)")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Select your vehicle's trim level")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Trim cards
                ForEach(availableTrims, id: \.trimLevel) { trim in
                    TrimCard(
                        trim: trim,
                        isSelected: selectedTrim?.trimLevel == trim.trimLevel
                    )
                    .onTapGesture {
                        selectTrim(trim)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
    
    private func loadTrims() {
        isLoading = true
        
        // Simulate slight delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            availableTrims = TrimDatabaseService.shared.getTrims(
                make: make,
                model: model,
                year: year
            )
            isLoading = false
        }
    }
    
    private func selectTrim(_ trim: TrimData) {
        selectedTrim = trim
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Dismiss after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Trim Card Component
struct TrimCard: View {
    let trim: TrimData
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with trim name and price
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trim.trimLevel)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("MSRP")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(formattedPrice)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            // Features
            if !trim.features.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Key Features")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    ForEach(Array(trim.features.prefix(5)), id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Text(feature)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    if trim.features.count > 5 {
                        Text("+ \(trim.features.count - 5) more features")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 24)
                    }
                }
            }
            
            // Selection indicator
            if isSelected {
                HStack {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
    
    private var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: trim.msrp)) ?? "$\(Int(trim.msrp))"
    }
}

// MARK: - Preview
struct TrimSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        TrimSelectionView(
            make: "Toyota",
            model: "Camry",
            year: 2024,
            selectedTrim: .constant(nil)
        )
    }
}

