import SwiftUI
import CoreData
import Charts

struct FuelTrackerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let vehicle: VehicleEntity
    
    @FetchRequest private var fuelEntries: FetchedResults<FuelEntryEntity>
    @State private var showingAddEntry = false
    
    init(vehicle: VehicleEntity) {
        self.vehicle = vehicle
        
        _fuelEntries = FetchRequest<FuelEntryEntity>(
            sortDescriptors: [NSSortDescriptor(keyPath: \FuelEntryEntity.date, ascending: false)],
            predicate: NSPredicate(format: "vehicleID == %@", vehicle.id as CVarArg),
            animation: .default
        )
    }
    
    private var mpgData: [(date: Date, mpg: Double)] {
        guard fuelEntries.count >= 2 else { return [] }
        
        var data: [(date: Date, mpg: Double)] = []
        let sortedEntries = fuelEntries.sorted { $0.date < $1.date }
        
        for i in 1..<sortedEntries.count {
            let current = sortedEntries[i]
            let previous = sortedEntries[i - 1]
            
            if let mpg = current.calculateMPG(previousEntry: previous) {
                data.append((date: current.date, mpg: mpg))
            }
        }
        
        return data
    }
    
    private var averageMPG: Double? {
        guard !mpgData.isEmpty else { return nil }
        let sum = mpgData.reduce(0.0) { $0 + $1.mpg }
        return sum / Double(mpgData.count)
    }
    
    private var totalCost: Double {
        fuelEntries.reduce(0) { $0 + $1.cost }
    }
    
    private var totalGallons: Double {
        fuelEntries.reduce(0) { $0 + $1.gallons }
    }
    
    private var averagePricePerGallon: Double? {
        guard totalGallons > 0 else { return nil }
        return totalCost / totalGallons
    }
    
    private var mileageData: [(date: Date, mileage: Int32)] {
        fuelEntries
            .filter { $0.mileage > 0 }
            .sorted { $0.date < $1.date }
            .map { (date: $0.date, mileage: $0.mileage) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Stats
                VStack(spacing: 16) {
                    // Average MPG Card
                    if let avgMPG = averageMPG {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Average MPG")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                Text(String(format: "%.1f", avgMPG))
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.green)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "fuelpump.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green.opacity(0.3))
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                    
                    // Quick Stats
                    HStack(spacing: 12) {
                        StatCard(
                            title: "Total Spent",
                            value: formatCurrency(totalCost),
                            icon: "dollarsign.circle.fill",
                            color: .blue
                        )
                        
                        StatCard(
                            title: "Fill-Ups",
                            value: "\(fuelEntries.count)",
                            icon: "number.circle.fill",
                            color: .orange
                        )
                    }
                    
                    HStack(spacing: 12) {
                        StatCard(
                            title: "Total Gallons",
                            value: String(format: "%.1f", totalGallons),
                            icon: "drop.fill",
                            color: .purple
                        )
                        
                        if let avgPrice = averagePricePerGallon {
                            StatCard(
                                title: "Avg $/Gal",
                                value: String(format: "$%.2f", avgPrice),
                                icon: "gauge.medium",
                                color: .red
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // MPG Chart
                if !mpgData.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MPG Over Time")
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        Chart(mpgData, id: \.date) { entry in
                            LineMark(
                                x: .value("Date", entry.date),
                                y: .value("MPG", entry.mpg)
                            )
                            .foregroundStyle(Color.green.gradient)
                            .interpolationMethod(.catmullRom)
                            
                            PointMark(
                                x: .value("Date", entry.date),
                                y: .value("MPG", entry.mpg)
                            )
                            .foregroundStyle(Color.green)
                            
                            if let avgMPG = averageMPG {
                                RuleMark(y: .value("Average", avgMPG))
                                    .foregroundStyle(Color.blue.opacity(0.5))
                                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                            }
                        }
                        .frame(height: 250)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: mpgData.count < 10 ? 1 : 7)) { _ in
                                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal)
                }
                
                // Mileage Over Time Chart
                if mileageData.count >= 2 {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Mileage Over Time")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            if let first = mileageData.first, let last = mileageData.last {
                                let driven = last.mileage - first.mileage
                                if driven > 0 {
                                    Text("+\(NumberFormatter.localizedString(from: NSNumber(value: driven), number: .decimal)) mi")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.cyan)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        Chart(mileageData, id: \.date) { entry in
                            AreaMark(
                                x: .value("Date", entry.date),
                                y: .value("Mileage", entry.mileage)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.3), Color.cyan.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                            
                            LineMark(
                                x: .value("Date", entry.date),
                                y: .value("Mileage", entry.mileage)
                            )
                            .foregroundStyle(Color.cyan.gradient)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            
                            PointMark(
                                x: .value("Date", entry.date),
                                y: .value("Mileage", entry.mileage)
                            )
                            .foregroundStyle(Color.cyan)
                            .symbolSize(30)
                            .annotation(position: .top, spacing: 6) {
                                if entry.date == mileageData.last?.date {
                                    Text("\(NumberFormatter.localizedString(from: NSNumber(value: entry.mileage), number: .decimal))")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.cyan)
                                }
                            }
                        }
                        .frame(height: 220)
                        .chartYScale(domain: .automatic(includesZero: false))
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisValueLabel {
                                    if let miles = value.as(Int.self) {
                                        Text("\(miles / 1000)k")
                                            .font(.caption2)
                                    }
                                }
                                AxisGridLine()
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: mileageData.count < 10 ? 1 : 7)) { _ in
                                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        // Fill-up frequency info
                        if mileageData.count >= 2,
                           let firstDate = mileageData.first?.date,
                           let lastDate = mileageData.last?.date {
                            let days = max(Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 1, 1)
                            let avgDaysBetween = Double(days) / Double(mileageData.count - 1)
                            let totalDriven = (mileageData.last?.mileage ?? 0) - (mileageData.first?.mileage ?? 0)
                            let milesPerDay = days > 0 ? Double(totalDriven) / Double(days) : 0
                            
                            HStack(spacing: 12) {
                                MileageStatPill(
                                    icon: "calendar.badge.clock",
                                    label: "Avg between fill-ups",
                                    value: String(format: "%.0f days", avgDaysBetween)
                                )
                                
                                MileageStatPill(
                                    icon: "road.lanes",
                                    label: "Daily average",
                                    value: String(format: "%.0f mi/day", milesPerDay)
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Fuel Entry List
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Fuel History")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: {
                            showingAddEntry = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    if fuelEntries.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "fuelpump")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            
                            Text("No Fuel Entries Yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Track your fuel consumption to see MPG trends")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            Button(action: {
                                showingAddEntry = true
                            }) {
                                Label("Add First Fill-Up", systemImage: "plus.circle.fill")
                                    .font(.headline)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(Array(fuelEntries.enumerated()), id: \.element.id) { index, entry in
                            FuelEntryRow(
                                entry: entry,
                                previousEntry: index < fuelEntries.count - 1 ? fuelEntries[index + 1] : nil
                            )
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
            }
        }
        .navigationTitle("Fuel Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddEntry = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddEntry) {
            AddFuelEntryView(vehicle: vehicle)
                .environment(\.managedObjectContext, viewContext)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
}

// MARK: - Stat Card Component
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Fuel Entry Row Component
struct FuelEntryRow: View {
    let entry: FuelEntryEntity
    let previousEntry: FuelEntryEntity?
    
    private var mpg: Double? {
        entry.calculateMPG(previousEntry: previousEntry)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Date & Station
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.date, style: .date)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let station = entry.station, !station.isEmpty {
                        Text(station)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Stats
                HStack(spacing: 16) {
                    // Gallons
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.2f", entry.gallons))
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("gal")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Cost
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "$%.2f", entry.cost))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("total")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            
            // MPG Display
            if let mpg = mpg {
                Divider()
                
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                            .foregroundColor(.green)
                        Text("MPG:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(String(format: "%.1f", mpg))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("mi/gal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.05))
            }
            
            // Additional Details
            if entry.notes != nil || entry.mileage > 0 {
                Divider()
                
                HStack(spacing: 16) {
                    if entry.mileage > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "speedometer")
                                .font(.caption)
                            Text("\(entry.mileage) mi")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    if let notes = entry.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Text(String(format: "$%.2f/gal", entry.pricePerGallon))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Mileage Stat Pill
struct MileageStatPill: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.cyan)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Preview
struct FuelTrackerView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let vehicle = VehicleEntity(context: context)
        vehicle.id = UUID()
        vehicle.make = "Toyota"
        vehicle.model = "Camry"
        vehicle.year = 2020
        
        return NavigationView {
            FuelTrackerView(vehicle: vehicle)
                .environment(\.managedObjectContext, context)
        }
    }
}

