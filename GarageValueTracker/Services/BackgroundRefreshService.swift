import Foundation
import BackgroundTasks
import CoreData

class BackgroundRefreshService {
    static let shared = BackgroundRefreshService()
    static let taskIdentifier = "com.garageiq.valuation.refresh"
    
    private init() {}
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            self.handleRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule background refresh: \(error)")
        }
    }
    
    private func handleRefresh(task: BGAppRefreshTask) {
        scheduleRefresh()
        
        let context = PersistenceController.shared.container.newBackgroundContext()
        
        task.expirationHandler = {
            context.reset()
        }
        
        context.perform {
            self.refreshValuations(context: context)
            AlertService.shared.checkAllAlerts(context: context)
            
            task.setTaskCompleted(success: true)
        }
    }
    
    private func refreshValuations(context: NSManagedObjectContext) {
        let request = VehicleEntity.fetchRequest()
        guard let vehicles = try? context.fetch(request) else { return }
        
        for vehicle in vehicles {
            let result = ValuationEngine.shared.valuate(
                make: vehicle.make, model: vehicle.model,
                year: Int(vehicle.year), mileage: Int(vehicle.mileage),
                trim: vehicle.trim, msrp: vehicle.trimMSRP > 0 ? vehicle.trimMSRP : nil,
                location: vehicle.location, condition: vehicle.conditionTier
            )
            
            vehicle.currentValue = result.mid
            vehicle.lastValuationUpdate = Date()
        }
        
        let signals = SignalEngine.shared.generateSignals(vehicles: vehicles, context: context)
        SignalEngine.shared.persistSignals(signals, context: context)
        
        try? context.save()
    }
    
    func performForegroundRefresh(context: NSManagedObjectContext) {
        let request = VehicleEntity.fetchRequest()
        guard let vehicles = try? context.fetch(request) else { return }
        
        for vehicle in vehicles {
            let result = ValuationEngine.shared.valuate(
                make: vehicle.make, model: vehicle.model,
                year: Int(vehicle.year), mileage: Int(vehicle.mileage),
                trim: vehicle.trim, msrp: vehicle.trimMSRP > 0 ? vehicle.trimMSRP : nil,
                location: vehicle.location, condition: vehicle.conditionTier
            )
            
            vehicle.currentValue = result.mid
            vehicle.lastValuationUpdate = Date()
        }
        
        try? context.save()
        
        let signals = SignalEngine.shared.generateSignals(vehicles: vehicles, context: context)
        SignalEngine.shared.persistSignals(signals, context: context)
        
        AlertService.shared.checkAllAlerts(context: context)
    }
}
