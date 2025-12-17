import SwiftUI
import CoreData

struct VehicleDashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let vehicle: VehicleEntity
    
    @State private var dashboardScore: DashboardScore?
    @State private var showingScoreDetails = false
    @State private var showingAddReminder = false
    
    // Fetch service reminders
    @FetchRequest var serviceReminders: FetchedResults<ServiceReminderEntity>
    
    // Fetch fuel entries
    @FetchRequest var fuelEntries: FetchedResults<FuelEntryEntity>
    
    init(vehicle: VehicleEntity) {
        self.vehicle = vehicle
        
        // Initialize fetch requests
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
                            // Edit mileage
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
                            // Get cash offer action
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
        }
        .sheet(isPresented: $showingScoreDetails) {
            DashboardScoreDetailView(score: dashboardScore ?? DashboardScore(percentage: 0, completedItems: 0, totalItems: 12, missingItems: [], message: ""))
        }
    }
    
    private func calculateDashboardScore() {
        dashboardScore = DashboardScoreService.shared.calculateDashboardScore(for: vehicle)
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
        
        if months >= 2 {
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
    let score: DashboardScore
    
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
                    Section(header: Text("Missing Information")) {
                        ForEach(score.missingItems, id: \.self) { item in
                            HStack {
                                Image(systemName: "circle")
                                    .foregroundColor(.orange)
                                Text(item)
                                    .font(.subheadline)
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
}

