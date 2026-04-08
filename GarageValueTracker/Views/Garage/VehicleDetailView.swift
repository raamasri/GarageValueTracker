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
    @State private var showingShopFinder = false
    @State private var showingRegistrationInspection = false
    @State private var showingAccidentHistory = false
    @State private var showingKnownIssues = false
    @State private var showingTCO = false
    @State private var showingDepreciationChart = false
    @State private var showingLoanTracker = false
    @State private var showingSellAdvisor = false
    @State private var showingMapTimeline = false
    @State private var showingScenarioModel = false
    @State private var showingAskAI = false
    @State private var showingMileageEditor = false
    @State private var dashboardScore: DashboardScore?
    @State private var knownIssueCount: Int = 0
    
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
                
                // Mileage Card (tappable to edit)
                Button(action: { showingMileageEditor = true }) {
                    HStack(spacing: 14) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 28))
                            .foregroundColor(.cyan)
                            .frame(width: 44, height: 44)
                            .background(Color.cyan.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Odometer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            Text(vehicle.mileage > 0 ? "\(NumberFormatter.localizedString(from: NSNumber(value: vehicle.mileage), number: .decimal)) mi" : "Not set")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundColor(.cyan)
                            Text("Update")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)
                
                // AI Signal + Market Range + Risk + Cost-to-Hold
                VehicleDetailInlineSection(vehicle: vehicle)
                    .environment(\.managedObjectContext, viewContext)
                
                // Ask AI Button
                Button(action: { showingAskAI = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                        Text("Ask AI about this vehicle")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    }
                    .foregroundColor(Color(red: 0.83, green: 0.66, blue: 0.26))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.83, green: 0.66, blue: 0.26).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 0.83, green: 0.66, blue: 0.26).opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                
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
                
                // TCO & Depreciation Row
                HStack(spacing: 12) {
                    Button(action: {
                        showingTCO = true
                    }) {
                        Label("Ownership Cost", systemImage: "chart.pie.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    
                    Button(action: {
                        showingDepreciationChart = true
                    }) {
                        Label("Value Chart", systemImage: "chart.xyaxis.line")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: [.green.opacity(0.8), .teal.opacity(0.8)],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.horizontal)
                
                // Loan & Sell Advisor Row
                HStack(spacing: 12) {
                    Button(action: {
                        showingLoanTracker = true
                    }) {
                        Label("Loan Tracker", systemImage: "banknote")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: [.indigo.opacity(0.8), .blue.opacity(0.8)],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: .indigo.opacity(0.3), radius: 8, x: 0, y: 4)
                    }

                    Button(action: {
                        showingSellAdvisor = true
                    }) {
                        Label("Sell Advisor", systemImage: "tag.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: [.orange.opacity(0.8), .red.opacity(0.7)],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.horizontal)

                // Market & Risk Row
                HStack(spacing: 12) {
                    NavigationLink(destination: VehicleMarketCardView(
                        make: vehicle.make, model: vehicle.model,
                        year: Int(vehicle.year), mileage: Int(vehicle.mileage),
                        trim: vehicle.trim
                    )) {
                        Label("Market Card", systemImage: "chart.bar.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: [.teal.opacity(0.8), .cyan.opacity(0.8)],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: .teal.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    
                    Button(action: {
                        showingScenarioModel = true
                    }) {
                        Label("Scenario", systemImage: "wand.and.stars")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: [.pink.opacity(0.8), .purple.opacity(0.7)],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: .pink.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
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
                
                // Action Buttons Row 3
                HStack(spacing: 12) {
                    NavigationLink(destination: FuelTrackerView(vehicle: vehicle)) {
                        Label("Fuel Tracker", systemImage: "fuelpump.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                ZStack {
                                    Color.cyan.opacity(0.8)
                                    Color.white.opacity(0.15)
                                }
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: .cyan.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    
                    Button(action: {
                        showingRegistrationInspection = true
                    }) {
                        Label("Registration", systemImage: "doc.text.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                ZStack {
                                    Color.indigo.opacity(0.8)
                                    Color.white.opacity(0.15)
                                }
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: .indigo.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.horizontal)
                
                // Action Buttons Row 4
                HStack(spacing: 12) {
                    Button(action: {
                        showingShopFinder = true
                    }) {
                        Label("Find Shops", systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                ZStack {
                                    Color.teal.opacity(0.8)
                                    Color.white.opacity(0.15)
                                }
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: .teal.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    
                    Button(action: {
                        showingAccidentHistory = true
                    }) {
                        Label("Accidents", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                ZStack {
                                    Color.red.opacity(0.8)
                                    Color.white.opacity(0.15)
                                }
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.horizontal)
                
                // Map Timeline Button
                Button(action: {
                    showingMapTimeline = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "map.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Map Timeline")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text("See where your car has been")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)
                
                // Known Issues Card
                if knownIssueCount > 0 {
                    Button(action: {
                        showingKnownIssues = true
                    }) {
                        HStack {
                            Image(systemName: "exclamationmark.bubble.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Community Reports")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Text("\(knownIssueCount) known issue\(knownIssueCount == 1 ? "" : "s") reported for this vehicle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                }
                
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
                DashboardScoreDetailView(score: score, vehicle: vehicle)
                    .environment(\.managedObjectContext, viewContext)
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
        .sheet(isPresented: $showingShopFinder) {
            ServiceShopFinderView(vehicle: vehicle)
        }
        .sheet(isPresented: $showingRegistrationInspection) {
            RegistrationInspectionView(vehicle: vehicle)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingAccidentHistory) {
            AccidentHistoryView(vehicle: vehicle)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingKnownIssues) {
            KnownIssuesView(make: vehicle.make, model: vehicle.model, year: Int(vehicle.year))
        }
        .sheet(isPresented: $showingTCO) {
            TotalCostOfOwnershipView(vehicle: vehicle)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingDepreciationChart) {
            DepreciationChartView(vehicle: vehicle)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingLoanTracker) {
            LoanTrackerView(vehicle: vehicle)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingSellAdvisor) {
            SellAdvisorView(vehicle: vehicle)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingMapTimeline) {
            MapTimelineView(vehicle: vehicle)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingScenarioModel) {
            ScenarioModelView(vehicle: vehicle)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingAskAI) {
            AskAIView(vehicle: vehicle)
        }
        .sheet(isPresented: $showingMileageEditor) {
            MileageEditorView(vehicle: vehicle)
                .environment(\.managedObjectContext, viewContext)
        }
        .onAppear {
            calculateDashboardScore()
            knownIssueCount = KnownIssuesService.shared.getIssues(
                make: vehicle.make, model: vehicle.model, year: Int(vehicle.year)
            ).count
        }
        .onChange(of: costEntries.count) {
            calculateDashboardScore()
        }
    }
    
    private func calculateDashboardScore() {
        dashboardScore = DashboardScoreService.shared.calculateDashboardScore(for: vehicle, costEntryCount: costEntries.count)
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

// MARK: - Mileage Editor
struct MileageEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    let vehicle: VehicleEntity
    @State private var mileageText: String
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(vehicle: VehicleEntity) {
        self.vehicle = vehicle
        _mileageText = State(initialValue: vehicle.mileage > 0 ? "\(vehicle.mileage)" : "")
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 56))
                        .foregroundColor(.cyan)
                    
                    Text("Update Odometer")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if vehicle.mileage > 0 {
                        Text("Current: \(NumberFormatter.localizedString(from: NSNumber(value: vehicle.mileage), number: .decimal)) mi")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 20)
                
                VStack(spacing: 12) {
                    TextField("Enter current mileage", text: $mileageText)
                        .keyboardType(.numberPad)
                        .font(.system(size: 36, weight: .bold))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    
                    Text("miles")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 32)
                
                if showError {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                Button(action: saveMileage) {
                    Text("Save")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.cyan)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .navigationTitle("Odometer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func saveMileage() {
        guard let value = Int32(mileageText), value > 0 else {
            errorMessage = "Please enter a valid mileage"
            showError = true
            return
        }
        
        vehicle.mileage = value
        vehicle.updatedAt = Date()
        
        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
            showError = true
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
