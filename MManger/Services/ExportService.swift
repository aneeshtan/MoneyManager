import Foundation

enum ExportService {
    static func transactionsCSV(_ transactions: [FinanceTransaction]) -> String {
        let formatter = ISO8601DateFormatter()
        let header = [
            "UserId",
            "Date",
            "Account",
            "Kind",
            "Category",
            "Subcategory",
            "Merchant",
            "Amount",
            "Currency",
            "Note",
            "Source",
            "SourceRow",
            "SourcePeriod",
            "SourceAccount",
            "SourceCategory",
            "SourceSubcategory",
            "SourceNote",
            "SourceAED",
            "SourceIncomeExpense",
            "SourceDescription",
            "SourceAmount",
            "SourceCurrency",
            "SourceTrailingAccounts"
        ].joined(separator: ",")
        let rows = transactions
            .sorted { $0.date > $1.date }
            .map { transaction in
                [
                    transaction.userId,
                    formatter.string(from: transaction.date),
                    transaction.accountName,
                    transaction.kind.displayName,
                    transaction.categoryName ?? "",
                    transaction.subcategoryName ?? "",
                    transaction.merchant,
                    NSDecimalNumber(decimal: transaction.amount).stringValue,
                    transaction.currency,
                    transaction.note,
                    transaction.sourceName ?? "",
                    transaction.sourceRow.map(String.init) ?? "",
                    transaction.sourcePeriodSerial ?? "",
                    transaction.sourceAccountColumn ?? "",
                    transaction.sourceCategoryColumn ?? "",
                    transaction.sourceSubcategoryColumn ?? "",
                    transaction.sourceNoteColumn ?? "",
                    transaction.sourceAEDColumn ?? "",
                    transaction.sourceIncomeExpenseColumn ?? "",
                    transaction.sourceDescriptionColumn ?? "",
                    transaction.sourceAmountColumn ?? "",
                    transaction.sourceCurrencyColumn ?? "",
                    transaction.sourceTrailingAccountsColumn ?? ""
                ]
                .map(csvEscape)
                .joined(separator: ",")
            }
        return ([header] + rows).joined(separator: "\n")
    }

    static func backupJSON(transactions: [FinanceTransaction], accounts: [Account], categories: [FinanceCategory], rules: [MerchantRule]) throws -> Data {
        let backup = BackupPayload(
            exportedAt: .now,
            accounts: accounts.map {
                AccountBackupRecord(
                    name: $0.name,
                    currency: $0.currency,
                    openingBalance: NSDecimalNumber(decimal: $0.openingBalance).stringValue,
                    type: $0.type.rawValue,
                    isArchived: $0.isArchived
                )
            },
            categories: categories.map { BackupCategory(name: $0.name, kind: $0.kind.rawValue, parentName: $0.parentName) },
            rules: rules.map { BackupRule(pattern: $0.pattern, category: $0.categoryName, subcategory: $0.subcategoryName, confidence: $0.confidence) },
            transactions: transactions.map {
                BackupTransaction(
                    date: $0.date,
                    accountName: $0.accountName,
                    kind: $0.kind.rawValue,
                    amount: NSDecimalNumber(decimal: $0.amount).stringValue,
                    currency: $0.currency,
                    merchant: $0.merchant,
                    categoryName: $0.categoryName,
                    subcategoryName: $0.subcategoryName,
                    note: $0.note,
                    source: BackupTransactionSource(
                        name: $0.sourceName,
                        row: $0.sourceRow,
                        periodSerial: $0.sourcePeriodSerial,
                        account: $0.sourceAccountColumn,
                        category: $0.sourceCategoryColumn,
                        subcategory: $0.sourceSubcategoryColumn,
                        note: $0.sourceNoteColumn,
                        aed: $0.sourceAEDColumn,
                        incomeExpense: $0.sourceIncomeExpenseColumn,
                        description: $0.sourceDescriptionColumn,
                        amount: $0.sourceAmountColumn,
                        currency: $0.sourceCurrencyColumn,
                        trailingAccounts: $0.sourceTrailingAccountsColumn
                    )
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    private static func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            return "\"\(escaped)\""
        }
        return escaped
    }
}

struct AccountBackupRecord: Codable {
    var name: String
    var currency: String
    var openingBalance: String
    var type: String
    var isArchived: Bool

    init(name: String, currency: String, openingBalance: String, type: String = AccountType.other.rawValue, isArchived: Bool = false) {
        self.name = name
        self.currency = currency
        self.openingBalance = openingBalance
        self.type = AccountType(rawValue: type)?.rawValue ?? AccountType.other.rawValue
        self.isArchived = isArchived
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        currency = try container.decode(String.self, forKey: .currency)
        openingBalance = try container.decode(String.self, forKey: .openingBalance)
        let decodedType = try container.decodeIfPresent(String.self, forKey: .type) ?? AccountType.other.rawValue
        type = AccountType(rawValue: decodedType)?.rawValue ?? AccountType.other.rawValue
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }
}

private struct BackupPayload: Codable {
    var exportedAt: Date
    var accounts: [AccountBackupRecord]
    var categories: [BackupCategory]
    var rules: [BackupRule]
    var transactions: [BackupTransaction]
}

private struct BackupCategory: Codable {
    var name: String
    var kind: String
    var parentName: String?
}

private struct BackupRule: Codable {
    var pattern: String
    var category: String
    var subcategory: String?
    var confidence: Double
}

private struct BackupTransaction: Codable {
    var date: Date
    var accountName: String
    var kind: String
    var amount: String
    var currency: String
    var merchant: String
    var categoryName: String?
    var subcategoryName: String?
    var note: String
    var source: BackupTransactionSource
}

private struct BackupTransactionSource: Codable {
    var name: String?
    var row: Int?
    var periodSerial: String?
    var account: String?
    var category: String?
    var subcategory: String?
    var note: String?
    var aed: String?
    var incomeExpense: String?
    var description: String?
    var amount: String?
    var currency: String?
    var trailingAccounts: String?
}
