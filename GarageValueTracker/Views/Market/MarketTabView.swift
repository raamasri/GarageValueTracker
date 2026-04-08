import SwiftUI
import CoreData

struct MarketTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedMode = 0

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GIQHeaderBar()

                    GIQSectionHeader(
                        label: "Market Intelligence",
                        headline: "What's moving"
                    )
                    .padding(.horizontal)

                    // Toggle
                    HStack(spacing: 0) {
                        ToggleButton(label: "Indexes", isSelected: selectedMode == 0) {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedMode = 0 }
                        }
                        ToggleButton(label: "Niches", isSelected: selectedMode == 1) {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedMode = 1 }
                        }
                    }
                    .padding(3)
                    .background(GIQ.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    if selectedMode == 0 {
                        IndexesSubView()
                            .environment(\.managedObjectContext, viewContext)
                    } else {
                        NichesSubView()
                    }

                    Spacer(minLength: 40)
                }
            }
            .themeBackground()
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Toggle Button

private struct ToggleButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.mono(13, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .black : GIQ.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? GIQ.accent : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Indexes

private struct IndexesSubView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MarketIndexEntity.createdAt, ascending: false)]
    )
    private var indexes: FetchedResults<MarketIndexEntity>

    @State private var showingCreate = false

    var body: some View {
        VStack(spacing: 12) {
            ForEach(indexes) { index in
                NavigationLink(destination: IndexDetailView(index: index)) {
                    IndexCard(index: index)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Button(action: { showingCreate = true }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Create Index")
                        .font(.mono(13, weight: .semibold))
                }
                .foregroundColor(GIQ.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(GIQ.accent.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingCreate) {
            CreateIndexView()
                .environment(\.managedObjectContext, viewContext)
        }
    }
}

private struct IndexCard: View {
    let index: MarketIndexEntity

    @FetchRequest private var members: FetchedResults<MarketIndexMemberEntity>

    init(index: MarketIndexEntity) {
        self.index = index
        _members = FetchRequest<MarketIndexMemberEntity>(
            sortDescriptors: [NSSortDescriptor(keyPath: \MarketIndexMemberEntity.createdAt, ascending: true)],
            predicate: NSPredicate(format: "indexID == %@", index.id as CVarArg)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(index.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("100.0")
                        .font(.mono(20, weight: .bold))
                        .foregroundColor(.white)
                    Text("Index Value")
                        .font(.mono(10, weight: .medium))
                        .foregroundColor(GIQ.tertiaryText)
                }
            }

            if !members.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(members) { member in
                        Text(member.displayName.uppercased())
                            .font(.mono(9, weight: .semibold))
                            .foregroundColor(GIQ.secondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            HStack(spacing: 16) {
                TrendLabel(period: "3 months", value: 0)
                TrendLabel(period: "12 months", value: 0)
            }
        }
        .themeCard()
    }
}

// MARK: - Niches

private struct NichesSubView: View {
    @State private var niches: [NicheEntry] = []

    struct NicheEntry: Identifiable {
        let id = UUID()
        let name: String
        let performance: Double
        let isPositive: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("12-month performance by segment")
                .font(.mono(11, weight: .medium))
                .foregroundColor(GIQ.secondaryText)
                .padding(.horizontal)
                .padding(.bottom, 8)

            ForEach(niches) { niche in
                NicheRow(niche: niche)
            }
        }
        .onAppear { loadNiches() }
    }

    private func loadNiches() {
        niches = [
            NicheEntry(name: "JDM GT platforms", performance: 31.4, isPositive: true),
            NicheEntry(name: "RAD-era Japanese", performance: 22.1, isPositive: true),
            NicheEntry(name: "Limited-run manuals", performance: 14.2, isPositive: true),
            NicheEntry(name: "Air-cooled 911s", performance: 8.7, isPositive: true),
            NicheEntry(name: "Modern supercar", performance: 2.3, isPositive: true),
            NicheEntry(name: "Pre-war American", performance: 1.1, isPositive: true),
            NicheEntry(name: "Younger collector EVs", performance: -4.1, isPositive: false),
            NicheEntry(name: "G-gen BMW M", performance: -11.2, isPositive: false),
        ]
    }
}

private struct NicheRow: View {
    let niche: NichesSubView.NicheEntry

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(niche.isPositive ? GIQ.gain : GIQ.loss)
                .frame(width: 8, height: 8)

            Text(niche.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)

            Spacer()

            GeometryReader { geo in
                let barWidth = min(abs(niche.performance) / 35.0, 1.0) * geo.size.width * 0.6
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(niche.isPositive ? GIQ.gain : GIQ.loss)
                        .frame(width: max(barWidth, 8), height: 6)
                }
            }
            .frame(width: 100, height: 10)

            Text("\(niche.isPositive ? "+" : "")\(niche.performance, specifier: "%.1f")%")
                .font(.mono(13, weight: .bold))
                .foregroundColor(niche.isPositive ? GIQ.gain : GIQ.loss)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

// MARK: - Simple Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (offsets: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            offsets.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (offsets, CGSize(width: maxX, height: y + rowHeight))
    }
}
