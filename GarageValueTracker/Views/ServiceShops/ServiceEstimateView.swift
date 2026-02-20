import SwiftUI

struct ServiceEstimateView: View {
    let vehicle: VehicleEntity
    @Environment(\.presentationMode) var presentationMode
    
    @State private var categories: [ServiceCategory] = []
    @State private var selectedCategory: ServiceCategory?
    @State private var selectedService: ServiceInfo?
    @State private var estimate: CostEstimate?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    vehicleHeader
                    
                    if let estimate = estimate {
                        estimateResultCard(estimate)
                        
                        Button("Get Another Estimate") {
                            self.estimate = nil
                            self.selectedService = nil
                            self.selectedCategory = nil
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding(.bottom)
                    } else if let category = selectedCategory {
                        servicePickerView(category)
                    } else {
                        categoryPickerView
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Service Estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                categories = ServiceCostEstimator.shared.getAllCategories()
            }
        }
    }
    
    // MARK: - Vehicle Header
    
    private var vehicleHeader: some View {
        HStack {
            Image(systemName: "car.fill")
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text(vehicle.displayName)
                    .font(.headline)
                if vehicle.mileage > 0 {
                    Text("\(vehicle.mileage) miles")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Category Picker
    
    private var categoryPickerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Service Category")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(categories) { category in
                Button(action: {
                    withAnimation { selectedCategory = category }
                }) {
                    HStack {
                        Image(systemName: iconForCategory(category.category))
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 40, height: 40)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.category)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Text("\(category.services.count) services")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Service Picker
    
    private func servicePickerView(_ category: ServiceCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation { selectedCategory = nil }
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("All Categories")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            Text(category.category)
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(category.services) { service in
                Button(action: {
                    withAnimation {
                        selectedService = service
                        estimate = ServiceCostEstimator.shared.estimateCost(service: service, for: vehicle)
                    }
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(service.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text(service.frequency)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(service.costRange)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Estimate Result
    
    private func estimateResultCard(_ estimate: CostEstimate) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(estimate.serviceName)
                    .font(.headline)
                
                Text("Estimated Cost for Your \(vehicle.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(estimate.formattedEstimate)
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.blue)
            
            Text("Range: \(estimate.formattedRange)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if !estimate.adjustmentFactors.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cost Adjustments")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    ForEach(estimate.adjustmentFactors, id: \.self) { factor in
                        HStack {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text(factor)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            if !estimate.baseService.factors.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Price Factors")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    ForEach(estimate.baseService.factors, id: \.self) { factor in
                        HStack(alignment: .top) {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(factor)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
    
    private func iconForCategory(_ category: String) -> String {
        switch category.lowercased() {
        case let c where c.contains("oil"): return "drop.fill"
        case let c where c.contains("tire"): return "circle.circle"
        case let c where c.contains("brake"): return "exclamationmark.octagon.fill"
        case let c where c.contains("engine"): return "engine.combustion.fill"
        case let c where c.contains("body"): return "paintbrush.fill"
        case let c where c.contains("electric"): return "bolt.fill"
        case let c where c.contains("transmission"): return "gearshape.2.fill"
        case let c where c.contains("routine"): return "wrench.fill"
        default: return "wrench.and.screwdriver.fill"
        }
    }
}
