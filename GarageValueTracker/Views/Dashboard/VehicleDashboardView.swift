import SwiftUI
import CoreData
import PhotosUI

struct VehicleDashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let vehicle: VehicleEntity
    
    @State private var dashboardScore: DashboardScore?
    @State private var showingScoreDetails = false
    @State private var showingAddReminder = false
    @State private var showingMileageEdit = false
    @State private var showingValueUpdate = false
    @State private var showingRecalls = false
    @State private var recallCount: Int?
    @State private var showingRegistrationInspection = false
    @State private var showingShopFinder = false
    @State private var showingLoanTracker = false
    @State private var showingSellAdvisor = false
    
    // Fetch service reminders
    @FetchRequest var serviceReminders: FetchedResults<ServiceReminderEntity>
    
    // Fetch fuel entries
    @FetchRequest var fuelEntries: FetchedResults<FuelEntryEntity>
    
    // Fetch cost entries for score calculation
    @FetchRequest var costEntries: FetchedResults<CostEntryEntity>
    
    init(vehicle: VehicleEntity) {
        self.vehicle = vehicle
        
        _serviceReminders = FetchRequest<ServiceReminderEntity>(
            sortDescriptors: [NSSortDescriptor(keyPath: \ServiceReminderEntity.dueDate, ascending: true)],
            predicate: NSPredicate(format: "vehicleID == %@ AND isCompleted == NO", vehicle.id as CVarArg),
            animation: .default
        )
        
        _fuelEntries = FetchRequest<FuelEntryEntity>(
            sortDescriptors: [NSSortDescriptor(keyPath: \FuelEntryEntity.date, ascending: false)],
            predicate: NSPredicate(format: "vehicleID == %@", vehicle.id as CVarArg),
            animation: .default
        )
        
        _costEntries = FetchRequest<CostEntryEntity>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CostEntryEntity.date, ascending: false)],
            predicate: NSPredicate(format: "vehicleID == %@", vehicle.id as CVarArg),
            animation: .default
        )
    }
    
    var averageMPG: Double? {
        guard fuelEntries.count >= 2 else { return nil }
        
        var totalMPG: Double = 0
        var count: Int = 0
        
        for i in 0..<(fuelEntries.count - 1) {
            let current = fuelEntries[i]
            let previous = fuelEntries[i + 1]
            
            if let mpg = current.calculateMPG(previousEntry: previous) {
                totalMPG += mpg
                count += 1
            }
        }
        
        return count > 0 ? totalMPG / Double(count) : nil
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Vehicle Header with Photo and Name
                VStack(spacing: 12) {
                    if let imageData = vehicle.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Text(vehicle.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        Label("\(vehicle.mileage)", systemImage: "gauge")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        Button(action: {
                            showingMileageEdit = true
                        }) {
                            Image(systemName: "pencil")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
                
                // Dashboard Score Card
                if let score = dashboardScore {
                    Button(action: {
                        showingScoreDetails = true
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
                                        .stroke(scoreColor(score.percentage), lineWidth: 10)
                                        .frame(width: 80, height: 80)
                                        .rotationEffect(.degrees(-90))
                                        .animation(.easeInOut, value: score.percentage)
                                    
                                    Text("\(score.percentage)%")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(scoreColor(score.percentage))
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
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                }
                
                // Vehicle Value Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Value")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            Text(formatPrice(vehicle.currentValue))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            showingValueUpdate = true
                        }) {
                            Text("Update Value")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if let lastUpdate = vehicle.lastValuationUpdate {
                        Text("Last updated \(formatDate(lastUpdate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                .padding(.horizontal)
                
                // Service Reminders Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Service Reminders")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            showingAddReminder = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if serviceReminders.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            
                            Text("No upcoming service reminders")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                showingAddReminder = true
                            }) {
                                Text("Add First Reminder")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    } else {
                        ForEach(serviceReminders) { reminder in
                            ServiceReminderRow(reminder: reminder, currentMileage: Int(vehicle.mileage))
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                .padding(.horizontal)
                
                // Safety Recalls Card
                Button(action: { showingRecalls = true }) {
                    HStack {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.title2)
                            .foregroundColor(recallCount ?? 0 > 0 ? .red : .green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Safety Recalls")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            if let count = recallCount {
                                Text(count == 0 ? "No Recalls Found" : "\(count) Recall\(count == 1 ? "" : "s") Found")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(count > 0 ? .red : .primary)
                            } else {
                                Text("Tap to check NHTSA")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)
                
                // Registration & Inspection Card
                Button(action: { showingRegistrationInspection = true }) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .font(.title2)
                                .foregroundColor(.indigo)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Registration & Inspection")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                if let regDate = vehicle.registrationRenewalDate {
                                    let days = Calendar.current.dateComponents([.day], from: Date(), to: regDate).day ?? 0
                                    if days < 0 {
                                        Text("Registration Overdue")
                                            .font(.headline)
                                            .foregroundColor(.red)
                                    } else if days <= 30 {
                                        Text("Registration due in \(days) days")
                                            .font(.headline)
                                            .foregroundColor(.orange)
                                    } else {
                                        Text("Registration: \(formatDate(regDate))")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                    }
                                } else if let inspDate = vehicle.inspectionDueDate {
                                    let days = Calendar.current.dateComponents([.day], from: Date(), to: inspDate).day ?? 0
                                    if days < 0 {
                                        Text("Inspection Overdue")
                                            .font(.headline)
                                            .foregroundColor(.red)
                                    } else if days <= 30 {
                                        Text("Inspection due in \(days) days")
                                            .font(.headline)
                                            .foregroundColor(.orange)
                                    } else {
                                        Text("Inspection: \(formatDate(inspDate))")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                    }
                                } else {
                                    Text("Tap to set dates")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        
                        if vehicle.registrationRenewalDate != nil && vehicle.inspectionDueDate != nil {
                            let inspDays = Calendar.current.dateComponents([.day], from: Date(), to: vehicle.inspectionDueDate!).day ?? 0
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.caption)
                                    .foregroundColor(inspDays < 0 ? .red : (inspDays <= 30 ? .orange : .green))
                                Text("Inspection: \(formatDate(vehicle.inspectionDueDate!))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)
                
                // Find Service Shops Card
                Button(action: { showingShopFinder = true }) {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.title2)
                            .foregroundColor(.teal)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Service Shops")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            Text("Find Nearby Shops")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)
                
                // Loan & Sell Advisor Cards
                HStack(spacing: 12) {
                    Button(action: { showingLoanTracker = true }) {
                        HStack {
                            Image(systemName: "banknote")
                                .font(.title3)
                                .foregroundColor(.indigo)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Loan Tracker")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Text("Payments & Equity")
                                    .font(.caption2)
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
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { showingSellAdvisor = true }) {
                        HStack {
                            Image(systemName: "tag.fill")
                                .font(.title3)
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sell Advisor")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Text("Best time to sell?")
                                    .font(.caption2)
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
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)

                // Fuel Tracker Card (if has fuel data)
                if !fuelEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "fuelpump.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Fuel Tracker")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                if let mpg = averageMPG {
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text(String(format: "%.1f", mpg))
                                            .font(.title)
                                            .fontWeight(.bold)
                                        Text("AVG. MPG")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        
                        if let lastFill = fuelEntries.first {
                            Text("Last Fill-Up - \(formatDate(lastFill.date))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            calculateDashboardScore()
            checkRecalls()
        }
        .sheet(isPresented: $showingScoreDetails) {
            DashboardScoreDetailView(score: dashboardScore ?? DashboardScore(percentage: 0, completedItems: 0, totalItems: 11, missingItems: [], message: ""), vehicle: vehicle)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingAddReminder) {
            DashboardAddServiceReminderView(vehicle: vehicle, onSave: {
                calculateDashboardScore()
            })
            .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingMileageEdit) {
            VehicleMileageEditView(vehicle: vehicle)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingValueUpdate) {
            VehicleValueUpdateView(vehicle: vehicle)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingRecalls) {
            RecallsView(vehicle: vehicle)
        }
        .sheet(isPresented: $showingRegistrationInspection) {
            RegistrationInspectionView(vehicle: vehicle)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingShopFinder) {
            ServiceShopFinderView(vehicle: vehicle)
        }
        .sheet(isPresented: $showingLoanTracker) {
            LoanTrackerView(vehicle: vehicle)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingSellAdvisor) {
            SellAdvisorView(vehicle: vehicle)
                .environment(\.managedObjectContext, viewContext)
        }
    }
    
    private func calculateDashboardScore() {
        dashboardScore = DashboardScoreService.shared.calculateDashboardScore(for: vehicle, costEntryCount: costEntries.count)
    }
    
    private func checkRecalls() {
        RecallsAPIService.shared.getRecalls(
            make: vehicle.make,
            model: vehicle.model,
            modelYear: Int(vehicle.year)
        ) { result in
            if case .success(let recalls) = result {
                recallCount = recalls.count
                if recalls.count > 0 {
                    NotificationService.shared.sendRecallAlert(vehicleName: vehicle.displayName, recallCount: recalls.count)
                }
            }
        }
    }
    
    private func scoreColor(_ percentage: Int) -> Color {
        switch percentage {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default: return .red
        }
    }
    
    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "$\(Int(price))"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// Service Reminder Row Component
struct ServiceReminderRow: View {
    let reminder: ServiceReminderEntity
    let currentMileage: Int
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Icon
                Image(systemName: reminder.iconName)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 35)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.serviceType)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)
                                .cornerRadius(2)
                            
                            Rectangle()
                                .fill(progressColor)
                                .frame(width: geometry.size.width * CGFloat(min(reminder.progressPercentage(currentMileage: currentMileage) / 100, 1.0)), height: 4)
                                .cornerRadius(2)
                        }
                    }
                    .frame(height: 4)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(timeRemainingText)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(reminder.isOverdue ? .red : .primary)
                    
                    Text(timeRemainingLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
        }
    }
    
    private var timeRemainingText: String {
        if reminder.isOverdue {
            return "Overdue"
        }
        
        let months = reminder.monthsRemaining
        let weeks = reminder.weeksRemaining
        
        if months >= 2 {
            return "\(months)"
        } else if weeks > 0 {
            return "\(weeks)"
        } else {
            let days = reminder.daysRemaining
            return "\(max(days, 0))"
        }
    }
    
    private var timeRemainingLabel: String {
        if reminder.isOverdue {
            return ""
        }
        
        let months = reminder.monthsRemaining
        let weeks = reminder.weeksRemaining
        
        if months >= 1 {
            return months == 1 ? "Month Left" : "Months Left"
        } else if weeks > 0 {
            return weeks == 1 ? "Week Left" : "Weeks Left"
        } else {
            return "Days Left"
        }
    }
    
    private var progressColor: Color {
        let progress = reminder.progressPercentage(currentMileage: currentMileage)
        if reminder.isOverdue {
            return .red
        } else if progress > 80 {
            return .orange
        } else {
            return .blue
        }
    }
}

// Dashboard Score Detail View
struct DashboardScoreDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    let score: DashboardScore
    let vehicle: VehicleEntity
    
    // Navigation states for different actions
    @State private var showingPhotoEdit = false
    @State private var showingVINEdit = false
    @State private var showingMileageEdit = false
    @State private var showingLocationEdit = false
    @State private var showingTrimSelection = false
    @State private var showingInsuranceEdit = false
    @State private var showingValueUpdate = false
    @State private var showingNotesEdit = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(spacing: 12) {
                        Text("\(score.percentage)%")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(scoreColor)
                        
                        Text("Dashboard Complete")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Text("\(score.completedItems) of \(score.totalItems) items")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                
                if !score.missingItems.isEmpty {
                    Section(header: Text("Improve Your Score")) {
                        ForEach(score.missingItems, id: \.self) { item in
                            Button(action: {
                                handleItemAction(item)
                            }) {
                                HStack {
                                    Image(systemName: iconForItem(item))
                                        .foregroundColor(.orange)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        
                                        Text("Tap to add")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Dashboard Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPhotoEdit) {
                VehiclePhotoEditView(vehicle: vehicle)
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingVINEdit) {
                VehicleVINEditView(vehicle: vehicle)
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingMileageEdit) {
                VehicleMileageEditView(vehicle: vehicle)
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingLocationEdit) {
                VehicleLocationEditView(vehicle: vehicle)
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingTrimSelection) {
                VehicleTrimEditView(vehicle: vehicle)
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingInsuranceEdit) {
                InsuranceTrackingView(vehicle: vehicle)
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingValueUpdate) {
                VehicleValueUpdateView(vehicle: vehicle)
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingNotesEdit) {
                VehicleNotesEditView(vehicle: vehicle)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
    
    private var scoreColor: Color {
        switch score.percentage {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default: return .red
        }
    }
    
    private func iconForItem(_ item: String) -> String {
        if item.contains("photo") {
            return "camera.fill"
        } else if item.contains("VIN") {
            return "barcode.viewfinder"
        } else if item.contains("mileage") {
            return "gauge"
        } else if item.contains("location") {
            return "location.fill"
        } else if item.contains("trim") {
            return "list.bullet.rectangle"
        } else if item.contains("insurance") {
            return "shield.checkered"
        } else if item.contains("premium") {
            return "dollarsign.circle"
        } else if item.contains("value") {
            return "chart.line.uptrend.xyaxis"
        } else if item.contains("notes") || item.contains("documentation") {
            return "doc.text"
        } else {
            return "circle"
        }
    }
    
    private func handleItemAction(_ item: String) {
        if item.contains("photo") {
            showingPhotoEdit = true
        } else if item.contains("VIN") {
            showingVINEdit = true
        } else if item.contains("mileage") {
            showingMileageEdit = true
        } else if item.contains("location") {
            showingLocationEdit = true
        } else if item.contains("trim") {
            showingTrimSelection = true
        } else if item.contains("insurance information") || item.contains("insurance premium") {
            showingInsuranceEdit = true
        } else if item.contains("value") {
            showingValueUpdate = true
        } else if item.contains("notes") || item.contains("documentation") {
            showingNotesEdit = true
        }
    }
}

// MARK: - Helper Edit Views

// Vehicle Photo Edit View
struct VehiclePhotoEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    let vehicle: VehicleEntity
    
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Add Vehicle Photo")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                if let photoData = selectedPhotoData ?? vehicle.imageData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 10)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 250)
                        
                        VStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("No Photo")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Choose Photo", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .onChange(of: selectedPhotoItem) {
                    Task {
                        if let item = selectedPhotoItem,
                           let data = try? await item.loadTransferable(type: Data.self) {
                            selectedPhotoData = compressImage(data)
                        }
                    }
                }
                .padding(.horizontal)
                
                if selectedPhotoData != nil {
                    Button(action: savePhoto) {
                        Text("Save Photo")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func savePhoto() {
        vehicle.imageData = selectedPhotoData
        vehicle.updatedAt = Date()
        
        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving photo: \(error)")
        }
    }
    
    private func compressImage(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return image.jpegData(compressionQuality: 0.7)
    }
}

// Vehicle VIN Edit View with NHTSA decode
struct VehicleVINEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    let vehicle: VehicleEntity
    
    @State private var vin: String
    @State private var isDecoding = false
    @State private var decodeResult: VINDecodeResult?
    @State private var decodeError: String?
    
    init(vehicle: VehicleEntity) {
        self.vehicle = vehicle
        _vin = State(initialValue: vehicle.vin ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Vehicle Identification Number")) {
                    TextField("Enter 17-character VIN", text: $vin)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onChange(of: vin) {
                            decodeResult = nil
                            decodeError = nil
                        }
                    
                    if vin.count == 17 {
                        Button(action: decodeVIN) {
                            HStack {
                                if isDecoding {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "magnifyingglass")
                                }
                                Text(isDecoding ? "Looking up VIN..." : "Decode VIN")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(isDecoding)
                    } else {
                        Text("\(vin.count)/17 characters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let result = decodeResult {
                    Section(header: Text("Decoded Vehicle Info")) {
                        VINInfoRow(label: "Make", value: result.make)
                        VINInfoRow(label: "Model", value: result.model)
                        VINInfoRow(label: "Year", value: "\(result.year)")
                        if let trim = result.trim {
                            VINInfoRow(label: "Trim", value: trim)
                        }
                        if let body = result.bodyClass {
                            VINInfoRow(label: "Body", value: body)
                        }
                        if let engine = result.engineDescription {
                            VINInfoRow(label: "Engine", value: engine)
                        }
                        if let drive = result.driveType {
                            VINInfoRow(label: "Drive", value: drive)
                        }
                        if let fuel = result.fuelType {
                            VINInfoRow(label: "Fuel", value: fuel)
                        }
                        if let trans = result.transmission {
                            VINInfoRow(label: "Transmission", value: trans)
                        }
                        if let plant = result.plantCity, let country = result.plantCountry {
                            VINInfoRow(label: "Built In", value: "\(plant), \(country)")
                        }
                    }
                }
                
                if let error = decodeError {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button(action: saveVIN) {
                        Text("Save VIN")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(vin.count == 17 ? .blue : .gray)
                    }
                    .disabled(vin.count != 17)
                }
            }
            .navigationTitle("Add VIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func decodeVIN() {
        isDecoding = true
        decodeError = nil
        decodeResult = nil
        
        VehicleAPIService.shared.decodeVIN(vin) { result in
            isDecoding = false
            switch result {
            case .success(let decoded):
                decodeResult = decoded
            case .failure(let error):
                decodeError = error.localizedDescription
            }
        }
    }
    
    private func saveVIN() {
        vehicle.vin = vin.uppercased()
        vehicle.updatedAt = Date()
        
        if let result = decodeResult {
            if let trim = result.trim, vehicle.trim == nil {
                vehicle.trim = trim
            }
        }
        
        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving VIN: \(error)")
        }
    }
}

struct VINInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// Vehicle Mileage Edit View
struct VehicleMileageEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    let vehicle: VehicleEntity
    
    @State private var mileage: String
    
    init(vehicle: VehicleEntity) {
        self.vehicle = vehicle
        _mileage = State(initialValue: vehicle.mileage > 0 ? "\(vehicle.mileage)" : "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Current Mileage")) {
                    TextField("Enter mileage", text: $mileage)
                        .keyboardType(.numberPad)
                    
                    Text("Enter the current odometer reading")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button(action: saveMileage) {
                        Text("Save Mileage")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(!mileage.isEmpty ? .blue : .gray)
                    }
                    .disabled(mileage.isEmpty)
                }
            }
            .navigationTitle("Update Mileage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func saveMileage() {
        if let miles = Int32(mileage) {
            vehicle.mileage = miles
            vehicle.updatedAt = Date()
            
            do {
                try viewContext.save()
                presentationMode.wrappedValue.dismiss()
            } catch {
                print("Error saving mileage: \(error)")
            }
        }
    }
}

// Vehicle Location Edit View
struct VehicleLocationEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    let vehicle: VehicleEntity
    
    @State private var location: String
    
    init(vehicle: VehicleEntity) {
        self.vehicle = vehicle
        _location = State(initialValue: vehicle.location ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Vehicle Location")) {
                    TextField("City, State", text: $location)
                        .textInputAutocapitalization(.words)
                    
                    Text("e.g., Los Angeles, CA")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button(action: saveLocation) {
                        Text("Save Location")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(!location.isEmpty ? .blue : .gray)
                    }
                    .disabled(location.isEmpty)
                }
            }
            .navigationTitle("Set Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func saveLocation() {
        vehicle.location = location
        vehicle.updatedAt = Date()
        
        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving location: \(error)")
        }
    }
}

// Vehicle Value Update View with market estimate
struct VehicleValueUpdateView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    let vehicle: VehicleEntity
    
    @State private var value: String
    @State private var isEstimating = false
    @State private var estimate: MarketValue?
    
    init(vehicle: VehicleEntity) {
        self.vehicle = vehicle
        _value = State(initialValue: vehicle.currentValue > 0 ? String(format: "%.0f", vehicle.currentValue) : "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Market Estimate")) {
                    if isEstimating {
                        HStack {
                            ProgressView()
                            Text("Calculating estimate...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else if let est = estimate {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Estimated Value")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatCurrency(est.averagePrice))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            HStack {
                                Text("Range")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(formatCurrency(est.lowPrice)) – \(formatCurrency(est.highPrice))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Button(action: {
                                value = String(format: "%.0f", est.averagePrice)
                            }) {
                                Text("Use This Estimate")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        
                        Text("Based on \(vehicle.year) \(vehicle.make) \(vehicle.model) depreciation, \(formatMileage(Int(vehicle.mileage))) mileage, and MSRP data.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Button(action: fetchEstimate) {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                Text("Get Market Estimate")
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                
                Section(header: Text("Your Value")) {
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("Enter value", text: $value)
                            .keyboardType(.numberPad)
                    }
                    
                    Text("Enter manually or use the estimate above")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button(action: saveValue) {
                        Text("Save Value")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(!value.isEmpty ? .blue : .gray)
                    }
                    .disabled(value.isEmpty)
                }
            }
            .navigationTitle("Update Value")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear { fetchEstimate() }
        }
    }
    
    private func fetchEstimate() {
        isEstimating = true
        MarketAPIService.shared.getMarketValue(
            make: vehicle.make,
            model: vehicle.model,
            year: Int(vehicle.year),
            mileage: Int(vehicle.mileage),
            trim: vehicle.trim,
            msrp: vehicle.trimMSRP > 0 ? vehicle.trimMSRP : nil
        ) { result in
            isEstimating = false
            if case .success(let marketValue) = result {
                estimate = marketValue
            }
        }
    }
    
    private func saveValue() {
        if let newValue = Double(value) {
            vehicle.currentValue = newValue
            vehicle.lastValuationUpdate = Date()
            vehicle.updatedAt = Date()
            
            do {
                try viewContext.save()
                presentationMode.wrappedValue.dismiss()
            } catch {
                print("Error saving value: \(error)")
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
    
    private func formatMileage(_ mileage: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: mileage)) ?? "\(mileage)") + " mi"
    }
}

// Vehicle Trim Edit View (wrapper for TrimSelectionView)
struct VehicleTrimEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    let vehicle: VehicleEntity
    
    @State private var selectedTrimData: TrimData?
    
    var body: some View {
        TrimSelectionView(
            make: vehicle.make,
            model: vehicle.model,
            year: Int(vehicle.year),
            selectedTrim: $selectedTrimData
        )
        .onChange(of: selectedTrimData) {
            if let trimData = selectedTrimData {
                vehicle.trim = trimData.trimLevel
                vehicle.trimMSRP = trimData.msrp
                vehicle.updatedAt = Date()
                
                // Try to get or create TrimEntity for the selected trim
                if let trimEntity = TrimDatabaseService.shared.getOrCreateTrimEntity(from: trimData) {
                    vehicle.selectedTrimID = trimEntity.id
                }
                
                do {
                    try viewContext.save()
                    presentationMode.wrappedValue.dismiss()
                } catch {
                    print("Error saving trim: \(error)")
                }
            }
        }
    }
}

// Vehicle Notes Edit View
struct VehicleNotesEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    let vehicle: VehicleEntity
    
    @State private var notes: String
    
    init(vehicle: VehicleEntity) {
        self.vehicle = vehicle
        _notes = State(initialValue: vehicle.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Vehicle Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 150)
                    
                    Text("Add notes, modifications, or other details about your vehicle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button(action: saveNotes) {
                        Text("Save Notes")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(!notes.isEmpty ? .blue : .gray)
                    }
                    .disabled(notes.isEmpty)
                }
            }
            .navigationTitle("Add Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func saveNotes() {
        vehicle.notes = notes
        vehicle.updatedAt = Date()
        
        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving notes: \(error)")
        }
    }
}

// MARK: - Dashboard Add Service Reminder View
struct DashboardAddServiceReminderView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    let vehicle: VehicleEntity
    let onSave: () -> Void
    
    @State private var serviceType = ""
    @State private var dueDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days from now
    @State private var dueMileage = ""
    @State private var intervalMonths = ""
    @State private var intervalMileage = ""
    @State private var notes = ""
    @State private var selectedIcon = "wrench.and.screwdriver"
    
    private let serviceIcons = [
        "wrench.and.screwdriver", "drop.fill", "car.fill",
        "fanblades.fill", "battery.100", "brake.signal",
        "engine.combustion", "fuelpump.fill", "sparkles"
    ]
    
    private var isValid: Bool {
        !serviceType.isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Service Details")) {
                    TextField("Service Type (e.g., Oil Change)", text: $serviceType)
                    
                    // Icon Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(serviceIcons, id: \.self) { icon in
                                    Button(action: {
                                        selectedIcon = icon
                                    }) {
                                        Image(systemName: icon)
                                            .font(.title2)
                                            .foregroundColor(selectedIcon == icon ? .blue : .gray)
                                            .frame(width: 44, height: 44)
                                            .background(selectedIcon == icon ? Color.blue.opacity(0.1) : Color.clear)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Due Date & Mileage")) {
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date])
                    
                    TextField("Due at Mileage (Optional)", text: $dueMileage)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("Service Interval (Optional)")) {
                    HStack {
                        TextField("Months", text: $intervalMonths)
                            .keyboardType(.numberPad)
                        Text("months")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        TextField("Miles", text: $intervalMileage)
                            .keyboardType(.numberPad)
                        Text("miles")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Notes (Optional)")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Add Service Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveReminder()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private func saveReminder() {
        let mileageValue = Int(dueMileage) ?? 0
        let intervalMonthsValue = Int(intervalMonths) ?? 0
        let intervalMileageValue = Int(intervalMileage) ?? 0
        
        let reminder = ServiceReminderEntity(
            context: viewContext,
            vehicleID: vehicle.id,
            serviceType: serviceType,
            iconName: selectedIcon,
            dueDate: dueDate,
            dueMileage: mileageValue,
            intervalMonths: intervalMonthsValue,
            intervalMileage: intervalMileageValue
        )
        
        if !notes.isEmpty {
            reminder.notes = notes
        }
        
        do {
            try viewContext.save()
            NotificationService.shared.scheduleServiceReminder(reminder, vehicleName: vehicle.displayName)
            onSave()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving service reminder: \(error)")
        }
    }
}

