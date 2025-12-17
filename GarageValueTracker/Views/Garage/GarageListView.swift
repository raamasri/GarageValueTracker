import SwiftUI
import CoreData

struct GarageListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \VehicleEntity.year, ascending: false)],
        animation: .default)
    private var vehicles: FetchedResults<VehicleEntity>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WishlistVehicleEntity.createdAt, ascending: false)],
        animation: .default)
    private var wishlistVehicles: FetchedResults<WishlistVehicleEntity>
    
    @State private var currentIndex = 0
    @State private var selectedTab: GarageTab = .myGarage
    
    enum GarageTab {
        case myGarage
        case wishlist
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Selector
            HStack(spacing: 0) {
                Button(action: { selectedTab = .myGarage }) {
                    VStack(spacing: 8) {
                        Text("My Garage")
                            .font(.headline)
                            .fontWeight(selectedTab == .myGarage ? .bold : .regular)
                        
                        if selectedTab == .myGarage {
                            Capsule()
                                .fill(Color.blue)
                                .frame(height: 3)
                        } else {
                            Capsule()
                                .fill(Color.clear)
                                .frame(height: 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(selectedTab == .myGarage ? .primary : .secondary)
                }
                
                Button(action: { selectedTab = .wishlist }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text("Wishlist")
                                .font(.headline)
                                .fontWeight(selectedTab == .wishlist ? .bold : .regular)
                            
                            if wishlistVehicles.count > 0 {
                                Text("\(wishlistVehicles.count)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        if selectedTab == .wishlist {
                            Capsule()
                                .fill(Color.blue)
                                .frame(height: 3)
                        } else {
                            Capsule()
                                .fill(Color.clear)
                                .frame(height: 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(selectedTab == .wishlist ? .primary : .secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .background(Color(.systemBackground))
            
            // Content
            GeometryReader { geometry in
                if selectedTab == .myGarage {
                    myGarageView
                } else {
                    wishlistView
                }
            }
        }
    }
    
    private var myGarageView: some View {
        VStack(spacing: 0) {
            // Page indicator at top
            if vehicles.count > 1 {
                HStack(spacing: 8) {
                    ForEach(0..<vehicles.count, id: \.self) { index in
                        Capsule()
                            .fill(currentIndex == index ? Color.white : Color.white.opacity(0.3))
                            .frame(width: currentIndex == index ? 30 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentIndex)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 10)
            }
            
            // Swipeable card stack
            TabView(selection: $currentIndex) {
                ForEach(Array(vehicles.enumerated()), id: \.element.id) { index, vehicle in
                    VehicleCard(vehicle: vehicle)
                        .tag(index)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
    
    private var wishlistView: some View {
        Group {
            if wishlistVehicles.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 80))
                        .foregroundColor(.secondary)
                    
                    Text("No Cars in Wishlist")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Track prices on cars you want to buy")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(wishlistVehicles, id: \.id) { wishlistVehicle in
                            WishlistVehicleCard(vehicle: wishlistVehicle)
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private func deleteVehicles(offsets: IndexSet) {
        withAnimation {
            offsets.map { vehicles[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error deleting vehicle: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

// MARK: - Vehicle Card Component
struct VehicleCard: View {
    let vehicle: VehicleEntity
    
    @FetchRequest private var costEntries: FetchedResults<CostEntryEntity>
    
    init(vehicle: VehicleEntity) {
        self.vehicle = vehicle
        
        _costEntries = FetchRequest<CostEntryEntity>(
            sortDescriptors: [],
            predicate: NSPredicate(format: "vehicleID == %@", vehicle.id as CVarArg),
            animation: .default
        )
    }
    
    private var totalCosts: Double {
        costEntries.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        NavigationLink(destination: VehicleDetailView(vehicle: vehicle)) {
            ZStack {
                // Card background with image or gradient
                RoundedRectangle(cornerRadius: 30)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.3),
                                Color.purple.opacity(0.3)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Vehicle photo background (if available)
                if let imageData = vehicle.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .clear,
                                    .clear,
                                    .black.opacity(0.8),
                                    .black.opacity(0.95)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                // Glass overlay
                RoundedRectangle(cornerRadius: 30)
                    .fill(.ultraThinMaterial)
                    .opacity(0.3)
                
                // Content
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Vehicle info
                    VStack(alignment: .leading, spacing: 12) {
                        // Year, Make, Model
                        Text("\(String(vehicle.year)) \(vehicle.make)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(vehicle.model)
                            .font(.title)
                            .fontWeight(.heavy)
                            .foregroundColor(.white)
                        
                        if let trim = vehicle.trim {
                            Text(trim)
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.3))
                            .padding(.vertical, 8)
                        
                        // Stats row
                        HStack(spacing: 20) {
                            // Mileage
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "gauge")
                                        .font(.caption)
                                    Text("Mileage")
                                        .font(.caption)
                                        .textCase(.uppercase)
                                }
                                .foregroundColor(.white.opacity(0.7))
                                
                                Text("\(vehicle.mileage)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            // Value
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Value")
                                    .font(.caption)
                                    .textCase(.uppercase)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text("$\(vehicle.currentValue, specifier: "%.0f")")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding(30)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Wishlist Vehicle Card Component
struct WishlistVehicleCard: View {
    let vehicle: WishlistVehicleEntity
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var priceStats: PriceStatistics?
    
    var body: some View {
        NavigationLink(destination: WishlistVehicleDetailView(vehicle: vehicle)) {
            ZStack {
                // Card background
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.15))
                    )
                
                // Content
                HStack(spacing: 16) {
                    // Vehicle Image
                    Group {
                        if let imageData = vehicle.imageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                        } else {
                            ZStack {
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.orange, Color.red]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                
                                Image(systemName: "heart.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(String(vehicle.year)) \(vehicle.make)")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text(vehicle.model)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let trim = vehicle.trim {
                            Text(trim)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        HStack(spacing: 12) {
                            // Current Price
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Current")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("$\(Int(vehicle.currentPrice))")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                            
                            // Price Trend
                            if let stats = priceStats {
                                HStack(spacing: 4) {
                                    Image(systemName: stats.trend.icon)
                                        .font(.caption)
                                    Text(stats.priceChangeSinceAdded > 0 ? "+$\(Int(abs(stats.priceChangeSinceAdded)))" : "-$\(Int(abs(stats.priceChangeSinceAdded)))")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(stats.trend == .decreasing ? .green : (stats.trend == .increasing ? .red : .gray))
                            }
                            
                            Spacer()
                            
                            // Target indicator
                            if vehicle.targetPrice > 0 {
                                if vehicle.isPriceUnderTarget {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption)
                                        Text("Under target!")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.15))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
            }
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadPriceStatistics()
        }
    }
    
    private func loadPriceStatistics() {
        priceStats = WishlistService.shared.getPriceStatistics(
            for: vehicle.id,
            context: viewContext
        )
    }
}

struct GarageListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GarageListView()
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}
