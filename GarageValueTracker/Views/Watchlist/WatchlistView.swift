import SwiftUI
import SwiftData

struct WatchlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VehicleEntity.createdAt, order: .reverse)
    private var allVehicles: [VehicleEntity]
    
    private var watchlistVehicles: [VehicleEntity] {
        allVehicles.filter { $0.ownershipType == .watchlist }
    }
    
    @State private var showingAddVehicle = false
    
    var body: some View {
        NavigationStack {
            Group {
                if watchlistVehicles.isEmpty {
                    emptyStateView
                } else {
                    watchlistList
                }
            }
            .navigationTitle("Watchlist")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddVehicle = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddVehicle) {
                AddVehicleView(ownershipType: .watchlist)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.circle")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)
            
            Text("No Watchlist Items")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Track cars you want to buy. Get alerts when prices drop and see expected depreciation.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showingAddVehicle = true
            } label: {
                Label("Add to Watchlist", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var watchlistList: some View {
        List {
            ForEach(watchlistVehicles) { vehicle in
                NavigationLink(destination: WatchlistDetailView(vehicle: vehicle)) {
                    WatchlistRowView(vehicle: vehicle)
                }
            }
            .onDelete(perform: deleteVehicles)
        }
    }
    
    private func deleteVehicles(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(watchlistVehicles[index])
        }
    }
}

struct WatchlistRowView: View {
    let vehicle: VehicleEntity
    @State private var valuation: ValuationEstimateResponse?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.displayName)
                        .font(.headline)
                    
                    Label("\(formatMileage(vehicle.mileageCurrent))", systemImage: "gauge")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if vehicle.alertEnabled {
                    Image(systemName: "bell.fill")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }
            
            // Market Data
            if let val = valuation {
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Market Price")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatCurrency(val.mid))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    if let targetPrice = vehicle.targetPrice {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Target Price")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text(formatCurrency(targetPrice))
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                if val.mid <= targetPrice {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("3yr Depr. Est.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("~22%") // Mock data - would come from depreciation curves
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.vertical, 8)
        .task {
            await loadValuation()
        }
    }
    
    private func loadValuation() async {
        do {
            let request = ValuationEstimateRequest(
                vehicleId: vehicle.id.uuidString,
                mileage: vehicle.mileageCurrent,
                zip: vehicle.zip
            )
            valuation = try await MarketAPIService.shared.getValuationEstimate(request)
        } catch {
            print("Failed to load valuation: \(error)")
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
    
    private func formatMileage(_ mileage: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return "\(formatter.string(from: NSNumber(value: mileage)) ?? "0") mi"
    }
}

#Preview {
    WatchlistView()
        .modelContainer(for: VehicleEntity.self, inMemory: true)
}

