import SwiftUI
import CoreData

struct ServiceEstimatorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    let vehicle: VehicleEntity?
    
    @State private var categories: [ServiceCategory] = []
    @State private var selectedCategory: ServiceCategory?
    @State private var selectedService: ServiceInfo?
    @State private var showingServiceDetail = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Service Cost Estimator")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Get cost estimates for common services")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search services...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .padding()
                
                // Content
                if searchText.isEmpty {
                    categoryListView
                } else {
                    searchResultsView
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingServiceDetail) {
                if let service = selectedService {
                    ServiceDetailView(
                        service: service,
                        vehicle: vehicle,
                        viewContext: viewContext
                    )
                }
            }
            .onAppear {
                loadCategories()
            }
        }
    }
    
    private var categoryListView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(categories) { category in
                    CategoryCard(category: category) {
                        selectedCategory = category
                    }
                }
            }
            .padding()
        }
    }
    
    private var searchResultsView: some View {
        ScrollView {
            VStack(spacing: 12) {
                let results = ServiceCostEstimator.shared.searchServices(query: searchText)
                
                if results.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No services found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Try a different search term")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 60)
                } else {
                    ForEach(results) { service in
                        ServiceRow(service: service) {
                            selectedService = service
                            showingServiceDetail = true
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func loadCategories() {
        categories = ServiceCostEstimator.shared.getAllCategories()
    }
}

// MARK: - Category Card
struct CategoryCard: View {
    let category: ServiceCategory
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: categoryIcon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(categoryColor)
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.category)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(category.services.count) services")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var categoryIcon: String {
        switch category.category {
        case "Routine Maintenance": return "calendar"
        case "Brakes": return "exclamationmark.octagon"
        case "Tires": return "circle.circle"
        case "Fluids": return "drop"
        case "Suspension": return "arrow.up.and.down"
        case "Cosmetic": return "paintbrush"
        case "Major Services": return "wrench.and.screwdriver"
        case "Electrical": return "bolt"
        default: return "gear"
        }
    }
    
    private var categoryColor: Color {
        switch category.category {
        case "Routine Maintenance": return .blue
        case "Brakes": return .red
        case "Tires": return .black
        case "Fluids": return .cyan
        case "Suspension": return .orange
        case "Cosmetic": return .purple
        case "Major Services": return .green
        case "Electrical": return .yellow
        default: return .gray
        }
    }
}

// MARK: - Service Row
struct ServiceRow: View {
    let service: ServiceInfo
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(service.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(formatCurrency(service.baseCost))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                Text(service.costRange)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(service.frequency)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
}

// MARK: - Service Detail View
struct ServiceDetailView: View {
    let service: ServiceInfo
    let vehicle: VehicleEntity?
    let viewContext: NSManagedObjectContext
    
    @Environment(\.presentationMode) var presentationMode
    @State private var estimate: CostEstimate?
    @State private var showingAddCost = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Service Header
                    VStack(spacing: 12) {
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text(service.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // Cost Estimate
                    if let estimate = estimate, let vehicle = vehicle {
                        VStack(spacing: 16) {
                            VStack(spacing: 8) {
                                Text("Estimated Cost")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text(estimate.formattedEstimate)
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.blue)
                                
                                Text("Range: \(estimate.formattedRange)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            if !estimate.adjustmentFactors.isEmpty {
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Adjustments for your vehicle:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    
                                    ForEach(estimate.adjustmentFactors, id: \.self) { factor in
                                        HStack(spacing: 8) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                            
                                            Text(factor)
                                                .font(.caption)
                                                .foregroundColor(.primary)
                                        }
                                    }
                                }
                            }
                            
                            Button(action: {
                                showingAddCost = true
                            }) {
                                Label("Add to Vehicle Costs", systemImage: "plus.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    } else {
                        VStack(spacing: 16) {
                            Text("Base Cost: \(formatCurrency(service.baseCost))")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                            
                            Text("Range: \(service.costRange)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if vehicle == nil {
                                Text("Select a vehicle to get personalized estimate")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                    
                    // Service Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Service Details")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        DetailRow(icon: "calendar", title: "Frequency", value: service.frequency)
                        DetailRow(icon: "dollarsign.circle", title: "Typical Cost", value: service.costRange)
                        
                        if !service.factors.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                    Text("Cost Factors")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                
                                ForEach(service.factors, id: \.self) { factor in
                                    Text("• \(factor)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 28)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                if let vehicle = vehicle {
                    estimate = ServiceCostEstimator.shared.estimateCost(service: service, for: vehicle)
                }
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

