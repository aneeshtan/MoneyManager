import Foundation

/// A header row plus its data rows, read from either an .xlsx worksheet or CSV text.
struct SpreadsheetTable: Sendable {
    var headers: [String]
    var rows: [[String]]

    var isEmpty: Bool { rows.isEmpty || headers.isEmpty }
}

/// Imports tabular exports where each row is already a transaction.
///
/// Unlike the bank-statement paths, these files often carry the user's own
/// `Category`/`Subcategory` and per-row `Account` columns. Those are trusted verbatim
/// rather than re-guessed, which is what makes the file usable as categorization
/// training data on save.
enum SpreadsheetImportParser {
    static func table(fromXLSX url: URL) throws -> SpreadsheetTable {
        let rows = try XLSXParser.firstSheetRows(from: url)
        return makeTable(from: rows)
    }

    static func table(fromCSV text: String) -> SpreadsheetTable {
        let parser = UniversalImportParser()
        let rows = text
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(parser.parseCSVLine)
        return makeTable(from: rows)
    }

    /// Exports frequently start with title or filter banners, so the header is the first
    /// row that actually names a date-like and an amount-like column.
    private static func makeTable(from rows: [[String]]) -> SpreadsheetTable {
        guard let headerIndex = rows.indices.prefix(20).first(where: { looksLikeHeader(rows[$0]) }) else {
            guard let first = rows.first else { return SpreadsheetTable(headers: [], rows: []) }
            return SpreadsheetTable(headers: first.map(normalizeHeader), rows: Array(rows.dropFirst()))
        }
        return SpreadsheetTable(
            headers: rows[headerIndex].map(normalizeHeader),
            rows: Array(rows.dropFirst(headerIndex + 1))
        )
    }

    private static func looksLikeHeader(_ row: [String]) -> Bool {
        let cells = Set(row.map(normalizeHeader))
        let hasDate = Columns.date.contains(where: cells.contains)
        let hasAmount = (Columns.amount + Columns.debit + Columns.credit).contains(where: cells.contains)
        return hasDate && hasAmount
    }

    static func isSupported(_ table: SpreadsheetTable) -> Bool {
        !table.isEmpty && looksLikeHeader(table.headers)
    }

    static func parse(
        _ table: SpreadsheetTable,
        ruleSnapshots: [MerchantRuleSnapshot],
        existingSnapshots: [TransactionSnapshot],
        defaultAccountName: String,
        fallbackCurrency: String
    ) -> [ParsedBankTransaction] {
        guard !table.isEmpty else { return [] }

        let matcher = PreparedCategoryMatcher(ruleSnapshots: ruleSnapshots)
        let duplicateLookup = DuplicateTransactionLookup(snapshots: existingSnapshots)
        let index = ColumnIndex(headers: table.headers)

        var parsed: [ParsedBankTransaction] = []
        parsed.reserveCapacity(table.rows.count)

        for row in table.rows {
            guard let date = parseDate(index.value(row, Columns.date)) else { continue }
            guard let money = amount(in: row, index: index) else { continue }

            let account = index.value(row, Columns.account)?.trimmed
            let category = index.value(row, Columns.category)?.trimmed
            let subcategory = index.value(row, Columns.subcategory)?.trimmed
            let kind = kind(
                declared: index.value(row, Columns.kind),
                isCreditColumn: money.isCreditColumn
            )

            let description = index.value(row, Columns.description)?.trimmed
                ?? category
                ?? "Imported transaction"
            let normalizedMerchant = MerchantNormalizer.normalize(description)

            let suggestion: CategorySuggestion? = category.map {
                CategorySuggestion(category: $0, subcategory: subcategory, kind: kind, confidence: 1)
            } ?? matcher.match(normalizedMerchant: normalizedMerchant, fallbackKind: kind)

            let accountName = account?.isEmpty == false ? account! : defaultAccountName
            let currency = index.value(row, Columns.currency)?.trimmed.uppercased()
            let isDuplicate = duplicateLookup.contains(
                accountName: accountName,
                date: date,
                amount: money.magnitude,
                normalizedMerchant: normalizedMerchant
            )

            var parsedRow = ParsedBankTransaction(
                date: date,
                description: description.isEmpty ? "Imported transaction" : description,
                normalizedMerchant: normalizedMerchant,
                kind: suggestion?.kind ?? kind,
                amount: money.magnitude,
                currency: currency?.isEmpty == false ? currency! : fallbackCurrency.uppercased(),
                suggestedCategory: suggestion?.category,
                suggestedSubcategory: suggestion?.subcategory,
                confidence: suggestion?.confidence ?? 0,
                isSelected: true,
                isDuplicate: isDuplicate,
                accountName: account?.isEmpty == false ? account : nil,
                isPreCategorized: category?.isEmpty == false
            )
            if isDuplicate {
                parsedRow.isSelected = false
            }
            parsed.append(parsedRow)
        }
        return parsed
    }

    // MARK: - Columns

    /// Ordered by preference, not just membership: a Money Manager export has both a
    /// populated `Note` and an empty `Description`, and other exports have the reverse.
    private enum Columns {
        static let date = ["date", "period", "transaction date", "posted date", "value date", "booking date"]
        static let account = ["account", "accounts", "account name", "wallet"]
        static let category = ["category", "main category"]
        static let subcategory = ["subcategory", "sub category", "sub-category"]
        static let description = ["note", "description", "details", "narration", "merchant", "payee", "memo"]
        static let amount = ["amount", "value", "transaction amount"]
        static let debit = ["debit", "withdrawal", "paid out", "expense"]
        static let credit = ["credit", "deposit", "paid in", "income"]
        static let currency = ["currency", "ccy"]
        static let kind = ["income/expense", "type", "cr/dr", "dr/cr", "direction", "transaction type"]
    }

    /// Resolves each logical column to a physical index once, instead of rebuilding a
    /// name→value dictionary for every row. Duplicate header names (Money Manager emits
    /// `Accounts` twice) resolve to the leftmost occurrence.
    private struct ColumnIndex {
        private let positions: [String: Int]

        init(headers: [String]) {
            var positions: [String: Int] = [:]
            for (offset, header) in headers.enumerated() where positions[header] == nil {
                positions[header] = offset
            }
            self.positions = positions
        }

        /// Returns the first non-empty value, walking `names` in priority order so the
        /// result does not depend on dictionary iteration order.
        func value(_ row: [String], _ names: [String]) -> String? {
            for name in names {
                guard let offset = positions[name], row.indices.contains(offset) else { continue }
                let value = row[offset].trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return value }
            }
            return nil
        }
    }

    private static func normalizeHeader(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Values

    private struct Money {
        var magnitude: Decimal
        var isCreditColumn: Bool
    }

    private static func amount(in row: [String], index: ColumnIndex) -> Money? {
        if let debit = decimal(index.value(row, Columns.debit)), debit != 0 {
            return Money(magnitude: abs(debit), isCreditColumn: false)
        }
        if let credit = decimal(index.value(row, Columns.credit)), credit != 0 {
            return Money(magnitude: abs(credit), isCreditColumn: true)
        }
        guard let amount = decimal(index.value(row, Columns.amount)), amount != 0 else { return nil }
        return Money(magnitude: abs(amount), isCreditColumn: false)
    }

    private static func decimal(_ value: String?) -> Decimal? {
        guard let value else { return nil }
        let cleaned = value
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: #"[A-Za-z]{3}"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " +"))
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func kind(declared: String?, isCreditColumn: Bool) -> TransactionKind {
        let value = (declared ?? "").lowercased()
        if value.contains("transfer") { return .transfer }
        if value.contains("income") || value.contains("credit") || value.hasPrefix("cr") { return .income }
        if value.contains("exp") || value.contains("debit") || value.hasPrefix("dr") { return .expense }
        return isCreditColumn ? .income : .expense
    }

    private static let candidateDateFormatters: [DateFormatter] = {
        ["yyyy-MM-dd", "dd/MM/yyyy", "d/M/yyyy", "MM/dd/yyyy", "dd-MM-yyyy", "d MMM yyyy", "dd MMM yyyy", "MMM d, yyyy", "yyyy/MM/dd"]
            .map { format in
                let formatter = DateFormatter()
                formatter.calendar = Calendar(identifier: .gregorian)
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = format
                return formatter
            }
    }()

    /// Spreadsheet dates arrive either as text or as an Excel day serial. The serial range
    /// is bounded so ordinary numbers in a mis-mapped column are not read as dates.
    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        if let serial = Double(cleaned), serial >= 20_000, serial <= 60_000 {
            return XLSXParser.date(fromSerial: serial)
        }
        for formatter in candidateDateFormatters {
            if let date = formatter.date(from: cleaned) { return date }
        }
        if let separatorIndex = cleaned.firstIndex(where: { $0 == " " || $0 == "T" }) {
            return parseDate(String(cleaned[cleaned.startIndex..<separatorIndex]))
        }
        return nil
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
