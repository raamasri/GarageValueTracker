import SwiftUI
import CoreData

struct SignalsFeedView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SignalEntity.createdAt, ascending: false)],
        animation: .default
    )
    private var signals: FetchedResults<SignalEntity>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \VehicleEntity.year, ascending: false)]
    )
    private var vehicles: FetchedResults<VehicleEntity>
    
    @State private var selectedFilter: SignalCategory?
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                filterBar
                
                if filteredSignals.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(filteredSignals) { signal in
                            SignalRowView(signal: signal, vehicles: Array(vehicles))
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        viewContext.delete(signal)
                                        try? viewContext.save()
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await refreshSignals() }
                }
            }
            .navigationTitle("Signals")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        Task { await refreshSignals() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isRefreshing)
                }
            }
            .onAppear {
                if signals.isEmpty {
                    Task { await refreshSignals() }
                }
            }
        }
    }
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", isSelected: selectedFilter == nil) {
                    selectedFilter = nil
                }
                
                ForEach(SignalCategory.allCases, id: \.rawValue) { category in
                    FilterChip(label: category.displayName, isSelected: selectedFilter == category) {
                        selectedFilter = category
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
    
    private var filteredSignals: [SignalEntity] {
        if let filter = selectedFilter {
            return signals.filter { $0.category == filter.rawValue }
        }
        return Array(signals)
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Signals")
                .font(.title3)
                .fontWeight(.bold)
            Text("Add vehicles to your garage to receive market signals and insights")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }
    
    private func refreshSignals() async {
        isRefreshing = true
        let allVehicles = Array(vehicles)
        let newSignals = SignalEngine.shared.generateSignals(vehicles: allVehicles, context: viewContext)
        SignalEngine.shared.persistSignals(newSignals, context: viewContext)
        isRefreshing = false
    }
}

struct SignalRowView: View {
    @ObservedObject var signal: SignalEntity
    let vehicles: [VehicleEntity]
    @Environment(\.managedObjectContext) private var viewContext
    
    private var vehicleName: String? {
        guard let vid = signal.vehicleID else { return nil }
        return vehicles.first { $0.id == vid }?.displayName
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: signal.signalCategory.icon)
                .font(.title3)
                .foregroundColor(severityColor)
                .frame(width: 40, height: 40)
                .background(severityColor.opacity(0.12))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(signal.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if !signal.isRead {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(signal.body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                HStack(spacing: 8) {
                    if let name = vehicleName {
                        Text(name)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    
                    Text(signal.signalCategory.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(signal.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if !signal.isRead {
                signal.isRead = true
                try? viewContext.save()
            }
        }
    }
    
    private var severityColor: Color {
        switch signal.signalSeverity {
        case .action: return .orange
        case .warning: return .yellow
        case .info: return .blue
        }
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.secondary.opacity(0.12))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
