import SwiftUI
import CoreData

struct AddLoanView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    let vehicle: VehicleEntity

    @FetchRequest private var existingLoans: FetchedResults<LoanEntity>

    @State private var lenderName = ""
    @State private var loanAmount = ""
    @State private var downPayment = ""
    @State private var interestRate = ""
    @State private var termMonths = "60"
    @State private var startDate = Date()
    @State private var notes = ""
    @State private var calculatedPayment: Double?

    private let commonTerms = [24, 36, 48, 60, 72, 84]

    init(vehicle: VehicleEntity) {
        self.vehicle = vehicle
        _existingLoans = FetchRequest<LoanEntity>(
            sortDescriptors: [NSSortDescriptor(keyPath: \LoanEntity.startDate, ascending: false)],
            predicate: NSPredicate(format: "vehicleID == %@ AND isActive == YES", vehicle.id as CVarArg),
            animation: .default
        )
    }

    private var isValid: Bool {
        guard let amount = Double(loanAmount), amount > 0,
              let rate = Double(interestRate), rate >= 0,
              let term = Int(termMonths), term > 0 else { return false }
        return true
    }

    var body: some View {
        NavigationView {
            Form {
                if let existing = existingLoans.first {
                    Section {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Saving will replace your current loan from \(existing.lenderName ?? "Unknown Lender").")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("Lender")) {
                    TextField("Bank / Credit Union name", text: $lenderName)
                        .textInputAutocapitalization(.words)
                }

                Section(header: Text("Loan Details")) {
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("Loan Amount (financed)", text: $loanAmount)
                            .keyboardType(.decimalPad)
                            .onChange(of: loanAmount) { recalculate() }
                    }

                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("Down Payment", text: $downPayment)
                            .keyboardType(.decimalPad)
                    }

                    HStack {
                        TextField("Interest Rate (APR)", text: $interestRate)
                            .keyboardType(.decimalPad)
                            .onChange(of: interestRate) { recalculate() }
                        Text("%")
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Loan Term")) {
                    Picker("Term (months)", selection: $termMonths) {
                        ForEach(commonTerms, id: \.self) { term in
                            Text("\(term) months (\(term / 12) yrs\(term % 12 > 0 ? " \(term % 12) mo" : ""))").tag("\(term)")
                        }
                    }
                    .onChange(of: termMonths) { recalculate() }

                    DatePicker("Start Date", selection: $startDate, displayedComponents: [.date])
                }

                if let payment = calculatedPayment {
                    Section(header: Text("Estimated Monthly Payment")) {
                        HStack {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.title2)
                                .foregroundColor(.green)

                            Text(formatCurrency(payment))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                            Text("/ month")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)

                        if let amount = Double(loanAmount), let term = Int(termMonths) {
                            let totalInterest = (payment * Double(term)) - amount
                            HStack {
                                Text("Total Interest")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatCurrency(totalInterest))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                            }
                            HStack {
                                Text("Total Cost")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatCurrency(payment * Double(term)))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }

                Section(header: Text("Notes (Optional)")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("Add Loan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveLoan() }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { prefill() }
        }
    }

    // MARK: - Prefill from existing loan

    private func prefill() {
        if let existing = existingLoans.first {
            lenderName = existing.lenderName ?? ""
            loanAmount = String(format: "%.0f", existing.loanAmount)
            downPayment = String(format: "%.0f", existing.downPayment)
            interestRate = String(format: "%.2f", existing.interestRate)
            termMonths = "\(existing.termMonths)"
            startDate = existing.startDate
            notes = existing.notes ?? ""
            recalculate()
        } else if vehicle.purchasePrice > 0 {
            loanAmount = String(format: "%.0f", vehicle.purchasePrice)
            recalculate()
        }
    }

    private func recalculate() {
        guard let amount = Double(loanAmount), amount > 0,
              let rate = Double(interestRate), rate >= 0,
              let term = Int(termMonths), term > 0 else {
            calculatedPayment = nil
            return
        }
        calculatedPayment = LoanEntity.calculateMonthlyPayment(
            principal: amount, annualRate: rate, termMonths: term
        )
    }

    private func saveLoan() {
        guard let amount = Double(loanAmount),
              let rate = Double(interestRate),
              let term = Int(termMonths) else { return }

        // Deactivate existing loans
        for existing in existingLoans {
            existing.isActive = false
        }

        let loan = LoanEntity(
            context: viewContext,
            vehicleID: vehicle.id,
            lenderName: lenderName.isEmpty ? nil : lenderName,
            loanAmount: amount,
            downPayment: Double(downPayment) ?? 0,
            interestRate: rate,
            termMonths: term,
            startDate: startDate
        )
        if !notes.isEmpty {
            loan.notes = notes
        }

        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving loan: \(error)")
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
}
