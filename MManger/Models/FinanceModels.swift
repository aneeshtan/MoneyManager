import Foundation
import SwiftData

enum TransactionKind: String, Codable, CaseIterable, Identifiable {
    case expense
    case income
    case transfer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .expense: "Expense"
        case .income: "Income"
        case .transfer: "Transfer"
        }
    }
}

enum MatchType: String, Codable, CaseIterable {
    case exact
    case contains
}

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case cash
    case bank
    case creditCard
    case liability
    case investment
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cash: "Cash"
        case .bank: "Bank"
        case .creditCard: "Credit Card"
        case .liability: "Liability"
        case .investment: "Investment"
        case .other: "Other"
        }
    }

    static func inferred(from accountName: String) -> AccountType {
        let name = accountName.lowercased()
        if name.contains("cash") { return .cash }
        if name.contains("saving") || name.contains("current") || name.contains("bank") || name.contains("adib") { return .bank }
        if name.contains("credit") || name.contains("card") { return .creditCard }
        if name.contains("tabby") || name.contains("loan") || name.contains("debt") { return .liability }
        if name.contains("invest") || name.contains("crypto") || name.contains("stock") { return .investment }
        return .other
    }
}

enum AccountBalance {
    static func value(for accountName: String, openingBalance: Decimal, transactions: [FinanceTransaction]) -> Decimal {
        transactions
            .filter { $0.accountName == accountName }
            .reduce(openingBalance) { partial, transaction in
                transaction.kind == .income ? partial + transaction.amount : partial - transaction.amount
            }
    }

    static func adjustedOpeningBalance(targetCurrentValue: Decimal, accountName: String, transactions: [FinanceTransaction]) -> Decimal {
        let transactionNet = transactions
            .filter { $0.accountName == accountName }
            .reduce(Decimal(0)) { partial, transaction in
                transaction.kind == .income ? partial + transaction.amount : partial - transaction.amount
            }
        return targetCurrentValue - transactionNet
    }
}

enum TransactionIdentityKey {
    static func make(accountName: String, date: Date, amount: Decimal, normalizedMerchant: String, calendar: Calendar = Calendar(identifier: .gregorian)) -> String {
        let day = calendar.startOfDay(for: date).timeIntervalSince1970
        let amountText = NSDecimalNumber(decimal: amount).stringValue
        return "\(accountName)|\(day)|\(amountText)|\(normalizedMerchant)"
    }
}

/// Value-type snapshot of a `MerchantRule` used for off-main parsing.
struct MerchantRuleSnapshot: Sendable {
    var pattern: String
    var matchType: MatchType
    var categoryName: String
    var subcategoryName: String?
    var kind: TransactionKind
    var confidence: Double
    var sampleCount: Int
    var isEnabled: Bool
    var accountName: String?
    var notePattern: String?
    var minAmount: Decimal?
    var maxAmount: Decimal?
    var priority: Int

    init(_ rule: MerchantRule) {
        self.pattern = rule.pattern
        self.matchType = rule.matchType
        self.categoryName = rule.categoryName
        self.subcategoryName = rule.subcategoryName
        self.kind = rule.kind
        self.confidence = rule.confidence
        self.sampleCount = rule.sampleCount
        self.isEnabled = rule.isEnabled
        self.accountName = rule.accountName
        self.notePattern = rule.notePattern
        self.minAmount = rule.minAmount
        self.maxAmount = rule.maxAmount
        self.priority = rule.priority
    }
}

/// Value-type snapshot of identity-relevant transaction fields used for off-main parsing.
struct TransactionSnapshot: Sendable {
    var accountName: String
    var date: Date
    var amount: Decimal
    var normalizedMerchant: String

    init(_ transaction: FinanceTransaction) {
        self.accountName = transaction.accountName
        self.date = transaction.date
        self.amount = transaction.amount
        self.normalizedMerchant = transaction.normalizedMerchant
    }
}

struct DuplicateTransactionLookup {
    private let calendar: Calendar
    private let keys: Set<String>

    init(existingTransactions: [FinanceTransaction], calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar
        self.keys = Set(existingTransactions.map { transaction in
            TransactionIdentityKey.make(
                accountName: transaction.accountName,
                date: transaction.date,
                amount: transaction.amount,
                normalizedMerchant: transaction.normalizedMerchant,
                calendar: calendar
            )
        })
    }

    init(snapshots: [TransactionSnapshot], calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar
        self.keys = Set(snapshots.map { snapshot in
            TransactionIdentityKey.make(
                accountName: snapshot.accountName,
                date: snapshot.date,
                amount: snapshot.amount,
                normalizedMerchant: snapshot.normalizedMerchant,
                calendar: calendar
            )
        })
    }

    func contains(accountName: String, date: Date, amount: Decimal, normalizedMerchant: String) -> Bool {
        keys.contains(
            TransactionIdentityKey.make(
                accountName: accountName,
                date: date,
                amount: amount,
                normalizedMerchant: normalizedMerchant,
                calendar: calendar
            )
        )
    }
}

struct DuplicateReviewCandidate: Identifiable {
    let id = UUID()
    var transactions: [FinanceTransaction]
    var isExact: Bool

    var isLikely: Bool { !isExact }
}

enum DuplicateReviewService {
    static func candidates(in transactions: [FinanceTransaction], calendar: Calendar = Calendar(identifier: .gregorian)) -> [DuplicateReviewCandidate] {
        let grouped = Dictionary(grouping: transactions) { transaction in
            likelyKey(for: transaction, calendar: calendar)
        }

        return grouped.values
            .filter { $0.count > 1 }
            .map { group in
                DuplicateReviewCandidate(
                    transactions: group.sorted { $0.date < $1.date },
                    isExact: Set(group.map { exactKey(for: $0, calendar: calendar) }).count == 1
                )
            }
            .sorted {
                guard let leftDate = $0.transactions.first?.date, let rightDate = $1.transactions.first?.date else {
                    return $0.transactions.count > $1.transactions.count
                }
                return leftDate > rightDate
            }
    }

    private static func exactKey(for transaction: FinanceTransaction, calendar: Calendar) -> String {
        TransactionIdentityKey.make(
            accountName: transaction.accountName,
            date: transaction.date,
            amount: transaction.amount,
            normalizedMerchant: transaction.normalizedMerchant,
            calendar: calendar
        )
    }

    private static func likelyKey(for transaction: FinanceTransaction, calendar: Calendar) -> String {
        let day = calendar.startOfDay(for: transaction.date).timeIntervalSince1970
        let dayBucket = Int(day / 86_400 / 3)
        let merchant = MerchantNormalizer.normalize(transaction.normalizedMerchant.isEmpty ? transaction.merchant : transaction.normalizedMerchant)
        let merchantTokens = merchant.split(separator: " ")
        let stableMerchantTokens = merchantTokens.filter { token in
            !token.allSatisfy { $0.isNumber }
        }
        let merchantRoot = (stableMerchantTokens.isEmpty ? merchantTokens : stableMerchantTokens)
            .prefix(2)
            .joined(separator: " ")
        return "\(transaction.accountName)|\(dayBucket)|\(NSDecimalNumber(decimal: transaction.amount).stringValue)|\(merchantRoot)"
    }
}

struct BudgetProgress {
    var budget: Budget
    var spent: Decimal

    var remaining: Decimal { budget.amount - spent }
    var isOverspent: Bool { remaining < 0 }

    var fractionUsed: Double {
        let budgetValue = NSDecimalNumber(decimal: budget.amount).doubleValue
        guard budgetValue > 0 else { return 0 }
        return NSDecimalNumber(decimal: spent).doubleValue / budgetValue
    }

    var clampedFractionUsed: Double {
        min(max(fractionUsed, 0), 1)
    }
}

enum BudgetProgressCalculator {
    static func monthStart(for date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    static func budget(forCategory categoryName: String, subcategory: String?, monthStart: Date, budgets: [Budget], calendar: Calendar = .current) -> Budget? {
        budgets.first { budget in
            budget.categoryName == categoryName
                && budget.subcategoryName == subcategory
                && calendar.isDate(budget.monthStart, equalTo: monthStart, toGranularity: .month)
        }
    }

    static func spent(forCategory categoryName: String, subcategory: String?, monthStart: Date, transactions: [FinanceTransaction], calendar: Calendar = .current) -> Decimal {
        transactions
            .filter { transaction in
                transaction.kind == .expense
                    && transaction.categoryName == categoryName
                    && transaction.subcategoryName == subcategory
                    && calendar.isDate(transaction.date, equalTo: monthStart, toGranularity: .month)
            }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }
}

@Model
final class UserProfile {
    @Attribute(.unique) var id: String
    var displayName: String
    var baseCurrency: String
    var createdAt: Date
    var preferredCurrencies: [String] = ["USD", "EUR", "GBP"]
    var countryCode: String?
    var timeZoneIdentifier: String?

    init(
        id: String,
        displayName: String,
        baseCurrency: String = "USD",
        createdAt: Date = .now,
        preferredCurrencies: [String] = ["USD", "EUR", "GBP"],
        countryCode: String? = nil,
        timeZoneIdentifier: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.baseCurrency = baseCurrency
        self.createdAt = createdAt
        self.preferredCurrencies = preferredCurrencies
        self.countryCode = countryCode
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    func applyRegionalDefaults(
        currency: String,
        countryCode: String?,
        timeZoneIdentifier: String?
    ) {
        self.baseCurrency = currency.uppercased()
        self.countryCode = countryCode
        self.timeZoneIdentifier = timeZoneIdentifier
    }
}

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var userId: String = "primary-user"
    var name: String
    var currency: String
    var openingBalance: Decimal
    var typeRaw: String = AccountType.other.rawValue
    var isArchived: Bool = false
    var sortOrder: Int
    var createdAt: Date

    var type: AccountType {
        get { AccountType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), userId: String = SeedStore.defaultUserId, name: String, currency: String = "USD", openingBalance: Decimal = 0, type: AccountType? = nil, isArchived: Bool = false, sortOrder: Int = 0, createdAt: Date = .now) {
        self.id = id
        self.userId = userId
        self.name = name
        self.currency = currency
        self.openingBalance = openingBalance
        self.typeRaw = (type ?? AccountType.inferred(from: name)).rawValue
        self.isArchived = isArchived
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}

@Model
final class FinanceCategory {
    @Attribute(.unique) var id: UUID
    var userId: String = "primary-user"
    var externalId: String?
    var name: String
    var kindRaw: String
    var parentName: String?
    var sortOrder: Int
    var isArchived: Bool = false

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), userId: String = SeedStore.defaultUserId, externalId: String? = nil, name: String, kind: TransactionKind, parentName: String? = nil, sortOrder: Int = 0, isArchived: Bool = false) {
        self.id = id
        self.userId = userId
        self.externalId = externalId
        self.name = name
        self.kindRaw = kind.rawValue
        self.parentName = parentName
        self.sortOrder = sortOrder
        self.isArchived = isArchived
    }
}

@Model
final class FinanceTransaction {
    @Attribute(.unique) var id: UUID
    var userId: String = "primary-user"
    var date: Date
    var kindRaw: String
    var amount: Decimal
    var currency: String
    var merchant: String
    var normalizedMerchant: String
    var note: String
    var rawDescription: String
    var accountName: String
    var categoryName: String?
    var subcategoryName: String?
    var importBatchId: UUID?
    var createdAt: Date
    var updatedAt: Date
    var sourceName: String?
    var sourceRow: Int?
    var sourcePeriodSerial: String?
    var sourceAccountColumn: String?
    var sourceCategoryColumn: String?
    var sourceSubcategoryColumn: String?
    var sourceNoteColumn: String?
    var sourceAEDColumn: String?
    var sourceIncomeExpenseColumn: String?
    var sourceDescriptionColumn: String?
    var sourceAmountColumn: String?
    var sourceCurrencyColumn: String?
    var sourceTrailingAccountsColumn: String?
    var tagNames: [String] = []

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        userId: String = SeedStore.defaultUserId,
        date: Date,
        kind: TransactionKind,
        amount: Decimal,
        currency: String = "USD",
        merchant: String,
        normalizedMerchant: String,
        note: String = "",
        rawDescription: String = "",
        accountName: String,
        categoryName: String? = nil,
        subcategoryName: String? = nil,
        importBatchId: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        sourceName: String? = nil,
        sourceRow: Int? = nil,
        sourcePeriodSerial: String? = nil,
        sourceAccountColumn: String? = nil,
        sourceCategoryColumn: String? = nil,
        sourceSubcategoryColumn: String? = nil,
        sourceNoteColumn: String? = nil,
        sourceAEDColumn: String? = nil,
        sourceIncomeExpenseColumn: String? = nil,
        sourceDescriptionColumn: String? = nil,
        sourceAmountColumn: String? = nil,
        sourceCurrencyColumn: String? = nil,
        sourceTrailingAccountsColumn: String? = nil,
        tagNames: [String] = []
    ) {
        self.id = id
        self.userId = userId
        self.date = date
        self.kindRaw = kind.rawValue
        self.amount = amount
        self.currency = currency
        self.merchant = merchant
        self.normalizedMerchant = normalizedMerchant
        self.note = note
        self.rawDescription = rawDescription
        self.accountName = accountName
        self.categoryName = categoryName
        self.subcategoryName = subcategoryName
        self.importBatchId = importBatchId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceName = sourceName
        self.sourceRow = sourceRow
        self.sourcePeriodSerial = sourcePeriodSerial
        self.sourceAccountColumn = sourceAccountColumn
        self.sourceCategoryColumn = sourceCategoryColumn
        self.sourceSubcategoryColumn = sourceSubcategoryColumn
        self.sourceNoteColumn = sourceNoteColumn
        self.sourceAEDColumn = sourceAEDColumn
        self.sourceIncomeExpenseColumn = sourceIncomeExpenseColumn
        self.sourceDescriptionColumn = sourceDescriptionColumn
        self.sourceAmountColumn = sourceAmountColumn
        self.sourceCurrencyColumn = sourceCurrencyColumn
        self.sourceTrailingAccountsColumn = sourceTrailingAccountsColumn
        self.tagNames = tagNames
    }
}

@Model
final class MerchantRule {
    @Attribute(.unique) var id: UUID
    var userId: String = "primary-user"
    var pattern: String
    var matchTypeRaw: String
    var categoryName: String
    var subcategoryName: String?
    var kindRaw: String
    var confidence: Double
    var sampleCount: Int
    var isEnabled: Bool = true
    var createdAt: Date
    var accountName: String?
    var notePattern: String?
    var minAmount: Decimal?
    var maxAmount: Decimal?
    var priority: Int = 0
    var isAutoGenerated: Bool = false

    var matchType: MatchType {
        get { MatchType(rawValue: matchTypeRaw) ?? .contains }
        set { matchTypeRaw = newValue.rawValue }
    }

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        userId: String = SeedStore.defaultUserId,
        pattern: String,
        matchType: MatchType = .contains,
        categoryName: String,
        subcategoryName: String? = nil,
        kind: TransactionKind = .expense,
        confidence: Double = 0.7,
        sampleCount: Int = 0,
        isEnabled: Bool = true,
        createdAt: Date = .now,
        accountName: String? = nil,
        notePattern: String? = nil,
        minAmount: Decimal? = nil,
        maxAmount: Decimal? = nil,
        priority: Int = 0,
        isAutoGenerated: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.pattern = pattern
        self.matchTypeRaw = matchType.rawValue
        self.categoryName = categoryName
        self.subcategoryName = subcategoryName
        self.kindRaw = kind.rawValue
        self.confidence = confidence
        self.sampleCount = sampleCount
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.accountName = accountName
        self.notePattern = notePattern
        self.minAmount = minAmount
        self.maxAmount = maxAmount
        self.priority = priority
        self.isAutoGenerated = isAutoGenerated
    }
}

@Model
final class TransactionAttachment {
    @Attribute(.unique) var id: UUID
    var userId: String = "primary-user"
    var transactionId: UUID
    var fileName: String
    var originalFileName: String
    var contentType: String
    var createdAt: Date

    init(id: UUID = UUID(), userId: String = SeedStore.defaultUserId, transactionId: UUID, fileName: String, originalFileName: String, contentType: String, createdAt: Date = .now) {
        self.id = id
        self.userId = userId
        self.transactionId = transactionId
        self.fileName = fileName
        self.originalFileName = originalFileName
        self.contentType = contentType
        self.createdAt = createdAt
    }
}

@Model
final class ImportBatch {
    @Attribute(.unique) var id: UUID
    var userId: String = "primary-user"
    var sourceFileName: String
    var importedAt: Date
    var parsedCount: Int
    var savedCount: Int
    var ignoredCount: Int

    init(id: UUID = UUID(), userId: String = SeedStore.defaultUserId, sourceFileName: String, importedAt: Date = .now, parsedCount: Int, savedCount: Int, ignoredCount: Int) {
        self.id = id
        self.userId = userId
        self.sourceFileName = sourceFileName
        self.importedAt = importedAt
        self.parsedCount = parsedCount
        self.savedCount = savedCount
        self.ignoredCount = ignoredCount
    }
}

@Model
final class Budget {
    @Attribute(.unique) var id: UUID
    var userId: String = "primary-user"
    var categoryName: String
    var subcategoryName: String?
    var monthStart: Date
    var amount: Decimal
    var currency: String

    init(id: UUID = UUID(), userId: String = SeedStore.defaultUserId, categoryName: String, subcategoryName: String? = nil, monthStart: Date, amount: Decimal, currency: String = "USD") {
        self.id = id
        self.userId = userId
        self.categoryName = categoryName
        self.subcategoryName = subcategoryName
        self.monthStart = monthStart
        self.amount = amount
        self.currency = currency
    }
}

@Model
final class SavingsGoal {
    @Attribute(.unique) var id: UUID
    var userId: String = "primary-user"
    var name: String
    var targetAmount: Decimal
    var currentAmount: Decimal
    var currency: String
    var targetDate: Date?
    var createdAt: Date
    var isArchived: Bool = false
    var sortOrder: Int

    init(id: UUID = UUID(), userId: String = SeedStore.defaultUserId, name: String, targetAmount: Decimal, currentAmount: Decimal = 0, currency: String = "USD", targetDate: Date? = nil, createdAt: Date = .now, isArchived: Bool = false, sortOrder: Int = 0) {
        self.id = id
        self.userId = userId
        self.name = name
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.currency = currency
        self.targetDate = targetDate
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.sortOrder = sortOrder
    }

    var progress: Double {
        let target = NSDecimalNumber(decimal: targetAmount).doubleValue
        guard target > 0 else { return 0 }
        return min(max(NSDecimalNumber(decimal: currentAmount).doubleValue / target, 0), 1)
    }

    var remaining: Decimal {
        max(targetAmount - currentAmount, 0)
    }

    var isComplete: Bool {
        currentAmount >= targetAmount
    }
}

@Model
final class ScheduledTransaction {
    @Attribute(.unique) var id: UUID
    var userId: String = "primary-user"
    var merchant: String
    var normalizedMerchant: String
    var amount: Decimal
    var currency: String
    var kind: TransactionKind
    var accountName: String
    var categoryName: String?
    var subcategoryName: String?
    var note: String
    var frequencyRaw: String
    var nextDate: Date
    var lastRunDate: Date?
    var isEnabled: Bool = true
    var createdAt: Date

    var frequency: ScheduleFrequency {
        get { ScheduleFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), userId: String = SeedStore.defaultUserId, merchant: String, amount: Decimal, currency: String = "USD", kind: TransactionKind, accountName: String, categoryName: String? = nil, subcategoryName: String? = nil, note: String = "", frequency: ScheduleFrequency = .monthly, nextDate: Date, lastRunDate: Date? = nil, isEnabled: Bool = true, createdAt: Date = .now) {
        self.id = id
        self.userId = userId
        self.merchant = merchant
        self.normalizedMerchant = MerchantNormalizer.normalize(merchant)
        self.amount = amount
        self.currency = currency
        self.kind = kind
        self.accountName = accountName
        self.categoryName = categoryName
        self.subcategoryName = subcategoryName
        self.note = note
        self.frequencyRaw = frequency.rawValue
        self.nextDate = nextDate
        self.lastRunDate = lastRunDate
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }
}

enum ScheduleFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly
    case biweekly
    case monthly
    case quarterly
    case yearly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekly: "Weekly"
        case .biweekly: "Biweekly"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .yearly: "Yearly"
        }
    }

    func nextDate(after date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date)
        }
    }
}

struct TransactionSplit: Identifiable, Hashable {
    let id = UUID()
    var amount: Decimal
    var categoryName: String
    var subcategoryName: String?
}

@Model
final class Tag {
    @Attribute(.unique) var id: UUID
    var userId: String = "primary-user"
    var name: String
    var colorHex: String
    var createdAt: Date

    init(id: UUID = UUID(), userId: String = SeedStore.defaultUserId, name: String, colorHex: String = "8151D1", createdAt: Date = .now) {
        self.id = id
        self.userId = userId
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
    }
}

@Model
final class DebtPayoffPlan {
    @Attribute(.unique) var id: UUID
    var userId: String = "primary-user"
    var name: String
    var accountName: String
    var totalDebt: Decimal
    var minimumPayment: Decimal
    var extraPayment: Decimal
    var interestRate: Double
    var strategyRaw: String
    var createdAt: Date
    var isArchived: Bool = false

    var strategy: DebtPayoffStrategy {
        get { DebtPayoffStrategy(rawValue: strategyRaw) ?? .avalanche }
        set { strategyRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), userId: String = SeedStore.defaultUserId, name: String, accountName: String, totalDebt: Decimal, minimumPayment: Decimal = 0, extraPayment: Decimal = 0, interestRate: Double = 0, strategy: DebtPayoffStrategy = .avalanche, createdAt: Date = .now, isArchived: Bool = false) {
        self.id = id
        self.userId = userId
        self.name = name
        self.accountName = accountName
        self.totalDebt = totalDebt
        self.minimumPayment = minimumPayment
        self.extraPayment = extraPayment
        self.interestRate = interestRate
        self.strategyRaw = strategy.rawValue
        self.createdAt = createdAt
        self.isArchived = isArchived
    }

    var monthlyPayment: Decimal {
        minimumPayment + extraPayment
    }

    var estimatedMonths: Int {
        guard monthlyPayment > 0, totalDebt > 0 else { return 0 }
        let monthly = NSDecimalNumber(decimal: monthlyPayment).doubleValue
        let debt = NSDecimalNumber(decimal: totalDebt).doubleValue
        let rate = interestRate / 100 / 12
        if rate == 0 {
            return Int(ceil(debt / monthly))
        }
        let months = log(monthly / (monthly - rate * debt)) / log(1 + rate)
        return Int(ceil(months))
    }
}

enum DebtPayoffStrategy: String, Codable, CaseIterable, Identifiable {
    case snowball
    case avalanche

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .snowball: "Snowball (lowest balance first)"
        case .avalanche: "Avalanche (highest interest first)"
        }
    }
}

struct ParsedBankTransaction: Identifiable, Hashable {
    let id = UUID()
    var date: Date
    var description: String
    var normalizedMerchant: String
    var kind: TransactionKind
    var amount: Decimal
    var currency: String
    var suggestedCategory: String?
    var suggestedSubcategory: String?
    var confidence: Double
    var isSelected: Bool
    var isDuplicate: Bool

    var isReviewOnly: Bool {
        normalizedMerchant.contains("PAYMENT RECEIVED")
            || normalizedMerchant.contains("CASHBACK")
            || normalizedMerchant.contains("FOREIGN TRANSACTION FEE")
            || normalizedMerchant.contains("VAT ON FOREIGN")
    }
}

struct ImportSaveDraft: Hashable {
    var date: Date
    var kind: TransactionKind
    var amount: Decimal
    var currency: String
    var merchant: String
    var normalizedMerchant: String
    var rawDescription: String
    var accountName: String
    var categoryName: String?
    var subcategoryName: String?
    var isDuplicate: Bool

    init(row: ParsedBankTransaction, accountName: String, fallbackCurrency: String = "USD") {
        let merchant = row.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = row.normalizedMerchant.trimmingCharacters(in: .whitespacesAndNewlines)
        self.date = row.date
        self.kind = row.kind
        self.amount = row.amount
        self.currency = Self.resolvedCurrency(row.currency, fallback: fallbackCurrency)
        self.merchant = merchant.isEmpty ? "Imported transaction" : merchant
        self.normalizedMerchant = normalized.isEmpty ? MerchantNormalizer.normalize(self.merchant) : normalized
        self.rawDescription = row.description
        self.accountName = accountName
        self.categoryName = row.suggestedCategory?.nilIfBlank
        self.subcategoryName = row.suggestedSubcategory?.nilIfBlank
        self.isDuplicate = row.isDuplicate
    }

    func identityKey() -> String {
        TransactionIdentityKey.make(
            accountName: accountName,
            date: date,
            amount: amount,
            normalizedMerchant: normalizedMerchant
        )
    }

    func transaction(importBatchId: UUID) -> FinanceTransaction {
        FinanceTransaction(
            date: date,
            kind: kind,
            amount: amount,
            currency: currency,
            merchant: merchant,
            normalizedMerchant: normalizedMerchant,
            rawDescription: rawDescription,
            accountName: accountName,
            categoryName: categoryName,
            subcategoryName: subcategoryName,
            importBatchId: importBatchId
        )
    }

    private static func resolvedCurrency(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback.uppercased() : trimmed.uppercased()
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Receipt OCR Models

@Model
final class ReceiptLineItem: Identifiable {
    var id: UUID = UUID()
    var itemName: String
    var unitPrice: Decimal
    var quantity: Int
    var totalPrice: Decimal
    var category: String?

    init(description: String, unitPrice: Decimal, quantity: Int, totalPrice: Decimal, category: String? = nil) {
        self.itemName = description
        self.unitPrice = unitPrice
        self.quantity = quantity
        self.totalPrice = totalPrice
        self.category = category
    }
}

@Model
final class ReceiptOCRData: Identifiable {
    var id: UUID = UUID()
    var transactionId: UUID?
    var rawText: String
    var lineItems: [ReceiptLineItem]
    var merchantName: String
    var totalAmount: Decimal
    var taxAmount: Decimal?
    var subtotal: Decimal?
    var currency: String
    var receiptDate: Date?
    var dateExtracted: Date
    var extractionConfidence: Double
    var isManuallyVerified: Bool
    var createdAt: Date

    init(
        rawText: String,
        merchantName: String,
        totalAmount: Decimal,
        currency: String,
        lineItems: [ReceiptLineItem] = [],
        taxAmount: Decimal? = nil,
        subtotal: Decimal? = nil,
        receiptDate: Date? = nil,
        extractionConfidence: Double = 0.5,
        transactionId: UUID? = nil
    ) {
        self.rawText = rawText
        self.merchantName = merchantName
        self.totalAmount = totalAmount
        self.currency = currency
        self.lineItems = lineItems
        self.taxAmount = taxAmount
        self.subtotal = subtotal
        self.receiptDate = receiptDate
        self.extractionConfidence = extractionConfidence
        self.transactionId = transactionId
        self.isManuallyVerified = false
        self.dateExtracted = Date()
        self.createdAt = Date()
    }
}
