import SwiftUI

struct KnownIssuesView: View {
    let make: String
    let model: String
    let year: Int
    
    @Environment(\.presentationMode) var presentationMode
    @State private var issues: [KnownIssue] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if issues.isEmpty {
                        emptyState
                    } else {
                        summaryCard
                        issuesList
                    }
                    
                    disclaimerText
                }
                .padding(.vertical)
            }
            .navigationTitle("Known Issues")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                issues = KnownIssuesService.shared.getIssues(make: make, model: model, year: year)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 56))
                .foregroundColor(.green)
            
            Text("No Known Issues")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("We don't have any commonly reported issues for the \(year) \(make) \(model) in our database.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 60)
    }
    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(year) \(make) \(model)")
                        .font(.headline)
                    Text("\(issues.count) known issue\(issues.count == 1 ? "" : "s") reported")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                let critical = issues.filter { $0.severity == "critical" || $0.severity == "severe" }.count
                if critical > 0 {
                    VStack(spacing: 2) {
                        Text("\(critical)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        Text("Critical")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                }
            }
            
            HStack(spacing: 12) {
                IssueSeverityPill(label: "Critical", count: issues.filter { $0.severity == "critical" }.count, color: .red)
                IssueSeverityPill(label: "Severe", count: issues.filter { $0.severity == "severe" }.count, color: .red)
                IssueSeverityPill(label: "Moderate", count: issues.filter { $0.severity == "moderate" }.count, color: .orange)
                IssueSeverityPill(label: "Minor", count: issues.filter { $0.severity == "minor" }.count, color: .yellow)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
    
    // MARK: - Issues List
    
    private var issuesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reported Issues")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(issues.sorted(by: { severityOrder($0.severity) < severityOrder($1.severity) })) { issue in
                KnownIssueCard(issue: issue)
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Disclaimer
    
    private var disclaimerText: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.horizontal)
            
            Text("Data sourced from NHTSA complaints, technical service bulletins, owner forums, and community reports. Not all vehicles will experience these issues.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.top, 8)
    }
    
    private func severityOrder(_ severity: String) -> Int {
        switch severity {
        case "critical": return 0
        case "severe": return 1
        case "moderate": return 2
        case "minor": return 3
        default: return 4
        }
    }
}

// MARK: - Severity Pill

struct IssueSeverityPill: View {
    let label: String
    let count: Int
    let color: Color
    
    var body: some View {
        if count > 0 {
            HStack(spacing: 4) {
                Text("\(count)")
                    .fontWeight(.bold)
                Text(label)
            }
            .font(.caption2)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

// MARK: - Known Issue Card

struct KnownIssueCard: View {
    let issue: KnownIssue
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    severityIndicator
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(issue.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("Years: \(issue.affectedYears.map(String.init).joined(separator: ", "))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text(issue.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .top) {
                        Image(systemName: "wrench.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Common Fix")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(issue.commonFix)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack(alignment: .top) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Estimated Cost")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(issue.estimatedCost)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack(alignment: .top) {
                        Image(systemName: "doc.text.fill")
                            .font(.caption)
                            .foregroundColor(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Source")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(issue.source)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private var severityIndicator: some View {
        Circle()
            .fill(severityColor)
            .frame(width: 10, height: 10)
    }
    
    private var severityColor: Color {
        switch issue.severity {
        case "critical", "severe": return .red
        case "moderate": return .orange
        case "minor": return .yellow
        default: return .gray
        }
    }
}
