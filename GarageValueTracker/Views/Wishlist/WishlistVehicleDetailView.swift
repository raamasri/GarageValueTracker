import SwiftUI
import CoreData

struct WishlistVehicleDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let vehicle: WishlistVehicleEntity
    
    @State private var priceHistory: [PriceHistoryEntity] = []
    @State private var priceStats: PriceStatistics?
    @State private var showingUpdatePrice = false
    @State private var showingMoveToGarage = false
    @State private var newPrice = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Vehicle Photo
                if let imageData = vehicle.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [.clear, .black.opacity(0.6)]),
                                startPoint: .center,
                                endPoint: .bottom
                            )
                        )
                }
                
                // Vehicle Header
                VStack(spacing: 8) {
                    Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let trim = vehicle.trim {
                        Text(trim)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        if let location = vehicle.location {
                            Label(location, systemImage: "location.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if vehicle.mileage > 0 {
                            Label("\(vehicle.mileage) miles", systemImage: "gauge")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                
                // Current Price Card
                if vehicle.currentPrice > 0 {
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current Price")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("$\(Int(vehicle.currentPrice))")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            if let stats = priceStats {
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Since Added")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: stats.trend.icon)
                                        Text(stats.priceChangeSinceAdded > 0 ? "+$\(Int(abs(stats.priceChangeSinceAdded)))" : "-$\(Int(abs(stats.priceChangeSinceAdded)))")
                                            .fontWeight(.semibold)
                                    }
                                    .font(.title3)
                                    .foregroundColor(stats.trend == .decreasing ? .green : (stats.trend == .increasing ? .red : .gray))
                                }
                            }
                        }
                        
                        if let lastUpdate = vehicle.lastPriceUpdate {
                            Text("Last updated: \(lastUpdate, style: .relative) ago")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Button(action: {
                            showingUpdatePrice = true
                        }) {
                            Label("Update Price", systemImage: "dollarsign.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.15)))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                } else {
                    // No price set - show add price option
                    VStack(spacing: 12) {
                        Image(systemName: "dollarsign.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text("No Price Set")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Track this vehicle's price to get notified when it drops")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            showingUpdatePrice = true
                        }) {
                            Label("Add Price", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.15)))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                }
                
                // Target Price Card
                if vehicle.targetPrice > 0 {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Target Price")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("$\(Int(vehicle.targetPrice))")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            
                            Spacer()
                            
                            if vehicle.isPriceUnderTarget {
                                VStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.green)
                                    Text("Under Target!")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                }
                            } else if let diff = vehicle.priceChangeFromTarget {
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Over by")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("$\(Int(diff))")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.15)))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                }
                
                // Price Statistics
                if let stats = priceStats, priceHistory.count > 1 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Price Statistics")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 16) {
                            StatItem(title: "Lowest", value: "$\(Int(stats.lowestPrice))", icon: "arrow.down.circle.fill", color: .green)
                            StatItem(title: "Highest", value: "$\(Int(stats.highestPrice))", icon: "arrow.up.circle.fill", color: .red)
                            StatItem(title: "Average", value: "$\(Int(stats.averagePrice))", icon: "chart.bar.fill", color: .blue)
                        }
                        
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.secondary)
                            Text("Tracking for \(stats.daysTracked) updates")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.15)))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                }
                
                // Price History
                if !priceHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Price History")
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        ForEach(priceHistory.reversed(), id: \.id) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("$\(Int(entry.price))")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                    Text(entry.date, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if let source = entry.source {
                                    Text(source)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(8)
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Listing Details
                if vehicle.seller != nil || vehicle.listingURL != nil || vehicle.vin != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Listing Details")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        if let seller = vehicle.seller {
                            WishlistDetailRow(icon: "person.fill", title: "Seller", value: seller)
                        }
                        
                        if let vin = vehicle.vin {
                            WishlistDetailRow(icon: "number", title: "VIN", value: vin)
                        }
                        
                        if let url = vehicle.listingURL {
                            Link(destination: URL(string: url)!) {
                                HStack {
                                    Image(systemName: "link")
                                    Text("View Listing")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.15)))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                }
                
                // Notes
                if let notes = vehicle.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Text(notes)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.15)))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                }
                
                // Move to Garage Button
                Button(action: {
                    showingMoveToGarage = true
                }) {
                    Label("Move to My Garage", systemImage: "car.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadData()
        }
        .sheet(isPresented: $showingUpdatePrice) {
            UpdatePriceView(vehicle: vehicle)
        }
        .sheet(isPresented: $showingMoveToGarage) {
            MoveToGarageView(wishlistVehicle: vehicle)
        }
    }
    
    private func loadData() {
        priceHistory = WishlistService.shared.getPriceHistory(for: vehicle.id, context: viewContext)
        priceStats = WishlistService.shared.getPriceStatistics(for: vehicle.id, context: viewContext)
    }
}

// MARK: - Stat Item Component
struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Wishlist Detail Row Component
struct WishlistDetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Update Price View
struct UpdatePriceView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    let vehicle: WishlistVehicleEntity
    @State private var newPrice = ""
    
    var body: some View {
        NavigationView {
            Form {
                if vehicle.currentPrice > 0 {
                    Section("Current Price") {
                        Text("$\(Int(vehicle.currentPrice))")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                
                Section("New Price") {
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("Enter price", text: $newPrice)
                            .keyboardType(.decimalPad)
                    }
                }
                
                if vehicle.targetPrice > 0 {
                    Section {
                        HStack {
                            Text("Target Price")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("$\(Int(vehicle.targetPrice))")
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle(vehicle.currentPrice > 0 ? "Update Price" : "Add Price")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updatePrice()
                    }
                    .disabled(newPrice.isEmpty || Double(newPrice) == nil)
                }
            }
        }
    }
    
    private func updatePrice() {
        guard let priceValue = Double(newPrice) else { return }
        
        if WishlistService.shared.updatePrice(
            for: vehicle.id,
            newPrice: priceValue,
            context: viewContext,
            source: "Manual"
        ) {
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Move to Garage View
struct MoveToGarageView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    let wishlistVehicle: WishlistVehicleEntity
    
    @State private var purchasePrice = ""
    @State private var purchaseDate = Date()
    @State private var mileage = ""
    @State private var vin = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Purchase Details") {
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("Purchase Price", text: $purchasePrice)
                            .keyboardType(.decimalPad)
                    }
                    
                    DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
                    
                    TextField("Current Mileage", text: $mileage)
                        .keyboardType(.numberPad)
                    
                    TextField("VIN", text: $vin)
                        .autocapitalization(.allCharacters)
                }
                
                Section {
                    Button(action: {
                        moveToGarage()
                    }) {
                        HStack {
                            Image(systemName: "car.fill")
                            Text("Add to My Garage")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.green)
                    }
                    .disabled(!isValid)
                }
            }
            .navigationTitle("Move to Garage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                mileage = String(wishlistVehicle.mileage)
                vin = wishlistVehicle.vin ?? ""
                purchasePrice = String(Int(wishlistVehicle.currentPrice))
            }
        }
    }
    
    private var isValid: Bool {
        guard let _ = Double(purchasePrice),
              let _ = Int32(mileage) else {
            return false
        }
        return true
    }
    
    private func moveToGarage() {
        guard let priceValue = Double(purchasePrice),
              let mileageValue = Int32(mileage) else { return }
        
        if WishlistService.shared.moveToGarage(
            wishlistVehicle,
            purchasePrice: priceValue,
            purchaseDate: purchaseDate,
            mileage: mileageValue,
            vin: vin.isEmpty ? nil : vin,
            context: viewContext
        ) != nil {
            presentationMode.wrappedValue.dismiss()
        }
    }
}

