import SwiftUI
import CoreData

struct ExportDataView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \VehicleEntity.year, ascending: false)],
        animation: .default)
    private var vehicles: FetchedResults<VehicleEntity>
    
    @State private var isExporting = false
    @State private var exportItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var exportMessage = ""
    @State private var showingAlert = false
    
    var body: some View {
        List {
            Section {
                Text("Export your garage data as CSV spreadsheets or PDF reports that you can share, print, or save.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Section("Vehicle Reports (PDF)") {
                ForEach(vehicles, id: \.id) { vehicle in
                    Button(action: { exportPDF(for: vehicle) }) {
                        HStack {
                            Image(systemName: "doc.richtext.fill")
                                .foregroundColor(.red)
                                .frame(width: 28)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vehicle.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Text("Vehicle Report Card with costs & depreciation")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                if vehicles.isEmpty {
                    HStack {
                        Image(systemName: "car")
                            .foregroundColor(.secondary)
                        Text("No vehicles to export")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Cost History (CSV)") {
                ForEach(vehicles, id: \.id) { vehicle in
                    Button(action: { exportCSV(for: vehicle) }) {
                        HStack {
                            Image(systemName: "tablecells.fill")
                                .foregroundColor(.green)
                                .frame(width: 28)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vehicle.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Text("All maintenance costs as spreadsheet")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            Section("Full Garage Export (CSV)") {
                Button(action: { exportAllVehiclesCSV() }) {
                    HStack {
                        Image(systemName: "tray.full.fill")
                            .foregroundColor(.blue)
                            .frame(width: 28)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export All Vehicles")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Text("All vehicles with details as spreadsheet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: exportItems)
        }
        .alert("Export", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(exportMessage)
        }
        .overlay {
            if isExporting {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Generating export...")
                            .font(.subheadline)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
            }
        }
    }
    
    // MARK: - Export Actions
    
    private func exportPDF(for vehicle: VehicleEntity) {
        isExporting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let costRequest: NSFetchRequest<CostEntryEntity> = CostEntryEntity.fetchRequest()
            costRequest.predicate = NSPredicate(format: "vehicleID == %@", vehicle.id as CVarArg)
            costRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CostEntryEntity.date, ascending: true)]
            
            let fuelRequest: NSFetchRequest<FuelEntryEntity> = FuelEntryEntity.fetchRequest()
            fuelRequest.predicate = NSPredicate(format: "vehicleID == %@", vehicle.id as CVarArg)
            fuelRequest.sortDescriptors = [NSSortDescriptor(keyPath: \FuelEntryEntity.date, ascending: true)]
            
            let bgContext = PersistenceController.shared.container.newBackgroundContext()
            bgContext.performAndWait {
                let costs = (try? bgContext.fetch(costRequest)) ?? []
                let fuels = (try? bgContext.fetch(fuelRequest)) ?? []
                
                let bgVehicleRequest: NSFetchRequest<VehicleEntity> = VehicleEntity.fetchRequest()
                bgVehicleRequest.predicate = NSPredicate(format: "id == %@", vehicle.id as CVarArg)
                
                guard let bgVehicle = try? bgContext.fetch(bgVehicleRequest).first else {
                    DispatchQueue.main.async {
                        isExporting = false
                        exportMessage = "Could not load vehicle data."
                        showingAlert = true
                    }
                    return
                }
                
                if let url = DataExportService.shared.generateVehicleReport(
                    for: bgVehicle, costEntries: costs, fuelEntries: fuels, context: bgContext
                ) {
                    DispatchQueue.main.async {
                        isExporting = false
                        exportItems = [url]
                        showingShareSheet = true
                    }
                } else {
                    DispatchQueue.main.async {
                        isExporting = false
                        exportMessage = "Failed to generate PDF report."
                        showingAlert = true
                    }
                }
            }
        }
    }
    
    private func exportCSV(for vehicle: VehicleEntity) {
        if let url = DataExportService.shared.exportCostEntriesCSV(for: vehicle, context: viewContext) {
            exportItems = [url]
            showingShareSheet = true
        } else {
            exportMessage = "No cost entries to export."
            showingAlert = true
        }
    }
    
    private func exportAllVehiclesCSV() {
        if let url = DataExportService.shared.exportAllVehiclesCSV(context: viewContext) {
            exportItems = [url]
            showingShareSheet = true
        } else {
            exportMessage = "No vehicles to export."
            showingAlert = true
        }
    }
}
