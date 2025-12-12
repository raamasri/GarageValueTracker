import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GarageListView()
                .tabItem {
                    Label("Garage", systemImage: "car.2")
                }
                .tag(0)
            
            WatchlistView()
                .tabItem {
                    Label("Watchlist", systemImage: "star")
                }
                .tag(1)
            
            DealCheckerView()
                .tabItem {
                    Label("Deal Check", systemImage: "checkmark.circle")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [VehicleEntity.self, CostEntryEntity.self])
}



