import SwiftUI
import CoreData

struct InsuranceTrackingView: View {
    let vehicle: VehicleEntity
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @State private var insuranceProvider: String
    @State private var annualPremium: String
    @State private var coverageLevel: String
    @State private var renewalDate: Date
    @State private var averageForMake: InsuranceAverage?
    @State private var showingComparison = false
    
    init(vehicle: VehicleEntity) {
        self.vehicle = vehicle
        _insuranceProvider = State(initialValue: vehicle.insuranceProvider ?? "")
        _annualPremium = State(initialValue: vehicle.insurancePremium > 0 ? String(format: "%.0f", vehicle.insurancePremium) : "")
        _coverageLevel = State(initialValue: vehicle.coverageLevel ?? "Full Coverage")
        _renewalDate = State(initialValue: vehicle.insuranceRenewalDate ?? Date().addingTimeInterval(365*24*60*60))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Insurance Tracking")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(vehicle.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    
                    // Current Insurance Info
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Insurance")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 12) {
                            TextField("Insurance Provider", text: $insuranceProvider)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            HStack {
                                Text("$")
                                    .foregroundColor(.secondary)
                                TextField("Annual Premium", text: $annualPremium)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            Picker("Coverage Level", selection: $coverageLevel) {
                                Text("Liability Only").tag("Liability Only")
                                Text("Collision").tag("Collision")
                                Text("Comprehensive").tag("Comprehensive")
                                Text("Full Coverage").tag("Full Coverage")
                            }
                            .pickerStyle(.menu)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            
                            DatePicker("Renewal Date", selection: $renewalDate, displayedComponents: .date)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        
                        Button(action: saveInsurance) {
                            Text("Save Insurance Info")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(annualPremium.isEmpty)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    // Monthly Cost
                    if let premium = Double(annualPremium), premium > 0 {
                        VStack(spacing: 12) {
                            Text("Monthly Cost")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text(formatCurrency(premium / 12))
                                .font(.system(size: 42, weight: .bold))
                                .foregroundColor(.blue)
                            
                            Text("per month")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                    
                    // Comparison
                    if let average = averageForMake, let premium = Double(annualPremium), premium > 0 {
                        ComparisonCard(
                            yourPremium: premium,
                            average: average,
                            location: vehicle.location
                        )
                    }
                    
                    // Renewal Reminder
                    if vehicle.insuranceRenewalDate != nil {
                        RenewalReminderCard(renewalDate: renewalDate)
                    }
                    
                    // Tips
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            Text("Money-Saving Tips")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        
                        InsuranceTip(icon: "chart.line.downtrend.xyaxis", tip: "Shop around annually for better rates")
                        InsuranceTip(icon: "shield.checkered", tip: "Bundle home and auto for discounts")
                        InsuranceTip(icon: "gauge", tip: "Low mileage can reduce premiums")
                        InsuranceTip(icon: "star.fill", tip: "Good driving record saves 20-40%")
                        InsuranceTip(icon: "creditcard", tip: "Higher deductible = lower premium")
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                }
                .padding()
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
            .onAppear {
                loadInsuranceAverage()
            }
        }
    }
    
    private func saveInsurance() {
        vehicle.insuranceProvider = insuranceProvider.isEmpty ? nil : insuranceProvider
        vehicle.insurancePremium = Double(annualPremium) ?? 0
        vehicle.coverageLevel = coverageLevel
        vehicle.insuranceRenewalDate = renewalDate
        vehicle.updatedAt = Date()
        
        do {
            try viewContext.save()
            NotificationService.shared.scheduleInsuranceRenewal(vehicleID: vehicle.id, vehicleName: vehicle.displayName, renewalDate: renewalDate)
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving insurance: \(error.localizedDescription)")
        }
    }
    
    private func loadInsuranceAverage() {
        // Load from JSON
        guard let url = Bundle.main.url(forResource: "insurance_averages", withExtension: "json") else { return }
        
        do {
            let data = try Data(contentsOf: url)
            let database = try JSONDecoder().decode(InsuranceDatabase.self, from: data)
            averageForMake = database.averages.first { $0.make.lowercased() == vehicle.make.lowercased() }
        } catch {
            print("Error loading insurance averages: \(error.localizedDescription)")
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
}

// MARK: - Comparison Card
struct ComparisonCard: View {
    let yourPremium: Double
    let average: InsuranceAverage
    let location: String?
    
    private var adjustedAverage: Double {
        var avg = average.averageAnnual
        
        // Apply regional adjustment if location is set
        if let location = location {
            if location.lowercased().contains("california") || location.lowercased().contains("ca") {
                avg *= 1.25
            } else if location.lowercased().contains("new york") || location.lowercased().contains("ny") {
                avg *= 1.30
            } else if location.lowercased().contains("texas") || location.lowercased().contains("tx") {
                avg *= 1.10
            } else if location.lowercased().contains("florida") || location.lowercased().contains("fl") {
                avg *= 1.20
            } else if location.lowercased().contains("michigan") || location.lowercased().contains("mi") {
                avg *= 1.40
            }
        }
        
        return avg
    }
    
    private var percentDifference: Double {
        return ((yourPremium - adjustedAverage) / adjustedAverage) * 100
    }
    
    private var status: String {
        if percentDifference <= -20 {
            return "Much Lower"
        } else if percentDifference <= -5 {
            return "Below Average"
        } else if percentDifference <= 5 {
            return "Average"
        } else if percentDifference <= 20 {
            return "Above Average"
        } else {
            return "Much Higher"
        }
    }
    
    private var statusColor: Color {
        if percentDifference <= -5 {
            return .green
        } else if percentDifference <= 5 {
            return .blue
        } else if percentDifference <= 20 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("vs. Average \(average.make)")
                    .font(.title3)
                    .fontWeight(.bold)
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Premium")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(yourPremium))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Typical")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(adjustedAverage))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            HStack {
                Image(systemName: comparisonIcon)
                    .foregroundColor(statusColor)
                
                Text(status)
                    .font(.headline)
                    .foregroundColor(statusColor)
                
                Spacer()
                
                Text(String(format: "%.0f%%", abs(percentDifference)))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(statusColor)
            }
            
            if !average.factors.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cost Factors:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(average.factors, id: \.self) { factor in
                        Text("• \(factor)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private var comparisonIcon: String {
        if percentDifference <= -5 {
            return "arrow.down.circle.fill"
        } else if percentDifference <= 5 {
            return "equal.circle.fill"
        } else {
            return "arrow.up.circle.fill"
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
}

// MARK: - Renewal Reminder Card
struct RenewalReminderCard: View {
    let renewalDate: Date
    
    private var daysUntilRenewal: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: renewalDate).day ?? 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(daysUntilRenewal <= 30 ? .orange : .blue)
                Text("Renewal Reminder")
                    .font(.headline)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Renewal Date")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(renewalDate, style: .date)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(daysUntilRenewal) days")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(daysUntilRenewal <= 30 ? .orange : .primary)
                    
                    Text(daysUntilRenewal <= 30 ? "Due soon" : "until renewal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if daysUntilRenewal <= 30 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Consider shopping for better rates before renewal")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(daysUntilRenewal <= 30 ? Color.orange.opacity(0.1) : Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Insurance Tip
struct InsuranceTip: View {
    let icon: String
    let tip: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(tip)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Supporting Types
struct InsuranceDatabase: Codable {
    let averages: [InsuranceAverage]
}

struct InsuranceAverage: Codable {
    let make: String
    let averageAnnual: Double
    let range: String
    let factors: [String]
}

