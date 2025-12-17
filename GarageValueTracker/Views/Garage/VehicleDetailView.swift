import SwiftUI
import CoreData

struct VehicleDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let vehicle: VehicleEntity
    
    @State private var showingAddCost = false
    @State private var selectedCostEntry: CostEntryEntity?
    @State private var showingReceiptImage = false
    @State private var showingTrimComparison = false
    @State private var showingDashboardScoreDetails = false
    @State private var showingMaintenanceInsights = false
    @State private var showingInsuranceTracking = false
    @State private var showingMaintenanceScheduler = false
    @State private var dashboardScore: DashboardScore?
    
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
                // Vehicle Photo
                if let imageData = vehicle.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [.clear, .black.opacity(0.4)]),
                                startPoint: .center,
                                endPoint: .bottom
                            )
                        )
                }
                
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
                
                // Dashboard Score Card
                if let score = dashboardScore {
                    Button(action: {
                        showingDashboardScoreDetails = true
                    }) {
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Your Dashboard Score")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(score.message)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                
                                Spacer()
                                
                                // Circular Progress
                                ZStack {
                                    Circle()
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                                        .frame(width: 80, height: 80)
                                    
                                    Circle()
                                        .trim(from: 0, to: CGFloat(score.percentage) / 100)
                                        .stroke(dashboardScoreColor(score.percentage), lineWidth: 10)
                                        .frame(width: 80, height: 80)
                                        .rotationEffect(.degrees(-90))
                                        .animation(.easeInOut, value: score.percentage)
                                    
                                    Text("\(score.percentage)%")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(dashboardScoreColor(score.percentage))
                                }
                            }
                            
                            if score.percentage < 100 {
                                Divider()
                                
                                HStack {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .foregroundColor(.blue)
                                    Text("Improve Your Score")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        .padding(.horizontal)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
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
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                .padding(.horizontal)
                
                // Action Buttons Row 1
                HStack(spacing: 12) {
                    Button(action: {
                        showingAddCost = true
                    }) {
                        Label("Add Cost", systemImage: "plus.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                ZStack {
                                    Color.blue.opacity(0.8)
                                    Color.white.opacity(0.15)
                                }
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    
                    Button(action: {
                        showingMaintenanceInsights = true
                    }) {
                        Label("Insights", systemImage: "chart.bar.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                ZStack {
                                    Color.green.opacity(0.8)
                                    Color.white.opacity(0.15)
                                }
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.horizontal)
                
                // Action Buttons Row 2
                HStack(spacing: 12) {
                    Button(action: {
                        showingInsuranceTracking = true
                    }) {
                        Label("Insurance", systemImage: "shield.checkered")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                ZStack {
                                    Color.purple.opacity(0.8)
                                    Color.white.opacity(0.15)
                                }
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    
                    Button(action: {
                        showingMaintenanceScheduler = true
                    }) {
                        Label("Schedule", systemImage: "calendar.badge.clock")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                ZStack {
                                    Color.orange.opacity(0.8)
                                    Color.white.opacity(0.15)
                                }
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
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
        .sheet(isPresented: $showingTrimComparison) {
            TrimComparisonView(vehicle: vehicle)
        }
        .sheet(isPresented: $showingDashboardScoreDetails) {
            if let score = dashboardScore {
                DashboardScoreDetailView(score: score)
            }
        }
        .sheet(isPresented: $showingMaintenanceInsights) {
            MaintenanceInsightsView(vehicle: vehicle, costEntries: Array(costEntries))
        }
        .sheet(isPresented: $showingInsuranceTracking) {
            InsuranceTrackingView(vehicle: vehicle)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingMaintenanceScheduler) {
            MaintenanceSchedulerView(vehicle: vehicle)
                .environment(\.managedObjectContext, viewContext)
        }
        .onAppear {
            calculateDashboardScore()
        }
        .onChange(of: costEntries.count) {
            calculateDashboardScore()
        }
    }
    
    private func calculateDashboardScore() {
        dashboardScore = DashboardScoreService.shared.calculateDashboardScore(for: vehicle)
    }
    
    private func dashboardScoreColor(_ percentage: Int) -> Color {
        switch percentage {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default: return .red
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
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
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
