import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsManager = AppSettingsManager.shared
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Appearance Section
                Section(header: Text("Appearance")) {
                    // Dark Mode Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Dark Mode", systemImage: "paintbrush.fill")
                            .font(.headline)
                        
                        HStack(spacing: 0) {
                            ForEach([AppearanceMode.light, AppearanceMode.dark, AppearanceMode.system], id: \.self) { mode in
                                Button(action: {
                                    settingsManager.appearanceMode = mode
                                }) {
                                    VStack(spacing: 6) {
                                        Image(systemName: mode.icon)
                                            .font(.title3)
                                        Text(mode.rawValue)
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        settingsManager.appearanceMode == mode ?
                                        Color.accentColor.opacity(0.15) : Color.clear
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                settingsManager.appearanceMode == mode ?
                                                Color.accentColor : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                                    .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        Text(settingsManager.appearanceMode.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    
                    // Accent Color Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Accent Color", systemImage: "paintpalette.fill")
                            .font(.headline)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(AccentColorOption.allCases, id: \.self) { colorOption in
                                    Button(action: {
                                        settingsManager.accentColor = colorOption
                                    }) {
                                        VStack(spacing: 6) {
                                            Circle()
                                                .fill(colorOption.color)
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Circle()
                                                        .strokeBorder(Color.primary, lineWidth: settingsManager.accentColor == colorOption ? 3 : 0)
                                                )
                                                .overlay(
                                                    Image(systemName: "checkmark")
                                                        .foregroundColor(.white)
                                                        .fontWeight(.bold)
                                                        .opacity(settingsManager.accentColor == colorOption ? 1 : 0)
                                                )
                                            
                                            Text(colorOption.rawValue)
                                                .font(.caption)
                                                .foregroundColor(settingsManager.accentColor == colorOption ? colorOption.color : .secondary)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Show Vehicle Photos Toggle
                    Toggle(isOn: $settingsManager.showVehiclePhotos) {
                        Label("Show Vehicle Photos", systemImage: "photo")
                    }
                }
                
                // MARK: - Units & Format Section
                Section(header: Text("Units & Format")) {
                    // Distance Unit
                    Picker(selection: $settingsManager.distanceUnit) {
                        ForEach(DistanceUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    } label: {
                        Label("Distance Unit", systemImage: "gauge")
                    }
                    
                    // Currency Symbol
                    HStack {
                        Label("Currency", systemImage: "dollarsign.circle")
                        Spacer()
                        Text(settingsManager.currencySymbol)
                            .foregroundColor(.secondary)
                    }
                }
                
                // MARK: - Data Section
                Section(header: Text("Data Management")) {
                    NavigationLink(destination: Text("Coming Soon")) {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }
                    
                    NavigationLink(destination: Text("Coming Soon")) {
                        Label("Import Data", systemImage: "square.and.arrow.down")
                    }
                    
                    NavigationLink(destination: Text("Coming Soon")) {
                        Label("Backup & Sync", systemImage: "icloud")
                    }
                }
                
                // MARK: - Notifications Section
                Section(header: Text("Notifications")) {
                    NavigationLink(destination: Text("Coming Soon")) {
                        Label("Service Reminders", systemImage: "bell.badge")
                    }
                    
                    NavigationLink(destination: Text("Coming Soon")) {
                        Label("Insurance Renewal", systemImage: "bell.circle")
                    }
                }
                
                // MARK: - About Section
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.3")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://apple.com")!) {
                        HStack {
                            Label("Privacy Policy", systemImage: "hand.raised")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://apple.com")!) {
                        HStack {
                            Label("Terms of Service", systemImage: "doc.text")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "mailto:support@garagevaluetracker.com")!) {
                        HStack {
                            Label("Contact Support", systemImage: "envelope")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // MARK: - Reset Section
                Section {
                    Button(action: {
                        showingResetAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Label("Reset All Settings", systemImage: "arrow.counterclockwise")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Reset Settings", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    settingsManager.resetToDefaults()
                }
            } message: {
                Text("This will reset all settings to their default values. This action cannot be undone.")
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

