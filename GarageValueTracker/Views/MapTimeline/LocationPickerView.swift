import SwiftUI
import MapKit
import CoreLocation

struct LocationPickerView: View {
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var selectedAddress: String

    private var locationService: LocationService { LocationService.shared }
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var isLocating = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showSearch = false

    var body: some View {
        VStack(spacing: 0) {
            if let coord = selectedCoordinate {
                Map(position: $cameraPosition) {
                    Marker(selectedAddress.isEmpty ? "Selected" : selectedAddress, coordinate: coord)
                        .tint(.blue)
                }
                .frame(height: 150)
                .cornerRadius(12)
                .onAppear {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: coord,
                        latitudinalMeters: 2000,
                        longitudinalMeters: 2000
                    ))
                }

                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.blue)
                    Text(selectedAddress.isEmpty ? "Location set" : selectedAddress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button("Change") {
                        showSearch = true
                    }
                    .font(.caption)
                }
                .padding(.top, 8)
            }

            if selectedCoordinate == nil || showSearch {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Button(action: useCurrentLocation) {
                            HStack(spacing: 6) {
                                if isLocating {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "location.fill")
                                }
                                Text("Current Location")
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(10)
                        }
                        .disabled(isLocating)
                    }

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search address or place", text: $searchText)
                            .font(.subheadline)
                            .textFieldStyle(.plain)
                            .onSubmit {
                                performSearch()
                            }
                        if !searchText.isEmpty {
                            Button(action: { searchText = ""; searchResults = [] }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                    if isSearching {
                        ProgressView("Searching...")
                            .font(.caption)
                            .padding(.vertical, 4)
                    }

                    if !searchResults.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(searchResults, id: \.self) { item in
                                    Button(action: { selectMapItem(item) }) {
                                        HStack(spacing: 10) {
                                            Image(systemName: "mappin.circle.fill")
                                                .foregroundColor(.red)
                                                .frame(width: 24)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.name ?? "Unknown")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.primary)
                                                if let address = item.address?.fullAddress {
                                                    Text(address)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                            Spacer()
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 4)
                                    }
                                    Divider()
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
            }
        }
    }

    private func useCurrentLocation() {
        isLocating = true
        Task {
            if let location = await locationService.requestCurrentLocation() {
                let coord = location.coordinate
                selectedCoordinate = coord
                let address = await locationService.reverseGeocode(coord)
                selectedAddress = address ?? ""
                showSearch = false
                cameraPosition = .region(MKCoordinateRegion(
                    center: coord,
                    latitudinalMeters: 2000,
                    longitudinalMeters: 2000
                ))
            }
            isLocating = false
        }
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        Task {
            searchResults = await locationService.searchLocations(query: searchText)
            isSearching = false
        }
    }

    private func selectMapItem(_ item: MKMapItem) {
        let coord = item.location.coordinate
        selectedCoordinate = coord
        selectedAddress = item.address?.fullAddress ?? item.name ?? ""
        searchText = ""
        searchResults = []
        showSearch = false
        cameraPosition = .region(MKCoordinateRegion(
            center: coord,
            latitudinalMeters: 2000,
            longitudinalMeters: 2000
        ))
    }
}
