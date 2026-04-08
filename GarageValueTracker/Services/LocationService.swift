import Foundation
import CoreData
import CoreLocation
import MapKit
import Observation

@MainActor
@Observable
class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private let manager = CLLocationManager()

    var currentLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func requestCurrentLocation() async -> CLLocation? {
        requestPermission()

        guard manager.authorizationStatus == .authorizedWhenInUse ||
              manager.authorizationStatus == .authorizedAlways else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task { @MainActor in
            currentLocation = location
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }

    // MARK: - Geocoding (using MapKit APIs for iOS 26+)

    func geocodeAddress(_ address: String) async -> CLLocationCoordinate2D? {
        guard !address.isEmpty else { return nil }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = address
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            return response.mapItems.first?.location.coordinate
        } catch {
            return nil
        }
    }

    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if let request = MKReverseGeocodingRequest(location: location) {
            do {
                let mapItems = try await request.mapItems
                if let item = mapItems.first {
                    if let fullAddr = item.address?.fullAddress, !fullAddr.isEmpty {
                        return fullAddr
                    }
                    return item.name
                }
            } catch {
                // fallthrough
            }
        }
        return "\(String(format: "%.4f", coordinate.latitude)), \(String(format: "%.4f", coordinate.longitude))"
    }

    // MARK: - Location Event Creation

    func createLocationEvent(
        context: NSManagedObjectContext,
        vehicleID: UUID,
        date: Date,
        coordinate: CLLocationCoordinate2D,
        address: String?,
        eventType: LocationEventType,
        title: String?,
        notes: String? = nil,
        sourceEntityID: UUID? = nil
    ) {
        let event = VehicleLocationEventEntity(entity: NSEntityDescription.entity(forEntityName: "VehicleLocationEventEntity", in: context)!, insertInto: context)
        event.id = UUID()
        event.vehicleID = vehicleID
        event.date = date
        event.latitude = coordinate.latitude
        event.longitude = coordinate.longitude
        event.address = address
        event.eventType = eventType.rawValue
        event.title = title
        event.notes = notes
        event.sourceEntityID = sourceEntityID
        event.createdAt = Date()
    }

    // MARK: - MKLocalSearch for location picking

    func searchLocations(query: String, region: MKCoordinateRegion? = nil) async -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let region = region {
            request.region = region
        }
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            return response.mapItems
        } catch {
            return []
        }
    }

    // MARK: - Data Migration

    func migrateExistingData(context: NSManagedObjectContext) async {
        let hasMigrated = UserDefaults.standard.bool(forKey: "hasRunLocationMigration")
        guard !hasMigrated else { return }

        await migrateFuelEntries(context: context)
        await migrateCostEntries(context: context)
        await migrateServiceReminders(context: context)
        await migrateVehicleLocations(context: context)

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: "hasRunLocationMigration")
        } catch {
            print("Error saving migration data: \(error)")
        }
    }

    private func migrateFuelEntries(context: NSManagedObjectContext) async {
        let request = FuelEntryEntity.fetchRequest()
        guard let entries = try? context.fetch(request) else { return }

        for entry in entries {
            guard let station = entry.station, !station.isEmpty else { continue }
            if let coord = await geocodeAddress(station) {
                createLocationEvent(
                    context: context,
                    vehicleID: entry.vehicleID,
                    date: entry.date,
                    coordinate: coord,
                    address: station,
                    eventType: .fuel,
                    title: station,
                    sourceEntityID: entry.id
                )
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    private func migrateCostEntries(context: NSManagedObjectContext) async {
        let request = CostEntryEntity.fetchRequest()
        guard let entries = try? context.fetch(request) else { return }

        for entry in entries {
            guard let merchant = entry.merchantName, !merchant.isEmpty else { continue }
            if let coord = await geocodeAddress(merchant) {
                createLocationEvent(
                    context: context,
                    vehicleID: entry.vehicleID,
                    date: entry.date,
                    coordinate: coord,
                    address: merchant,
                    eventType: .cost,
                    title: "\(entry.category) - \(merchant)",
                    sourceEntityID: entry.id
                )
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    private func migrateServiceReminders(context: NSManagedObjectContext) async {
        let request = ServiceReminderEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isCompleted == YES")
        guard let reminders = try? context.fetch(request) else { return }

        for reminder in reminders {
            guard let completedDate = reminder.completedDate else { continue }
            let vehicleRequest = VehicleEntity.fetchRequest()
            vehicleRequest.predicate = NSPredicate(format: "id == %@", reminder.vehicleID as CVarArg)
            guard let vehicle = try? context.fetch(vehicleRequest).first,
                  let location = vehicle.location, !location.isEmpty,
                  let coord = await geocodeAddress(location) else { continue }

            createLocationEvent(
                context: context,
                vehicleID: reminder.vehicleID,
                date: completedDate,
                coordinate: coord,
                address: location,
                eventType: .service,
                title: reminder.serviceType,
                sourceEntityID: reminder.id
            )
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    private func migrateVehicleLocations(context: NSManagedObjectContext) async {
        let request = VehicleEntity.fetchRequest()
        guard let vehicles = try? context.fetch(request) else { return }

        for vehicle in vehicles {
            guard let location = vehicle.location, !location.isEmpty else { continue }
            if let coord = await geocodeAddress(location) {
                createLocationEvent(
                    context: context,
                    vehicleID: vehicle.id,
                    date: vehicle.purchaseDate,
                    coordinate: coord,
                    address: location,
                    eventType: .home,
                    title: "Home - \(location)"
                )

                createLocationEvent(
                    context: context,
                    vehicleID: vehicle.id,
                    date: vehicle.purchaseDate,
                    coordinate: coord,
                    address: location,
                    eventType: .purchase,
                    title: "Purchased \(vehicle.displayName)"
                )
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }
}
