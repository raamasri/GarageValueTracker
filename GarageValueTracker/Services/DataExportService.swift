import Foundation
import CoreData
import UIKit

class DataExportService {
    static let shared = DataExportService()
    private init() {}
    
    // MARK: - CSV Export
    
    func exportCostEntriesCSV(for vehicle: VehicleEntity, context: NSManagedObjectContext) -> URL? {
        let request: NSFetchRequest<CostEntryEntity> = CostEntryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "vehicleID == %@", vehicle.id as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CostEntryEntity.date, ascending: true)]
        
        guard let entries = try? context.fetch(request) else { return nil }
        
        var csv = "Date,Category,Amount,Merchant,Notes\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        for entry in entries {
            let date = dateFormatter.string(from: entry.date)
            let category = entry.category.replacingOccurrences(of: ",", with: ";")
            let merchant = (entry.merchantName ?? "").replacingOccurrences(of: ",", with: ";")
            let notes = (entry.notes ?? "").replacingOccurrences(of: ",", with: ";").replacingOccurrences(of: "\n", with: " ")
            csv += "\(date),\(category),\(String(format: "%.2f", entry.amount)),\(merchant),\(notes)\n"
        }
        
        let fileName = "\(vehicle.displayName.replacingOccurrences(of: " ", with: "_"))_costs.csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Error writing CSV: \(error)")
            return nil
        }
    }
    
    func exportAllVehiclesCSV(context: NSManagedObjectContext) -> URL? {
        let request: NSFetchRequest<VehicleEntity> = VehicleEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \VehicleEntity.year, ascending: false)]
        
        guard let vehicles = try? context.fetch(request) else { return nil }
        
        var csv = "Year,Make,Model,Trim,VIN,Mileage,Purchase Price,Current Value,Purchase Date,Insurance Provider,Insurance Premium\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        for v in vehicles {
            let trim = (v.trim ?? "").replacingOccurrences(of: ",", with: ";")
            let vin = v.vin ?? ""
            let insurance = v.insuranceProvider ?? ""
            csv += "\(v.year),\(v.make),\(v.model),\(trim),\(vin),\(v.mileage),"
            csv += "\(String(format: "%.2f", v.purchasePrice)),\(String(format: "%.2f", v.currentValue)),"
            csv += "\(dateFormatter.string(from: v.purchaseDate)),\(insurance),\(String(format: "%.2f", v.insurancePremium))\n"
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("garage_vehicles.csv")
        
        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Error writing CSV: \(error)")
            return nil
        }
    }
    
    // MARK: - PDF Report
    
    func generateVehicleReport(for vehicle: VehicleEntity, costEntries: [CostEntryEntity], fuelEntries: [FuelEntryEntity], context: NSManagedObjectContext) -> URL? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - (margin * 2)
        
        let pdfData = NSMutableData()
        let consumer = CGDataConsumer(data: pdfData as CFMutableData)!
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }
        
        var yPosition: CGFloat = pageHeight - margin
        
        func startNewPage() {
            if yPosition < pageHeight - margin {
                pdfContext.endPage()
            }
            pdfContext.beginPage(mediaBox: &mediaBox)
            yPosition = pageHeight - margin
        }
        
        func drawText(_ text: String, x: CGFloat, y: CGFloat, font: UIFont, color: UIColor = .black) {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color
            ]
            let attrString = NSAttributedString(string: text, attributes: attributes)
            let line = CTLineCreateWithAttributedString(attrString)
            pdfContext.saveGState()
            pdfContext.textMatrix = CGAffineTransform.identity
            pdfContext.translateBy(x: x, y: y)
            CTLineDraw(line, pdfContext)
            pdfContext.restoreGState()
        }
        
        func drawLine(from: CGPoint, to: CGPoint, color: UIColor = .lightGray) {
            pdfContext.saveGState()
            pdfContext.setStrokeColor(color.cgColor)
            pdfContext.setLineWidth(0.5)
            pdfContext.move(to: from)
            pdfContext.addLine(to: to)
            pdfContext.strokePath()
            pdfContext.restoreGState()
        }
        
        func checkPageBreak(_ needed: CGFloat) {
            if yPosition - needed < margin {
                startNewPage()
            }
        }
        
        // PAGE 1: Vehicle Overview
        startNewPage()
        
        // Title
        drawText("Vehicle Report Card", x: margin, y: yPosition, font: .boldSystemFont(ofSize: 24))
        yPosition -= 30
        
        drawText(vehicle.displayName, x: margin, y: yPosition, font: .boldSystemFont(ofSize: 18), color: .darkGray)
        yPosition -= 20
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        drawText("Generated \(dateFormatter.string(from: Date()))", x: margin, y: yPosition, font: .systemFont(ofSize: 10), color: .gray)
        yPosition -= 25
        
        drawLine(from: CGPoint(x: margin, y: yPosition), to: CGPoint(x: pageWidth - margin, y: yPosition))
        yPosition -= 25
        
        // Vehicle Info Section
        drawText("Vehicle Information", x: margin, y: yPosition, font: .boldSystemFont(ofSize: 16))
        yPosition -= 22
        
        let vehicleInfo: [(String, String)] = [
            ("Make / Model", "\(vehicle.year) \(vehicle.make) \(vehicle.model)"),
            ("Trim", vehicle.trim ?? "N/A"),
            ("VIN", vehicle.vin ?? "N/A"),
            ("Mileage", "\(vehicle.mileage) miles"),
            ("Purchase Date", dateFormatter.string(from: vehicle.purchaseDate)),
            ("Purchase Price", "$\(String(format: "%.2f", vehicle.purchasePrice))"),
            ("Current Value", "$\(String(format: "%.2f", vehicle.currentValue))"),
            ("Location", vehicle.location ?? "N/A")
        ]
        
        for (label, value) in vehicleInfo {
            drawText(label, x: margin, y: yPosition, font: .systemFont(ofSize: 11), color: .gray)
            drawText(value, x: margin + 150, y: yPosition, font: .systemFont(ofSize: 11))
            yPosition -= 16
        }
        
        yPosition -= 15
        drawLine(from: CGPoint(x: margin, y: yPosition), to: CGPoint(x: pageWidth - margin, y: yPosition))
        yPosition -= 25
        
        // Depreciation Summary
        drawText("Depreciation Summary", x: margin, y: yPosition, font: .boldSystemFont(ofSize: 16))
        yPosition -= 22
        
        let depreciation = max(vehicle.purchasePrice - vehicle.currentValue, 0)
        let depPercent = vehicle.purchasePrice > 0 ? (depreciation / vehicle.purchasePrice) * 100 : 0
        
        let depInfo: [(String, String)] = [
            ("Total Depreciation", "$\(String(format: "%.2f", depreciation))"),
            ("Depreciation %", "\(String(format: "%.1f", depPercent))%"),
            ("Value Retained", "\(String(format: "%.1f", 100 - depPercent))%")
        ]
        
        for (label, value) in depInfo {
            drawText(label, x: margin, y: yPosition, font: .systemFont(ofSize: 11), color: .gray)
            drawText(value, x: margin + 150, y: yPosition, font: .boldSystemFont(ofSize: 11))
            yPosition -= 16
        }
        
        yPosition -= 15
        drawLine(from: CGPoint(x: margin, y: yPosition), to: CGPoint(x: pageWidth - margin, y: yPosition))
        yPosition -= 25
        
        // Cost Summary
        drawText("Cost of Ownership Summary", x: margin, y: yPosition, font: .boldSystemFont(ofSize: 16))
        yPosition -= 22
        
        let totalMaintenance = costEntries.reduce(0.0) { $0 + $1.amount }
        let totalFuel = fuelEntries.reduce(0.0) { $0 + $1.cost }
        let monthsOwned = max(Calendar.current.dateComponents([.month], from: vehicle.purchaseDate, to: Date()).month ?? 1, 1)
        let totalInsurance = vehicle.insurancePremium > 0 ? vehicle.insurancePremium * (Double(monthsOwned) / 12.0) : 0
        let totalTCO = depreciation + totalMaintenance + totalFuel + totalInsurance
        
        let costSummary: [(String, String)] = [
            ("Depreciation", "$\(String(format: "%.2f", depreciation))"),
            ("Maintenance & Repairs", "$\(String(format: "%.2f", totalMaintenance)) (\(costEntries.count) entries)"),
            ("Fuel", "$\(String(format: "%.2f", totalFuel)) (\(fuelEntries.count) fill-ups)"),
            ("Insurance (est.)", "$\(String(format: "%.2f", totalInsurance))"),
            ("Total Cost of Ownership", "$\(String(format: "%.2f", totalTCO))"),
            ("Cost per Month", "$\(String(format: "%.2f", totalTCO / Double(monthsOwned)))"),
        ]
        
        for (i, (label, value)) in costSummary.enumerated() {
            let isTotal = i == costSummary.count - 2
            let font: UIFont = isTotal ? .boldSystemFont(ofSize: 12) : .systemFont(ofSize: 11)
            drawText(label, x: margin, y: yPosition, font: font, color: isTotal ? .black : .gray)
            drawText(value, x: margin + 200, y: yPosition, font: isTotal ? .boldSystemFont(ofSize: 12) : .systemFont(ofSize: 11))
            yPosition -= 16
            
            if isTotal {
                yPosition -= 4
                drawLine(from: CGPoint(x: margin, y: yPosition + 10), to: CGPoint(x: pageWidth - margin, y: yPosition + 10))
                yPosition -= 4
            }
        }
        
        // Insurance Info
        if vehicle.insuranceProvider != nil || vehicle.insurancePremium > 0 {
            yPosition -= 15
            drawLine(from: CGPoint(x: margin, y: yPosition), to: CGPoint(x: pageWidth - margin, y: yPosition))
            yPosition -= 25
            
            drawText("Insurance Information", x: margin, y: yPosition, font: .boldSystemFont(ofSize: 16))
            yPosition -= 22
            
            let insuranceInfo: [(String, String)] = [
                ("Provider", vehicle.insuranceProvider ?? "N/A"),
                ("Annual Premium", "$\(String(format: "%.2f", vehicle.insurancePremium))"),
                ("Coverage Level", vehicle.coverageLevel ?? "N/A")
            ]
            
            for (label, value) in insuranceInfo {
                drawText(label, x: margin, y: yPosition, font: .systemFont(ofSize: 11), color: .gray)
                drawText(value, x: margin + 150, y: yPosition, font: .systemFont(ofSize: 11))
                yPosition -= 16
            }
        }
        
        // PAGE 2: Cost History
        if !costEntries.isEmpty {
            startNewPage()
            
            drawText("Maintenance & Cost History", x: margin, y: yPosition, font: .boldSystemFont(ofSize: 16))
            yPosition -= 22
            
            // Table header
            drawText("Date", x: margin, y: yPosition, font: .boldSystemFont(ofSize: 10))
            drawText("Category", x: margin + 80, y: yPosition, font: .boldSystemFont(ofSize: 10))
            drawText("Merchant", x: margin + 180, y: yPosition, font: .boldSystemFont(ofSize: 10))
            drawText("Amount", x: margin + 350, y: yPosition, font: .boldSystemFont(ofSize: 10))
            yPosition -= 5
            drawLine(from: CGPoint(x: margin, y: yPosition), to: CGPoint(x: pageWidth - margin, y: yPosition))
            yPosition -= 14
            
            let shortDateFormatter = DateFormatter()
            shortDateFormatter.dateStyle = .short
            
            for entry in costEntries {
                checkPageBreak(20)
                
                drawText(shortDateFormatter.string(from: entry.date), x: margin, y: yPosition, font: .systemFont(ofSize: 9))
                drawText(entry.category, x: margin + 80, y: yPosition, font: .systemFont(ofSize: 9))
                drawText(entry.merchantName ?? "", x: margin + 180, y: yPosition, font: .systemFont(ofSize: 9))
                drawText("$\(String(format: "%.2f", entry.amount))", x: margin + 350, y: yPosition, font: .systemFont(ofSize: 9))
                yPosition -= 14
            }
        }
        
        // Footer
        yPosition -= 20
        drawLine(from: CGPoint(x: margin, y: yPosition), to: CGPoint(x: pageWidth - margin, y: yPosition))
        yPosition -= 15
        drawText("Generated by Garage Value Tracker", x: margin, y: yPosition, font: .italicSystemFont(ofSize: 8), color: .gray)
        
        pdfContext.endPage()
        pdfContext.closePDF()
        
        let fileName = "\(vehicle.displayName.replacingOccurrences(of: " ", with: "_"))_Report.pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try pdfData.write(to: tempURL)
            return tempURL
        } catch {
            print("Error writing PDF: \(error)")
            return nil
        }
    }
}
