import SwiftUI
import Combine

// MARK: - App Settings Manager
class AppSettingsManager: ObservableObject {
    static let shared = AppSettingsManager()
    
    // MARK: - Published Properties
    @Published var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
        }
    }
    
    @Published var accentColor: AccentColorOption {
        didSet {
            UserDefaults.standard.set(accentColor.rawValue, forKey: "accentColor")
        }
    }
    
    @Published var showVehiclePhotos: Bool {
        didSet {
            UserDefaults.standard.set(showVehiclePhotos, forKey: "showVehiclePhotos")
        }
    }
    
    @Published var distanceUnit: DistanceUnit {
        didSet {
            UserDefaults.standard.set(distanceUnit.rawValue, forKey: "distanceUnit")
        }
    }
    
    @Published var currencySymbol: String {
        didSet {
            UserDefaults.standard.set(currencySymbol, forKey: "currencySymbol")
        }
    }
    
    @Published var garageViewMode: GarageViewMode {
        didSet {
            UserDefaults.standard.set(garageViewMode.rawValue, forKey: "garageViewMode")
        }
    }
    
    // MARK: - Initialization
    private init() {
        // Load appearance mode
        if let savedMode = UserDefaults.standard.string(forKey: "appearanceMode"),
           let mode = AppearanceMode(rawValue: savedMode) {
            self.appearanceMode = mode
        } else {
            self.appearanceMode = .system
        }
        
        // Load accent color
        if let savedColor = UserDefaults.standard.string(forKey: "accentColor"),
           let color = AccentColorOption(rawValue: savedColor) {
            self.accentColor = color
        } else {
            self.accentColor = .blue
        }
        
        // Load show photos preference
        self.showVehiclePhotos = UserDefaults.standard.object(forKey: "showVehiclePhotos") as? Bool ?? true
        
        // Load distance unit
        if let savedUnit = UserDefaults.standard.string(forKey: "distanceUnit"),
           let unit = DistanceUnit(rawValue: savedUnit) {
            self.distanceUnit = unit
        } else {
            self.distanceUnit = .miles
        }
        
        // Load currency
        self.currencySymbol = UserDefaults.standard.string(forKey: "currencySymbol") ?? "$"
        
        // Load garage view mode
        if let savedMode = UserDefaults.standard.string(forKey: "garageViewMode"),
           let mode = GarageViewMode(rawValue: savedMode) {
            self.garageViewMode = mode
        } else {
            self.garageViewMode = .card
        }
    }
    
    // MARK: - Color Scheme
    var colorScheme: ColorScheme? {
        switch appearanceMode {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
    
    // MARK: - Reset Settings
    func resetToDefaults() {
        appearanceMode = .system
        accentColor = .blue
        showVehiclePhotos = true
        distanceUnit = .miles
        currencySymbol = "$"
        garageViewMode = .card
    }
}

// MARK: - Appearance Mode Enum
enum AppearanceMode: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    
    var icon: String {
        switch self {
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        case .system:
            return "circle.lefthalf.filled"
        }
    }
    
    var description: String {
        switch self {
        case .light:
            return "Always use light mode"
        case .dark:
            return "Always use dark mode"
        case .system:
            return "Match system settings"
        }
    }
}

// MARK: - Accent Color Options
enum AccentColorOption: String, CaseIterable {
    case blue = "Blue"
    case green = "Green"
    case orange = "Orange"
    case red = "Red"
    case purple = "Purple"
    case pink = "Pink"
    
    var color: Color {
        switch self {
        case .blue:
            return .blue
        case .green:
            return .green
        case .orange:
            return .orange
        case .red:
            return .red
        case .purple:
            return .purple
        case .pink:
            return .pink
        }
    }
}

// MARK: - Distance Unit
enum DistanceUnit: String, CaseIterable {
    case miles = "Miles"
    case kilometers = "Kilometers"
}

// MARK: - Garage View Mode
enum GarageViewMode: String, CaseIterable {
    case card = "Card"
    case list = "List"
    
    var icon: String {
        switch self {
        case .card:
            return "square.stack.3d.up"
        case .list:
            return "list.bullet"
        }
    }
}

