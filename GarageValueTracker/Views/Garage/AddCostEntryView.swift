import SwiftUI
import CoreData

struct AddCostEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    let vehicleID: UUID
    
    @State private var selectedCategory: CostCategory = .maintenance
    @State private var amount: String = ""
    @State private var merchantName: String = ""
    @State private var notes: String = ""
    @State private var date = Date()
    @State private var showingScanner = false
    @State private var scannedImage: UIImage?
    @State private var receiptImageData: Data?
    @StateObject private var scannerService = ReceiptScannerService()
    @State private var showingScanAlert = false
    @State private var scanAlertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                // Receipt Scanner Section
                Section(header: Text("Receipt")) {
                    if let image = scannedImage {
                        VStack(spacing: 12) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(8)
                            
                            HStack {
                                Button(action: {
                                    showingScanner = true
                                }) {
                                    Label("Re-scan Receipt", systemImage: "camera")
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    scannedImage = nil
                                    receiptImageData = nil
                                }) {
                                    Label("Remove", systemImage: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        if scannerService.isProcessing {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Processing receipt...")
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Button(action: {
                            showingScanner = true
                        }) {
                            HStack {
                                Image(systemName: "doc.text.viewfinder")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                Text("Scan Receipt")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                // Cost Details Section
                Section(header: Text("Details")) {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(CostCategory.allCases, id: \.self) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                    }
                    
                    TextField("Merchant (Optional)", text: $merchantName)
                }
                
                // Notes Section
                Section(header: Text("Notes (Optional)")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Cost")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCostEntry()
                    }
                    .disabled(!isValidEntry)
                }
            }
            .sheet(isPresented: $showingScanner) {
                ReceiptScannerView { image in
                    handleScannedImage(image)
                }
            }
            .alert("Receipt Scanned", isPresented: $showingScanAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(scanAlertMessage)
            }
        }
    }
    
    private var isValidEntry: Bool {
        guard let amountValue = Double(amount), amountValue > 0 else {
            return false
        }
        return true
    }
    
    private func handleScannedImage(_ image: UIImage) {
        scannedImage = image
        receiptImageData = image.jpegData(compressionQuality: 0.7)
        
        // Process the image to extract data
        scannerService.processImage(image) { receiptData in
            guard let data = receiptData else {
                scanAlertMessage = "Could not extract data from receipt. Please enter details manually."
                showingScanAlert = true
                return
            }
            
            // Auto-fill fields with extracted data
            if let extractedAmount = data.amount {
                amount = String(format: "%.2f", extractedAmount)
            }
            
            if let extractedDate = data.date {
                date = extractedDate
            }
            
            if let extractedMerchant = data.merchantName, !extractedMerchant.isEmpty {
                merchantName = extractedMerchant
            }
            
            // Show success message
            var extractedFields: [String] = []
            if data.amount != nil { extractedFields.append("amount") }
            if data.date != nil { extractedFields.append("date") }
            if data.merchantName != nil { extractedFields.append("merchant") }
            
            if !extractedFields.isEmpty {
                scanAlertMessage = "Extracted: \(extractedFields.joined(separator: ", ")). Please verify the details."
                showingScanAlert = true
            } else {
                scanAlertMessage = "Receipt saved, but could not extract details. Please enter manually."
                showingScanAlert = true
            }
        }
    }
    
    private func saveCostEntry() {
        guard let amountValue = Double(amount) else { return }
        
        let costEntry = CostEntryEntity(
            context: viewContext,
            vehicleID: vehicleID,
            date: date,
            category: selectedCategory.rawValue,
            amount: amountValue,
            merchantName: merchantName.isEmpty ? nil : merchantName,
            notes: notes.isEmpty ? nil : notes,
            receiptImageData: receiptImageData
        )
        
        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving cost entry: \(error.localizedDescription)")
        }
    }
}

// Preview
struct AddCostEntryView_Previews: PreviewProvider {
    static var previews: some View {
        AddCostEntryView(vehicleID: UUID())
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
