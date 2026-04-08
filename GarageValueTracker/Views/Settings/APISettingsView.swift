import SwiftUI

struct APISettingsView: View {
    @State private var marketcheckKey: String = ""
    @State private var carmdKey: String = ""
    @State private var carmdPartnerToken: String = ""
    @State private var showingSaved = false
    @State private var validatingMarketcheck = false
    @State private var validatingCarMD = false
    @State private var marketcheckStatus: ValidationStatus = .unknown
    @State private var carmdStatus: ValidationStatus = .unknown

    enum ValidationStatus {
        case unknown, valid, invalid
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Live Market Data", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.headline)
                    Text("Connect free API services to get real-time listing prices, NHTSA complaints, and repair cost data. NHTSA data (VIN decode, recalls, complaints) requires no API key.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            marketcheckSection
            carmdSection
            freeServicesSection

            Section {
                Button(action: clearAllCaches) {
                    Label("Clear Cached Market Data", systemImage: "trash")
                        .foregroundColor(.red)
                }
            } footer: {
                Text("Cached data reduces API calls. Clear if you want fresh data on next load.")
            }
        }
        .navigationTitle("API Keys")
        .onAppear(perform: loadExistingKeys)
        .overlay {
            if showingSaved {
                savedToast
            }
        }
    }

    // MARK: - Marketcheck Section

    private var marketcheckSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Marketcheck")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    statusBadge(for: marketcheckStatus, isLoading: validatingMarketcheck)
                }

                Text("Real active listings, market comps, price calibration. Free tier: ~1,000 calls/month.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                SecureField("API Key", text: $marketcheckKey)
                    .textContentType(.password)
                    .font(.system(.body, design: .monospaced))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                HStack {
                    Button("Save") {
                        saveMarketcheckKey()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(marketcheckKey.isEmpty)

                    if APIKeyManager.shared.hasMarketcheck {
                        Button("Remove", role: .destructive) {
                            APIKeyManager.shared.removeKey(for: .marketcheck)
                            marketcheckKey = ""
                            marketcheckStatus = .unknown
                        }
                    }

                    Spacer()

                    if let url = APIKeyManager.APIProvider.marketcheck.signupURL {
                        Link("Get Free Key", destination: url)
                            .font(.caption)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Marketcheck API")
        }
    }

    // MARK: - CarMD Section

    private var carmdSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("CarMD")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    statusBadge(for: carmdStatus, isLoading: validatingCarMD)
                }

                Text("Real repair costs and OEM maintenance schedules. Free tier available.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                SecureField("API Key", text: $carmdKey)
                    .textContentType(.password)
                    .font(.system(.body, design: .monospaced))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                SecureField("Partner Token", text: $carmdPartnerToken)
                    .textContentType(.password)
                    .font(.system(.body, design: .monospaced))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                HStack {
                    Button("Save") {
                        saveCarMDKeys()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(carmdKey.isEmpty || carmdPartnerToken.isEmpty)

                    if APIKeyManager.shared.hasCarMD {
                        Button("Remove", role: .destructive) {
                            APIKeyManager.shared.removeKey(for: .carmd)
                            APIKeyManager.shared.removeKey(for: .carmdPartner)
                            carmdKey = ""
                            carmdPartnerToken = ""
                            carmdStatus = .unknown
                        }
                    }

                    Spacer()

                    if let url = APIKeyManager.APIProvider.carmd.signupURL {
                        Link("Get Free Key", destination: url)
                            .font(.caption)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("CarMD API")
        }
    }

    // MARK: - Free Services

    private var freeServicesSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NHTSA VIN Decode")
                        .font(.subheadline)
                    Text("Vehicle specs from VIN — no key needed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NHTSA Safety Recalls")
                        .font(.subheadline)
                    Text("Real recall data — no key needed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NHTSA Consumer Complaints")
                        .font(.subheadline)
                    Text("Real owner complaints — no key needed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        } header: {
            Text("Free Services (Always Active)")
        }
    }

    // MARK: - Helpers

    private func statusBadge(for status: ValidationStatus, isLoading: Bool) -> some View {
        Group {
            if isLoading {
                ProgressView().scaleEffect(0.7)
            } else {
                switch status {
                case .unknown:
                    if APIKeyManager.shared.hasMarketcheck || APIKeyManager.shared.hasCarMD {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    } else {
                        Text("Not configured").font(.caption2).foregroundColor(.secondary)
                    }
                case .valid:
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text("Valid").font(.caption2).foregroundColor(.green)
                    }
                case .invalid:
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                        Text("Invalid").font(.caption2).foregroundColor(.red)
                    }
                }
            }
        }
    }

    private var savedToast: some View {
        VStack {
            Spacer()
            Text("Saved")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.green)
                .clipShape(Capsule())
                .shadow(radius: 8)
                .padding(.bottom, 40)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(), value: showingSaved)
    }

    private func loadExistingKeys() {
        if let key = APIKeyManager.shared.getKey(for: .marketcheck) {
            marketcheckKey = key
            marketcheckStatus = .unknown
        }
        if let key = APIKeyManager.shared.getKey(for: .carmd) {
            carmdKey = key
        }
        if let token = APIKeyManager.shared.getKey(for: .carmdPartner) {
            carmdPartnerToken = token
        }
    }

    private func saveMarketcheckKey() {
        APIKeyManager.shared.setKey(marketcheckKey, for: .marketcheck)
        flashSaved()
    }

    private func saveCarMDKeys() {
        APIKeyManager.shared.setKey(carmdKey, for: .carmd)
        APIKeyManager.shared.setKey(carmdPartnerToken, for: .carmdPartner)
        flashSaved()
    }

    private func flashSaved() {
        withAnimation { showingSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showingSaved = false }
        }
    }

    private func clearAllCaches() {
        LiveMarketDataService.shared.clearAllCaches()
        flashSaved()
    }
}
