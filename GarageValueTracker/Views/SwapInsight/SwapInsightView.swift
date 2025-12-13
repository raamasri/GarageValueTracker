import SwiftUI

struct SwapInsightView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Swap Insight")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Coming Soon")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("This feature will help you determine if swapping your current vehicle for another is a good financial decision.")
                    .multilineTextAlignment(.center)
                    .padding()
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("Swap Insight")
        }
    }
}

struct SwapInsightView_Previews: PreviewProvider {
    static var previews: some View {
        SwapInsightView()
    }
}
