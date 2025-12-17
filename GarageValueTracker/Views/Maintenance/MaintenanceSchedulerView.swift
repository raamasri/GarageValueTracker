import SwiftUI
import CoreData

struct MaintenanceSchedulerView: View {
    let vehicle: VehicleEntity
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @State private var upcomingServices: [ScheduledService] = []
    @State private var completedServices: [ScheduledService] = []
    @State private var showingAddService = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
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
                    
                    // Add Service Button
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
                    
                    // Upcoming Services
                    if !upcomingServices.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.orange)
                                Text("Upcoming Services")
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal)
                            
                            ForEach(upcomingServices) { service in
                                ScheduledServiceRow(
                                    service: service,
                                    currentMileage: Int(vehicle.mileage),
                                    onComplete: {
                                        markComplete(service)
                                    },
                                    onDelete: {
                                        deleteService(service)
                                    }
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
                    
                    // Recently Completed
                    if !completedServices.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Recently Completed")
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal)
                            
                            ForEach(completedServices.prefix(5)) { service in
                                CompletedServiceRow(service: service)
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
                AddServiceReminderView(vehicle: vehicle) {
                    loadServices()
                }
            }
            .onAppear {
                loadServices()
            }
        }
    }
    
    private func loadServices() {
        // Load from MaintenanceInsightService
        let insights = MaintenanceInsightService.shared.generateInsights(for: vehicle, costEntries: [])
        
        // Convert upcoming maintenance to scheduled services
        upcomingServices = insights.upcomingMaintenance.map { item in
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
        
        // Sort by due mileage
        upcomingServices.sort { $0.dueAtMileage < $1.dueAtMileage }
        
        // Filter completed
        completedServices = upcomingServices.filter { $0.isCompleted }
            .sorted { $0.completedDate ?? Date() > $1.completedDate ?? Date() }
        
        upcomingServices = upcomingServices.filter { !$0.isCompleted }
    }
    
    private func markComplete(_ service: ScheduledService) {
        if let index = upcomingServices.firstIndex(where: { $0.id == service.id }) {
            upcomingServices[index].isCompleted = true
            upcomingServices[index].completedDate = Date()
            
            // Move to completed
            completedServices.insert(upcomingServices[index], at: 0)
            upcomingServices.remove(at: index)
        }
    }
    
    private func deleteService(_ service: ScheduledService) {
        upcomingServices.removeAll { $0.id == service.id }
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

// MARK: - Completed Service Row
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

// MARK: - Add Service Reminder View
struct AddServiceReminderView: View {
    let vehicle: VehicleEntity
    let onSave: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    @State private var serviceName = ""
    @State private var dueAtMileage = ""
    @State private var estimatedCost = ""
    @State private var priority: MaintenancePriority = .recommended
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Service Details")) {
                    TextField("Service Name (e.g., Oil Change)", text: $serviceName)
                    
                    TextField("Due at Mileage", text: $dueAtMileage)
                        .keyboardType(.numberPad)
                    
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("Estimated Cost", text: $estimatedCost)
                            .keyboardType(.decimalPad)
                    }
                    
                    Picker("Priority", selection: $priority) {
                        Text("Critical").tag(MaintenancePriority.critical)
                        Text("Recommended").tag(MaintenancePriority.recommended)
                        Text("Optional").tag(MaintenancePriority.optional)
                    }
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
                        onSave()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(serviceName.isEmpty || dueAtMileage.isEmpty)
                }
            }
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

