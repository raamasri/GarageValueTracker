import SwiftUI

struct WatchlistDetailView: View {
    let vehicleName: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(vehicleName)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Coming Soon")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Detailed market information and price tracking will be available here.")
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WatchlistDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WatchlistDetailView(vehicleName: "2020 Toyota Camry")
        }
    }
}
