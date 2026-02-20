import SwiftUI
import MapKit
import CoreLocation
import Combine

struct ServiceShopFinderView: View {
    let vehicle: VehicleEntity?
    
    @StateObject private var locationManager = ShopLocationManager()
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedShop: MKMapItem?
    @State private var isSearching = false
    @State private var searchQuery = "auto repair"
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var hasSearched = false
    @State private var showingEstimate = false
    @State private var favoriteShopNames: Set<String> = []
    
    @Environment(\.presentationMode) var presentationMode
    
    private let shopCategories = [
        ("Auto Repair", "auto repair shop"),
        ("Oil Change", "oil change"),
        ("Tire Shop", "tire shop"),
        ("Body Shop", "auto body shop"),
        ("Dealership", "car dealership service"),
        ("Brake Shop", "brake repair"),
        ("Transmission", "transmission repair"),
        ("Emissions", "emissions testing")
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                categoryPicker
                
                Map(position: $cameraPosition, selection: $selectedShop) {
                    UserAnnotation()
                    
                    ForEach(searchResults, id: \.self) { item in
                        Marker(
                            item.name ?? "Shop",
                            systemImage: "wrench.and.screwdriver.fill",
                            coordinate: item.placemark.coordinate
                        )
                        .tint(.blue)
                        .tag(item)
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                .frame(height: 300)
                
                shopListView
            }
            .navigationTitle("Find Service Shops")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if vehicle != nil {
                        Button(action: { showingEstimate = true }) {
                            Label("Estimate", systemImage: "dollarsign.circle")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingEstimate) {
                if let vehicle = vehicle {
                    ServiceEstimateView(vehicle: vehicle)
                }
            }
            .onAppear {
                locationManager.requestLocation()
                loadFavorites()
            }
            .onChange(of: locationManager.location) { _, location in
                if let location = location, !hasSearched {
                    hasSearched = true
                    searchNearby(query: searchQuery, near: location)
                }
            }
        }
    }
    
    // MARK: - Category Picker
    
    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(shopCategories, id: \.0) { (name, query) in
                    Button(action: {
                        searchQuery = query
                        if let location = locationManager.location {
                            searchNearby(query: query, near: location)
                        }
                    }) {
                        Text(name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(searchQuery == query ? Color.blue : Color(.systemGray5))
                            .foregroundColor(searchQuery == query ? .white : .primary)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Shop List
    
    private var shopListView: some View {
        Group {
            if isSearching {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Finding nearby shops...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    if locationManager.authorizationStatus == .denied {
                        Text("Location access is needed to find nearby shops.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    } else {
                        Text("No shops found nearby. Try a different category.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sortedResults, id: \.self) { item in
                        HStack {
                            ShopRow(item: item, userLocation: locationManager.location)
                                .onTapGesture {
                                    selectedShop = item
                                    if let coord = item.placemark.location?.coordinate {
                                        withAnimation {
                                            cameraPosition = .region(MKCoordinateRegion(
                                                center: coord,
                                                latitudinalMeters: 1000,
                                                longitudinalMeters: 1000
                                            ))
                                        }
                                    }
                                }
                            
                            Button(action: {
                                if let name = item.name {
                                    toggleFavorite(name)
                                }
                            }) {
                                Image(systemName: favoriteShopNames.contains(item.name ?? "") ? "star.fill" : "star")
                                    .foregroundColor(favoriteShopNames.contains(item.name ?? "") ? .yellow : .gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    // MARK: - Search
    
    private func loadFavorites() {
        let saved = UserDefaults.standard.stringArray(forKey: "favoriteShops") ?? []
        favoriteShopNames = Set(saved)
    }
    
    private func toggleFavorite(_ name: String) {
        if favoriteShopNames.contains(name) {
            favoriteShopNames.remove(name)
        } else {
            favoriteShopNames.insert(name)
        }
        UserDefaults.standard.set(Array(favoriteShopNames), forKey: "favoriteShops")
    }
    
    private var sortedResults: [MKMapItem] {
        searchResults.sorted { a, b in
            let aFav = favoriteShopNames.contains(a.name ?? "")
            let bFav = favoriteShopNames.contains(b.name ?? "")
            if aFav != bFav { return aFav }
            guard let userLoc = locationManager.location,
                  let locA = a.placemark.location,
                  let locB = b.placemark.location else { return false }
            return locA.distance(from: userLoc) < locB.distance(from: userLoc)
        }
    }
    
    private func searchNearby(query: String, near location: CLLocation) {
        isSearching = true
        searchResults = []
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 16000,
            longitudinalMeters: 16000
        )
        request.resultTypes = .pointOfInterest
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            
            guard let response = response else { return }
            
            searchResults = response.mapItems.sorted { a, b in
                guard let locA = a.placemark.location, let locB = b.placemark.location else { return false }
                return locA.distance(from: location) < locB.distance(from: location)
            }
            
            if let first = searchResults.first?.placemark.location?.coordinate {
                cameraPosition = .region(MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: max(location.distance(from: CLLocation(latitude: first.latitude, longitude: first.longitude)) * 3, 5000),
                    longitudinalMeters: max(location.distance(from: CLLocation(latitude: first.latitude, longitude: first.longitude)) * 3, 5000)
                ))
            }
        }
    }
}

// MARK: - Shop Row

struct ShopRow: View {
    let item: MKMapItem
    let userLocation: CLLocation?
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name ?? "Unknown Shop")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let address = item.placemark.title {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 12) {
                    if let distance = distanceText {
                        Label(distance, systemImage: "location")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    
                    if let phone = item.phoneNumber {
                        Label(phone, systemImage: "phone")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(spacing: 6) {
                Button(action: openInMaps) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                
                Text("Directions")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var distanceText: String? {
        guard let userLocation = userLocation,
              let shopLocation = item.placemark.location else { return nil }
        
        let meters = userLocation.distance(from: shopLocation)
        let miles = meters / 1609.34
        
        if miles < 0.1 {
            return "Nearby"
        } else if miles < 10 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.0f mi", miles)
        }
    }
    
    private func openInMaps() {
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

// MARK: - Location Manager

class ShopLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    func requestLocation() {
        authorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
