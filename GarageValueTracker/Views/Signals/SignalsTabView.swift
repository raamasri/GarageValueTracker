import SwiftUI
import CoreData

struct SignalsTabView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SignalEntity.createdAt, ascending: false)],
        animation: .default
    )
    private var signals: FetchedResults<SignalEntity>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \VehicleEntity.year, ascending: false)]
    )
    private var vehicles: FetchedResults<VehicleEntity>

    @State private var expandedID: UUID?
    @State private var isRefreshing = false
    @State private var aiMacroContext: String?
    @State private var isGeneratingMacro = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GIQHeaderBar()

                    GIQSectionHeader(
                        label: "Market Signals",
                        headline: "What the data is saying",
                        accentWord: "is saying"
                    )
                    .padding(.horizontal)

                    if signals.isEmpty && !isRefreshing {
                        emptyState
                    } else {
                        signalsList
                    }

                    macroContext
                        .padding(.horizontal)

                    Spacer(minLength: 40)
                }
            }
            .themeBackground()
            .navigationBarHidden(true)
            .refreshable { await refreshSignals() }
            .onAppear {
                if signals.isEmpty {
                    Task { await refreshSignals() }
                }
            }
        }
    }

    // MARK: - Signals List

    private var signalsList: some View {
        LazyVStack(spacing: 2) {
            ForEach(signals) { signal in
                ExpandableSignalRow(
                    signal: signal,
                    vehicles: Array(vehicles),
                    isExpanded: expandedID == signal.id,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedID = expandedID == signal.id ? nil : signal.id
                        }
                        if !signal.isRead {
                            signal.isRead = true
                            try? viewContext.save()
                        }
                    }
                )
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 40))
                .foregroundColor(GIQ.secondaryText)
            Text("No signals yet")
                .font(.mono(14))
                .foregroundColor(GIQ.secondaryText)
            Text("Add vehicles to generate insights")
                .font(.mono(12))
                .foregroundColor(GIQ.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Macro Context

    private var macroContext: some View {
        VStack(alignment: .leading, spacing: 10) {
            let dateFormatter: DateFormatter = {
                let f = DateFormatter()
                f.dateFormat = "MMMM yyyy"
                return f
            }()

            HStack {
                Text("MACRO CONTEXT  \u{00B7}  \(dateFormatter.string(from: Date()))")
                    .font(.mono(10, weight: .semibold))
                    .foregroundColor(GIQ.secondaryText)
                    .tracking(1.0)
                if isGeneratingMacro {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(GIQ.accent)
                }
            }

            Text(aiMacroContext ?? SignalEngine.shared.generateMacroContext())
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .themeCard()
        .onAppear { generateAIMacro() }
    }
    
    private func generateAIMacro() {
        guard AIServiceWrapper.shared.isAvailable, aiMacroContext == nil else { return }
        isGeneratingMacro = true
        
        let totalValue = vehicles.reduce(0.0) { $0 + $1.currentValue }
        let totalCost = vehicles.reduce(0.0) { $0 + $1.purchasePrice }
        let gainLoss = totalCost > 0 ? ((totalValue - totalCost) / totalCost) * 100 : 0
        
        let trends: [(String, Double)] = [
            ("Sports Cars", -4.1), ("SUVs", 2.3),
            ("Trucks", 3.5), ("EVs", -8.4),
            ("Luxury", -6.2), ("Exotic", 1.1)
        ]
        
        Task {
            let result = await AIServiceWrapper.shared.generateMacroContext(
                segmentTrends: trends,
                vehicleCount: vehicles.count,
                portfolioValue: totalValue,
                portfolioGainLoss: gainLoss
            )
            await MainActor.run {
                aiMacroContext = result
                isGeneratingMacro = false
            }
        }
    }

    private func refreshSignals() async {
        isRefreshing = true
        let allVehicles = Array(vehicles)
        let newSignals = SignalEngine.shared.generateSignals(vehicles: allVehicles, context: viewContext)
        SignalEngine.shared.persistSignals(newSignals, context: viewContext)
        isRefreshing = false
    }
}

// MARK: - Expandable Signal Row

struct ExpandableSignalRow: View {
    let signal: SignalEntity
    let vehicles: [VehicleEntity]
    let isExpanded: Bool
    let onTap: () -> Void

    private var vehicleName: String? {
        guard let vid = signal.vehicleID else { return nil }
        return vehicles.first { $0.id == vid }?.displayName
    }

    private var icon: String {
        signal.signalCategory.icon
    }

    private var severityColor: Color {
        switch signal.signalSeverity {
        case .action: return GIQ.accent
        case .warning: return .yellow
        case .info: return GIQ.secondaryText
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(severityColor)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(signal.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                        if let name = vehicleName {
                            Text(name)
                                .font(.mono(11))
                                .foregroundColor(GIQ.secondaryText)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(GIQ.tertiaryText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal)
                .padding(.vertical, 14)

                if isExpanded {
                    Text(signal.body)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.75))
                        .lineSpacing(3)
                        .padding(.horizontal)
                        .padding(.bottom, 14)
                        .padding(.leading, 36)
                }

                Rectangle()
                    .fill(GIQ.divider)
                    .frame(height: 1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
