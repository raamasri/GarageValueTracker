import SwiftUI
import SwiftData

struct GarageListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VehicleEntity.createdAt, order: .reverse)
    private var allVehicles: [VehicleEntity]
    
    private var vehicles: [VehicleEntity] {
        allVehicles.filter { $0.ownershipType == .owned }
    }
    
    @State private var showingAddVehicle = false
    
    var body: some View {
        NavigationStack {
            Group {
                if vehicles.isEmpty {
                    emptyStateView
                } else {
                    vehiclesList
                }
            }
            .navigationTitle("Garage")
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
                AddVehicleView(ownershipType: .owned)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "car.2")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)
            
            Text("No Vehicles Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Track your cars like assets. Add your first vehicle to see true P&L and timing insights.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showingAddVehicle = true
            } label: {
                Label("Add Vehicle", systemImage: "plus.circle.fill")
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
    
    private var vehiclesList: some View {
        List {
            ForEach(vehicles) { vehicle in
                NavigationLink(destination: VehicleDetailView(vehicle: vehicle)) {
                    VehicleRowView(vehicle: vehicle)
                }
            }
            .onDelete(perform: deleteVehicles)
        }
    }
    
    private func deleteVehicles(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(vehicles[index])
        }
    }
}

struct VehicleRowView: View {
    let vehicle: VehicleEntity
    @State private var valuation: ValuationEstimateResponse?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.displayName)
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        Label("\(formatMileage(vehicle.mileageCurrent))", systemImage: "gauge")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if let vin = vehicle.vin {
                            Text("VIN: \(String(vin.suffix(6)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                if let rec = valuation?.recommendation {
                    recommendationBadge(rec)
                }
            }
            
            // Market Data
            if let val = valuation {
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Market Value")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatCurrency(val.mid))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    if let purchasePrice = vehicle.purchasePrice {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Unrealized P&L")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            let pnl = val.mid - purchasePrice
                            Text(formatCurrency(pnl))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(pnl >= 0 ? .green : .red)
                        }
                    }
                    
                    if val.momentum90d != 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("90d Momentum")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f%%", val.momentum90d))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(val.momentum90d >= 0 ? .green : .red)
                        }
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
    
    private func recommendationBadge(_ recommendation: String) -> some View {
        let (text, color): (String, Color) = {
            switch recommendation {
            case "hold": return ("Hold", .green)
            case "consider_selling": return ("Consider Sell", .orange)
            case "strong_sell": return ("Strong Sell", .red)
            default: return (recommendation, .gray)
            }
        }()
        
        return Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
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
    GarageListView()
        .modelContainer(for: VehicleEntity.self, inMemory: true)
}

