import SwiftUI

struct UpgradePathView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "arrow.up.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Upgrade Path")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Coming Soon")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("This feature will suggest potential vehicle upgrades based on your budget and preferences.")
                    .multilineTextAlignment(.center)
                    .padding()
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("Upgrade Path")
        }
    }
}

struct UpgradePathView_Previews: PreviewProvider {
    static var previews: some View {
        UpgradePathView()
    }
}
