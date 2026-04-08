import SwiftUI
import CoreData

struct WatchlistTabView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WishlistVehicleEntity.createdAt, ascending: false)],
        animation: .default
    )
    private var items: FetchedResults<WishlistVehicleEntity>

    @State private var showingAdd = false

    enum TargetStatus: String {
        case hit, near, above
    }

    private func status(for item: WishlistVehicleEntity) -> TargetStatus {
        guard item.targetPrice > 0 else { return .above }
        let val = ValuationEngine.shared.valuate(
            make: item.make, model: item.model,
            year: Int(item.year), mileage: Int(item.mileage), trim: item.trim
        )
        if val.mid <= item.targetPrice { return .hit }
        let diff = (val.mid - item.targetPrice) / item.targetPrice
        if diff <= 0.10 { return .near }
        return .above
    }

    private var grouped: [(TargetStatus, [WishlistVehicleEntity])] {
        var dict: [TargetStatus: [WishlistVehicleEntity]] = [.hit: [], .near: [], .above: []]
        for item in items {
            let s = status(for: item)
            dict[s, default: []].append(item)
        }
        var result: [(TargetStatus, [WishlistVehicleEntity])] = []
        if let hits = dict[.hit], !hits.isEmpty { result.append((.hit, hits)) }
        if let nears = dict[.near], !nears.isEmpty { result.append((.near, nears)) }
        if let aboves = dict[.above], !aboves.isEmpty { result.append((.above, aboves)) }
        return result
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GIQHeaderBar()

                    GIQSectionHeader(
                        label: "Watchlist",
                        headline: "Cars you're tracking"
                    )
                    .padding(.horizontal)

                    if items.isEmpty {
                        emptyState
                    } else {
                        ForEach(grouped, id: \.0.rawValue) { status, vehicles in
                            WatchlistGroup(status: status, vehicles: vehicles)
                        }
                    }

                    Button(action: { showingAdd = true }) {
                        Text("+ Add to Watchlist")
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

                    Spacer(minLength: 40)
                }
            }
            .themeBackground()
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAdd) {
                AddWishlistVehicleView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "eye.slash")
                .font(.system(size: 40))
                .foregroundColor(GIQ.secondaryText)
            Text("No cars on your watchlist yet")
                .font(.mono(14))
                .foregroundColor(GIQ.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Group

private struct WatchlistGroup: View {
    let status: WatchlistTabView.TargetStatus
    let vehicles: [WishlistVehicleEntity]

    private var statusLabel: String {
        switch status {
        case .hit: return "Target Hit!"
        case .near: return "Near Target"
        case .above: return "Above Target"
        }
    }

    private var statusColor: Color {
        switch status {
        case .hit: return GIQ.gain
        case .near: return .yellow
        case .above: return GIQ.loss
        }
    }

    private var statusIcon: String {
        switch status {
        case .hit: return "checkmark"
        case .near: return "circle.dotted"
        case .above: return "arrow.up"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(vehicles, id: \.id) { item in
                WatchlistCard(item: item, status: status, statusLabel: statusLabel, statusColor: statusColor, statusIcon: statusIcon)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Card

private struct WatchlistCard: View {
    let item: WishlistVehicleEntity
    let status: WatchlistTabView.TargetStatus
    let statusLabel: String
    let statusColor: Color
    let statusIcon: String

    @State private var marketMid: Double = 0
    @State private var aiInsight: String?

    private var vsTarget: Double {
        guard item.targetPrice > 0 else { return 0 }
        return marketMid - item.targetPrice
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 9, weight: .bold))
                    Text(statusLabel)
                        .font(.mono(10, weight: .heavy))
                        .tracking(0.3)
                }
                .foregroundColor(status == .above ? statusColor : .black)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(statusColor)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                Spacer()

                Text(item.createdAt, style: .relative)
                    .font(.mono(10))
                    .foregroundColor(GIQ.tertiaryText)
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(String(item.year)) \(item.make) \(item.model)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    if let trim = item.trim {
                        Text(trim)
                            .font(.mono(12))
                            .foregroundColor(GIQ.secondaryText)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Market Mid")
                        .font(.mono(9, weight: .medium))
                        .foregroundColor(GIQ.tertiaryText)
                    Text(giqCurrency(marketMid))
                        .font(.mono(20, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Target Price")
                        .font(.mono(9, weight: .medium))
                        .foregroundColor(GIQ.tertiaryText)
                    Text(giqCurrency(item.targetPrice))
                        .font(.mono(15, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text("Vs. Target")
                        .font(.mono(9, weight: .medium))
                        .foregroundColor(GIQ.tertiaryText)
                    HStack(spacing: 2) {
                        Image(systemName: vsTarget <= 0 ? "arrow.down" : "arrow.up")
                            .font(.system(size: 10))
                        Text(giqCurrency(abs(vsTarget)))
                            .font(.mono(15, weight: .bold))
                    }
                    .foregroundColor(vsTarget <= 0 ? GIQ.gain : GIQ.loss)
                }

                Spacer()

                if let url = item.listingURL, let link = URL(string: url) {
                    Link(destination: link) {
                        Text("View Listings")
                            .font(.mono(11, weight: .semibold))
                            .foregroundColor(GIQ.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(GIQ.accent, lineWidth: 1)
                            )
                    }
                }
            }
            
            if let insight = aiInsight {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(GIQ.accent)
                        .padding(.top, 2)
                    Text(insight)
                        .font(.mono(11))
                        .foregroundColor(GIQ.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .themeCard(border: statusColor.opacity(0.4))
        .onAppear {
            let val = ValuationEngine.shared.valuate(
                make: item.make, model: item.model,
                year: Int(item.year), mileage: Int(item.mileage), trim: item.trim
            )
            marketMid = val.mid
            
            guard AIServiceWrapper.shared.isAvailable, item.targetPrice > 0 else { return }
            let segment = LocationMarketService.shared.classifyVehicle(make: item.make, model: item.model)
            Task {
                let insight = await AIServiceWrapper.shared.generateWatchlistInsight(
                    vehicleName: item.displayName,
                    targetPrice: item.targetPrice,
                    marketMid: val.mid,
                    vsTarget: val.mid - item.targetPrice,
                    segment: segment
                )
                await MainActor.run { aiInsight = insight }
            }
        }
    }
}

