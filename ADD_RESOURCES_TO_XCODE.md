# 📦 Add Resource Files to Xcode Project

## Quick Fix Required

The following JSON resource files exist in the filesystem but need to be added to the Xcode project so they're bundled with the app:

### Files to Add:
- ✅ `GarageValueTracker/Resources/vehicle_makes_models.json` (NEW - for smart dropdowns)
- ⚠️ `GarageValueTracker/Resources/trim_database.json` (may already be added)
- ⚠️ `GarageValueTracker/Resources/service_costs.json` (may already be added)
- ⚠️ `GarageValueTracker/Resources/insurance_averages.json` (may already be added)

## How to Add Files to Xcode:

### Method 1: Drag & Drop (Easiest)
1. Open `GarageValueTracker.xcodeproj` in Xcode
2. In the Project Navigator (left sidebar), find the "Resources" folder
3. Open Finder and navigate to: `GarageValueTracker/Resources/`
4. Drag ALL `.json` files from Finder into the "Resources" folder in Xcode
5. In the dialog that appears:
   - ✅ **UNCHECK** "Copy items if needed" (files are already in place)
   - ✅ **CHECK** "GarageValueTracker" target
   - ✅ Select "Create groups"
6. Click "Finish"

### Method 2: Add Files Menu
1. Open `GarageValueTracker.xcodeproj` in Xcode
2. Right-click on "Resources" folder in Project Navigator
3. Select "Add Files to GarageValueTracker..."
4. Navigate to `GarageValueTracker/Resources/`
5. Select all `.json` files
6. Make sure:
   - ✅ "Copy items if needed" is **UNCHECKED**
   - ✅ "GarageValueTracker" target is **CHECKED**
   - ✅ "Create groups" is selected
7. Click "Add"

## Verify Files Were Added:

1. In Xcode Project Navigator, expand the "Resources" folder
2. You should see all 4 JSON files with a document icon
3. Click on each JSON file
4. In the File Inspector (right sidebar), verify:
   - "Target Membership" shows ✅ GarageValueTracker

## Test:

After adding the files:
1. Clean build folder: **Cmd+Shift+K**
2. Build and run: **Cmd+R**
3. Try adding a new vehicle - you should see dropdowns with makes/models

## What These Files Do:

- **vehicle_makes_models.json**: Powers the smart make/model/year dropdowns
- **trim_database.json**: Provides trim-level pricing and features
- **service_costs.json**: Estimates for various service costs
- **insurance_averages.json**: National/regional insurance cost data

All these files are LOCAL - no network required!

