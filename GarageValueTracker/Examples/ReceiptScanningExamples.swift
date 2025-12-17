import SwiftUI
import CoreData
import Combine

// MARK: - Example Usage of Receipt Scanning Feature

/*
 This file demonstrates how to use the receipt scanning feature
 in the Garage Value Tracker app.
 */

// MARK: - Example 1: Basic Receipt Scanning

struct ExampleReceiptScanningView: View {
    @State private var showScanner = false
    @StateObject private var scannerService = ReceiptScannerService()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Scan a Receipt")
                .font(.title)
            
            Button("Open Scanner") {
                showScanner = true
            }
            
            if scannerService.isProcessing {
                ProgressView("Processing receipt...")
            }
            
            if let receipt = scannerService.scannedReceipt {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Extracted Data:")
                        .font(.headline)
                    
                    if let amount = receipt.amount {
                        Text("Amount: $\(amount, specifier: "%.2f")")
                    }
                    
                    if let date = receipt.date {
                        Text("Date: \(date, style: .date)")
                    }
                    
                    if let merchant = receipt.merchantName {
                        Text("Merchant: \(merchant)")
                    }
                    
                    Text("Confidence: \(Int(receipt.confidence * 100))%")
                        .foregroundColor(receipt.confidence > 0.7 ? .green : .orange)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
        .sheet(isPresented: $showScanner) {
            ReceiptScannerView { image in
                processReceipt(image)
            }
        }
    }
    
    private func processReceipt(_ image: UIImage) {
        scannerService.processImage(image) { receiptData in
            print("Receipt processed!")
            if let data = receiptData {
                print("Amount: \(data.amount ?? 0)")
                print("Date: \(data.date ?? Date())")
                print("Merchant: \(data.merchantName ?? "Unknown")")
            }
        }
    }
}

// MARK: - Example 2: Integrating with Vehicle Maintenance

class MaintenanceViewModel: ObservableObject {
    @Published var vehicles: [VehicleEntity] = []
    @Published var costEntries: [CostEntryEntity] = []
    
    private let viewContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        loadVehicles()
    }
    
    func loadVehicles() {
        let request: NSFetchRequest<VehicleEntity> = VehicleEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \VehicleEntity.year, ascending: false)]
        
        do {
            vehicles = try viewContext.fetch(request)
        } catch {
            print("Error loading vehicles: \(error)")
        }
    }
    
    func addMaintenanceCost(
        vehicleID: UUID,
        category: CostCategory,
        amount: Double,
        date: Date,
        merchantName: String? = nil,
        notes: String? = nil,
        receiptImage: UIImage? = nil
    ) {
        // Convert image to data if provided
        let receiptImageData = receiptImage?.jpegData(compressionQuality: 0.7)
        
        // Create cost entry
        _ = CostEntryEntity(
            context: viewContext,
            vehicleID: vehicleID,
            date: date,
            category: category.rawValue,
            amount: amount,
            merchantName: merchantName,
            notes: notes,
            receiptImageData: receiptImageData
        )
        
        // Save to Core Data
        do {
            try viewContext.save()
            print("✅ Cost entry saved successfully!")
            
            // Update vehicle's last updated timestamp
            if let vehicle = vehicles.first(where: { $0.id == vehicleID }) {
                vehicle.updatedAt = Date()
                try viewContext.save()
            }
        } catch {
            print("❌ Error saving cost entry: \(error)")
        }
    }
    
    func getCostEntries(for vehicleID: UUID) -> [CostEntryEntity] {
        let request: NSFetchRequest<CostEntryEntity> = CostEntryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "vehicleID == %@", vehicleID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CostEntryEntity.date, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error loading cost entries: \(error)")
            return []
        }
    }
    
    func getTotalCosts(for vehicleID: UUID) -> Double {
        let entries = getCostEntries(for: vehicleID)
        return entries.reduce(0) { $0 + $1.amount }
    }
    
    func getCostsByCategory(for vehicleID: UUID) -> [String: Double] {
        let entries = getCostEntries(for: vehicleID)
        var categoryTotals: [String: Double] = [:]
        
        for entry in entries {
            categoryTotals[entry.category, default: 0] += entry.amount
        }
        
        return categoryTotals
    }
}

// MARK: - Example 3: Complete Flow with Receipt Scanner

struct CompleteMaintenanceFlowExample: View {
    @StateObject private var viewModel: MaintenanceViewModel
    @StateObject private var scannerService = ReceiptScannerService()
    
    let vehicle: VehicleEntity
    
    @State private var showScanner = false
    @State private var scannedImage: UIImage?
    @State private var amount: String = ""
    @State private var date = Date()
    @State private var merchantName: String = ""
    @State private var notes: String = ""
    @State private var category: CostCategory = .maintenance
    
    init(vehicle: VehicleEntity, context: NSManagedObjectContext) {
        self.vehicle = vehicle
        _viewModel = StateObject(wrappedValue: MaintenanceViewModel(context: context))
    }
    
    var body: some View {
        Form {
            Section("Receipt") {
                if let image = scannedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                    
                    Button("Re-scan") {
                        showScanner = true
                    }
                } else {
                    Button("Scan Receipt") {
                        showScanner = true
                    }
                }
            }
            
            Section("Details") {
                Picker("Category", selection: $category) {
                    ForEach(CostCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                
                DatePicker("Date", selection: $date, displayedComponents: .date)
                
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
                
                TextField("Merchant", text: $merchantName)
                
                TextField("Notes", text: $notes)
            }
            
            Section {
                Button("Save Maintenance Record") {
                    saveMaintenance()
                }
                .disabled(amount.isEmpty)
            }
        }
        .sheet(isPresented: $showScanner) {
            ReceiptScannerView { image in
                handleScannedReceipt(image)
            }
        }
    }
    
    private func handleScannedReceipt(_ image: UIImage) {
        scannedImage = image
        
        scannerService.processImage(image) { receiptData in
            guard let data = receiptData else { return }
            
            // Auto-fill form with extracted data
            if let extractedAmount = data.amount {
                amount = String(format: "%.2f", extractedAmount)
            }
            
            if let extractedDate = data.date {
                date = extractedDate
            }
            
            if let extractedMerchant = data.merchantName {
                merchantName = extractedMerchant
            }
        }
    }
    
    private func saveMaintenance() {
        guard let amountValue = Double(amount) else { return }
        
        viewModel.addMaintenanceCost(
            vehicleID: vehicle.id,
            category: category,
            amount: amountValue,
            date: date,
            merchantName: merchantName.isEmpty ? nil : merchantName,
            notes: notes.isEmpty ? nil : notes,
            receiptImage: scannedImage
        )
    }
}

// MARK: - Example 4: Receipt Data Extraction Only

func extractReceiptDataExample() {
    let scannerService = ReceiptScannerService()
    
    // Assuming you have a receipt image
    guard let receiptImage = UIImage(named: "sample_receipt") else {
        print("No sample receipt found")
        return
    }
    
    print("🔍 Processing receipt...")
    
    scannerService.processImage(receiptImage) { receiptData in
        guard let data = receiptData else {
            print("❌ Failed to extract data")
            return
        }
        
        print("✅ Receipt processed successfully!")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        if let amount = data.amount {
            print("💰 Amount: $\(String(format: "%.2f", amount))")
        } else {
            print("💰 Amount: Not found")
        }
        
        if let date = data.date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            print("📅 Date: \(formatter.string(from: date))")
        } else {
            print("📅 Date: Not found")
        }
        
        if let merchant = data.merchantName {
            print("🏪 Merchant: \(merchant)")
        } else {
            print("🏪 Merchant: Not found")
        }
        
        print("📊 Confidence: \(Int(data.confidence * 100))%")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("\n📄 Raw Text:")
        print(data.rawText)
    }
}

// MARK: - Example 5: Analytics & Reporting

extension MaintenanceViewModel {
    func generateMaintenanceReport(for vehicleID: UUID) -> MaintenanceReport {
        let entries = getCostEntries(for: vehicleID)
        
        let totalCost = entries.reduce(0) { $0 + $1.amount }
        let entriesWithReceipts = entries.filter { $0.receiptImageData != nil }.count
        let categoryBreakdown = getCostsByCategory(for: vehicleID)
        
        let averageCost = entries.isEmpty ? 0 : totalCost / Double(entries.count)
        
        // Find most expensive entry
        let mostExpensive = entries.max(by: { $0.amount < $1.amount })
        
        // Calculate monthly average
        let calendar = Calendar.current
        let monthsTracked = Set(entries.map { 
            calendar.dateComponents([.year, .month], from: $0.date)
        }).count
        let monthlyAverage = monthsTracked > 0 ? totalCost / Double(monthsTracked) : 0
        
        return MaintenanceReport(
            totalCost: totalCost,
            entryCount: entries.count,
            entriesWithReceipts: entriesWithReceipts,
            categoryBreakdown: categoryBreakdown,
            averageCost: averageCost,
            monthlyAverage: monthlyAverage,
            mostExpensiveEntry: mostExpensive
        )
    }
}

struct MaintenanceReport {
    let totalCost: Double
    let entryCount: Int
    let entriesWithReceipts: Int
    let categoryBreakdown: [String: Double]
    let averageCost: Double
    let monthlyAverage: Double
    let mostExpensiveEntry: CostEntryEntity?
    
    var receiptAttachmentRate: Double {
        entryCount > 0 ? Double(entriesWithReceipts) / Double(entryCount) : 0
    }
}

// MARK: - Example 6: Batch Processing Multiple Receipts

class BatchReceiptProcessor: ObservableObject {
    @Published var receipts: [ProcessedReceipt] = []
    @Published var isProcessing = false
    @Published var progress: Double = 0
    
    private let scannerService = ReceiptScannerService()
    
    func processReceipts(_ images: [UIImage], completion: @escaping () -> Void) {
        isProcessing = true
        progress = 0
        receipts.removeAll()
        
        let group = DispatchGroup()
        
        for (index, image) in images.enumerated() {
            group.enter()
            
            scannerService.processImage(image) { [weak self] receiptData in
                defer { group.leave() }
                
                if let data = receiptData {
                    let processed = ProcessedReceipt(
                        image: image,
                        data: data,
                        index: index
                    )
                    
                    DispatchQueue.main.async {
                        self?.receipts.append(processed)
                        self?.progress = Double(index + 1) / Double(images.count)
                    }
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.isProcessing = false
            completion()
        }
    }
}

struct ProcessedReceipt: Identifiable {
    let id = UUID()
    let image: UIImage
    let data: ReceiptData
    let index: Int
}

// MARK: - Example 7: Testing Utilities

#if DEBUG
struct ReceiptScannerTestUtilities {
    
    /// Create a mock receipt for testing
    static func createMockReceipt() -> ReceiptData {
        return ReceiptData(
            rawText: """
            QUICK LUBE EXPRESS
            123 Main Street
            City, ST 12345
            
            Date: 05/15/2024
            Time: 10:30 AM
            
            Oil Change - Full Synthetic    $49.99
            Tire Rotation                  $24.99
            Air Filter Replacement         $19.99
            
            Subtotal:                      $94.97
            Tax (8.5%):                     $8.07
            TOTAL:                        $103.04
            
            Thank you for your business!
            """,
            amount: 103.04,
            date: Calendar.current.date(from: DateComponents(year: 2024, month: 5, day: 15)),
            merchantName: "Quick Lube Express",
            confidence: 0.95
        )
    }
    
    /// Test the extraction algorithms
    static func testExtractionAccuracy() {
        let testCases = [
            ("TOTAL: $49.99", 49.99),
            ("$129.50", 129.50),
            ("Amount Due: 75.00", 75.00),
            ("GRAND TOTAL $1,234.56", 1234.56)
        ]
        
        _ = ReceiptScannerService()
        
        for (text, expectedAmount) in testCases {
            // Note: This is a simplified test
            // In practice, you'd need to expose extraction methods for testing
            print("Testing: \(text)")
            print("Expected: $\(expectedAmount)")
        }
    }
}
#endif

// MARK: - Preview Provider

struct ReceiptExamples_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ExampleReceiptScanningView()
                .previewDisplayName("Basic Scanner")
            
            // Additional previews would go here
        }
    }
}

