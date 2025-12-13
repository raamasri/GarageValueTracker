import SwiftUI

struct WatchlistView: View {
    @State private var watchlistVehicles: [String] = []
    
    var body: some View {
        NavigationView {
            Group {
                if watchlistVehicles.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "star.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                        
                        Text("No Vehicles in Watchlist")
                            .font(.headline)
                        
                        Text("Add vehicles you're interested in to track their market values.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding()
                        
                        Button(action: {
                            // Add vehicle logic
                        }) {
                            Label("Add to Watchlist", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .padding()
                                .background(Color.yellow)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                } else {
                    List {
                        ForEach(watchlistVehicles, id: \.self) { vehicle in
                            Text(vehicle)
                        }
                    }
                }
            }
            .navigationTitle("Watchlist")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Add vehicle
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

struct WatchlistView_Previews: PreviewProvider {
    static var previews: some View {
        WatchlistView()
    }
}
