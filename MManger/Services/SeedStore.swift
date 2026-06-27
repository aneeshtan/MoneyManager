import Foundation
import SwiftData

enum SeedStore {
    static let defaultUserId = "primary-user"
    static let defaultImportAccountName = "Credit Card"

    static func seedIfNeeded(modelContext: ModelContext) throws {
        let seed = try loadSeed()

        let userDescriptor = FetchDescriptor<UserProfile>()
        if try modelContext.fetchCount(userDescriptor) == 0 {
            modelContext.insert(
                UserProfile(
                    id: seed.user.id,
                    displayName: seed.user.displayName,
                    baseCurrency: seed.user.baseCurrency
                )
            )
        }

        let accountDescriptor = FetchDescriptor<Account>()
        let shouldSeedMasterData = try modelContext.fetchCount(accountDescriptor) == 0
        let transactionDescriptor = FetchDescriptor<FinanceTransaction>()
        let existingTransactionCount = try modelContext.fetchCount(transactionDescriptor)
        let shouldSeedTransactions = existingTransactionCount == 0 && !seed.initialTransactions.isEmpty

        if shouldSeedMasterData {
            for account in seed.accounts {
                modelContext.insert(Account(userId: seed.user.id, name: account.name, currency: account.currency, sortOrder: account.sortOrder))
            }
        }

        let categoryById = Dictionary(uniqueKeysWithValues: seed.categories.map { ($0.id, $0) })
        if shouldSeedMasterData {
            for category in seed.categories {
                let parentName = category.parentId.flatMap { categoryById[$0]?.name }
                modelContext.insert(
                    FinanceCategory(
                        userId: seed.user.id,
                        externalId: category.id,
                        name: category.name,
                        kind: category.kind == "income" ? .income : .expense,
                        parentName: parentName,
                        sortOrder: category.sortOrder
                    )
                )
            }
        }

        if shouldSeedMasterData {
            for rule in seed.merchantRules {
                modelContext.insert(
                    MerchantRule(
                        userId: seed.user.id,
                        pattern: rule.pattern,
                        matchType: MatchType(rawValue: rule.matchType) ?? .contains,
                        categoryName: rule.category,
                        subcategoryName: rule.subcategory,
                        kind: TransactionKind(rawValue: rule.kind) ?? .expense,
                        confidence: rule.confidence,
                        sampleCount: rule.sampleCount
                    )
                )
            }
        }

        if shouldSeedTransactions {
            for transaction in seed.initialTransactions {
                modelContext.insert(transaction.model(userId: seed.user.id))
            }
        }
        try modelContext.save()
    }

    static func loadSeed() throws -> SeedData {
        guard let url = Bundle.main.url(forResource: "SeedData", withExtension: "json") else {
            throw SeedError.missingSeedFile
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SeedData.self, from: data)
    }
}

enum SeedError: Error {
    case missingSeedFile
}

struct SeedData: Codable {
    var version: Int
    var user: SeedUser
    var defaultCurrency: String
    var defaultImportAccount: String
    var accounts: [SeedAccount]
    var categories: [SeedCategory]
    var merchantRules: [SeedMerchantRule]
    var initialTransactions: [SeedInitialTransaction]
}

struct SeedUser: Codable {
    var id: String
    var displayName: String
    var baseCurrency: String
}

struct SeedAccount: Codable {
    var id: String
    var name: String
    var currency: String
    var sortOrder: Int
}

struct SeedCategory: Codable {
    var id: String
    var name: String
    var kind: String
    var parentId: String?
    var sortOrder: Int
}

struct SeedMerchantRule: Codable {
    var pattern: String
    var matchType: String
    var category: String
    var subcategory: String?
    var kind: String
    var confidence: Double
    var sampleCount: Int
}

struct SeedInitialTransaction: Codable {
    static let pdfImportSourceName = "Bank Statement Import"

    var sourceName: String?
    var sourceRow: Int
    var date: String
    var periodSerial: String
    var account: String
    var category: String
    var subcategory: String?
    var note: String
    var aed: String
    var incomeExpense: String
    var description: String
    var amount: String
    var currency: String
    var accountsTrailing: String
    var kind: String
    var merchant: String
    var normalizedMerchant: String

    func model(userId: String) -> FinanceTransaction {
        let parsedAmount = Decimal(string: amount, locale: Locale(identifier: "en_US_POSIX"))
            ?? Decimal(string: aed, locale: Locale(identifier: "en_US_POSIX"))
            ?? 0
        return FinanceTransaction(
            userId: userId,
            date: Self.dateFormatter.date(from: date) ?? .now,
            kind: TransactionKind(rawValue: kind) ?? .expense,
            amount: parsedAmount,
            currency: currency.isEmpty ? "USD" : currency,
            merchant: merchant,
            normalizedMerchant: normalizedMerchant.isEmpty ? MerchantNormalizer.normalize(merchant) : normalizedMerchant,
            note: note,
            rawDescription: note,
            accountName: account,
            categoryName: category.isEmpty ? nil : category,
            subcategoryName: subcategory,
            sourceName: sourceName ?? "Money Manager Excel Export",
            sourceRow: sourceRow,
            sourcePeriodSerial: periodSerial,
            sourceAccountColumn: account,
            sourceCategoryColumn: category,
            sourceSubcategoryColumn: subcategory,
            sourceNoteColumn: note,
            sourceAEDColumn: aed,
            sourceIncomeExpenseColumn: incomeExpense,
            sourceDescriptionColumn: description,
            sourceAmountColumn: amount,
            sourceCurrencyColumn: currency,
            sourceTrailingAccountsColumn: accountsTrailing
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
}
