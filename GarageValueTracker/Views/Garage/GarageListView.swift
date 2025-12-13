import SwiftUI
import CoreData

struct GarageListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \VehicleEntity.year, ascending: false)],
        animation: .default)
    private var vehicles: FetchedResults<VehicleEntity>
    
    var body: some View {
        List {
            ForEach(vehicles) { vehicle in
                NavigationLink(destination: VehicleDetailView(vehicle: vehicle)) {
                    VehicleRow(vehicle: vehicle)
                }
            }
            .onDelete(perform: deleteVehicles)
        }
        .listStyle(InsetGroupedListStyle())
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

struct VehicleRow: View {
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
        HStack(spacing: 15) {
            // Vehicle icon or image
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "car.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.displayName)
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Label("\(vehicle.mileage)", systemImage: "gauge")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if totalCosts > 0 {
                        Label("$\(totalCosts, specifier: "%.2f")", systemImage: "dollarsign.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(vehicle.currentValue, specifier: "%.0f")")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Text("Value")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
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
