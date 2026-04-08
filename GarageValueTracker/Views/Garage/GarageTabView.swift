import SwiftUI
import CoreData

struct GarageTabView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \VehicleEntity.year, ascending: false)],
        animation: .default
    )
    private var vehicles: FetchedResults<VehicleEntity>

    @State private var showingAddVehicle = false
    @State private var showingAddWatchlist = false
    @State private var showingSettings = false
    @State private var showingShareGarage = false
    @State private var showingMapTimeline = false

    private var totalValue: Double {
        vehicles.reduce(0) { $0 + $1.currentValue }
    }
    private var totalCost: Double {
        vehicles.reduce(0) { $0 + $1.purchasePrice }
    }
    private var totalGainLoss: Double { totalValue - totalCost }
    private var gainLossPercent: Double {
        guard totalCost > 0 else { return 0 }
        return (totalGainLoss / totalCost) * 100
    }
    private var isPositive: Bool { totalGainLoss >= 0 }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    GIQHeaderBar(trailing: {
                        AnyView(
                            HStack(spacing: 14) {
                                Button(action: { showingSettings = true }) {
                                    Image(systemName: "gearshape")
                                        .foregroundColor(GIQ.secondaryText)
                                }
                                Menu {
                                    Button(action: { showingAddVehicle = true }) {
                                        Label("Add Vehicle", systemImage: "car.fill")
                                    }
                                    Button(action: { showingAddWatchlist = true }) {
                                        Label("Add to Watchlist", systemImage: "eye")
                                    }
                                    Divider()
                                    Button(action: { showingMapTimeline = true }) {
                                        Label("Map Timeline", systemImage: "map")
                                    }
                                    Button(action: { showingShareGarage = true }) {
                                        Label("Share Garage", systemImage: "square.and.arrow.up")
                                    }
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(GIQ.accent)
                                }
                            }
                        )
                    })

                    if vehicles.isEmpty {
                        emptyState
                    } else {
                        portfolioHeader
                            .padding(.top, 20)
                            .padding(.horizontal)

                        compositionBar
                            .padding(.top, 12)
                            .padding(.horizontal)

                        vehicleList
                            .padding(.top, 16)

                        addButton
                            .padding(.top, 8)
                            .padding(.bottom, 24)
                    }
                }
            }
            .themeBackground()
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddVehicle) {
                AddVehicleView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingAddWatchlist) {
                AddWishlistVehicleView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingShareGarage) {
                ShareGarageView(vehicles: Array(vehicles))
            }
            .sheet(isPresented: $showingMapTimeline) {
                MapTimelineView(vehicle: nil)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    // MARK: - Portfolio Header

    private var portfolioHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PORTFOLIO VALUE")
                    .font(.mono(10, weight: .semibold))
                    .foregroundColor(GIQ.secondaryText)
                    .tracking(1.2)
                Text(giqCurrency(totalValue))
                    .font(.mono(36, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Total Gain")
                    .font(.mono(10, weight: .medium))
                    .foregroundColor(GIQ.secondaryText)
                Text("\(isPositive ? "+" : "")\(giqCurrency(abs(totalGainLoss)))")
                    .font(.mono(22, weight: .bold))
                    .foregroundColor(isPositive ? GIQ.gain : GIQ.loss)
                Text("\(isPositive ? "+" : "")\(gainLossPercent, specifier: "%.1f")% all time")
                    .font(.mono(11, weight: .medium))
                    .foregroundColor(isPositive ? GIQ.gain : GIQ.loss)
            }
        }
    }

    // MARK: - Composition Bar

    private var compositionBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(Array(vehicles.enumerated()), id: \.element.id) { idx, vehicle in
                        let share = totalValue > 0 ? vehicle.currentValue / totalValue : 1.0 / Double(vehicles.count)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(GIQ.segmentColors[idx % GIQ.segmentColors.count])
                            .frame(width: max(geo.size.width * CGFloat(share) - 2, 4))
                    }
                }
            }
            .frame(height: 8)

            HStack(spacing: 14) {
                ForEach(Array(vehicles.enumerated()), id: \.element.id) { idx, vehicle in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(GIQ.segmentColors[idx % GIQ.segmentColors.count])
                            .frame(width: 6, height: 6)
                        Text("\(vehicle.make) \(vehicle.model)")
                            .font(.mono(10, weight: .medium))
                            .foregroundColor(GIQ.secondaryText)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - Vehicle List

    private var vehicleList: some View {
        LazyVStack(spacing: 12) {
            ForEach(vehicles) { vehicle in
                NavigationLink(destination: VehicleDetailView(vehicle: vehicle)
                    .environment(\.managedObjectContext, viewContext)
                ) {
                    GarageVehicleCardView(vehicle: vehicle)
                        .environment(\.managedObjectContext, viewContext)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button(action: { showingAddVehicle = true }) {
            Text("+ Add Vehicle")
                .font(.mono(14, weight: .semibold))
                .foregroundColor(GIQ.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(GIQ.divider, lineWidth: 1)
                )
        }
        .padding(.horizontal)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 60)

            Image(systemName: "car.fill")
                .font(.system(size: 60))
                .foregroundColor(GIQ.accent)

            Text("Welcome to Garage IQ")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text("Add your first vehicle to start tracking")
                .font(.mono(14))
                .foregroundColor(GIQ.secondaryText)

            HStack(spacing: 12) {
                Button(action: { showingAddVehicle = true }) {
                    Text("Add Vehicle")
                        .font(.mono(14, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(GIQ.accent)
                        .cornerRadius(12)
                }

                Button(action: { showingAddWatchlist = true }) {
                    Text("Add Watchlist")
                        .font(.mono(14, weight: .semibold))
                        .foregroundColor(GIQ.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(GIQ.accent, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}
