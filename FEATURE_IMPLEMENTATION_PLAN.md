# Feature Implementation Plan
## GarageValueTracker - Enhanced Features

**Date Created:** December 16, 2025  
**Approach:** Local-only, no account management, all data stored via CoreData

---

## 📋 Overview

This plan outlines the implementation of advanced features to enhance the GarageValueTracker app while maintaining a fully local data architecture. Features are organized into phases based on complexity and dependencies.

---

## 🎯 Feature Breakdown by Phase

### **PHASE 1: Trim & Pricing Intelligence** (Foundation)
*Priority: HIGH - Enables most other features*

#### 1.1 Separate Premium vs Base Trims
**Current State:** App has a `trim` field but treats all trims equally  
**Goal:** Differentiate between trim levels with pricing intelligence

**Implementation Steps:**
1. **Data Model Updates**
   - Add `TrimEntity` to CoreData:
     ```swift
     - id: UUID
     - vehicleID: UUID
     - trimLevel: String (e.g., "Base", "Premium", "Limited")
     - msrp: Double
     - features: [String] (JSON encoded array)
     - marketValue: Double?
     - lastUpdated: Date
     ```
   - Update `VehicleEntity` to include:
     - `selectedTrimID: UUID?`
     - `trimComparisons: Data?` (JSON encoded array of comparable trims)

2. **Trim Database Service**
   - Create `TrimDatabaseService.swift` with local JSON database:
     - Store common trim levels by make/model/year
     - Include MSRP differentials (e.g., Premium = Base + $5k)
     - Feature differences per trim
   - Bundle initial trim data file: `trim_database.json`

3. **UI Components**
   - Create `TrimSelectionView.swift`:
     - Dropdown/picker for trim selection when adding vehicle
     - Show MSRP for each trim level
   - Create `TrimComparisonView.swift`:
     - Side-by-side comparison of selected trim vs others
     - Feature differences highlighted
     - Price differentials clearly shown

#### 1.2 Show Trim Price Differences
**Goal:** Automatically display price differences between trims

**Implementation Steps:**
1. **Create `TrimPricingService.swift`**
   - Calculate price differentials between trims
   - Methods:
     - `getPriceDifferential(from: Trim, to: Trim) -> Double`
     - `getFeatureDifferences(from: Trim, to: Trim) -> [String]`

2. **Update `VehicleDetailView`**
   - Add new section: "Trim Information"
   - Show current trim's MSRP
   - Add button: "Compare with other trims"
   - Display: "Premium trim adds $5,000 and includes: Leather seats, Sunroof, etc."

3. **Data Population**
   - Create comprehensive trim database for popular makes/models
   - Include at minimum:
     - Top 20 makes
     - Common trim levels (Base, Premium, Limited, Sport, etc.)
     - MSRP data for years 2015-2025

---

### **PHASE 2: Deal Intelligence & Market Analysis**
*Priority: HIGH - Core value proposition*

#### 2.1 "What's Driving the Good Deal" Analysis
**Goal:** Provide detailed breakdown of deal quality factors

**Implementation Steps:**
1. **Create `DealAnalysisEngine.swift`**
   - Scoring algorithm that considers:
     - Price vs market value (-20% to +20% scale)
     - Mileage vs average for year (-30% to +30%)
     - Trim level value (is asking price fair for trim?)
     - Condition factors (accident history, maintenance)
     - Location market adjustments
   
2. **Data Models**
   - Add `DealAnalysisEntity` to CoreData:
     ```swift
     - id: UUID
     - vehicleID: UUID (or potential purchase ID)
     - overallScore: Int16 (0-100)
     - priceScore: Int16
     - mileageScore: Int16
     - conditionScore: Int16
     - marketScore: Int16
     - insights: [String] (JSON array)
     - createdAt: Date
     ```

3. **Scoring Logic**
   - **Price Factor** (30% weight):
     - Compare asking price to trim-specific market value
     - Formula: `score = 100 - ((askingPrice - marketValue) / marketValue * 100)`
   
   - **Mileage Factor** (25% weight):
     - Average miles per year for vehicle age
     - Formula: `expectedMiles = (currentYear - vehicleYear) * 12000`
     - Score based on deviation from expected
   
   - **Condition Factor** (25% weight):
     - Accident history impact (see 2.2)
     - Maintenance history (if available)
     - Number of previous owners
   
   - **Market Factor** (20% weight):
     - Location-based demand
     - Seasonal trends (if data available locally)

4. **Update `DealCheckerView`**
   - Replace "Coming Soon" with full analysis
   - Add fields for:
     - Trim selection
     - Accident history (Yes/No + details)
     - Number of previous owners
     - Location/ZIP code
   - Results screen showing:
     - Overall score (0-100) with color coding
     - Breakdown by factor with gauges/charts
     - List of insights (e.g., "15% below market value", "High mileage for year")
     - Recommendation: "Great Deal", "Fair Deal", "Overpriced"

#### 2.2 Accident Impact Calculator
**Goal:** Quantify how accidents affect vehicle value

**Implementation Steps:**
1. **Data Model Updates**
   - Add to `VehicleEntity`:
     ```swift
     - hasAccidentHistory: Bool
     - accidentDetails: Data? (JSON: [{date, severity, damage, repairCost}])
     - accidentValueImpact: Double (calculated depreciation)
     ```

2. **Create `AccidentImpactCalculator.swift`**
   - Depreciation rules:
     - Minor accident (< $3k damage): -5% to -10%
     - Moderate accident ($3k-$10k): -10% to -20%
     - Major accident (> $10k): -20% to -30%
     - Structural damage: -30% to -40%
   - Adjust based on vehicle age (older cars = less impact)
   - Multiple accidents = compounding depreciation

3. **UI Components**
   - Create `AccidentHistoryView.swift`:
     - Add/edit accident records
     - Input: Date, severity, type of damage, repair cost
     - Visual indicator of impact on value
   
   - Update `VehicleDetailView`:
     - Warning badge if accident history exists
     - Section showing: "Accident Impact: -$4,200 (-12%)"
     - Breakdown of each accident's contribution
   
   - Update `DealCheckerView`:
     - Checkbox: "Vehicle has accident history"
     - If checked, show fields for accident details
     - Real-time update of value adjustment

4. **Value Calculation Integration**
   - Update market value calculations to factor in accidents
   - Formula: `adjustedValue = baseMarketValue * (1 - accidentDepreciation)`

#### 2.3 Location-Based Market Value
**Goal:** Adjust market values based on geographic location

**Implementation Steps:**
1. **Data Model Updates**
   - Add `MarketRegionEntity` to CoreData:
     ```swift
     - id: UUID
     - regionName: String (e.g., "California", "Midwest")
     - stateCode: String
     - demandMultiplier: Double (0.8 to 1.2)
     - popularMakes: [String]
     - notes: String?
     ```

2. **Create Local Region Database**
   - `market_regions.json`:
     - Pre-populated regional data
     - Demand multipliers by region
     - Popular vehicle types by region
     - Seasonal factors

3. **Create `LocationMarketService.swift`**
   - Methods:
     - `getRegionMultiplier(for location: String) -> Double`
     - `adjustValueForLocation(baseValue: Double, location: String) -> Double`
     - `getRegionalInsights(make: String, model: String, region: String) -> [String]`
   
   - Regional adjustments examples:
     - Trucks: +15% in Texas, +10% in rural areas
     - EVs: +20% in California, -10% in cold climates
     - AWD vehicles: +15% in snow states
     - Convertibles: +10% in warm climates

4. **UI Updates**
   - Add location field to:
     - Vehicle add/edit (optional)
     - Deal Checker (required for accurate analysis)
   
   - Show regional insights:
     - "This vehicle is in high demand in your region (+12%)"
     - "AWD vehicles command premium in Colorado markets"

5. **Settings Integration**
   - Add to `SettingsView`:
     - Default location/region setting
     - Option to set search radius (affects market comps)

---

### **PHASE 3: Quality Scoring & Insights**
*Priority: MEDIUM - Enhanced user experience*

#### 3.1 Overall Quality Score
**Goal:** Simple, digestible score (like a credit score) for vehicle quality

**Implementation Steps:**
1. **Data Model**
   - Add to `VehicleEntity`:
     ```swift
     - qualityScore: Int16 (300-850 range, like credit score)
     - qualityGrade: String ("Poor", "Fair", "Good", "Very Good", "Excellent")
     - lastScoreUpdate: Date
     - scoreFactors: Data? (JSON breakdown)
     ```

2. **Create `VehicleQualityScorer.swift`**
   - Scoring factors (total = 850 points):
     - **Maintenance History** (250 points):
       - Regular maintenance = full points
       - Missed services = deductions
       - Proactive repairs = bonus
     
     - **Condition** (200 points):
       - Accident-free = full points
       - Minor accidents = -50 points each
       - Major accidents = -100 points
     
     - **Mileage** (150 points):
       - Low mileage for age = bonus
       - High mileage = deductions
       - Formula based on age vs miles
     
     - **Age** (100 points):
       - Newer = more points
       - Well-maintained older car = bonus
     
     - **Cost Efficiency** (100 points):
       - Low maintenance costs = high score
       - Frequent expensive repairs = low score
     
     - **Market Demand** (50 points):
       - Popular make/model = bonus
       - High resale value = bonus

3. **Grade Ranges**
   - 750-850: Excellent (Green)
   - 650-749: Very Good (Blue)
   - 550-649: Good (Light Blue)
   - 450-549: Fair (Yellow)
   - 300-449: Poor (Orange/Red)

4. **UI Components**
   - Create `QualityScoreView.swift`:
     - Large circular gauge showing score
     - Color-coded grade
     - Breakdown of factors contributing to score
     - Tips for improving score
   
   - Update `GarageListView`:
     - Show quality score badge on each vehicle card
     - Sort option by quality score
   
   - Update `VehicleDetailView`:
     - Prominent quality score at top
     - Tap to see detailed breakdown
     - Historical score tracking over time

#### 3.2 Maintenance Cost Insights
**Goal:** Show average yearly/5-year maintenance costs with predictions

**Implementation Steps:**
1. **Data Model Updates**
   - Create `MaintenancePredictionEntity`:
     ```swift
     - id: UUID
     - vehicleID: UUID
     - year: Int16
     - predictedCost: Double
     - actualCost: Double?
     - breakdown: Data? (JSON: categories and amounts)
     - confidence: Double (0.0-1.0)
     ```

2. **Create Local Maintenance Database**
   - `maintenance_costs.json`:
     - Average costs by make/model/year
     - Common maintenance schedules
     - Expected repairs by mileage
     - Part replacement schedules

3. **Create `MaintenanceInsightService.swift`**
   - Calculate metrics:
     - Actual yearly average from user's cost entries
     - Compare to typical costs for make/model
     - Predict upcoming maintenance based on mileage
     - 5-year total cost projection
   
   - Methods:
     - `calculateYearlyAverage(for vehicle: VehicleEntity) -> Double`
     - `compareToTypical(vehicle: VehicleEntity) -> ComparisonResult`
     - `predict5YearCosts(vehicle: VehicleEntity) -> [YearlyPrediction]`
     - `getUpcomingMaintenance(vehicle: VehicleEntity) -> [MaintenanceItem]`

4. **UI Components**
   - Create `MaintenanceInsightsView.swift`:
     - **Current Stats Section:**
       - Yearly average: "$1,250/year"
       - vs. typical: "12% below average" (green badge)
       - Total spent to date
     
     - **5-Year Projection:**
       - Year-by-year breakdown chart
       - Major services highlighted (60k, 100k mile services)
       - Expected costs with confidence indicators
     
     - **Upcoming Maintenance:**
       - List of services due based on mileage
       - Estimated costs
       - Priority level (Critical, Recommended, Optional)
       - Due date/mileage
     
     - **Cost Comparison:**
       - How your vehicle compares to others
       - Cost per mile metric
       - Efficiency rating
   
   - Update `VehicleDetailView`:
     - Add "Maintenance Insights" button/card
     - Show quick stats: "Avg: $1,250/yr"

5. **Data Points Tracked**
   - Cost per mile driven
   - Cost per month of ownership
   - Comparison percentile (top 25%, median, etc.)
   - Cost trend (increasing, stable, decreasing)

---

### **PHASE 4: Service Integration**
*Priority: MEDIUM - Practical utility*

#### 4.1 Local Service Cost Estimator
**Goal:** Provide cost estimates for common services (paint, oil change, etc.)

**Implementation Steps:**
1. **Data Model**
   - Create `ServiceProviderEntity`:
     ```swift
     - id: UUID
     - name: String
     - serviceType: String
     - averageCost: Double
     - costRange: String (e.g., "$50-$80")
     - location: String?
     - notes: String?
     - isActive: Bool
     ```
   
   - Create `ServiceEstimateEntity`:
     ```swift
     - id: UUID
     - serviceType: String
     - baseCost: Double
     - variableFactors: Data? (JSON)
     - lastUpdated: Date
     ```

2. **Create Local Service Database**
   - `service_costs.json`:
     - Common services with cost ranges:
       - Oil change: $40-$80
       - Tire rotation: $20-$50
       - Brake pad replacement: $150-$400
       - Full paint job: $3,000-$10,000
       - Detailing: $150-$400
       - etc.
     - Factors affecting cost:
       - Vehicle size/type
       - Service complexity
       - Regional variations

3. **Create `ServiceCostEstimator.swift`**
   - Methods:
     - `estimateCost(service: String, vehicle: VehicleEntity) -> CostEstimate`
     - `adjustForVehicle(baseCost: Double, vehicle: VehicleEntity) -> Double`
     - `getServicesByCategory() -> [ServiceCategory]`
   
   - Adjustment factors:
     - Luxury vehicle = +30-50%
     - Larger vehicle = +20-40%
     - Older vehicle = variable (may need more work)
     - Electric vehicle = different cost structure

4. **UI Components**
   - Create `ServiceEstimatorView.swift`:
     - **Service Browser:**
       - Categories: Maintenance, Repair, Cosmetic, Performance
       - List of services with base cost ranges
     
     - **Estimate Calculator:**
       - Select service type
       - Select vehicle (if multiple)
       - Show personalized estimate
       - Cost range with confidence level
       - Factors considered (shown as tags)
     
     - **Add to Budget:**
       - Button to add estimated service to budget/planning
       - Set reminder for service
       - Option to convert to actual cost entry when done
   
   - Integration with `AddCostEntryView`:
     - "Get Estimate" button
     - Pre-fills amount based on service type
     - Option to note if actual cost vs estimate

5. **Smart Suggestions**
   - Based on mileage, suggest upcoming services
   - "Your vehicle is due for 60k service ($850-$1,200)"
   - Cost planning feature for budgeting

---

### **PHASE 5: Advanced Features**
*Priority: LOW-MEDIUM - Nice to have*

#### 5.1 Insurance Cost Linking
**Goal:** Track insurance costs and compare to averages

**Implementation Steps:**
1. **Data Model Updates**
   - Add to `VehicleEntity`:
     ```swift
     - insurancePremium: Double?
     - insuranceProvider: String?
     - insuranceRenewalDate: Date?
     - coverageLevel: String?
     ```
   
   - Create `InsuranceCostEntity`:
     ```swift
     - id: UUID
     - vehicleID: UUID
     - premium: Double
     - provider: String
     - startDate: Date
     - endDate: Date
     - coverageDetails: Data? (JSON)
     ```

2. **Create `insurance_averages.json`**
   - Average costs by:
     - Vehicle make/model
     - Vehicle year
     - Region/state
     - Coverage level

3. **Create `InsuranceInsightService.swift`**
   - Compare user's premium to averages
   - Calculate insurance cost per month/year
   - Factor into total cost of ownership
   - Renewal reminders

4. **UI Components**
   - Add insurance section to `VehicleDetailView`
   - Create `InsuranceComparisonView`:
     - Show your premium
     - Average for your vehicle/region
     - Percentage above/below average
     - Tips for reducing premium
   
   - Integration with cost tracking:
     - Include insurance in total cost metrics
     - Show as separate category in cost breakdown

#### 5.2 Maintenance Schedule Tracker
**Goal:** Track service schedules and send reminders

**Implementation Steps:**
1. **Data Model**
   - Create `MaintenanceScheduleEntity`:
     ```swift
     - id: UUID
     - vehicleID: UUID
     - serviceType: String
     - lastPerformed: Date?
     - lastMileage: Int32?
     - dueDate: Date?
     - dueMileage: Int32?
     - recurring: Bool
     - intervalMiles: Int32?
     - intervalMonths: Int16?
     - estimatedCost: Double?
     - priority: String
     - completed: Bool
     ```

2. **Create `maintenance_schedules.json`**
   - Standard schedules by make/model
   - Common service intervals:
     - Oil change: 5k-10k miles / 6 months
     - Tire rotation: 5k-7k miles
     - Brake inspection: 10k miles / annual
     - Major service: 30k, 60k, 90k miles

3. **UI Components**
   - Create `MaintenanceScheduleView.swift`:
     - Calendar view of upcoming services
     - List view sorted by due date
     - Overdue services highlighted in red
     - Notifications/reminders
   
   - Integration with `AddCostEntryView`:
     - Mark scheduled item as complete
     - Automatically update next due date

---

### **PHASE 6: Social Features (Modified for Local-Only)**
*Priority: LOW - Requires rethinking for local-only architecture*

#### 6.1 "Car Feed" - Local Showcase (Modified)
**Challenge:** Original request for Instagram-like feed requires cloud/sharing, which conflicts with local-only requirement.

**Local-Only Alternative Options:**

**Option A: Personal Timeline/Journal**
- Private feed showing your own garage's history
- Timeline view of all vehicles, purchases, services
- Photo gallery/memories feature
- "On this day" type memories

**Option B: Anonymous Local Comparisons**
- Store anonymized aggregate data locally
- Compare your vehicles to "similar users"
- No actual sharing, just statistical comparisons
- "Your 2020 Toyota Camry's maintenance costs are 15% lower than average"

**Option C: Export/Share Feature**
- Generate shareable images/PDFs of your garage
- User manually shares via social media/messages
- No in-app social features
- Think "Nike Run Club" summary cards

**Recommended: Option C**
Implementation:
1. **Create `GarageShowcaseGenerator.swift`**
   - Generate beautiful summary cards
   - Vehicle stats, photos, achievements
   - Cost savings highlights
   - Quality scores

2. **UI Component: `ShareGarageView.swift`**
   - Preview of shareable card
   - Customization options (what to include/hide)
   - Export as image
   - Share via system share sheet

---

## 🗃️ Data Architecture Updates

### New CoreData Entities Summary:
1. `TrimEntity` - Trim level information
2. `DealAnalysisEntity` - Deal quality analysis
3. `MarketRegionEntity` - Location-based market data
4. `MaintenancePredictionEntity` - Cost predictions
5. `ServiceProviderEntity` - Service cost reference data
6. `ServiceEstimateEntity` - Service cost estimates
7. `InsuranceCostEntity` - Insurance tracking
8. `MaintenanceScheduleEntity` - Service schedules

### New Local JSON Databases:
1. `trim_database.json` - Trim levels and pricing
2. `market_regions.json` - Regional market adjustments
3. `maintenance_costs.json` - Average maintenance costs
4. `service_costs.json` - Common service cost ranges
5. `insurance_averages.json` - Insurance cost averages
6. `maintenance_schedules.json` - Standard service schedules

---

## 🏗️ New Services/Classes:

### Core Services:
1. `TrimDatabaseService.swift` - Trim data management
2. `TrimPricingService.swift` - Trim price calculations
3. `DealAnalysisEngine.swift` - Deal quality scoring
4. `AccidentImpactCalculator.swift` - Accident depreciation
5. `LocationMarketService.swift` - Location-based adjustments
6. `VehicleQualityScorer.swift` - Quality score calculation
7. `MaintenanceInsightService.swift` - Maintenance analytics
8. `ServiceCostEstimator.swift` - Service cost estimates
9. `InsuranceInsightService.swift` - Insurance analysis

### Utility Classes:
1. `ScoreCalculator.swift` - Generic scoring utilities
2. `DataSeeder.swift` - Populate local databases
3. `GarageShowcaseGenerator.swift` - Generate share cards

---

## 📱 New Views/UI Components:

### Views:
1. `TrimSelectionView.swift`
2. `TrimComparisonView.swift`
3. `AccidentHistoryView.swift`
4. `QualityScoreView.swift`
5. `MaintenanceInsightsView.swift`
6. `ServiceEstimatorView.swift`
7. `InsuranceComparisonView.swift`
8. `MaintenanceScheduleView.swift`
9. `ShareGarageView.swift`

### Enhanced Existing Views:
1. `VehicleDetailView.swift` - Add quality score, insights sections
2. `DealCheckerView.swift` - Complete deal analysis implementation
3. `GarageListView.swift` - Add quality score badges, sorting
4. `SettingsView.swift` - Add location preferences

---

## 🎨 UI/UX Enhancements:

### Dashboard/Garage View:
- Quality score badges on vehicle cards
- Quick insights (upcoming maintenance, deals)
- Summary metrics (total value, total costs, avg quality)

### Vehicle Detail Enhancements:
- Quality Score section (prominent)
- Trim comparison button
- Accident impact warning (if applicable)
- Maintenance insights card
- Insurance comparison
- Service schedule overview

### Deal Checker Enhancements:
- Multi-step form with progress indicator
- Real-time score updates
- Visual gauges and charts
- Color-coded recommendations
- Factor-by-factor breakdown
- Save searches/analyses

---

## 📊 Implementation Priority Ranking:

### Must Have (MVP):
1. ✅ Trim separation and pricing (Phase 1)
2. ✅ Deal analysis engine (Phase 2.1)
3. ✅ Accident impact calculator (Phase 2.2)
4. ✅ Quality score (Phase 3.1)

### Should Have:
5. ✅ Location-based market values (Phase 2.3)
6. ✅ Maintenance insights (Phase 3.2)
7. ✅ Service cost estimator (Phase 4.1)

### Nice to Have:
8. ⭐ Insurance linking (Phase 5.1)
9. ⭐ Maintenance scheduler (Phase 5.2)
10. ⭐ Garage showcase/sharing (Phase 6.1)

---

## 🚀 Implementation Timeline Estimate:

### Phase 1: 2-3 weeks
- Data models and migrations
- Trim database creation
- Basic UI components

### Phase 2: 3-4 weeks
- Deal analysis engine
- Accident calculator
- Location services
- Enhanced Deal Checker UI

### Phase 3: 2-3 weeks
- Quality scoring system
- Maintenance insights
- Analytics dashboards

### Phase 4: 1-2 weeks
- Service cost estimator
- Integration with existing flows

### Phase 5: 2-3 weeks
- Insurance tracking
- Maintenance scheduler
- Additional refinements

### Phase 6: 1-2 weeks
- Showcase generator
- Export/share features

**Total Estimated Time: 11-17 weeks**

---

## 🔄 Migration Strategy:

### Existing Data:
- All existing vehicles will need quality scores calculated
- Trim data will be populated from existing vehicle trims
- Historical cost entries will feed into maintenance insights

### Data Seeding:
1. On first launch after update, seed local JSON databases
2. Background task to calculate quality scores for existing vehicles
3. Prompt user to add missing data (accidents, location, insurance)

---

## ⚠️ Technical Considerations:

### Performance:
- Local JSON databases should be indexed for fast lookup
- Quality score calculations should be cached
- Async/background processing for complex calculations

### Data Privacy:
- All data remains local (CoreData)
- No cloud sync or external services
- User can export data for backup

### Extensibility:
- Modular service architecture allows easy additions
- JSON databases can be updated independently
- Scoring algorithms can be tuned/improved

### Testing:
- Unit tests for all scoring/calculation logic
- UI tests for critical flows
- Mock data for comprehensive testing

---

## 📝 Notes & Recommendations:

1. **Start with Phase 1 & 2** - These provide the most immediate value and enable other features.

2. **Gradual Rollout** - Consider releasing features incrementally rather than all at once.

3. **User Onboarding** - New features will need explanation/tutorial flows.

4. **Data Collection** - Prompt users to fill in missing data (location, accidents) to enable features.

5. **Quality Score** - This should be prominently featured as it's easily digestible and compelling.

6. **Deal Checker** - This is the "killer feature" - focus on making it extremely accurate and useful.

7. **Social Features** - If user really wants social features later, would need to add backend/cloud infrastructure.

8. **API Integration** - Some features (trim pricing, market values) would benefit from real API data, but can work with local databases initially.

---

## 🎯 Success Metrics:

- Quality scores calculated for all vehicles
- Deal analyses showing meaningful insights
- Maintenance cost predictions within 20% of actual
- User engagement with new features
- App provides clear value proposition vs competitors

---

## 🔮 Future Considerations (Beyond Scope):

- Real-time market data APIs
- VIN decoder integration
- Cloud backup/sync (optional)
- Social features with backend
- Machine learning for better predictions
- Integration with OBD-II readers
- Apple Watch companion app
- Siri shortcuts
- Widgets

---

**This plan maintains the local-only architecture while delivering substantial value through intelligent analysis and insights.**

