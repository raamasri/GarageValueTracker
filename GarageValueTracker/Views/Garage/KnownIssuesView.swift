import SwiftUI

struct KnownIssuesView: View {
    let make: String
    let model: String
    let year: Int
    
    @Environment(\.presentationMode) var presentationMode
    @State private var issues: [KnownIssue] = []
    @State private var aiNarrative: String?
    @State private var isGeneratingAI = false
    @State private var selectedTab = 0
    @State private var complaints: [NHTSAComplaint] = []
    @State private var complaintSummary: ComplaintSummary?
    @State private var isLoadingComplaints = false
    @State private var complaintsError: String?
    var mileage: Int = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Source", selection: $selectedTab) {
                    Text("Community").tag(0)
                    Text("NHTSA Complaints (\(complaints.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                ScrollView {
                    if selectedTab == 0 {
                        communityIssuesTab
                    } else {
                        nhtsaComplaintsTab
                    }
                }
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
                generateAINarrative()
                loadNHTSAComplaints()
            }
        }
    }

    // MARK: - Community Issues Tab

    private var communityIssuesTab: some View {
        VStack(spacing: 20) {
            if issues.isEmpty {
                emptyState
            } else {
                if aiNarrative != nil || isGeneratingAI {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(Color(red: 0.83, green: 0.66, blue: 0.26))
                            Text("AI Summary")
                                .font(.headline)
                            if isGeneratingAI {
                                ProgressView().scaleEffect(0.7)
                            }
                        }
                        if let narrative = aiNarrative {
                            Text(narrative)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                }
                
                summaryCard
                issuesList
            }
            
            disclaimerText
        }
        .padding(.vertical)
    }

    // MARK: - NHTSA Complaints Tab

    private var nhtsaComplaintsTab: some View {
        VStack(spacing: 16) {
            if isLoadingComplaints {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading NHTSA complaints...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else if let error = complaintsError {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text("Could not load complaints")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") { loadNHTSAComplaints() }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if complaints.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.green)
                    Text("No NHTSA Complaints")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("No complaints have been filed with NHTSA for the \(year) \(make) \(model).")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.vertical, 60)
            } else {
                if let summary = complaintSummary {
                    complaintSummaryCard(summary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("All Complaints (\(complaints.count))")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(complaints.prefix(50)) { complaint in
                        NHTSAComplaintCard(complaint: complaint)
                    }
                    .padding(.horizontal)

                    if complaints.count > 50 {
                        Text("Showing 50 of \(complaints.count) complaints")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }

                VStack(spacing: 8) {
                    Divider().padding(.horizontal)
                    Text("Live data from NHTSA (National Highway Traffic Safety Administration). Complaints are filed by vehicle owners.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical)
    }

    private func complaintSummaryCard(_ summary: ComplaintSummary) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(year) \(make) \(model)")
                        .font(.headline)
                    HStack(spacing: 4) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("\(summary.totalComplaints) NHTSA complaints filed")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if summary.crashRelated > 0 || summary.fireRelated > 0 {
                    VStack(spacing: 2) {
                        Text("\(summary.crashRelated + summary.fireRelated)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        Text("Safety")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                }
            }

            if !summary.topComponents.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Most Reported Components")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    ForEach(summary.topComponents) { comp in
                        HStack {
                            Text(comp.component.capitalized)
                                .font(.caption)
                            Spacer()
                            Text("\(comp.count)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }

            HStack(spacing: 16) {
                if summary.crashRelated > 0 {
                    Label("\(summary.crashRelated) crashes", systemImage: "car.side.rear.and.collision.and.car.side.front")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
                if summary.fireRelated > 0 {
                    Label("\(summary.fireRelated) fires", systemImage: "flame")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
                if summary.totalInjuries > 0 {
                    Label("\(summary.totalInjuries) injuries", systemImage: "cross.case")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }

    // MARK: - Load Complaints

    private func loadNHTSAComplaints() {
        isLoadingComplaints = true
        complaintsError = nil
        Task {
            do {
                let results = try await NHTSAComplaintsService.shared.getComplaints(
                    make: make, model: model, modelYear: year
                )
                let summary = await NHTSAComplaintsService.shared.getComplaintSummary(
                    make: make, model: model, modelYear: year
                )
                await MainActor.run {
                    complaints = results
                    complaintSummary = summary
                    isLoadingComplaints = false
                }
            } catch {
                await MainActor.run {
                    complaintsError = error.localizedDescription
                    isLoadingComplaints = false
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private func generateAINarrative() {
        guard AIServiceWrapper.shared.isAvailable, !issues.isEmpty else { return }
        isGeneratingAI = true
        Task {
            let narrative = await AIServiceWrapper.shared.generateKnownIssuesNarrative(
                vehicleName: "\(year) \(make) \(model)",
                make: make, model: model, year: year,
                mileage: mileage,
                issues: issues.map { $0.title }
            )
            await MainActor.run {
                aiNarrative = narrative
                isGeneratingAI = false
            }
        }
    }
    
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
            
            Text("Community data sourced from technical service bulletins, owner forums, and community reports. NHTSA complaints are live from the National Highway Traffic Safety Administration. Not all vehicles will experience these issues.")
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

// MARK: - NHTSA Complaint Card

struct NHTSAComplaintCard: View {
    let complaint: NHTSAComplaint
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Circle()
                        .fill(severityColor)
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(complaint.component)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            if !complaint.dateComplaintFiled.isEmpty {
                                Text(complaint.dateComplaintFiled)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            if complaint.crash {
                                Label("Crash", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                            if complaint.fire {
                                Label("Fire", systemImage: "flame.fill")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded, !complaint.summary.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(complaint.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        if complaint.injuries > 0 {
                            Label("\(complaint.injuries) injuries", systemImage: "cross.case")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        if complaint.deaths > 0 {
                            Label("\(complaint.deaths) deaths", systemImage: "exclamationmark.octagon")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                        Text("ODI #\(complaint.odiNumber)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
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

    private var severityColor: Color {
        switch complaint.severityLevel {
        case "critical": return .red
        case "severe": return .red
        case "moderate": return .orange
        default: return .yellow
        }
    }
}
