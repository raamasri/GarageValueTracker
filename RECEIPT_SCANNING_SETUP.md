# Receipt Scanning Setup Guide

## Integration Steps for Xcode

### 1. Add Files to Xcode Project

Open your Xcode project and add the following new files:

**Models:**
- `GarageValueTracker/Models/CostEntryEntity.swift`
- `GarageValueTracker/Models/VehicleEntity.swift`

**Services:**
- `GarageValueTracker/Services/ReceiptScannerService.swift`

**Views:**
- `GarageValueTracker/Views/ReceiptScannerView.swift`
- `GarageValueTracker/Views/Garage/AddCostEntryView.swift`
- `GarageValueTracker/Views/Garage/VehicleDetailView.swift`

### 2. Update Info.plist

The `Info.plist` has been updated with the required camera permission. Verify it contains:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to scan receipts for your maintenance records</string>
```

### 3. Configure Core Data Model

You need to add entities to your Core Data model (`.xcdatamodeld` file):

#### VehicleEntity Attributes:
- `id` (UUID)
- `make` (String)
- `model` (String)
- `year` (Integer 16)
- `trim` (String, Optional)
- `vin` (String, Optional)
- `mileage` (Integer 32)
- `purchasePrice` (Double)
- `purchaseDate` (Date)
- `currentValue` (Double)
- `lastValuationUpdate` (Date, Optional)
- `imageData` (Binary Data, Optional)
- `notes` (String, Optional)
- `createdAt` (Date)
- `updatedAt` (Date)

#### CostEntryEntity Attributes:
- `id` (UUID)
- `vehicleID` (UUID)
- `date` (Date)
- `category` (String)
- `amount` (Double)
- `merchantName` (String, Optional)
- `notes` (String, Optional)
- `receiptImageData` (Binary Data, Optional)
- `receiptImagePath` (String, Optional)
- `createdAt` (Date)
- `updatedAt` (Date)

### 4. Required Frameworks

Ensure these frameworks are imported in your project:
- **VisionKit** - For document scanning
- **Vision** - For OCR text recognition
- **CoreData** - For local data persistence
- **SwiftUI** - For the user interface

### 5. Project Settings

In Xcode project settings:

1. **Deployment Target**: iOS 14.0 or later
2. **Capabilities**: 
   - Camera usage
   - Photo library access (if needed)

### 6. Build Configuration

No additional build settings or dependencies are required. All frameworks used are part of iOS SDK.

## Testing the Feature

### Manual Testing Steps:

1. **Build and Run** the app on a physical device (simulator camera is limited)

2. **Test Receipt Scanning:**
   - Add a vehicle to your garage
   - Open the vehicle detail page
   - Tap "Add Maintenance Cost"
   - Tap "Scan Receipt"
   - Point camera at a receipt
   - Verify auto-capture and edge detection
   - Review extracted data accuracy

3. **Test Data Extraction:**
   - Use various receipt types (gas station, repair shop, etc.)
   - Verify amount extraction accuracy
   - Check date parsing
   - Confirm merchant name detection

4. **Test Receipt Viewing:**
   - Save a cost entry with receipt
   - Tap on the entry in the cost history
   - Verify receipt image displays
   - Test pinch-to-zoom functionality

### Edge Cases to Test:

- Receipts with poor lighting
- Faded receipts
- Receipts with unusual formatting
- Multiple currency amounts on one receipt
- Different date formats
- Long merchant names
- Receipts with special characters

## Troubleshooting

### Common Issues:

1. **"Camera access denied"**
   - Check Info.plist has NSCameraUsageDescription
   - Settings > GarageValueTracker > Camera (ON)

2. **"Module not found: VisionKit"**
   - Ensure iOS deployment target is 14.0+
   - Clean build folder (Cmd+Shift+K)
   - Rebuild project

3. **Core Data errors**
   - Verify entity names match exactly: "VehicleEntity", "CostEntryEntity"
   - Check attribute types match the model
   - Regenerate NSManagedObject subclasses if needed

4. **OCR not working**
   - Test on physical device (simulator OCR is unreliable)
   - Verify receipt has good contrast
   - Check for clear, unfaded text

## Optional Enhancements

### Add to Your Project:

1. **Haptic Feedback:**
```swift
let generator = UINotificationFeedbackGenerator()
generator.notificationOccurred(.success) // After successful scan
```

2. **Analytics:**
Track scanning success rate and extraction accuracy

3. **Receipt Templates:**
Create preset templates for common merchant formats

4. **Batch Scanning:**
Support multiple receipts in one session

5. **Export Feature:**
Allow users to export receipts as PDF or ZIP

## File Structure

```
GarageValueTracker/
├── Models/
│   ├── CostEntryEntity.swift ✓ NEW
│   ├── VehicleEntity.swift ✓ NEW
│   ├── UserSettingsEntity.swift
│   └── ValuationSnapshotEntity.swift
├── Services/
│   └── ReceiptScannerService.swift ✓ NEW
├── Views/
│   ├── ReceiptScannerView.swift ✓ NEW
│   └── Garage/
│       ├── AddCostEntryView.swift ✓ UPDATED
│       ├── VehicleDetailView.swift ✓ UPDATED
│       ├── AddVehicleView.swift
│       └── GarageListView.swift
├── Info.plist ✓ UPDATED
└── ...
```

## Next Steps

After integrating the receipt scanning feature:

1. ✓ Add files to Xcode project
2. ✓ Configure Core Data model
3. ✓ Build and test on device
4. ✓ Test various receipt formats
5. Gather user feedback
6. Iterate on extraction accuracy
7. Add additional features as needed

## Support

For issues or questions about the receipt scanning feature, refer to:
- `RECEIPT_SCANNING.md` - Full feature documentation
- Apple's Vision Framework documentation
- Apple's VisionKit documentation

---

**Note:** This feature requires a physical iOS device with a camera. The iOS Simulator has limited camera functionality and is not suitable for testing document scanning.

