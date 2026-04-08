import SwiftUI
import CoreData

struct MarketIndexView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MarketIndexEntity.createdAt, ascending: false)],
        animation: .default
    )
    private var indexes: FetchedResults<MarketIndexEntity>
    
    @State private var showingCreateIndex = false
    
    var body: some View {
        NavigationView {
            Group {
                if indexes.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No Custom Indexes")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("Create indexes to track segment performance")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button(action: { showingCreateIndex = true }) {
                            Label("Create Index", systemImage: "plus.circle.fill")
                                .fontWeight(.semibold)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                        }
                        .padding(.horizontal, 40)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(indexes) { index in
                                NavigationLink(destination: IndexDetailView(index: index)) {
                                    IndexRowView(index: index)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Market Indexes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !indexes.isEmpty {
                        Button(action: { showingCreateIndex = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCreateIndex) {
                CreateIndexView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
}

struct IndexRowView: View {
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(index.name)
                        .font(.headline)
                    if let desc = index.indexDescription, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text("\(members.count) vehicles")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(Capsule())
            }
            
            if !members.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(members) { member in
                            Text(member.displayName)
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
    }
}

struct CreateIndexView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name = ""
    @State private var description = ""
    @State private var members: [IndexMemberDraft] = []
    @State private var newMake = ""
    @State private var newModel = ""
    @State private var newYearStart = ""
    @State private var newYearEnd = ""
    
    struct IndexMemberDraft: Identifiable {
        let id = UUID()
        let make: String
        let model: String
        let yearStart: Int
        let yearEnd: Int
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Index Details") {
                    TextField("Index Name", text: $name)
                    TextField("Description (optional)", text: $description)
                }
                
                Section("Add Vehicle Specs") {
                    TextField("Make (e.g. Porsche)", text: $newMake)
                    TextField("Model (e.g. 911)", text: $newModel)
                    HStack {
                        TextField("Year From", text: $newYearStart)
                            .keyboardType(.numberPad)
                        TextField("Year To", text: $newYearEnd)
                            .keyboardType(.numberPad)
                    }
                    
                    Button("Add to Index") {
                        guard !newMake.isEmpty, !newModel.isEmpty,
                              let start = Int(newYearStart), let end = Int(newYearEnd) else { return }
                        members.append(IndexMemberDraft(make: newMake, model: newModel, yearStart: start, yearEnd: end))
                        newMake = ""
                        newModel = ""
                        newYearStart = ""
                        newYearEnd = ""
                    }
                    .disabled(newMake.isEmpty || newModel.isEmpty)
                }
                
                if !members.isEmpty {
                    Section("Members (\(members.count))") {
                        ForEach(members) { member in
                            HStack {
                                Text("\(member.yearStart)-\(member.yearEnd) \(member.make) \(member.model)")
                                Spacer()
                            }
                        }
                        .onDelete { offsets in
                            members.remove(atOffsets: offsets)
                        }
                    }
                }
            }
            .navigationTitle("Create Index")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { save() }
                        .disabled(name.isEmpty || members.isEmpty)
                }
            }
        }
    }
    
    private func save() {
        let index = MarketIndexEntity(context: viewContext, name: name, description: description.isEmpty ? nil : description)
        
        for member in members {
            _ = MarketIndexMemberEntity(
                context: viewContext, indexID: index.id,
                make: member.make, model: member.model,
                yearStart: member.yearStart, yearEnd: member.yearEnd
            )
        }
        
        try? viewContext.save()
        presentationMode.wrappedValue.dismiss()
    }
}

struct IndexDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let index: MarketIndexEntity
    
    @FetchRequest private var members: FetchedResults<MarketIndexMemberEntity>
    @State private var memberValuations: [(MarketIndexMemberEntity, ValuationResult)] = []
    
    init(index: MarketIndexEntity) {
        self.index = index
        _members = FetchRequest<MarketIndexMemberEntity>(
            sortDescriptors: [NSSortDescriptor(keyPath: \MarketIndexMemberEntity.createdAt, ascending: true)],
            predicate: NSPredicate(format: "indexID == %@", index.id as CVarArg)
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let desc = index.indexDescription, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                // Aggregate Metrics
                if !memberValuations.isEmpty {
                    let avgValue = memberValuations.reduce(0.0) { $0 + $1.1.mid } / Double(memberValuations.count)
                    
                    VStack(spacing: 8) {
                        Text("Index Average Value")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(avgValue))
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                
                // Member Details
                ForEach(memberValuations, id: \.0.id) { member, valuation in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(member.displayName)
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Estimated Value")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatCurrency(valuation.mid))
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Confidence")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(valuation.confidenceLabel)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(index.name)
        .onAppear { loadValuations() }
    }
    
    private func loadValuations() {
        memberValuations = members.map { member in
            let midYear = (Int(member.yearStart) + Int(member.yearEnd)) / 2
            let val = ValuationEngine.shared.valuate(
                make: member.make, model: member.model,
                year: midYear, mileage: midYear < Calendar.current.component(.year, from: Date()) ? (Calendar.current.component(.year, from: Date()) - midYear) * 12000 : 5000,
                trim: member.trimFilter
            )
            return (member, val)
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }
}
