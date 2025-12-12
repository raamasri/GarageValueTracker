import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettingsEntity]
    
    @State private var showingSwapInsight = false
    @State private var showingUpgradePath = false
    
    private var userSettings: UserSettingsEntity {
        if let existing = settings.first {
            return existing
        } else {
            let newSettings = UserSettingsEntity()
            modelContext.insert(newSettings)
            return newSettings
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                featuresSection
                
                hassleAssumptionsSection
                
                aboutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingSwapInsight) {
                SwapInsightView()
            }
            .sheet(isPresented: $showingUpgradePath) {
                UpgradePathView()
            }
        }
    }
    
    // MARK: - Sections
    
    private var featuresSection: some View {
        Section("Advanced Features") {
            Button {
                showingSwapInsight = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Swap Insight")
                            .font(.headline)
                        Text("Compare depreciation: current vs watchlist")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.triangle.swap")
                }
            }
            .foregroundStyle(.primary)
            
            Button {
                showingUpgradePath = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Upgrade Path")
                            .font(.headline)
                        Text("Net cost to move up over 12 months")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                }
            }
            .foregroundStyle(.primary)
        }
    }
    
    private var hassleAssumptionsSection: some View {
        Section {
            HStack {
                Text("Hours/week active listing")
                Spacer()
                TextField("", value: Binding(
                    get: { userSettings.hoursPerWeekActiveListing },
                    set: { userSettings.hoursPerWeekActiveListing = $0 }
                ), format: .number)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
                .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Text("Hours per test drive")
                Spacer()
                TextField("", value: Binding(
                    get: { userSettings.hoursPerTestDrive },
                    set: { userSettings.hoursPerTestDrive = $0 }
                ), format: .number)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
                .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Text("Hours per price change")
                Spacer()
                TextField("", value: Binding(
                    get: { userSettings.hoursPerPriceChange },
                    set: { userSettings.hoursPerPriceChange = $0 }
                ), format: .number)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
                .textFieldStyle(.roundedBorder)
            }
        } header: {
            Text("Hassle Model Assumptions")
        } footer: {
            Text("These values are used in Deal Checker to estimate time cost of selling.")
        }
    }
    
    private var aboutSection: some View {
        Section("About") {
            LabeledContent("App Name", value: "Garage Value Tracker")
            LabeledContent("Version", value: "1.0.0 (MVP)")
            
            Link(destination: URL(string: "https://github.com")!) {
                HStack {
                    Text("Source Code")
                    Spacer()
                    Image(systemName: "link")
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Data Transparency")
                    .fontWeight(.medium)
                
                Text("This app uses free NHTSA VIN data and derived market observations. No proprietary KBB/Carfax data is used.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: UserSettingsEntity.self, inMemory: true)
}



