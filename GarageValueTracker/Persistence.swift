import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample data for previews
        let vehicle = VehicleEntity(
            context: viewContext,
            make: "Toyota",
            model: "Camry",
            year: 2020,
            trim: "XSE",
            mileage: 35000,
            purchasePrice: 25000.00
        )
        
        // Create sample cost entries
        let costEntry1 = CostEntryEntity(
            context: viewContext,
            vehicleID: vehicle.id,
            date: Date(),
            category: "Maintenance",
            amount: 149.99,
            merchantName: "Quick Lube",
            notes: "Oil change and tire rotation"
        )
        
        let costEntry2 = CostEntryEntity(
            context: viewContext,
            vehicleID: vehicle.id,
            date: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
            category: "Fuel",
            amount: 65.00,
            merchantName: "Shell Station"
        )
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "GarageValueTracker")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // In production, you should handle this error appropriately
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

