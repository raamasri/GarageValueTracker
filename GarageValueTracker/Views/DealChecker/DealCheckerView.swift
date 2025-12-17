import SwiftUI

struct DealCheckerView: View {
    @State private var make: String = ""
    @State private var model: String = ""
    @State private var year: String = ""
    @State private var trim: String = ""
    @State private var mileage: String = ""
    @State private var askingPrice: String = ""
    @State private var location: String = ""
    @State private var hasAccidentHistory = false
    @State private var accidentSeverity: AccidentRecord.AccidentSeverity = .minor
    
    @State private var showingResults = false
    @State private var analysisResult: DealAnalysisResult?
    @State private var showingTrimSelection = false
    @State private var selectedTrimData: TrimData?
    @State private var hasTrimsAvailable = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Deal Checker")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Get instant analysis on any vehicle deal")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // Input Form
                    VStack(spacing: 16) {
                        // Vehicle Info Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Vehicle Information")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            TextField("Make (e.g., Toyota)", text: $make)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.words)
                                .onChange(of: make) {
                                    checkTrimsAvailability()
                                }
                            
                            TextField("Model (e.g., Camry)", text: $model)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.words)
                                .onChange(of: model) {
                                    checkTrimsAvailability()
                                }
                            
                            TextField("Year", text: $year)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                                .onChange(of: year) {
                                    checkTrimsAvailability()
                                }
                            
                            // Trim selection
                            if hasTrimsAvailable {
                                Button(action: {
                                    showingTrimSelection = true
                                }) {
                                    HStack {
                                        Text("Trim")
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if let trimData = selectedTrimData {
                                            Text(trimData.trimLevel)
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text("Select Trim")
                                                .foregroundColor(.blue)
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            } else {
                                TextField("Trim (Optional)", text: $trim)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            TextField("Mileage", text: $mileage)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        
                        // Price & Location Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Price & Location")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("$")
                                    .foregroundColor(.secondary)
                                    .font(.title3)
                                TextField("Asking Price", text: $askingPrice)
                                    .keyboardType(.decimalPad)
                                    .font(.title3)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            
                            TextField("Location (Optional, e.g., California)", text: $location)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.words)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        
                        // Condition Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Condition")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Toggle("Has Accident History", isOn: $hasAccidentHistory)
                            
                            if hasAccidentHistory {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Accident Severity")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Picker("Severity", selection: $accidentSeverity) {
                                        Text("Minor").tag(AccidentRecord.AccidentSeverity.minor)
                                        Text("Moderate").tag(AccidentRecord.AccidentSeverity.moderate)
                                        Text("Major").tag(AccidentRecord.AccidentSeverity.major)
                                        Text("Structural").tag(AccidentRecord.AccidentSeverity.structural)
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        
                        // Analyze Button
                        Button(action: analyzeDeal) {
                            HStack {
                                Image(systemName: "chart.bar.doc.horizontal")
                                Text("Analyze Deal")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isValidInput ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!isValidInput)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Deal Checker")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingResults) {
                if let result = analysisResult {
                    DealAnalysisResultView(result: result)
                }
            }
            .sheet(isPresented: $showingTrimSelection) {
                if let yearInt = Int(year), !make.isEmpty, !model.isEmpty {
                    TrimSelectionView(
                        make: make,
                        model: model,
                        year: yearInt,
                        selectedTrim: $selectedTrimData
                    )
                }
            }
        }
    }
    
    private var isValidInput: Bool {
        !make.isEmpty && !model.isEmpty && !year.isEmpty &&
        !mileage.isEmpty && !askingPrice.isEmpty
    }
    
    private func checkTrimsAvailability() {
        guard let yearInt = Int(year), !make.isEmpty, !model.isEmpty else {
            hasTrimsAvailable = false
            return
        }
        
        hasTrimsAvailable = TrimDatabaseService.shared.hasTrimsAvailable(
            make: make,
            model: model,
            year: yearInt
        )
        
        if hasTrimsAvailable {
            selectedTrimData = nil
        }
    }
    
    private func analyzeDeal() {
        guard let yearInt = Int(year),
              let mileageInt = Int(mileage),
              let priceDouble = Double(askingPrice) else {
            return
        }
        
        let trimName = selectedTrimData?.trimLevel ?? (trim.isEmpty ? nil : trim)
        
        let result = DealAnalysisEngine.shared.analyzeDeal(
            make: make,
            model: model,
            year: yearInt,
            trim: trimName,
            mileage: mileageInt,
            askingPrice: priceDouble,
            location: location.isEmpty ? nil : location,
            hasAccidentHistory: hasAccidentHistory,
            accidentSeverity: hasAccidentHistory ? accidentSeverity : nil
        )
        
        analysisResult = result
        showingResults = true
    }
}

struct DealCheckerView_Previews: PreviewProvider {
    static var previews: some View {
        DealCheckerView()
    }
}
