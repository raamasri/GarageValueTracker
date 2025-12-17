import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \VehicleEntity.year, ascending: false)],
        animation: .default)
    private var vehicles: FetchedResults<VehicleEntity>
    
    @State private var showingAddVehicle = false
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if vehicles.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.blue)
                        
                        Text("Welcome to Garage Value Tracker")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Add your first vehicle to get started")
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            showingAddVehicle = true
                        }) {
                            Label("Add Vehicle", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.top)
                    }
                    .padding()
                } else {
                    // Vehicle list
                    GarageListView()
                }
            }
            .navigationTitle("My Garage")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                    }
                }
                
                if !vehicles.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingAddVehicle = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddVehicle) {
                AddVehicleView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
