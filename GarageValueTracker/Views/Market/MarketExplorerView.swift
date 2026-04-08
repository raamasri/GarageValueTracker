import SwiftUI

struct MarketExplorerView: View {
    @Environment(\.presentationMode) var presentationMode
    
    private let segments = ["sports", "sedan", "suv", "truck", "ev", "luxury", "exotic"]
    
    @State private var profiles: [String: SegmentProfile] = [:]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(segments, id: \.self) { segment in
                        if let profile = profiles[segment] {
                            SegmentCardView(segment: segment, profile: profile)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Market Explorer")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .onAppear { loadProfiles() }
        }
    }
    
    private func loadProfiles() {
        guard let url = Bundle.main.url(forResource: "segment_profiles", withExtension: "json") else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(SegmentProfilesFileForView.self, from: data)
            profiles = decoded.segments
        } catch {
            print("Error loading profiles: \(error)")
        }
    }
}

private struct SegmentProfilesFileForView: Codable {
    let segments: [String: SegmentProfile]
}

struct SegmentCardView: View {
    let segment: String
    let profile: SegmentProfile
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: profile.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(segmentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName)
                        .font(.headline)
                    Text(profile.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Divider()
            
            HStack(spacing: 16) {
                MiniMetric(label: "Volatility", value: profile.cyclicalityScore, color: profile.cyclicalityScore > 50 ? .red : .green)
                MiniMetric(label: "Liquidity", value: profile.basePopularity, color: profile.basePopularity > 50 ? .green : .orange)
                MiniMetric(label: "Provenance", value: profile.provenancePremium, color: .purple)
            }
            
            if !profile.topModels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(profile.topModels.prefix(6), id: \.self) { model in
                            Text(model)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var segmentColor: Color {
        switch segment {
        case "sports": return .red
        case "sedan": return .blue
        case "suv": return .green
        case "truck": return .brown
        case "ev": return .teal
        case "luxury": return .purple
        case "exotic": return .orange
        default: return .gray
        }
    }
}

struct MiniMetric: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 36, height: 36)
                Circle()
                    .trim(from: 0, to: CGFloat(value) / 100.0)
                    .stroke(color, lineWidth: 4)
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
                Text("\(value)")
                    .font(.caption2)
                    .fontWeight(.bold)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
