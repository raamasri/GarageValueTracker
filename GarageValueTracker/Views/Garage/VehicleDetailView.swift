import SwiftUI
import CoreData

struct VehicleDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let vehicle: VehicleEntity
    
    @State private var showingAddCost = false
    @State private var selectedCostEntry: CostEntryEntity?
    @State private var showingReceiptImage = false
    
    // Fetch cost entries for this vehicle
    @FetchRequest var costEntries: FetchedResults<CostEntryEntity>
    
    init(vehicle: VehicleEntity) {
        self.vehicle = vehicle
        
        // Initialize fetch request for this vehicle's cost entries
        _costEntries = FetchRequest<CostEntryEntity>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CostEntryEntity.date, ascending: false)],
            predicate: NSPredicate(format: "vehicleID == %@", vehicle.id as CVarArg),
            animation: .default
        )
    }
    
    var totalCosts: Double {
        costEntries.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Vehicle Header
                VStack(spacing: 8) {
                    Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let trim = vehicle.trim {
                        Text(trim)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                // Cost Summary Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Total Costs")
                        .font(.headline)
                    
                    Text("$\(totalCosts, specifier: "%.2f")")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("\(costEntries.count) entries")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Add Cost Button
                Button(action: {
                    showingAddCost = true
                }) {
                    Label("Add Maintenance Cost", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Cost Entries List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cost History")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if costEntries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No costs recorded yet")
                                .foregroundColor(.secondary)
                            Text("Tap 'Add Maintenance Cost' to get started")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(costEntries) { entry in
                            CostEntryRow(entry: entry)
                                .onTapGesture {
                                    if entry.receiptImageData != nil {
                                        selectedCostEntry = entry
                                        showingReceiptImage = true
                                    }
                                }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Vehicle Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddCost) {
            AddCostEntryView(vehicleID: vehicle.id)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingReceiptImage) {
            if let entry = selectedCostEntry,
               let imageData = entry.receiptImageData,
               let image = UIImage(data: imageData) {
                ReceiptImageView(image: image, entry: entry)
            }
        }
    }
}

// Cost Entry Row Component
struct CostEntryRow: View {
    let entry: CostEntryEntity
    
    private var category: CostCategory? {
        CostCategory(rawValue: entry.category)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            Image(systemName: category?.icon ?? "dollarsign.circle")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.category)
                        .font(.headline)
                    
                    if entry.receiptImageData != nil {
                        Image(systemName: "paperclip")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let merchant = entry.merchantName {
                    Text(merchant)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Text("$\(entry.amount, specifier: "%.2f")")
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// Receipt Image Viewer
struct ReceiptImageView: View {
    @Environment(\.presentationMode) var presentationMode
    let image: UIImage
    let entry: CostEntryEntity
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale *= delta
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    if scale < 1.0 {
                                        withAnimation {
                                            scale = 1.0
                                        }
                                    } else if scale > 4.0 {
                                        withAnimation {
                                            scale = 4.0
                                        }
                                    }
                                }
                        )
                }
                
                VStack {
                    Spacer()
                    
                    // Receipt info overlay
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.category)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                if let merchant = entry.merchantName {
                                    Text(merchant)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            
                            Spacer()
                            
                            Text("$\(entry.amount, specifier: "%.2f")")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        Text(entry.date, style: .date)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                    .padding()
                }
            }
            .navigationTitle("Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// Preview
struct VehicleDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let vehicle = VehicleEntity(context: context)
        vehicle.id = UUID()
        vehicle.make = "Toyota"
        vehicle.model = "Camry"
        vehicle.year = 2020
        vehicle.trim = "XSE"
        
        return NavigationView {
            VehicleDetailView(vehicle: vehicle)
                .environment(\.managedObjectContext, context)
        }
    }
}
