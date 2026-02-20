import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \VehicleEntity.year, ascending: false)],
        animation: .default)
    private var vehicles: FetchedResults<VehicleEntity>
    
    @State private var showingAddVehicle = false
    @State private var showingAddWishlist = false
    @State private var showingSettings = false
    @State private var showingAddOptions = false
    @State private var showingShareGarage = false
    @State private var selectedTab: GarageListView.GarageTab = .myGarage
    
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
                        
                        HStack(spacing: 16) {
                            Button(action: {
                                showingAddVehicle = true
                            }) {
                                VStack {
                                    Image(systemName: "car.fill")
                                        .font(.title)
                                    Text("Add Vehicle")
                                        .font(.headline)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                            }
                            
                            Button(action: {
                                showingAddWishlist = true
                            }) {
                                VStack {
                                    Image(systemName: "heart.fill")
                                        .font(.title)
                                    Text("Add Wishlist")
                                        .font(.headline)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                            }
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
                        HStack(spacing: 16) {
                            Button(action: {
                                showingShareGarage = true
                            }) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            
                            Menu {
                                Button(action: {
                                    showingAddVehicle = true
                                }) {
                                    Label("Add to My Garage", systemImage: "car.fill")
                                }
                                
                                Button(action: {
                                    showingAddWishlist = true
                                }) {
                                    Label("Add to Wishlist", systemImage: "heart.fill")
                                }
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddVehicle) {
                AddVehicleView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingAddWishlist) {
                AddWishlistVehicleView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingShareGarage) {
                ShareGarageView(vehicles: Array(vehicles))
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
