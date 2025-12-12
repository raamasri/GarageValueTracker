# Feature Specification & Implementation Guide

## Overview

Garage Value Tracker is a complete iOS app for tracking car ownership like financial assets. This document details all implemented features and their usage.

---

## 1. GARAGE (Owned Cars)

### Purpose
Track vehicles you own with full financial performance metrics.

### Features Implemented

#### A. Add Vehicle Flow
**Entry Points:**
- Empty state CTA button
- Navigation bar "+" button

**Methods:**
1. **VIN Decode** (Recommended)
   - Enter 17-character VIN
   - Automatic lookup via NHTSA API
   - Pre-fills year/make/model/trim
   - User completes mileage + zip + purchase info

2. **Manual Entry**
   - Year picker (1990-2026)
   - Make, Model, Trim text fields
   - Transmission picker (Manual/Automatic)
   - Current mileage + zip code
   - Purchase price, date, and mileage

**Purchase Information Captured:**
- Purchase price ($)
- Purchase date
- Purchase mileage
- Automatically used for P&L calculations

#### B. Vehicle List View
**Display per vehicle:**
- Year/Make/Model/Trim header
- Current mileage + VIN (last 6)
- Market value (mid estimate)
- Unrealized P&L (vs purchase price)
- 90-day momentum (% change)
- Recommendation badge (Hold/Consider Sell/Strong Sell)

**Interactions:**
- Tap to view detail
- Swipe left to delete

#### C. Vehicle Detail View

**Market Valuation Card:**
- Large current mid value
- Low-Mid-High value band
- Confidence indicator (Low/Medium/High based on sample size)
- 90-day momentum with icon
- Liquidity score (0-100)
- Sample size

**Ownership Performance Card:**
- **Unrealized P&L** (big number, green/red)
- Purchase price
- Total costs (from ledger)
- Total basis (purchase + costs)
- Current market value
- Cumulative depreciation
- **Avg monthly cost** (total cost of ownership / months held)
- Ownership duration display

**Cost Ledger Section:**
- List of all cost entries (most recent first)
- Each entry shows:
  - Category icon
  - Category name
  - Date
  - Notes (if any)
  - Amount
- "Add Cost" button
- Empty state with first-cost CTA

#### D. Cost Entry Flow
**Categories:**
- Maintenance (wrench icon)
- Repairs (hammer)
- Insurance (shield)
- Registration/Tax (document)
- Modifications (sparkles)
- Fuel (pump)
- Other (ellipsis)

**Fields:**
- Date picker
- Category picker (with icons)
- Amount (numeric)
- Notes (optional text area)

**Integration:**
- Automatically adds to vehicle's cost ledger
- Included in P&L basis calculation
- Updates average monthly cost

---

## 2. WATCHLIST (Cars You Want)

### Purpose
Track vehicles you're interested in buying with price alerts and entry guidance.

### Features Implemented

#### A. Add to Watchlist
- Same vehicle entry flow as Garage
- VIN decode or manual entry
- Current market mileage/condition to track
- Optional: Target entry price

#### B. Watchlist View
**Display per vehicle:**
- Year/Make/Model/Trim
- Current mileage
- Market price (mid)
- Target price (if set) with checkmark if met
- 3-year depreciation estimate
- Alert bell icon if enabled

#### C. Watchlist Detail View

**Market Valuation:**
- Current market mid value
- Low-High range
- 90-day momentum
- Liquidity score
- Sample size

**Price Alerts Section:**
- Toggle to enable/disable alerts
- Set target price ($)
- Shows difference from current market
  - Dollar amount
  - Percentage
  - Above/below indicator

**Expected Depreciation Card:**
- 1-year estimate (%, dollar amount)
- 3-year estimate (%, dollar amount)
- Projected future values

**Entry Strategy Suggestions:**
- **Fair Entry**: 5% below market mid
- **Good Deal**: At market low
- **Steal**: 5% below market low
- Each with price and reasoning

---

## 3. DEAL CHECKER

### Purpose
Evaluate any car listing to determine if it's a fair price and how fast it will sell.

### Features Implemented

#### A. Input Form
**Vehicle Details:**
- Year (picker)
- Make, Model, Trim
- Transmission

**Listing Details:**
- Current mileage
- Zip code (for regional pricing)
- Asking price

#### B. Deal Analysis Results

**Rating Header:**
- Big visual indicator:
  - **Under Market** (green, down arrow)
  - **Fair Price** (blue, checkmark)
  - **Over Market** (red, up arrow)
- Percentage vs market mid

**Fair Value Band:**
- Low / Mid / High estimates
- Asking price comparison

**Sell Speed Forecast:**
- Expected days on market
- Probability of selling in < 7 days (%)
- Estimated hassle hours (based on user settings)

**Price-for-Speed Scenarios:**
Multiple pricing options showing:
- Recommended price
- Expected days on market
- Probability of < 7 day sale
- Hassle hours required
- **Hassle hours saved** vs current pricing

#### C. Hassle Model
User-configurable in Settings:
- Hours/week active listing (default: 1.5)
- Hours per test drive (default: 1.0)
- Hours per price change (default: 0.5)

**Formula:**
```
hassle_hours = (weeks_on_market * hours_per_week) + 
               (test_drives * hours_per_test) + 
               (price_changes * hours_per_change)
```

---

## 4. SWAP INSIGHT

### Purpose
Compare your current owned vehicle against a watchlist vehicle to see if swapping makes financial sense.

### Features Implemented

#### A. Vehicle Selection
- Dropdown for owned vehicles
- Dropdown for watchlist vehicles
- Both must be selected to analyze

#### B. Analysis Results

**Current Vehicle Metrics:**
- 3-year expected depreciation (% and $)
- Actual monthly cost (from ledger)

**Alternative Vehicle Metrics:**
- 3-year expected depreciation (% and $)
- Estimated monthly cost

**Verdict:**
- Depreciation drop (percentage points)
- Expected 3-year savings ($)
- Monthly cost delta ($/month)

**Visual Indicators:**
- Green checkmarks for improvements
- Orange warnings for higher costs
- Clear recommendation statement

**Example Output:**
> "If you replace your 2020 Toyota GR86 with a 2024 Mazda MX-5 Miata, monthly cost is similar but expected 3-year depreciation drops by ~8%"

---

## 5. UPGRADE PATH PLANNING ⭐

### Purpose
Calculate the TRUE net cost of upgrading to a different vehicle over 12 months, factoring in your current car's depreciation.

### Features Implemented

#### A. Input Parameters
- **Current Vehicle**: Select from owned vehicles
- **Max Budget**: Optional budget cap
- **Timeframe**: 6/12/18/24 months
- **Annual Mileage**: Expected usage pattern

#### B. Upgrade Recommendations
Returns top 3 moves ranked by optimization criteria.

**For each recommendation:**

**Vehicle Info:**
- Year/Make/Model/Trim
- MSRP
- Expected actual price (after discount)

**Cost Breakdown:**
```
MSRP:                     $45,000
Expected Discount:        -$1,800
Expected Price:           $43,200
Tax & Fees:               +$3,400
Your Car Depreciation:    +$5,200
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Net Out of Pocket:        $15,700
```

**Net Cost Over Timeframe:**
- Total cost over selected period (12 months default)
- Factors in:
  - Your current car's expected depreciation
  - Transaction costs
  - Expected discounts
  - Tax/registration

**Monthly Impact:**
- Cost per month delta
- Green if lower, red if higher
- Shows true economic impact

**Smart Reasoning:**
Each recommendation includes AI-generated reasoning:
- "Lower depreciation rate, similar performance class"
- "Best cost optimization. Strong resale value."
- "Performance upgrade with practical daily usability"

#### C. Real-World Example

**Scenario:**
- Current: 2020 Honda Civic Si
- Market value: $24,000
- 12-month timeframe

**Recommendation #1: 2023 Mazda MX-5 Miata**
```
Net Cost (12 months):  $4,200
Monthly Delta:         -$45/mo
MSRP:                  $33,770
Expected Price:        $31,500
Your Car Depr:         $2,400
Net Out of Pocket:     $3,700

Reasoning: "Lower depreciation rate than Civic Si. 
Better resale in sports car enthusiast market. 
Expected 12-month cost savings of $540."
```

---

## 6. SETTINGS

### Features Implemented

#### A. Advanced Features Menu
Quick access to:
- Swap Insight (sheet modal)
- Upgrade Path Planning (sheet modal)

#### B. Hassle Model Assumptions
User-configurable values:
- Hours/week active listing
- Hours per test drive  
- Hours per price change

Used by Deal Checker for time-cost calculations.

#### C. About Section
- App version
- Data transparency statement
- Source code link
- Legal compliance notice

---

## Data Flow & Integration

### Market Data
1. Vehicle normalization (segment, region bucket, mileage band)
2. Valuation estimate (low/mid/high, momentum, liquidity)
3. Depreciation curves (1yr, 3yr forecasts)
4. Clearance curves (days on market, sell probability)

### P&L Calculation
```
Total Basis = Purchase Price + Sum(All Costs)
Current Value = Market Mid Estimate
Unrealized P&L = Current Value - Total Basis
Cumulative Depreciation = Purchase Price - Current Value
Avg Monthly Cost = (Purchase Price - Current Value + Total Costs) / Months Held
```

### Cost Categories
All cost entries flow into:
- Vehicle detail cost ledger
- P&L total costs
- Average monthly cost calculation
- Swap insight current vehicle metrics

---

## Mock Data (MVP)

All backend endpoints return realistic mock data for testing:
- Market valuations vary by mileage
- Depreciation estimates are segment-specific
- Deal checker scenarios are price-responsive
- Upgrade recommendations are contextual

**To enable real backend:**
```swift
// In MarketAPIService.swift
private let useMockData = false // Change to false
private let baseURL = "https://your-api.com" // Set real URL
```

---

## UX Principles

### Numbers-First Design
- Large, bold values for key metrics
- Color-coded performance indicators
- Clear visual hierarchy
- Minimal charts (tables/cards preferred)

### Investor-Lite Aesthetic
- Clean, professional styling
- Rounded cards with subtle shadows
- Consistent padding/spacing
- Accentuated positive/negative with color

### Progressive Disclosure
- Simple list views
- Detailed cards on tap
- Empty states with clear CTAs
- Contextual help text

---

## Next Steps for Production

### Backend Integration
1. Deploy FastAPI/Node backend
2. Implement all 6 endpoints
3. Add authentication
4. Connect to real market data sources

### Enhanced Features
1. Push notifications (APNs)
2. Historical valuation charts
3. Export P&L to CSV
4. Social comparison features
5. Receipt OCR for cost entries

### Data Collection
1. User-submitted sale prices
2. Dealer offer tracking
3. Trade-in value reporting
4. Builds proprietary dataset over time

---

## Testing Checklist

### Garage Flow
- [x] Add vehicle via VIN
- [x] Add vehicle manually
- [x] View market valuation
- [x] Add cost entries (all categories)
- [x] View P&L performance
- [x] Delete vehicle

### Watchlist Flow
- [x] Add watchlist vehicle
- [x] Set target price
- [x] Enable alerts
- [x] View entry strategies
- [x] Delete watchlist item

### Deal Checker
- [x] Input vehicle details
- [x] Get fair value analysis
- [x] View sell speed forecast
- [x] Compare pricing scenarios

### Swap Insight
- [x] Select owned + watchlist vehicles
- [x] View depreciation comparison
- [x] See cost delta
- [x] Read verdict reasoning

### Upgrade Path
- [x] Select current vehicle
- [x] Set budget/timeframe
- [x] View top 3 recommendations
- [x] See net cost breakdown
- [x] Understand monthly impact

### Settings
- [x] Adjust hassle model values
- [x] Access advanced features
- [x] View about info

---

**All MVP features are fully implemented and functional! 🎉**



