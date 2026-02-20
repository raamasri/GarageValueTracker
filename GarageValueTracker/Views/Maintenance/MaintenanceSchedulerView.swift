import SwiftUI
import CoreData

struct MaintenanceSchedulerView: View {
    let vehicle: VehicleEntity
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @FetchRequest var savedReminders: FetchedResults<ServiceReminderEntity>
    
    @State private var generatedServices: [ScheduledService] = []
    @State private var showingAddService = false
    
    init(vehicle: VehicleEntity) {
        self.vehicle = vehicle
        _savedReminders = FetchRequest<ServiceReminderEntity>(
            sortDescriptors: [NSSortDescriptor(keyPath: \ServiceReminderEntity.dueDate, ascending: true)],
            predicate: NSPredicate(format: "vehicleID == %@", vehicle.id as CVarArg),
            animation: .default
        )
    }
    
    private var upcomingReminders: [ServiceReminderEntity] {
        savedReminders.filter { !$0.isCompleted }
    }
    
    private var completedReminders: [ServiceReminderEntity] {
        savedReminders.filter { $0.isCompleted }.sorted { ($0.completedDate ?? .distantPast) > ($1.completedDate ?? .distantPast) }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Maintenance Schedule")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(vehicle.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Current: \(formatMileage(Int(vehicle.mileage)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    
                    Button(action: {
                        showingAddService = true
                    }) {
                        Label("Add Service Reminder", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    if !upcomingReminders.isEmpty || !generatedServices.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.orange)
                                Text("Upcoming Services")
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal)
                            
                            ForEach(upcomingReminders) { reminder in
                                SavedReminderRow(
                                    reminder: reminder,
                                    currentMileage: Int(vehicle.mileage),
                                    onComplete: { markReminderComplete(reminder) },
                                    onDelete: { deleteReminder(reminder) }
                                )
                            }
                            .padding(.horizontal)
                            
                            ForEach(generatedServices) { service in
                                ScheduledServiceRow(
                                    service: service,
                                    currentMileage: Int(vehicle.mileage),
                                    onComplete: { saveGeneratedAsCompleted(service) },
                                    onDelete: { generatedServices.removeAll { $0.id == service.id } }
                                )
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        EmptyStateView(
                            icon: "calendar.badge.clock",
                            title: "No Scheduled Services",
                            message: "Add service reminders to track upcoming maintenance"
                        )
                        .padding()
                    }
                    
                    if !completedReminders.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Recently Completed")
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal)
                            
                            ForEach(Array(completedReminders.prefix(5))) { reminder in
                                CompletedReminderRow(reminder: reminder)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddService) {
                AddServiceReminderView(vehicle: vehicle)
                    .environment(\.managedObjectContext, viewContext)
            }
            .onAppear {
                loadGeneratedServices()
            }
        }
    }
    
    private func loadGeneratedServices() {
        let insights = MaintenanceInsightService.shared.generateInsights(for: vehicle, costEntries: [])
        
        let savedTypes = Set(savedReminders.map { $0.serviceType.lowercased() })
        
        generatedServices = insights.upcomingMaintenance
            .filter { !savedTypes.contains($0.service.lowercased()) }
            .map { item in
                ScheduledService(
                    id: UUID(),
                    serviceName: item.service,
                    dueAtMileage: item.dueAtMileage,
                    dueDate: nil,
                    estimatedCost: item.estimatedCost,
                    priority: item.priority,
                    notes: nil,
                    isCompleted: false,
                    completedDate: nil
                )
            }
            .sorted { $0.dueAtMileage < $1.dueAtMileage }
    }
    
    private func markReminderComplete(_ reminder: ServiceReminderEntity) {
        reminder.isCompleted = true
        reminder.completedDate = Date()
        reminder.updatedAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("Error completing reminder: \(error)")
        }
    }
    
    private func deleteReminder(_ reminder: ServiceReminderEntity) {
        viewContext.delete(reminder)
        
        do {
            try viewContext.save()
        } catch {
            print("Error deleting reminder: \(error)")
        }
    }
    
    private func saveGeneratedAsCompleted(_ service: ScheduledService) {
        let reminder = ServiceReminderEntity(
            context: viewContext,
            vehicleID: vehicle.id,
            serviceType: service.serviceName,
            iconName: "wrench.and.screwdriver",
            dueDate: Date(),
            dueMileage: service.dueAtMileage
        )
        reminder.isCompleted = true
        reminder.completedDate = Date()
        
        do {
            try viewContext.save()
            generatedServices.removeAll { $0.id == service.id }
        } catch {
            print("Error saving completed service: \(error)")
        }
    }
    
    private func formatMileage(_ mileage: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: mileage)) ?? "\(mileage)") + " mi"
    }
}

// MARK: - Scheduled Service Row
struct ScheduledServiceRow: View {
    let service: ScheduledService
    let currentMileage: Int
    let onComplete: () -> Void
    let onDelete: () -> Void
    
    private var milesRemaining: Int {
        return service.dueAtMileage - currentMileage
    }
    
    private var isDueSoon: Bool {
        return milesRemaining <= 500 && milesRemaining >= 0
    }
    
    private var isOverdue: Bool {
        return milesRemaining < 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: priorityIcon)
                    .foregroundColor(priorityColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(service.serviceName)
                        .font(.headline)
                    
                    Text("Due at \(formatMileage(service.dueAtMileage))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if isOverdue {
                        Text("⚠️ OVERDUE by \(formatMileage(abs(milesRemaining)))")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    } else if isDueSoon {
                        Text("⚠️ Due soon - \(formatMileage(milesRemaining)) remaining")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    } else {
                        Text("\(formatMileage(milesRemaining)) remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatCurrency(service.estimatedCost))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    if let date = service.dueDate {
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            HStack(spacing: 12) {
                Button(action: onComplete) {
                    Label("Complete", systemImage: "checkmark.circle")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: onDelete) {
                    Label("Remove", systemImage: "trash")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(isOverdue ? Color.red.opacity(0.1) : (isDueSoon ? Color.orange.opacity(0.1) : Color(.systemBackground)))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var priorityIcon: String {
        switch service.priority {
        case .critical: return "exclamationmark.triangle.fill"
        case .recommended: return "checkmark.circle"
        case .optional: return "circle"
        }
    }
    
    private var priorityColor: Color {
        if isOverdue { return .red }
        if isDueSoon { return .orange }
        
        switch service.priority {
        case .critical: return .red
        case .recommended: return .blue
        case .optional: return .gray
        }
    }
    
    private func formatMileage(_ mileage: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: abs(mileage))) ?? "\(abs(mileage))") + " mi"
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
}

// MARK: - Completed Service Row (for generated ScheduledService)
struct CompletedServiceRow: View {
    let service: ScheduledService
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(service.serviceName)
                    .font(.subheadline)
                
                if let completedDate = service.completedDate {
                    Text("Completed \(completedDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(formatCurrency(service.estimatedCost))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
}

// MARK: - Saved Reminder Row (Core Data backed)
struct SavedReminderRow: View {
    let reminder: ServiceReminderEntity
    let currentMileage: Int
    let onComplete: () -> Void
    let onDelete: () -> Void
    
    private var milesRemaining: Int {
        guard reminder.dueMileage > 0 else { return 0 }
        return Int(reminder.dueMileage) - currentMileage
    }
    
    private var isDueSoon: Bool {
        return (reminder.dueMileage > 0 && milesRemaining <= 500 && milesRemaining >= 0) || (reminder.daysRemaining <= 7 && reminder.daysRemaining >= 0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: reminder.iconName)
                    .foregroundColor(reminder.isOverdue ? .red : (isDueSoon ? .orange : .blue))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.serviceType)
                        .font(.headline)
                    
                    if reminder.dueMileage > 0 {
                        Text("Due at \(formatMileage(Int(reminder.dueMileage)))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if reminder.isOverdue {
                        Text("OVERDUE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    } else {
                        Text("Due \(reminder.dueDate, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button(action: onComplete) {
                    Label("Complete", systemImage: "checkmark.circle")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: onDelete) {
                    Label("Remove", systemImage: "trash")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(reminder.isOverdue ? Color.red.opacity(0.1) : (isDueSoon ? Color.orange.opacity(0.1) : Color(.systemBackground)))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func formatMileage(_ mileage: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: abs(mileage))) ?? "\(abs(mileage))") + " mi"
    }
}

// MARK: - Completed Reminder Row (Core Data backed)
struct CompletedReminderRow: View {
    let reminder: ServiceReminderEntity
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.serviceType)
                    .font(.subheadline)
                
                if let completedDate = reminder.completedDate {
                    Text("Completed \(completedDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Add Service Reminder View
struct AddServiceReminderView: View {
    let vehicle: VehicleEntity
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @State private var serviceName = ""
    @State private var dueAtMileage = ""
    @State private var dueDate = Date().addingTimeInterval(90 * 24 * 60 * 60)
    @State private var estimatedCost = ""
    @State private var notes = ""
    @State private var selectedIcon = "wrench.and.screwdriver"
    
    private let serviceIcons = [
        "wrench.and.screwdriver", "drop.fill", "car.fill",
        "fanblades.fill", "battery.100", "fuelpump.fill"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Service Details")) {
                    TextField("Service Name (e.g., Oil Change)", text: $serviceName)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(serviceIcons, id: \.self) { icon in
                                    Button(action: { selectedIcon = icon }) {
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
                    
                    TextField("Due at Mileage (Optional)", text: $dueAtMileage)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("Notes (Optional)")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Add Reminder")
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
                    .disabled(serviceName.isEmpty)
                }
            }
        }
    }
    
    private func saveReminder() {
        let mileageValue = Int(dueAtMileage) ?? 0
        
        let reminder = ServiceReminderEntity(
            context: viewContext,
            vehicleID: vehicle.id,
            serviceType: serviceName,
            iconName: selectedIcon,
            dueDate: dueDate,
            dueMileage: mileageValue
        )
        
        if !notes.isEmpty {
            reminder.notes = notes
        }
        
        do {
            try viewContext.save()
            NotificationService.shared.scheduleServiceReminder(reminder, vehicleName: vehicle.displayName)
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving service reminder: \(error)")
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Scheduled Service Model
struct ScheduledService: Identifiable {
    let id: UUID
    let serviceName: String
    let dueAtMileage: Int
    let dueDate: Date?
    let estimatedCost: Double
    let priority: MaintenancePriority
    let notes: String?
    var isCompleted: Bool
    var completedDate: Date?
}

