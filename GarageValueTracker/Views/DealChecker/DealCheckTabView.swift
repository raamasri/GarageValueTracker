import SwiftUI
import CoreData

struct DealCheckTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var inputText = ""
    @State private var analysisResult: DealAnalysisResult?
    @State private var showingResults = false
    @State private var showingAdvanced = false
    @State private var parseError = false
    @State private var lastMake = ""
    @State private var lastModel = ""
    @State private var lastYear = 0
    @State private var lastMileage = 0

    private let examples = [
        "2006 Honda S2000 AP2, 62k miles, $38,500, San Jose CA",
        "2015 Porsche Cayman GT4, 981, 24k miles, $95,000",
        "2021 BMW M3 Competition xDrive, 15k miles, $71,000, Chicago"
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GIQHeaderBar()

                    GIQSectionHeader(
                        label: "Deal Checker",
                        headline: "Is this deal actually good?",
                        accentWord: "actually good?"
                    )
                    .padding(.horizontal)

                    // Input Card
                    VStack(alignment: .leading, spacing: 12) {
                        ZStack(alignment: .topLeading) {
                            if inputText.isEmpty {
                                Text("Paste a listing URL, VIN, or describe the car:\n\n\"2019 Porsche 718 Cayman S, 6MT, 28k miles, $74,000, Guards Red, San Diego\"")
                                    .font(.mono(14))
                                    .foregroundColor(GIQ.tertiaryText)
                                    .padding(4)
                            }

                            TextEditor(text: $inputText)
                                .font(.mono(14))
                                .foregroundColor(.white)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 100)
                        }
                    }
                    .themeCard()
                    .padding(.horizontal)

                    // Check button
                    Button(action: checkDeal) {
                        HStack {
                            Spacer()
                            Text("Check This Deal")
                                .font(.mono(15, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                        }
                        .foregroundColor(.black)
                        .padding(.vertical, 16)
                        .background(inputText.isEmpty ? GIQ.accentMuted : GIQ.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(inputText.isEmpty)
                    .padding(.horizontal)

                    if parseError {
                        Button(action: { showingAdvanced = true }) {
                            HStack {
                                Image(systemName: "exclamationmark.circle")
                                Text("Could not parse input. Use Advanced Mode")
                                    .font(.mono(12))
                            }
                            .foregroundColor(GIQ.accent)
                        }
                        .padding(.horizontal)
                    }

                    // Examples
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TRY AN EXAMPLE")
                            .font(.mono(10, weight: .semibold))
                            .foregroundColor(GIQ.secondaryText)
                            .tracking(1.5)

                        ForEach(examples, id: \.self) { example in
                            Button(action: {
                                inputText = example
                            }) {
                                Text(example)
                                    .font(.mono(13))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                                    .background(GIQ.cardSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(GIQ.divider, lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
            }
            .themeBackground()
            .navigationBarHidden(true)
            .sheet(isPresented: $showingResults) {
                if let result = analysisResult {
                    DealAnalysisResultView(
                        result: result,
                        make: lastMake,
                        model: lastModel,
                        year: lastYear,
                        mileage: lastMileage
                    )
                }
            }
            .sheet(isPresented: $showingAdvanced) {
                DealCheckerView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    private func checkDeal() {
        parseError = false

        if let url = URL(string: inputText.trimmingCharacters(in: .whitespacesAndNewlines)),
           url.scheme?.hasPrefix("http") == true {
            ListingParserService.shared.parse(url: url) { parsed in
                guard let p = parsed, p.make != nil else {
                    parseError = true
                    return
                }
                runAnalysis(
                    make: p.make ?? "", model: p.model ?? "",
                    year: p.year ?? 2020, trim: p.trim,
                    mileage: p.mileage ?? 0, price: p.price ?? 0,
                    location: nil
                )
            }
            return
        }

        guard let parsed = DealInputParser.parse(inputText) else {
            parseError = true
            return
        }

        guard let make = parsed.make, !make.isEmpty else {
            parseError = true
            return
        }

        runAnalysis(
            make: make,
            model: parsed.model ?? "",
            year: parsed.year ?? Calendar.current.component(.year, from: Date()),
            trim: parsed.trim,
            mileage: parsed.mileage ?? 0,
            price: parsed.price ?? 0,
            location: parsed.location
        )
    }

    private func runAnalysis(make: String, model: String, year: Int, trim: String?, mileage: Int, price: Double, location: String?) {
        let result = DealAnalysisEngine.shared.analyzeDeal(
            make: make, model: model, year: year,
            trim: trim, mileage: mileage, askingPrice: price,
            location: location
        )

        _ = ListingEntity(
            context: viewContext,
            make: make, model: model, year: year,
            trim: trim, mileage: mileage,
            askingPrice: price, dealScore: result.overallScore
        )
        try? viewContext.save()

        lastMake = make
        lastModel = model
        lastYear = year
        lastMileage = mileage
        analysisResult = result
        showingResults = true
    }
}
