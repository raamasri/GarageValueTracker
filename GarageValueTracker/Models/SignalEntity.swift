import Foundation
import CoreData

@objc(SignalEntity)
public class SignalEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var vehicleID: UUID?
    @NSManaged public var title: String
    @NSManaged public var body: String
    @NSManaged public var category: String
    @NSManaged public var severity: String
    @NSManaged public var actionType: String?
    @NSManaged public var isRead: Bool
    @NSManaged public var createdAt: Date
}

extension SignalEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SignalEntity> {
        return NSFetchRequest<SignalEntity>(entityName: "SignalEntity")
    }
    
    convenience init(context: NSManagedObjectContext, signal: Signal, vehicleID: UUID? = nil) {
        self.init(context: context)
        self.id = UUID()
        self.vehicleID = vehicleID
        self.title = signal.title
        self.body = signal.body
        self.category = signal.category.rawValue
        self.severity = signal.severity.rawValue
        self.actionType = signal.actionType?.rawValue
        self.isRead = false
        self.createdAt = Date()
    }
    
    var signalCategory: SignalCategory {
        SignalCategory(rawValue: category) ?? .market
    }
    
    var signalSeverity: SignalSeverity {
        SignalSeverity(rawValue: severity) ?? .info
    }
}

struct Signal {
    let title: String
    let body: String
    let category: SignalCategory
    let severity: SignalSeverity
    let actionType: SignalActionType?
    let vehicleID: UUID?
    
    init(title: String, body: String, category: SignalCategory, severity: SignalSeverity, actionType: SignalActionType? = nil, vehicleID: UUID? = nil) {
        self.title = title
        self.body = body
        self.category = category
        self.severity = severity
        self.actionType = actionType
        self.vehicleID = vehicleID
    }
}

enum SignalCategory: String, CaseIterable {
    case market = "market"
    case portfolio = "portfolio"
    case timing = "timing"
    case anomaly = "anomaly"
    case maintenance = "maintenance"
    
    var displayName: String {
        switch self {
        case .market: return "Market"
        case .portfolio: return "Portfolio"
        case .timing: return "Timing"
        case .anomaly: return "Anomaly"
        case .maintenance: return "Maintenance"
        }
    }
    
    var icon: String {
        switch self {
        case .market: return "chart.line.uptrend.xyaxis"
        case .portfolio: return "briefcase"
        case .timing: return "clock"
        case .anomaly: return "exclamationmark.triangle"
        case .maintenance: return "wrench"
        }
    }
}

enum SignalSeverity: String {
    case info = "info"
    case warning = "warning"
    case action = "action"
    
    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .action: return "bolt.fill"
        }
    }
}

enum SignalActionType: String {
    case sell = "sell"
    case hold = "hold"
    case buy = "buy"
    case wait = "wait"
    case service = "service"
}
