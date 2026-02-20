import SwiftUI
import Charts
import CoreData

struct LoanTrackerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    let vehicle: VehicleEntity

    @FetchRequest private var loans: FetchedResults<LoanEntity>
    @State private var showingAddLoan = false
    @State private var showingAmortization = false
    @State private var showingExtraPayment = false

    init(vehicle: VehicleEntity) {
        self.vehicle = vehicle
        _loans = FetchRequest<LoanEntity>(
            sortDescriptors: [NSSortDescriptor(keyPath: \LoanEntity.startDate, ascending: false)],
            predicate: NSPredicate(format: "vehicleID == %@", vehicle.id as CVarArg),
            animation: .default
        )
    }

    private var activeLoan: LoanEntity? {
        loans.first(where: { $0.isActive })
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let loan = activeLoan {
                        activeLoanContent(loan)
                    } else {
                        emptyState
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Loan Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .sheet(isPresented: $showingAddLoan) {
                AddLoanView(vehicle: vehicle)
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingAmortization) {
                if let loan = activeLoan {
                    AmortizationScheduleView(loan: loan)
                }
            }
            .sheet(isPresented: $showingExtraPayment) {
                if let loan = activeLoan {
                    AddExtraPaymentView(loan: loan)
                        .environment(\.managedObjectContext, viewContext)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 60)

            Image(systemName: "banknote")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Loan Tracked")
                .font(.title2)
                .fontWeight(.bold)

            Text("Add your auto loan details to track payments, equity, and payoff progress.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { showingAddLoan = true }) {
                Label("Add Loan", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Active Loan Content

    @ViewBuilder
    private func activeLoanContent(_ loan: LoanEntity) -> some View {
        balanceCard(loan)
        equityCard(loan)
        paymentBreakdownChart(loan)
        balanceOverTimeChart(loan)
        loanDetailsCard(loan)
        actionButtons(loan)
    }

    // MARK: - Balance Card

    private func balanceCard(_ loan: LoanEntity) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Remaining Balance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(formatCurrency(loan.currentBalance))
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Monthly Payment")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(loan.monthlyPayment))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }

            // Progress bar
            VStack(spacing: 6) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12)

                        let paidPercent = loan.loanAmount > 0
                            ? loan.principalPaidToDate / loan.loanAmount
                            : 0
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .green],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * min(paidPercent, 1.0), height: 12)
                            .animation(.easeInOut, value: paidPercent)
                    }
                }
                .frame(height: 12)

                HStack {
                    let paidPercent = loan.loanAmount > 0
                        ? (loan.principalPaidToDate / loan.loanAmount) * 100
                        : 0
                    Text("\(Int(paidPercent))% paid off")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(loan.monthsRemaining) months remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let lender = loan.lenderName, !lender.isEmpty {
                HStack {
                    Image(systemName: "building.columns")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(lender)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }

    // MARK: - Equity Card

    private func equityCard(_ loan: LoanEntity) -> some View {
        let equity = vehicle.currentValue - loan.currentBalance
        let isPositive = equity >= 0

        return HStack(spacing: 12) {
            QuickStatCard(
                title: "Equity",
                value: formatCurrency(abs(equity)),
                icon: isPositive ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                color: isPositive ? .green : .red
            )
            QuickStatCard(
                title: "Interest Paid",
                value: formatCurrency(loan.interestPaidToDate),
                icon: "percent",
                color: .orange
            )
            QuickStatCard(
                title: "Payoff Date",
                value: shortDate(loan.payoffDate),
                icon: "calendar.badge.checkmark",
                color: .blue
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Payment Breakdown Chart (Principal vs Interest)

    private func paymentBreakdownChart(_ loan: LoanEntity) -> some View {
        let principalPaid = loan.principalPaidToDate
        let interestPaid = loan.interestPaidToDate
        let principalRemaining = loan.currentBalance
        let interestRemaining = max(loan.totalInterest - interestPaid, 0)

        let data: [(String, Double, Color)] = [
            ("Principal Paid", principalPaid, .green),
            ("Interest Paid", interestPaid, .orange),
            ("Principal Left", principalRemaining, .blue.opacity(0.4)),
            ("Interest Left", interestRemaining, .orange.opacity(0.3))
        ].filter { $0.1 > 0 }

        return VStack(alignment: .leading, spacing: 16) {
            Text("Payment Breakdown")
                .font(.headline)

            Chart {
                ForEach(data, id: \.0) { item in
                    SectorMark(
                        angle: .value(item.0, item.1),
                        innerRadius: .ratio(0.6),
                        angularInset: 2
                    )
                    .foregroundStyle(item.2)
                    .annotation(position: .overlay) {
                        if item.1 > loan.totalCost * 0.08 {
                            Text(formatCompact(item.1))
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .frame(height: 200)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(data, id: \.0) { item in
                    HStack(spacing: 6) {
                        Circle().fill(item.2).frame(width: 8, height: 8)
                        Text(item.0).font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text(formatCurrency(item.1)).font(.caption).fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }

    // MARK: - Balance Over Time Chart

    private func balanceOverTimeChart(_ loan: LoanEntity) -> some View {
        let schedule = loan.amortizationSchedule()
        let vehicleValue = vehicle.currentValue
        let projectedValues = SellAdvisorService.shared.projectValues(
            currentValue: vehicleValue,
            make: vehicle.make,
            model: vehicle.model,
            months: Int(loan.termMonths)
        )

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Balance vs. Vehicle Value")
                    .font(.headline)
                Spacer()
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(.blue).frame(width: 8, height: 8)
                        Text("Loan").font(.caption2).foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 8, height: 8)
                        Text("Value").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }

            Chart {
                ForEach(schedule.filter({ $0.month % 3 == 0 || $0.month == 1 || $0.month == schedule.count })) { entry in
                    LineMark(
                        x: .value("Month", entry.month),
                        y: .value("Balance", entry.remainingBalance),
                        series: .value("Type", "Loan Balance")
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                }

                ForEach(projectedValues.filter({ $0.monthsFromNow % 3 == 0 || $0.monthsFromNow == 0 })) { point in
                    LineMark(
                        x: .value("Month", point.monthsFromNow),
                        y: .value("Value", point.value),
                        series: .value("Type", "Vehicle Value")
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                }

                // Equity crossover point
                if let crossover = findEquityCrossover(schedule: schedule, projections: projectedValues) {
                    RuleMark(x: .value("Month", crossover))
                        .foregroundStyle(.orange.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        .annotation(position: .top, alignment: .center) {
                            Text("Positive Equity")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .padding(4)
                                .background(.ultraThinMaterial)
                                .cornerRadius(4)
                        }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text("$\(Int(amount / 1000))k")
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let month = value.as(Int.self) {
                            Text("Mo \(month)")
                        }
                    }
                }
            }
            .frame(height: 250)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }

    // MARK: - Loan Details Card

    private func loanDetailsCard(_ loan: LoanEntity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Loan Details")
                .font(.headline)

            Group {
                detailRow("Original Amount", formatCurrency(loan.loanAmount))
                detailRow("Down Payment", formatCurrency(loan.downPayment))
                detailRow("Interest Rate", String(format: "%.2f%%", loan.interestRate))
                detailRow("Term", "\(loan.termMonths) months")
                detailRow("Start Date", formatDate(loan.startDate))
                detailRow("Total Interest", formatCurrency(loan.totalInterest))
                detailRow("Total Cost", formatCurrency(loan.totalCost))
            }

            if !loan.extraPayments.isEmpty {
                Divider()
                Text("Extra Payments")
                    .font(.subheadline)
                    .fontWeight(.medium)

                ForEach(loan.extraPayments) { payment in
                    HStack {
                        Text(formatDate(payment.date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("+\(formatCurrency(payment.amount))")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }

    // MARK: - Action Buttons

    private func actionButtons(_ loan: LoanEntity) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: { showingExtraPayment = true }) {
                    Label("Extra Payment", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                }

                Button(action: { showingAmortization = true }) {
                    Label("Schedule", systemImage: "list.number")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }

            Button(action: { showingAddLoan = true }) {
                Label("Edit Loan", systemImage: "pencil")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(16)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func findEquityCrossover(schedule: [AmortizationEntry], projections: [ProjectedValue]) -> Int? {
        for entry in schedule {
            if let projected = projections.first(where: { $0.monthsFromNow == entry.month }) {
                if projected.value > entry.remainingBalance {
                    return entry.month
                }
            }
        }
        return nil
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }

    private func formatCompact(_ amount: Double) -> String {
        if amount >= 1000 {
            return "$\(Int(amount / 1000))k"
        }
        return "$\(Int(amount))"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Amortization Schedule View

struct AmortizationScheduleView: View {
    @Environment(\.presentationMode) var presentationMode
    let loan: LoanEntity

    var body: some View {
        NavigationView {
            List {
                Section(header: headerRow) {
                    ForEach(loan.amortizationSchedule()) { entry in
                        HStack {
                            Text("\(entry.month)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .leading)

                            Text(shortDate(entry.date))
                                .font(.caption)
                                .frame(width: 65, alignment: .leading)

                            Spacer()

                            Text(formatCurrency(entry.principal))
                                .font(.caption)
                                .foregroundColor(.green)
                                .frame(width: 70, alignment: .trailing)

                            Text(formatCurrency(entry.interest))
                                .font(.caption)
                                .foregroundColor(.orange)
                                .frame(width: 60, alignment: .trailing)

                            Text(formatCurrency(entry.remainingBalance))
                                .font(.caption)
                                .fontWeight(.medium)
                                .frame(width: 70, alignment: .trailing)
                        }
                        .listRowBackground(
                            entry.month <= loan.monthsElapsed
                                ? Color.green.opacity(0.05)
                                : Color.clear
                        )
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Amortization Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }

    private var headerRow: some View {
        HStack {
            Text("#")
                .frame(width: 30, alignment: .leading)
            Text("Date")
                .frame(width: 65, alignment: .leading)
            Spacer()
            Text("Principal")
                .frame(width: 70, alignment: .trailing)
            Text("Interest")
                .frame(width: 60, alignment: .trailing)
            Text("Balance")
                .frame(width: 70, alignment: .trailing)
        }
        .font(.caption2)
        .fontWeight(.semibold)
        .foregroundColor(.secondary)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yy"
        return formatter.string(from: date)
    }
}

// MARK: - Add Extra Payment View

struct AddExtraPaymentView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    let loan: LoanEntity

    @State private var amount = ""
    @State private var date = Date()
    @State private var notes = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Extra Payment Details")) {
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                    }

                    DatePicker("Payment Date", selection: $date, displayedComponents: [.date])
                }

                Section(header: Text("Notes (Optional)")) {
                    TextField("e.g., Bonus payment", text: $notes)
                }

                Section {
                    Button(action: savePayment) {
                        Text("Add Extra Payment")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(!amount.isEmpty ? .blue : .gray)
                    }
                    .disabled(amount.isEmpty)
                }
            }
            .navigationTitle("Extra Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }

    private func savePayment() {
        guard let amountValue = Double(amount), amountValue > 0 else { return }

        var payments = loan.extraPayments
        payments.append(ExtraPayment(
            date: date,
            amount: amountValue,
            notes: notes.isEmpty ? nil : notes
        ))
        loan.setExtraPayments(payments)
        loan.updatedAt = Date()

        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving extra payment: \(error)")
        }
    }
}
