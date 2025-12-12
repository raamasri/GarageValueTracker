import SwiftUI
import SwiftData

/// Debug view to verify data persistence
/// Shows all stored data and storage statistics
struct DataStorageDebugView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var stats: StorageStats?
    @State private var showClearConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                // Storage Stats Section
                if let stats = stats {
                    Section("Storage Statistics") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(stats.summary)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.primary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // App Preferences Section
                Section("App Preferences (UserDefaults)") {
                    LabeledContent("Launch Count", value: "\(AppPreferences.shared.launchCount)")
                    
                    if let lastLaunch = AppPreferences.shared.lastLaunchDate {
                        LabeledContent("Last Launch", value: lastLaunch.formatted(date: .abbreviated, time: .shortened))
                    }
                    
                    LabeledContent("Onboarding Complete", value: AppPreferences.shared.hasCompletedOnboarding ? "Yes" : "No")
                    
                    LabeledContent("Notifications", value: AppPreferences.shared.notificationsEnabled ? "Enabled" : "Disabled")
                }
                
                // Storage Info Section
                Section("Storage Details") {
                    LabeledContent("Storage Type", value: "SwiftData (Persistent)")
                    LabeledContent("Database Location", value: "Local Device")
                    LabeledContent("Cloud Sync", value: "Not Configured")
                }
                
                // Actions Section
                Section("Data Management") {
                    Button("Refresh Statistics") {
                        loadStats()
                    }
                    
                    Button("Record Test Launch") {
                        AppPreferences.shared.recordLaunch()
                        loadStats()
                    }
                    
                    Button("Clear All Data", role: .destructive) {
                        showClearConfirmation = true
                    }
                }
                
                // Persistence Test Section
                Section("Persistence Verification") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("✅ Data Persistence Active")
                            .font(.headline)
                            .foregroundStyle(.green)
                        
                        Text("All vehicles, costs, and settings are automatically saved to device storage and will persist even after the app is closed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("To verify:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Text("1. Add a vehicle or cost entry\n2. Force quit the app\n3. Reopen the app\n4. Your data will still be there!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Data Storage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadStats()
            }
            .alert("Clear All Data?", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("This will permanently delete all vehicles, costs, and valuation snapshots. User settings will be preserved. This action cannot be undone.")
            }
        }
    }
    
    private func loadStats() {
        stats = PersistenceManager.shared.getStorageStats(context: modelContext)
    }
    
    private func clearAllData() {
        PersistenceManager.shared.clearAllData(context: modelContext)
        loadStats()
    }
}

#Preview {
    DataStorageDebugView()
        .modelContainer(for: [VehicleEntity.self], inMemory: false)
}

