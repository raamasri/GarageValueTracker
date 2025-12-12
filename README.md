# Garage Value Tracker

> Bloomberg-lite for car ownership + watchlists

Track your cars like assets with true P&L, timing guidance, and depreciation insights.

## 🎯 Product Vision

**Core Promise:**
1. True ownership P&L (not just current value)
2. Timing + sell/hold guidance
3. Deal checker that prices in time/hassle
4. Watchlist alerts for cars you want to buy
5. Swap/diversification insight to optimize your fleet
6. **Upgrade Path Planning**: Net cost to move up over 12 months

## ✨ MVP Features (Implemented)

### 1. **Garage (Owned Cars)**
- Add via VIN decode (NHTSA API) or manual entry
- Track purchase price, date, and mileage
- Real-time market valuation with confidence bands
- 90-day momentum tracking
- Liquidity scoring
- Sell/hold recommendations
- **Full P&L tracking**: unrealized gains/losses, cumulative depreciation, avg monthly cost

### 2. **Watchlist (Cars You Want)**
- Manual or VIN-based entry
- Market valuation with price bands
- Expected 3-year depreciation forecasts
- Target entry price alerts
- Momentum-based alert triggers
- Entry strategy suggestions (fair/good/steal pricing)

### 3. **Ownership Ledger (Cost Tracking)**
- Manual cost entries by category:
  - Maintenance
  - Repairs
  - Insurance
  - Registration/Tax
  - Modifications
  - Fuel (optional)
  - Other
- Per-vehicle total costs
- Cost-per-month calculations
- Integrated into P&L computations

### 4. **Deal Checker (Fair Value + Time Cost)**
- Input any car details + asking price
- Output:
  - Fair value band (low/mid/high)
  - Expected days on market at that price
  - Probability of selling in < 7 days
  - Price-for-speed scenarios
  - **Hassle hours saved** by pricing strategically
- Customizable hassle model assumptions

### 5. **Swap Insight**
- Compare owned vehicle vs watchlist vehicle
- Expected 3-year depreciation for both
- Monthly cost comparison
- Net savings calculation
- Verdict: "Replace X with Y to drop depreciation by Z% while keeping monthly cost similar"

### 6. **Upgrade Path Planning** ⭐ NEW
- Select current owned vehicle
- Get personalized upgrade recommendations
- See **net cost over 12 months** including:
  - Current car's expected depreciation
  - Tax and fees on new vehicle
  - Expected dealer discounts
  - Net out-of-pocket cost
- Monthly cost delta comparison
- Smart reasoning for each recommendation
- Optimized for your mileage pattern and budget

## 🏗️ Architecture

### iOS App
- **Framework**: SwiftUI (iOS 18+)
- **Persistence**: SwiftData
- **Networking**: URLSession with async/await
- **Design**: Numbers-first, "investor-lite" aesthetic

### Data Models
- `VehicleEntity`: Core vehicle data (owned or watchlist)
- `CostEntryEntity`: Individual cost entries
- `ValuationSnapshotEntity`: Historical market valuations
- `UserSettingsEntity`: Hassle model preferences

### API Layer
- **NHTSA VIN Decode**: Free public API for vehicle identity
- **Market API Service**: Backend integration (currently using mock data for MVP)
  - Vehicle normalization
  - Valuation estimates
  - P&L computation
  - Deal checking
  - Swap insights
  - Upgrade path analysis

## 📊 Backend API Endpoints

All endpoints use mock data for MVP development. Switch `useMockData = false` in `MarketAPIService.swift` to connect to real backend.

### Implemented Endpoints:
```
POST /v1/vehicles/normalize
POST /v1/valuation/estimate
POST /v1/pnl/compute
POST /v1/deal/check
POST /v1/swap/insight
POST /v1/upgrade/path (NEW)
```

See [BUILD_SPEC.md](BUILD_SPEC.md) for full API contracts.

## 🚀 Getting Started

### Prerequisites
- Xcode 15+ (for iOS 18 SDK)
- macOS Ventura or later
- iOS 18+ device or simulator

### Installation
1. Clone the repository
2. Open `GarageValueTracker.xcodeproj` in Xcode
3. Select your target device/simulator
4. Build and run (⌘R)

### Initial Setup
The app works out of the box with mock data. No backend required for MVP testing.

## 🎨 User Flow

### First-Time Experience
1. **Empty Garage**: Clean onboarding with call-to-action
2. **Add First Vehicle**: VIN decode or manual entry
3. **See Market Valuation**: Instant insights with confidence bands
4. **Add Costs**: Track maintenance, insurance, etc.
5. **View P&L**: See true ownership performance

### Power User Features
1. **Watchlist**: Track dream cars with price alerts
2. **Deal Checker**: Evaluate any listing before making an offer
3. **Swap Insight**: Should you trade your GR86 for a Miata?
4. **Upgrade Path**: What's the real cost to move from a Civic Si to a Golf R?

## 🔒 Legal & Data Transparency

**We DO:**
- Use free NHTSA VIN decode API (public domain)
- Store aggregated market observations (user-derived)
- Accept user-submitted pricing outcomes

**We DON'T:**
- Scrape or republish KBB/Carfax proprietary data
- Use black-box ML models
- Violate any third-party ToS

All valuations are based on observable market data and user contributions.

## 📱 Screenshots

### Garage View
- Clean list of owned vehicles
- At-a-glance P&L and momentum
- Sell/hold recommendations

### Vehicle Detail
- Comprehensive market valuation
- Ownership performance card
- Cost ledger with category breakdown

### Deal Checker
- Fair value analysis
- Sell speed forecasts
- Hassle-hours calculator
- Price-for-speed scenarios

### Upgrade Path Planner
- Top 3 recommended upgrades
- Net cost breakdown over 12 months
- Monthly cost impact
- Smart reasoning for each option

## 🎯 Go-to-Market Strategy

### Target Wedge (Launch Focus)
**Option A**: Modern sports cars with active cross-shopping
- Miata / GR86 / BRZ / Civic Si / Golf R / WRX / M2

**Option B**: EVs with unusual depreciation patterns
- Model 3/Y Performance / Taycan trims

### Acquisition Channels
1. **Reddit**: r/askcarsales, r/whatcarshouldIbuy, brand subreddits
2. **Owner Forums**: Dedicated enthusiast communities
3. **Local Groups**: Bay Area Tesla/Toyota/BMW/etc.

### Viral Loop
- Deal checker results generate shareable cards
- Referral unlocks: +5 deal checks or watchlist alerts

### Pricing (Planned)
**Free Tier**:
- 1 owned car
- 1 watchlist car
- 3 deal checks/month
- Basic upgrade path

**Paid ($8-12/mo)**:
- Unlimited vehicles
- Unlimited watchlist + alerts
- Unlimited deal checks
- Full swap insights
- Premium upgrade recommendations
- CSV export

## 🛣️ Roadmap

### Phase 1: MVP ✅ COMPLETE
- Core CRUD for vehicles
- NHTSA VIN decode
- Mock backend integration
- All 6 core features
- Upgrade Path Planning

### Phase 2: Backend (Next 30 Days)
- Deploy FastAPI backend
- PostgreSQL setup
- Real market data aggregation
- User authentication

### Phase 3: Polish (Days 60-90)
- Push notifications (APNs)
- Receipt OCR (optional)
- Chart visualizations
- Onboarding improvements
- Beta launch

### Phase 4: Scale (Post-Launch)
- ML-enhanced predictions
- Dealer integrations
- Expanded vehicle coverage
- Social features (compare with friends)

## 🧪 Testing

### Manual Testing Checklist
- [ ] Add vehicle via VIN decode
- [ ] Add vehicle manually
- [ ] View vehicle detail and P&L
- [ ] Add cost entries (all categories)
- [ ] Add watchlist item
- [ ] Set price alert
- [ ] Run deal checker
- [ ] Compare swap scenarios
- [ ] Analyze upgrade paths
- [ ] Adjust hassle model settings

## 📚 Technical Debt & Known Issues

### Current Limitations
- Mock data only (no real backend yet)
- No persistent authentication
- Local-only notifications
- Limited error handling UI
- No offline support

### Future Improvements
- Add charts for valuation history
- Implement receipt scanning (OCR)
- Add social comparison features
- Support for multiple users/accounts
- iCloud sync

## 🤝 Contributing

This is an MVP build. Contributions welcome post-launch!

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

- NHTSA for free VIN decode API
- Car enthusiast communities for feedback
- Early beta testers

---

**Built with ❤️ for car enthusiasts who think like investors**

*"KBB tells you today's value. We tell you when to act."*



