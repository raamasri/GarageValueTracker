# Receipt Scanning Feature

## Overview
The Garage Value Tracker app now includes an advanced receipt scanning feature that allows users to automatically capture and extract maintenance cost information from receipts using their device's camera.

## Features

### 1. **Document Scanning**
- Uses Apple's VisionKit framework for professional-quality document scanning
- Automatic edge detection and perspective correction
- Multi-page support (captures first page for receipts)

### 2. **Optical Character Recognition (OCR)**
- Powered by Apple's Vision framework
- Extracts text with high accuracy
- Supports English language receipts

### 3. **Smart Data Extraction**
The scanner automatically identifies and extracts:
- **Amount**: Total cost from the receipt
- **Date**: Transaction date
- **Merchant Name**: Business name from the receipt header

### 4. **Auto-Fill Form Fields**
- Extracted data automatically populates the cost entry form
- Users can verify and edit the extracted information before saving
- Confidence scoring to indicate reliability of extracted data

### 5. **Receipt Storage**
- Original receipt images are stored with each cost entry
- Images are compressed (JPEG, 70% quality) to save storage space
- Full-resolution receipt viewing with pinch-to-zoom functionality

## How to Use

### Scanning a Receipt

1. Open a vehicle's detail page
2. Tap "Add Maintenance Cost"
3. Tap "Scan Receipt" in the Receipt section
4. The document scanner will open with the camera view
5. Position the receipt in the camera frame
6. The scanner will automatically detect edges and capture when ready
7. Review the captured image and tap "Save" (or retake if needed)
8. Wait for the OCR processing to complete
9. Review the auto-filled fields and make any necessary corrections
10. Tap "Save" to store the cost entry with the receipt

### Viewing Stored Receipts

1. In the vehicle detail page, cost entries with receipts show a paperclip icon
2. Tap any cost entry with a receipt to view the full receipt image
3. Use pinch-to-zoom to examine receipt details
4. Receipt metadata (category, merchant, amount, date) is displayed at the bottom

## Technical Implementation

### Files Created

1. **Models/CostEntryEntity.swift**
   - Core Data model for maintenance cost entries
   - Includes fields for receipt image storage
   - Supports categories, merchant info, and notes

2. **Services/ReceiptScannerService.swift**
   - Vision framework integration for OCR
   - Text extraction and parsing logic
   - Smart pattern matching for amounts, dates, and merchant names

3. **Views/ReceiptScannerView.swift**
   - SwiftUI wrapper for VNDocumentCameraViewController
   - Handles document scanning workflow
   - Manages success/error callbacks

4. **Views/Garage/AddCostEntryView.swift**
   - Enhanced cost entry form with receipt scanning
   - Auto-fill functionality from extracted data
   - Receipt image preview and management

5. **Views/Garage/VehicleDetailView.swift**
   - Vehicle detail page with cost history
   - Receipt viewing functionality
   - Cost summaries and analytics

### Data Extraction Algorithms

#### Amount Detection
Searches for patterns like:
- `TOTAL: $XX.XX`
- `AMOUNT: XX.XX`
- Standard currency format `$XX.XX`
- Falls back to largest dollar amount found

#### Date Detection
Recognizes formats including:
- `MM/DD/YYYY`, `DD/MM/YYYY`
- `M/D/YY`, `D/M/YY`
- `DD MMM YYYY` (e.g., "15 Jan 2024")
- Date prefixed with "Date:" or "DATE:"

#### Merchant Name Extraction
- Analyzes first 5 lines of receipt
- Filters out common non-merchant patterns (URLs, dates, generic terms)
- Prioritizes lines with letter characters
- Returns most likely merchant name

## Privacy & Permissions

### Required Permissions
- **Camera Access**: Required for document scanning
- **Usage Description**: "We need camera access to scan receipts for your maintenance records"

### Data Storage
- All receipt images are stored locally on the device
- Images are compressed to optimize storage
- Core Data manages all persistence
- No data is sent to external servers

## Cost Categories

The app supports the following maintenance categories:
- **Maintenance**: Regular servicing and upkeep
- **Repair**: Fix broken or damaged components
- **Fuel**: Gas/diesel purchases
- **Insurance**: Insurance payments
- **Registration**: DMV and registration fees
- **Modification**: Upgrades and modifications
- **Cleaning**: Car wash and detailing
- **Other**: Miscellaneous expenses

## Best Practices

### For Best Scanning Results:
1. Ensure good lighting conditions
2. Lay receipt flat on a contrasting surface
3. Avoid shadows and glare
4. Make sure text is clearly visible and not faded
5. Capture the entire receipt within the frame

### For Accurate Data Extraction:
1. Use clear, recent receipts
2. Avoid crumpled or damaged receipts
3. Ensure total amount is clearly visible
4. Date should be prominently displayed
5. Business name should be at the top of the receipt

## Future Enhancements

Potential improvements for future versions:
- [ ] Multi-receipt batch scanning
- [ ] Support for more languages
- [ ] Invoice and estimate support
- [ ] Receipt search and filtering
- [ ] Export receipts as PDF
- [ ] Cloud backup integration
- [ ] Machine learning for improved extraction
- [ ] Integration with accounting software
- [ ] Receipt categorization suggestions
- [ ] Warranty tracking from receipts

## Troubleshooting

### Scanner Won't Open
- Check camera permissions in Settings > GarageValueTracker
- Ensure device has a working camera
- Try restarting the app

### Poor OCR Results
- Retake the photo with better lighting
- Ensure receipt text is in focus
- Try cleaning the camera lens
- Manually enter data if extraction fails

### Storage Issues
- Old receipts can be deleted to free up space
- Consider archiving vehicles you no longer own
- Receipt images are already compressed

## Technical Requirements

- iOS 14.0 or later (for VisionKit support)
- Device with camera (iPhone/iPad)
- Sufficient storage space for images
- Camera permission granted

## Architecture

```
┌─────────────────────────────────────┐
│     AddCostEntryView               │
│  (User Interface)                  │
└─────────────┬───────────────────────┘
              │
              ├──> ReceiptScannerView
              │    (Document Camera)
              │           │
              │           ↓
              │    VNDocumentCameraViewController
              │    (Apple's Scanner)
              │           │
              ↓           ↓
┌─────────────────────────────────────┐
│   ReceiptScannerService             │
│   - processImage()                  │
│   - parseReceiptText()              │
│   - extractAmount()                 │
│   - extractDate()                   │
│   - extractMerchantName()           │
└─────────────┬───────────────────────┘
              │
              ├──> Vision Framework (OCR)
              │
              ↓
┌─────────────────────────────────────┐
│      CostEntryEntity                │
│      (Core Data Model)              │
└─────────────────────────────────────┘
```

## Code Examples

### Scanning a Receipt Programmatically

```swift
let scannerService = ReceiptScannerService()

scannerService.processImage(receiptImage) { receiptData in
    guard let data = receiptData else {
        print("Failed to extract data")
        return
    }
    
    print("Amount: $\(data.amount ?? 0)")
    print("Date: \(data.date ?? Date())")
    print("Merchant: \(data.merchantName ?? "Unknown")")
    print("Confidence: \(data.confidence)")
}
```

### Creating a Cost Entry with Receipt

```swift
let costEntry = CostEntryEntity(
    context: viewContext,
    vehicleID: vehicleID,
    date: Date(),
    category: "Maintenance",
    amount: 149.99,
    merchantName: "Quick Lube",
    notes: "Oil change and tire rotation",
    receiptImageData: imageData
)

try? viewContext.save()
```

## Contributing

To extend or modify the receipt scanning feature:
1. OCR logic is in `ReceiptScannerService.swift`
2. Update pattern matching in extraction methods
3. Add new cost categories in `CostCategory` enum
4. Enhance UI in `AddCostEntryView.swift`

---

Built with ❤️ using Swift, SwiftUI, Vision, and VisionKit frameworks.

