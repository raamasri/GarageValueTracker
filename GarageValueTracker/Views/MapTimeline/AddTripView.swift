import SwiftUI
import MapKit
import CoreData
import CoreLocation

struct AddTripView: View {
    let vehicleID: UUID
    let vehicles: [VehicleEntity]?

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode

    @State private var destination = ""
    @State private var date = Date()
    @State private var notes = ""
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedAddress = ""
    @State private var selectedVehicleID: UUID

    init(vehicleID: UUID, vehicles: [VehicleEntity]? = nil) {
        self.vehicleID = vehicleID
        self.vehicles = vehicles
        _selectedVehicleID = State(initialValue: vehicleID)
    }

    private var isValid: Bool {
        !destination.isEmpty && selectedCoordinate != nil
    }

    var body: some View {
        NavigationView {
            Form {
                if let vehicles = vehicles, vehicles.count > 1 {
                    Section("Vehicle") {
                        Picker("Vehicle", selection: $selectedVehicleID) {
                            ForEach(vehicles, id: \.id) { vehicle in
                                Text(vehicle.displayName).tag(vehicle.id)
                            }
                        }
                    }
                }

                Section("Trip Details") {
                    TextField("Destination Name", text: $destination)
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                }

                Section("Location") {
                    LocationPickerView(
                        selectedCoordinate: $selectedCoordinate,
                        selectedAddress: $selectedAddress
                    )
                }

                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Log Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTrip()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func saveTrip() {
        guard let coord = selectedCoordinate else { return }

        let trip = TripEventEntity(entity: NSEntityDescription.entity(forEntityName: "TripEventEntity", in: viewContext)!, insertInto: viewContext)
        trip.id = UUID()
        trip.vehicleID = selectedVehicleID
        trip.date = date
        trip.destination = destination
        trip.latitude = coord.latitude
        trip.longitude = coord.longitude
        trip.notes = notes.isEmpty ? nil : notes
        trip.createdAt = Date()

        LocationService.shared.createLocationEvent(
            context: viewContext,
            vehicleID: selectedVehicleID,
            date: date,
            coordinate: coord,
            address: selectedAddress.isEmpty ? destination : selectedAddress,
            eventType: .trip,
            title: destination,
            notes: notes.isEmpty ? nil : notes,
            sourceEntityID: trip.id
        )

        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving trip: \(error)")
        }
    }
}
