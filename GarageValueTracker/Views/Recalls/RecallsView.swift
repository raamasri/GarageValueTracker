import SwiftUI

struct RecallsView: View {
    let vehicle: VehicleEntity
    @Environment(\.presentationMode) var presentationMode
    
    @State private var recalls: [RecallResult] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Checking for recalls...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("Could Not Check Recalls")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Try Again") { loadRecalls() }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if recalls.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("No Open Recalls")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Your \(vehicle.displayName) has no known recalls from NHTSA.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title2)
                                    .foregroundColor(.red)
                                VStack(alignment: .leading) {
                                    Text("\(recalls.count) Recall\(recalls.count == 1 ? "" : "s") Found")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Text("Source: NHTSA")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            
                            ForEach(Array(recalls.enumerated()), id: \.offset) { _, recall in
                                RecallCard(recall: recall)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Safety Recalls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear { loadRecalls() }
        }
    }
    
    private func loadRecalls() {
        isLoading = true
        errorMessage = nil
        
        RecallsAPIService.shared.getRecalls(
            make: vehicle.make,
            model: vehicle.model,
            modelYear: Int(vehicle.year)
        ) { result in
            isLoading = false
            switch result {
            case .success(let data):
                recalls = data
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct RecallCard: View {
    let recall: RecallResult
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: recall.parkIt ? "car.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(recall.parkIt ? .red : .orange)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recall.component)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 8) {
                        Text("Campaign: \(recall.campaignNumber)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if !recall.reportDate.isEmpty {
                            Text(recall.reportDate)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if recall.parkIt {
                        Text("DO NOT DRIVE -- Park immediately")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
                
                Spacer()
                
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    if !recall.summary.isEmpty {
                        RecallDetailSection(title: "Issue", text: recall.summary)
                    }
                    if !recall.consequence.isEmpty {
                        RecallDetailSection(title: "Risk", text: recall.consequence)
                    }
                    if !recall.remedy.isEmpty {
                        RecallDetailSection(title: "Fix", text: recall.remedy)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct RecallDetailSection: View {
    let title: String
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .textCase(.uppercase)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
