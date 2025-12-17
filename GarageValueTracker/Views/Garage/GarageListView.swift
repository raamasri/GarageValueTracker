import SwiftUI
import CoreData

struct GarageListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \VehicleEntity.year, ascending: false)],
        animation: .default)
    private var vehicles: FetchedResults<VehicleEntity>
    
    @State private var currentIndex = 0
    
    var body: some View {
        GeometryReader { geometry in
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

struct GarageListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GarageListView()
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}
