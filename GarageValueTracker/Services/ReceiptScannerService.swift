import Foundation
import Vision
import UIKit
import VisionKit
import Combine

// Structure to hold extracted receipt data
struct ReceiptData {
    var amount: Double?
    var date: Date?
    var merchantName: String?
    var rawText: String
    var confidence: Float
    
    init(rawText: String = "", amount: Double? = nil, date: Date? = nil, merchantName: String? = nil, confidence: Float = 0.0) {
        self.rawText = rawText
        self.amount = amount
        self.date = date
        self.merchantName = merchantName
        self.confidence = confidence
    }
}

class ReceiptScannerService: ObservableObject {
    @Published var scannedReceipt: ReceiptData?
    @Published var isProcessing = false
    @Published var error: String?
    
    // Process a scanned image and extract text using Vision framework
    func processImage(_ image: UIImage, completion: @escaping (ReceiptData?) -> Void) {
        guard let cgImage = image.cgImage else {
            error = "Unable to process image"
            completion(nil)
            return
        }
        
        isProcessing = true
        error = nil
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isProcessing = false
                
                if let error = error {
                    self.error = "Text recognition failed: \(error.localizedDescription)"
                    completion(nil)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    self.error = "No text found in image"
                    completion(nil)
                    return
                }
                
                // Extract text from observations
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                let fullText = recognizedStrings.joined(separator: "\n")
                
                // Parse the receipt data
                let receiptData = self.parseReceiptText(fullText)
                self.scannedReceipt = receiptData
                completion(receiptData)
            }
        }
        
        // Configure for accurate text recognition
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true
        
        do {
            try requestHandler.perform([request])
        } catch {
            DispatchQueue.main.async {
                self.isProcessing = false
                self.error = "Failed to perform text recognition: \(error.localizedDescription)"
                completion(nil)
            }
        }
    }
    
    // Parse receipt text to extract key information
    private func parseReceiptText(_ text: String) -> ReceiptData {
        var receiptData = ReceiptData(rawText: text)
        
        // Extract amount
        receiptData.amount = extractAmount(from: text)
        
        // Extract date
        receiptData.date = extractDate(from: text)
        
        // Extract merchant name (usually in first few lines)
        receiptData.merchantName = extractMerchantName(from: text)
        
        // Calculate confidence based on extracted data
        var confidenceScore: Float = 0.0
        if receiptData.amount != nil { confidenceScore += 0.4 }
        if receiptData.date != nil { confidenceScore += 0.3 }
        if receiptData.merchantName != nil { confidenceScore += 0.3 }
        receiptData.confidence = confidenceScore
        
        return receiptData
    }
    
    // Extract monetary amount from text
    private func extractAmount(from text: String) -> Double? {
        // Common patterns for amounts: $XX.XX, XX.XX, TOTAL: XX.XX, etc.
        let patterns = [
            #"(?:TOTAL|AMOUNT|SUBTOTAL|GRAND TOTAL)[\s:]*\$?(\d+\.\d{2})"#,
            #"\$(\d+\.\d{2})"#,
            #"(\d+\.\d{2})\s*(?:USD|$)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let range = Range(match.range(at: 1), in: text),
                   let amount = Double(text[range]) {
                    return amount
                }
            }
        }
        
        // Fallback: find largest dollar amount
        let amountPattern = #"\$?(\d+\.\d{2})"#
        if let regex = try? NSRegularExpression(pattern: amountPattern, options: []) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            let amounts = matches.compactMap { match -> Double? in
                guard let range = Range(match.range(at: 1), in: text) else { return nil }
                return Double(text[range])
            }
            return amounts.max()
        }
        
        return nil
    }
    
    // Extract date from text
    private func extractDate(from text: String) -> Date? {
        // Common date patterns
        let patterns = [
            #"(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})"#,
            #"(\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4})"#,
            #"(?:Date|DATE)[\s:]*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})"#
        ]
        
        let dateFormatters = [
            "MM/dd/yyyy", "M/d/yyyy", "MM-dd-yyyy", "M-d-yyyy",
            "dd/MM/yyyy", "d/M/yyyy", "dd-MM-yyyy", "d-M-yyyy",
            "d MMM yyyy", "dd MMM yyyy", "d MMMM yyyy"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let dateString = String(text[range])
                
                for format in dateFormatters {
                    let formatter = DateFormatter()
                    formatter.dateFormat = format
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }
            }
        }
        
        return nil
    }
    
    // Extract merchant name (typically from first few lines)
    private func extractMerchantName(from text: String) -> String? {
        let lines = text.split(separator: "\n").map(String.init)
        guard !lines.isEmpty else { return nil }
        
        // Skip lines that are likely not merchant names
        let skipPatterns = [
            #"^\d+$"#, // Just numbers
            #"^[A-Z]{2,3}\s+\d+"#, // State + number
            #"^Receipt$"#, // Generic "Receipt"
            #"^Invoice$"#, // Generic "Invoice"
            #"^\d{1,2}[/-]\d{1,2}[/-]\d{2,4}$"#, // Just a date
            #"^www\."#, // Website
            #"^http"# // URL
        ]
        
        // Take first 5 lines and filter
        for line in lines.prefix(5) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 3 && trimmed.count <= 50 else { continue }
            
            var shouldSkip = false
            for pattern in skipPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                    shouldSkip = true
                    break
                }
            }
            
            if !shouldSkip && trimmed.contains(where: { $0.isLetter }) {
                return trimmed
            }
        }
        
        return lines.first?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

