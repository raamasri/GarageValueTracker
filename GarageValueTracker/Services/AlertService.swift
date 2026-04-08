import Foundation
import CoreData
import UserNotifications

class AlertService {
    static let shared = AlertService()
    
    private init() {}
    
    // MARK: - Check and Fire Alerts
    
    func checkAllAlerts(context: NSManagedObjectContext) {
        checkPriceTargetAlerts(context: context)
        checkDepreciationCliffAlerts(context: context)
        checkSellWindowAlerts(context: context)
        checkReminderAlerts(context: context)
    }
    
    // MARK: - Price Target Alerts
    
    private func checkPriceTargetAlerts(context: NSManagedObjectContext) {
        let request = WishlistVehicleEntity.fetchRequest()
        request.predicate = NSPredicate(format: "alertEnabled == YES AND targetPrice > 0")
        
        guard let watchlist = try? context.fetch(request) else { return }
        
        for item in watchlist {
            let valuation = ValuationEngine.shared.valuate(
                make: item.make, model: item.model,
                year: Int(item.year), mileage: Int(item.mileage),
                trim: item.trim, location: item.location
            )
            
            if valuation.mid <= item.targetPrice {
                fireLocalNotification(
                    title: "Price Target Reached",
                    body: "\(item.displayName) estimated value has reached your target of \(formatCurrency(item.targetPrice)).",
                    identifier: "price_target_\(item.id.uuidString)"
                )
                
                saveAlertRecord(
                    context: context,
                    type: .priceTarget,
                    title: "Price Target Reached",
                    message: "\(item.displayName) estimated at \(formatCurrency(valuation.mid)), target was \(formatCurrency(item.targetPrice))."
                )
            }
        }
    }
    
    // MARK: - Depreciation Cliff Alerts
    
    private func checkDepreciationCliffAlerts(context: NSManagedObjectContext) {
        let request = VehicleEntity.fetchRequest()
        guard let vehicles = try? context.fetch(request) else { return }
        
        for vehicle in vehicles {
            let mileage = Int(vehicle.mileage)
            let thresholds = [50000, 75000, 100000, 150000]
            
            for threshold in thresholds {
                let distance = threshold - mileage
                if distance > 0 && distance <= 2000 {
                    fireLocalNotification(
                        title: "Mileage Milestone Ahead",
                        body: "\(vehicle.displayName) is \(distance) miles from \(threshold / 1000)k. This can impact resale value.",
                        identifier: "mileage_cliff_\(vehicle.id.uuidString)_\(threshold)"
                    )
                    break
                }
            }
        }
    }
    
    // MARK: - Sell Window Alerts
    
    private func checkSellWindowAlerts(context: NSManagedObjectContext) {
        let request = VehicleEntity.fetchRequest()
        guard let vehicles = try? context.fetch(request) else { return }
        
        let currentMonth = Calendar.current.component(.month, from: Date())
        
        for vehicle in vehicles {
            let segment = vehicle.resolvedSegment
            var peakMonths: [Int] = []
            
            switch segment {
            case "sports": peakMonths = [3, 4, 5]
            case "truck", "suv": peakMonths = [8, 9, 10]
            default: break
            }
            
            for peakMonth in peakMonths {
                let monthsUntil = (peakMonth - currentMonth + 12) % 12
                if monthsUntil == 1 || monthsUntil == 2 {
                    let monthName = Calendar.current.monthSymbols[peakMonth - 1]
                    fireLocalNotification(
                        title: "Peak Selling Season Approaching",
                        body: "Your \(vehicle.displayName) enters its peak selling season in \(monthName). Consider listing soon for best value.",
                        identifier: "sell_window_\(vehicle.id.uuidString)_\(peakMonth)"
                    )
                    break
                }
            }
        }
    }
    
    // MARK: - Reminder Alerts (Registration, Insurance, Inspection)
    
    private func checkReminderAlerts(context: NSManagedObjectContext) {
        let request = VehicleEntity.fetchRequest()
        guard let vehicles = try? context.fetch(request) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        
        for vehicle in vehicles {
            if let regDate = vehicle.registrationRenewalDate {
                let daysUntil = calendar.dateComponents([.day], from: now, to: regDate).day ?? 999
                if daysUntil > 0 && daysUntil <= 30 {
                    fireLocalNotification(
                        title: "Registration Renewal Due",
                        body: "\(vehicle.displayName) registration expires in \(daysUntil) days.",
                        identifier: "registration_\(vehicle.id.uuidString)"
                    )
                }
            }
            
            if let insDate = vehicle.insuranceRenewalDate {
                let daysUntil = calendar.dateComponents([.day], from: now, to: insDate).day ?? 999
                if daysUntil > 0 && daysUntil <= 30 {
                    fireLocalNotification(
                        title: "Insurance Renewal Due",
                        body: "\(vehicle.displayName) insurance expires in \(daysUntil) days.",
                        identifier: "insurance_\(vehicle.id.uuidString)"
                    )
                }
            }
            
            if let inspDate = vehicle.inspectionDueDate {
                let daysUntil = calendar.dateComponents([.day], from: now, to: inspDate).day ?? 999
                if daysUntil > 0 && daysUntil <= 30 {
                    fireLocalNotification(
                        title: "Inspection Due",
                        body: "\(vehicle.displayName) inspection is due in \(daysUntil) days.",
                        identifier: "inspection_\(vehicle.id.uuidString)"
                    )
                }
            }
        }
    }
    
    // MARK: - Create Alert Configuration
    
    func createAlert(context: NSManagedObjectContext, vehicleID: UUID?, type: AlertType, title: String, message: String?, threshold: Double = 0) -> AlertEntity {
        let alert = AlertEntity(context: context, vehicleID: vehicleID, type: type, title: title, message: message, threshold: threshold)
        try? context.save()
        return alert
    }
    
    func toggleAlert(_ alert: AlertEntity, context: NSManagedObjectContext) {
        alert.isEnabled.toggle()
        alert.updatedAt = Date()
        try? context.save()
    }
    
    func deleteAlert(_ alert: AlertEntity, context: NSManagedObjectContext) {
        context.delete(alert)
        try? context.save()
    }
    
    // MARK: - Helpers
    
    private func fireLocalNotification(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Alert notification error: \(error)")
            }
        }
    }
    
    private func saveAlertRecord(context: NSManagedObjectContext, type: AlertType, title: String, message: String) {
        let alert = AlertEntity(context: context, type: type, title: title, message: message)
        alert.lastTriggered = Date()
        try? context.save()
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }
}
