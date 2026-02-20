import SwiftUI

struct ShareGarageView: View {
    let vehicles: [VehicleEntity]
    @Environment(\.presentationMode) var presentationMode
    @State private var renderedImage: UIImage?
    @State private var showingShareSheet = false
    
    var totalGarageValue: Double {
        vehicles.reduce(0) { $0 + $1.currentValue }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    garageCard
                        .padding(.horizontal)
                    
                    Button(action: {
                        renderAndShare()
                    }) {
                        Label("Share My Garage", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Text("Share your garage collection with friends")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical)
            }
            .navigationTitle("Share Garage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let image = renderedImage {
                    ShareSheet(items: [image])
                }
            }
        }
    }
    
    // MARK: - Garage Card
    
    private var garageCard: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "car.2.fill")
                        .font(.title2)
                    Text("My Garage")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                
                Text("\(vehicles.count) Vehicle\(vehicles.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            // Vehicle List
            VStack(spacing: 0) {
                ForEach(Array(vehicles.prefix(6).enumerated()), id: \.element.id) { index, vehicle in
                    HStack(spacing: 12) {
                        if let imageData = vehicle.imageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(colors: [.blue.opacity(0.5), .purple.opacity(0.5)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "car.fill")
                                        .foregroundColor(.white)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            
                            if let trim = vehicle.trim {
                                Text(trim)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if vehicle.currentValue > 0 {
                            Text("$\(Int(vehicle.currentValue))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    
                    if index < min(vehicles.count - 1, 5) {
                        Divider().padding(.horizontal, 16)
                    }
                }
                
                if vehicles.count > 6 {
                    Text("+\(vehicles.count - 6) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                }
            }
            .padding(.vertical, 8)
            
            // Footer
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Garage Value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(Int(totalGarageValue))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Garage Value Tracker")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color(.systemGray6))
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 8)
    }
    
    // MARK: - Render and Share
    
    @MainActor
    private func renderAndShare() {
        let renderer = ImageRenderer(content: garageCard.frame(width: 380))
        renderer.scale = 3
        
        if let image = renderer.uiImage {
            renderedImage = image
            showingShareSheet = true
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
