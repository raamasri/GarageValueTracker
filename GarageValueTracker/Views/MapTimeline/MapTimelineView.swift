import SwiftUI
import MapKit
import CoreData
import CoreLocation

struct MapTimelineView: View {
    let vehicle: VehicleEntity?

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode

    @FetchRequest var locationEvents: FetchedResults<VehicleLocationEventEntity>

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedEvent: VehicleLocationEventEntity?
    @State private var selectedInterval: TimeInterval = .allTime
    @State private var selectedTypes: Set<LocationEventType> = Set(LocationEventType.allCases)
    @State private var lineMode: LineMode = .chronological
    @State private var showingAddTrip = false
    @State private var showingMigrateAlert = false
    @State private var isMigrating = false
    @State private var selectedVehicleFilter: UUID?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \VehicleEntity.year, ascending: false)],
        animation: .default
    ) private var allVehicles: FetchedResults<VehicleEntity>

    enum TimeInterval: String, CaseIterable {
        case lastWeek = "Week"
        case lastMonth = "Month"
        case lastYear = "Year"
        case allTime = "All Time"

        var startDate: Date {
            let calendar = Calendar.current
            switch self {
            case .lastWeek: return calendar.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
            case .lastMonth: return calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            case .lastYear: return calendar.date(byAdding: .year, value: -1, to: Date()) ?? Date()
            case .allTime: return Date.distantPast
            }
        }
    }

    enum LineMode: String, CaseIterable {
        case chronological = "Timeline"
        case radial = "From Home"
    }

    init(vehicle: VehicleEntity?) {
        self.vehicle = vehicle
        if let vehicle = vehicle {
            _locationEvents = FetchRequest<VehicleLocationEventEntity>(
                sortDescriptors: [NSSortDescriptor(keyPath: \VehicleLocationEventEntity.date, ascending: true)],
                predicate: NSPredicate(format: "vehicleID == %@", vehicle.id as CVarArg),
                animation: .default
            )
        } else {
            _locationEvents = FetchRequest<VehicleLocationEventEntity>(
                sortDescriptors: [NSSortDescriptor(keyPath: \VehicleLocationEventEntity.date, ascending: true)],
                animation: .default
            )
        }
    }

    private var filteredEvents: [VehicleLocationEventEntity] {
        locationEvents.filter { event in
            let matchesTime = event.date >= selectedInterval.startDate
            let matchesType = selectedTypes.contains(event.locationEventType)
            let matchesVehicle: Bool
            if let vehicleFilter = selectedVehicleFilter {
                matchesVehicle = event.vehicleID == vehicleFilter
            } else {
                matchesVehicle = true
            }
            return matchesTime && matchesType && matchesVehicle
        }
    }

    private var homeEvent: VehicleLocationEventEntity? {
        filteredEvents.first { $0.locationEventType == .home }
    }

    private var polylineCoordinates: [CLLocationCoordinate2D] {
        filteredEvents.map { $0.coordinate }
    }

    private var radialLines: [(CLLocationCoordinate2D, CLLocationCoordinate2D)] {
        guard let home = homeEvent else { return [] }
        return filteredEvents
            .filter { $0.locationEventType != .home }
            .map { (home.coordinate, $0.coordinate) }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                filterBar
                mapView
                timelineList
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(vehicle != nil ? "Map Timeline" : "All Vehicles Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingAddTrip = true }) {
                            Label("Log a Trip", systemImage: "flag.fill")
                        }
                        Button(action: { showingMigrateAlert = true }) {
                            Label("Import Existing Data", systemImage: "arrow.down.circle")
                        }
                        Menu("Line Mode") {
                            ForEach(LineMode.allCases, id: \.self) { mode in
                                Button(action: { lineMode = mode }) {
                                    HStack {
                                        Text(mode.rawValue)
                                        if lineMode == mode {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddTrip) {
                if let vehicle = vehicle {
                    AddTripView(vehicleID: vehicle.id)
                        .environment(\.managedObjectContext, viewContext)
                } else if let first = allVehicles.first {
                    AddTripView(vehicleID: first.id, vehicles: Array(allVehicles))
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            .alert("Import Location Data", isPresented: $showingMigrateAlert) {
                Button("Import") {
                    runMigration()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will geocode existing fuel stations, cost merchants, and vehicle locations into map events. This may take a moment.")
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 8) {
            // Time interval picker
            Picker("Time", selection: $selectedInterval) {
                ForEach(TimeInterval.allCases, id: \.self) { interval in
                    Text(interval.rawValue).tag(interval)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Event type filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // All / None toggle
                    Button(action: {
                        if selectedTypes.count == LocationEventType.allCases.count {
                            selectedTypes = []
                        } else {
                            selectedTypes = Set(LocationEventType.allCases)
                        }
                    }) {
                        Text("All")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedTypes.count == LocationEventType.allCases.count ? Color.blue : Color(.systemGray5))
                            .foregroundColor(selectedTypes.count == LocationEventType.allCases.count ? .white : .primary)
                            .cornerRadius(16)
                    }

                    ForEach(LocationEventType.allCases) { type in
                        Button(action: {
                            if selectedTypes.contains(type) {
                                selectedTypes.remove(type)
                            } else {
                                selectedTypes.insert(type)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: type.icon)
                                    .font(.caption2)
                                Text(type.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedTypes.contains(type) ? colorForType(type) : Color(.systemGray5))
                            .foregroundColor(selectedTypes.contains(type) ? .white : .primary)
                            .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Vehicle picker (global mode only)
            if vehicle == nil && allVehicles.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button(action: { selectedVehicleFilter = nil }) {
                            Text("All Vehicles")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedVehicleFilter == nil ? Color.purple : Color(.systemGray5))
                                .foregroundColor(selectedVehicleFilter == nil ? .white : .primary)
                                .cornerRadius(16)
                        }
                        ForEach(allVehicles, id: \.id) { v in
                            Button(action: { selectedVehicleFilter = v.id }) {
                                Text(v.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedVehicleFilter == v.id ? Color.purple : Color(.systemGray5))
                                    .foregroundColor(selectedVehicleFilter == v.id ? .white : .primary)
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    // MARK: - Map View

    private var mapView: some View {
        Map(position: $cameraPosition, selection: $selectedEvent) {
            ForEach(filteredEvents) { event in
                Annotation(
                    event.title ?? event.locationEventType.displayName,
                    coordinate: event.coordinate
                ) {
                    eventPin(for: event)
                }
                .tag(event)
            }

            if lineMode == .chronological && polylineCoordinates.count >= 2 {
                MapPolyline(coordinates: polylineCoordinates)
                    .stroke(.blue.opacity(0.6), lineWidth: 3)
            }

            if lineMode == .radial {
                ForEach(Array(radialLines.enumerated()), id: \.offset) { _, pair in
                    MapPolyline(coordinates: [pair.0, pair.1])
                        .stroke(.purple.opacity(0.4), lineWidth: 2)
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .frame(minHeight: 300, maxHeight: 400)
        .onChange(of: filteredEvents.count) {
            fitMapToEvents()
        }
        .onAppear {
            fitMapToEvents()
        }
    }

    private func eventPin(for event: VehicleLocationEventEntity) -> some View {
        ZStack {
            Circle()
                .fill(colorForType(event.locationEventType))
                .frame(width: 32, height: 32)
                .shadow(color: colorForType(event.locationEventType).opacity(0.4), radius: 4, x: 0, y: 2)

            Image(systemName: event.locationEventType.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    // MARK: - Timeline List

    private var timelineList: some View {
        Group {
            if filteredEvents.isEmpty {
                VStack(spacing: 16) {
                    if isMigrating {
                        ProgressView("Importing location data...")
                            .padding()
                    } else {
                        Image(systemName: "map")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Location Events")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Log fuel fill-ups, services, trips, or import existing data to see your vehicle's journey.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button(action: { showingMigrateAlert = true }) {
                            Label("Import Existing Data", systemImage: "arrow.down.circle.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredEvents.reversed().enumerated()), id: \.element.id) { index, event in
                            TimelineEventRow(
                                event: event,
                                isFirst: index == 0,
                                isLast: index == filteredEvents.count - 1,
                                vehicleName: vehicle == nil ? vehicleName(for: event.vehicleID) : nil
                            )
                            .onTapGesture {
                                selectedEvent = event
                                withAnimation {
                                    cameraPosition = .region(MKCoordinateRegion(
                                        center: event.coordinate,
                                        latitudinalMeters: 3000,
                                        longitudinalMeters: 3000
                                    ))
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Helpers

    private func fitMapToEvents() {
        guard !filteredEvents.isEmpty else { return }
        let coords = filteredEvents.map { $0.coordinate }
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)

        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let latDelta = max((maxLat - minLat) * 1.4, 0.01)
        let lonDelta = max((maxLon - minLon) * 1.4, 0.01)

        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
            ))
        }
    }

    private func vehicleName(for vehicleID: UUID) -> String? {
        allVehicles.first { $0.id == vehicleID }?.displayName
    }

    private func colorForType(_ type: LocationEventType) -> Color {
        switch type {
        case .fuel: return .cyan
        case .service: return .blue
        case .cost: return .green
        case .home: return .purple
        case .purchase: return .indigo
        case .accident: return .red
        case .trip: return .orange
        }
    }

    private func runMigration() {
        isMigrating = true
        Task {
            await LocationService.shared.migrateExistingData(context: viewContext)
            isMigrating = false
        }
    }
}
