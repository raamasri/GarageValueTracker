import Foundation
import UserNotifications
import CoreData

class NotificationService {
    static let shared = NotificationService()
    
    private let center = UNUserNotificationCenter.current()
    
    private init() {}
    
    // MARK: - Permission
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func checkPermission(completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }
    
    // MARK: - Schedule Service Reminder Notifications
    
    func scheduleServiceReminder(_ reminder: ServiceReminderEntity, vehicleName: String) {
        guard !reminder.isCompleted else { return }
        
        let reminderID = reminder.id.uuidString
        
        cancelNotification(id: reminderID)
        cancelNotification(id: "\(reminderID)-week")
        
        let dueDateContent = UNMutableNotificationContent()
        dueDateContent.title = "Service Due: \(reminder.serviceType)"
        dueDateContent.body = "\(vehicleName) -- \(reminder.serviceType) is due today."
        dueDateContent.sound = .default
        dueDateContent.categoryIdentifier = "SERVICE_REMINDER"
        dueDateContent.userInfo = ["reminderID": reminderID, "type": "service"]
        
        let dueComponents = Calendar.current.dateComponents([.year, .month, .day, .hour], from: reminder.dueDate)
        var dueTriggerComponents = dueComponents
        dueTriggerComponents.hour = 9
        
        if reminder.dueDate > Date() {
            let dueTrigger = UNCalendarNotificationTrigger(dateMatching: dueTriggerComponents, repeats: false)
            let dueRequest = UNNotificationRequest(identifier: reminderID, content: dueDateContent, trigger: dueTrigger)
            center.add(dueRequest)
        }
        
        let weekBefore = Calendar.current.date(byAdding: .day, value: -7, to: reminder.dueDate) ?? reminder.dueDate
        if weekBefore > Date() {
            let earlyContent = UNMutableNotificationContent()
            earlyContent.title = "Upcoming: \(reminder.serviceType)"
            earlyContent.body = "\(vehicleName) -- \(reminder.serviceType) is due in 1 week."
            earlyContent.sound = .default
            earlyContent.categoryIdentifier = "SERVICE_REMINDER"
            earlyContent.userInfo = ["reminderID": reminderID, "type": "service_early"]
            
            var earlyComponents = Calendar.current.dateComponents([.year, .month, .day], from: weekBefore)
            earlyComponents.hour = 9
            
            let earlyTrigger = UNCalendarNotificationTrigger(dateMatching: earlyComponents, repeats: false)
            let earlyRequest = UNNotificationRequest(identifier: "\(reminderID)-week", content: earlyContent, trigger: earlyTrigger)
            center.add(earlyRequest)
        }
    }
    
    // MARK: - Recall Alert
    
    func sendRecallAlert(vehicleName: String, recallCount: Int) {
        guard recallCount > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Safety Recall Alert"
        content.body = "\(vehicleName) has \(recallCount) open recall\(recallCount == 1 ? "" : "s") from NHTSA. Tap to view details."
        content.sound = .default
        content.categoryIdentifier = "RECALL_ALERT"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "recall-\(vehicleName.replacingOccurrences(of: " ", with: "-"))",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }
    
    // MARK: - Insurance Renewal
    
    func scheduleInsuranceRenewal(vehicleID: UUID, vehicleName: String, renewalDate: Date) {
        let id = "insurance-\(vehicleID.uuidString)"
        cancelNotification(id: id)
        cancelNotification(id: "\(id)-week")
        cancelNotification(id: "\(id)-month")
        
        let scheduleAt: [(String, Date, String)] = [
            (id, renewalDate, "Your insurance renewal is today."),
            ("\(id)-week", Calendar.current.date(byAdding: .day, value: -7, to: renewalDate)!, "Your insurance renews in 1 week."),
            ("\(id)-month", Calendar.current.date(byAdding: .month, value: -1, to: renewalDate)!, "Your insurance renews in 1 month.")
        ]
        
        for (notifID, date, body) in scheduleAt {
            guard date > Date() else { continue }
            
            let content = UNMutableNotificationContent()
            content.title = "Insurance Renewal: \(vehicleName)"
            content.body = body
            content.sound = .default
            content.categoryIdentifier = "INSURANCE_RENEWAL"
            
            var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
            components.hour = 9
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: notifID, content: content, trigger: trigger)
            center.add(request)
        }
    }
    
    // MARK: - Registration Renewal
    
    func scheduleRegistrationRenewal(vehicleID: UUID, vehicleName: String, renewalDate: Date) {
        let id = "registration-\(vehicleID.uuidString)"
        cancelNotification(id: id)
        cancelNotification(id: "\(id)-week")
        cancelNotification(id: "\(id)-month")
        
        let scheduleAt: [(String, Date, String)] = [
            (id, renewalDate, "Your vehicle registration renewal is today."),
            ("\(id)-week", Calendar.current.date(byAdding: .day, value: -7, to: renewalDate)!, "Your vehicle registration renews in 1 week."),
            ("\(id)-month", Calendar.current.date(byAdding: .month, value: -1, to: renewalDate)!, "Your vehicle registration renews in 1 month.")
        ]
        
        for (notifID, date, body) in scheduleAt {
            guard date > Date() else { continue }
            
            let content = UNMutableNotificationContent()
            content.title = "Registration Renewal: \(vehicleName)"
            content.body = body
            content.sound = .default
            content.categoryIdentifier = "REGISTRATION_RENEWAL"
            
            var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
            components.hour = 9
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: notifID, content: content, trigger: trigger)
            center.add(request)
        }
    }
    
    // MARK: - Inspection Reminder
    
    func scheduleInspectionReminder(vehicleID: UUID, vehicleName: String, inspectionDate: Date) {
        let id = "inspection-\(vehicleID.uuidString)"
        cancelNotification(id: id)
        cancelNotification(id: "\(id)-week")
        cancelNotification(id: "\(id)-month")
        
        let scheduleAt: [(String, Date, String)] = [
            (id, inspectionDate, "Your vehicle inspection is due today."),
            ("\(id)-week", Calendar.current.date(byAdding: .day, value: -7, to: inspectionDate)!, "Your vehicle inspection is due in 1 week."),
            ("\(id)-month", Calendar.current.date(byAdding: .month, value: -1, to: inspectionDate)!, "Your vehicle inspection is due in 1 month.")
        ]
        
        for (notifID, date, body) in scheduleAt {
            guard date > Date() else { continue }
            
            let content = UNMutableNotificationContent()
            content.title = "Inspection Due: \(vehicleName)"
            content.body = body
            content.sound = .default
            content.categoryIdentifier = "INSPECTION_REMINDER"
            
            var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
            components.hour = 9
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: notifID, content: content, trigger: trigger)
            center.add(request)
        }
    }
    
    // MARK: - Wishlist Price Alert
    
    func sendPriceTargetAlert(vehicleName: String, currentPrice: Double, targetPrice: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Price Target Hit!"
        content.body = "\(vehicleName) is now $\(Int(currentPrice)) — at or below your target of $\(Int(targetPrice))."
        content.sound = .default
        content.categoryIdentifier = "PRICE_ALERT"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "price-alert-\(vehicleName.replacingOccurrences(of: " ", with: "-"))-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }
    
    func sendPriceDropAlert(vehicleName: String, currentPrice: Double, targetPrice: Double, percentAway: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Price Dropping: \(vehicleName)"
        content.body = "Now $\(Int(currentPrice)) — only \(String(format: "%.0f", percentAway))% above your target of $\(Int(targetPrice))."
        content.sound = .default
        content.categoryIdentifier = "PRICE_ALERT"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "price-near-\(vehicleName.replacingOccurrences(of: " ", with: "-"))-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }
    
    // MARK: - Schedule All Reminders for a Vehicle
    
    func scheduleAllReminders(for vehicle: VehicleEntity, context: NSManagedObjectContext) {
        let request = ServiceReminderEntity.fetchRequest()
        request.predicate = NSPredicate(format: "vehicleID == %@ AND isCompleted == NO", vehicle.id as CVarArg)
        
        do {
            let reminders = try context.fetch(request)
            for reminder in reminders {
                scheduleServiceReminder(reminder, vehicleName: vehicle.displayName)
            }
        } catch {
            print("Error fetching reminders for notifications: \(error)")
        }
        
        if let renewalDate = vehicle.insuranceRenewalDate {
            scheduleInsuranceRenewal(vehicleID: vehicle.id, vehicleName: vehicle.displayName, renewalDate: renewalDate)
        }
        
        if let registrationDate = vehicle.registrationRenewalDate {
            scheduleRegistrationRenewal(vehicleID: vehicle.id, vehicleName: vehicle.displayName, renewalDate: registrationDate)
        }
        
        if let inspectionDate = vehicle.inspectionDueDate {
            scheduleInspectionReminder(vehicleID: vehicle.id, vehicleName: vehicle.displayName, inspectionDate: inspectionDate)
        }
    }
    
    // MARK: - Cancel
    
    func cancelNotification(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }
    
    func cancelAllForVehicle(vehicleID: UUID) {
        center.getPendingNotificationRequests { requests in
            let idsToRemove = requests.filter { $0.identifier.contains(vehicleID.uuidString) }.map { $0.identifier }
            self.center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
        }
    }
    
    // MARK: - Pending Count (for debugging / settings)
    
    func getPendingCount(completion: @escaping (Int) -> Void) {
        center.getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                completion(requests.count)
            }
        }
    }
}
