import Foundation
import CoreData

@objc(LoanEntity)
public class LoanEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var vehicleID: UUID
    @NSManaged public var lenderName: String?
    @NSManaged public var loanAmount: Double
    @NSManaged public var downPayment: Double
    @NSManaged public var interestRate: Double
    @NSManaged public var termMonths: Int16
    @NSManaged public var monthlyPayment: Double
    @NSManaged public var startDate: Date
    @NSManaged public var extraPaymentsJSON: String?
    @NSManaged public var notes: String?
    @NSManaged public var isActive: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
}

extension LoanEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<LoanEntity> {
        return NSFetchRequest<LoanEntity>(entityName: "LoanEntity")
    }

    convenience init(context: NSManagedObjectContext,
                     vehicleID: UUID,
                     lenderName: String? = nil,
                     loanAmount: Double,
                     downPayment: Double = 0,
                     interestRate: Double,
                     termMonths: Int,
                     startDate: Date = Date()) {
        self.init(context: context)
        self.id = UUID()
        self.vehicleID = vehicleID
        self.lenderName = lenderName
        self.loanAmount = loanAmount
        self.downPayment = downPayment
        self.interestRate = interestRate
        self.termMonths = Int16(termMonths)
        self.monthlyPayment = LoanEntity.calculateMonthlyPayment(
            principal: loanAmount, annualRate: interestRate, termMonths: termMonths
        )
        self.startDate = startDate
        self.isActive = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Monthly Payment Calculation (standard amortization)

    static func calculateMonthlyPayment(principal: Double, annualRate: Double, termMonths: Int) -> Double {
        guard principal > 0, termMonths > 0 else { return 0 }
        let r = annualRate / 100.0 / 12.0
        if r == 0 { return principal / Double(termMonths) }
        let factor = pow(1 + r, Double(termMonths))
        return principal * (r * factor) / (factor - 1)
    }

    // MARK: - Computed Properties

    var monthsElapsed: Int {
        let components = Calendar.current.dateComponents([.month], from: startDate, to: Date())
        return max(components.month ?? 0, 0)
    }

    var monthsRemaining: Int {
        max(Int(termMonths) - monthsElapsed, 0)
    }

    var payoffDate: Date {
        Calendar.current.date(byAdding: .month, value: Int(termMonths), to: startDate) ?? startDate
    }

    var totalInterest: Double {
        (monthlyPayment * Double(termMonths)) - loanAmount
    }

    var totalCost: Double {
        loanAmount + totalInterest + downPayment
    }

    var extraPayments: [ExtraPayment] {
        guard let json = extraPaymentsJSON,
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([ExtraPayment].self, from: data) else {
            return []
        }
        return decoded
    }

    func setExtraPayments(_ payments: [ExtraPayment]) {
        if let data = try? JSONEncoder().encode(payments),
           let json = String(data: data, encoding: .utf8) {
            extraPaymentsJSON = json
        }
    }

    /// Current remaining balance accounting for regular + extra payments
    var currentBalance: Double {
        let r = interestRate / 100.0 / 12.0
        var balance = loanAmount
        let elapsed = monthsElapsed
        let extras = extraPayments

        for month in 0..<elapsed {
            guard balance > 0 else { break }
            let interest = balance * r
            var principal = monthlyPayment - interest
            if let extra = extras.first(where: { paymentMonth(for: $0.date) == month }) {
                principal += extra.amount
            }
            balance -= principal
        }
        return max(balance, 0)
    }

    /// Total interest paid so far
    var interestPaidToDate: Double {
        let r = interestRate / 100.0 / 12.0
        var balance = loanAmount
        var totalInterestPaid: Double = 0
        let elapsed = monthsElapsed
        let extras = extraPayments

        for month in 0..<elapsed {
            guard balance > 0 else { break }
            let interest = balance * r
            totalInterestPaid += interest
            var principal = monthlyPayment - interest
            if let extra = extras.first(where: { paymentMonth(for: $0.date) == month }) {
                principal += extra.amount
            }
            balance -= principal
        }
        return totalInterestPaid
    }

    var principalPaidToDate: Double {
        loanAmount - currentBalance
    }

    /// Full amortization schedule
    func amortizationSchedule() -> [AmortizationEntry] {
        let r = interestRate / 100.0 / 12.0
        var balance = loanAmount
        var entries: [AmortizationEntry] = []
        let extras = extraPayments

        for month in 0..<Int(termMonths) {
            guard balance > 0 else { break }
            let date = Calendar.current.date(byAdding: .month, value: month + 1, to: startDate) ?? startDate
            let interest = balance * r
            var principal = monthlyPayment - interest
            var extraAmt: Double = 0
            if let extra = extras.first(where: { paymentMonth(for: $0.date) == month }) {
                extraAmt = extra.amount
                principal += extraAmt
            }
            balance = max(balance - principal, 0)
            entries.append(AmortizationEntry(
                month: month + 1,
                date: date,
                payment: monthlyPayment + extraAmt,
                principal: principal,
                interest: interest,
                remainingBalance: balance
            ))
        }
        return entries
    }

    private func paymentMonth(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.month], from: startDate, to: date)
        return max(components.month ?? 0, 0)
    }
}

// MARK: - Supporting Types

struct ExtraPayment: Codable, Identifiable {
    let id: UUID
    let date: Date
    let amount: Double
    let notes: String?

    init(date: Date, amount: Double, notes: String? = nil) {
        self.id = UUID()
        self.date = date
        self.amount = amount
        self.notes = notes
    }
}

struct AmortizationEntry: Identifiable {
    let id = UUID()
    let month: Int
    let date: Date
    let payment: Double
    let principal: Double
    let interest: Double
    let remainingBalance: Double
}
