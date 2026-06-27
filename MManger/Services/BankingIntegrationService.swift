import Foundation
import PDFKit

// MARK: - Universal Banking Integration Service

/// Protocol for bank-specific adapters
protocol BankAdapter {
    var name: String { get }
    var supportedFormats: [ImportFormat] { get }
    
    func parsePDF(at url: URL, ruleSnapshots: [MerchantRuleSnapshot], existingSnapshots: [TransactionSnapshot], accountName: String) throws -> [ParsedBankTransaction]
    func parseCSV(_ text: String, ruleSnapshots: [MerchantRuleSnapshot], existingSnapshots: [TransactionSnapshot], accountName: String, fallbackCurrency: String) -> [ParsedBankTransaction]
    func parsePlainText(_ text: String, ruleSnapshots: [MerchantRuleSnapshot], existingSnapshots: [TransactionSnapshot], accountName: String, requireDate: Bool, fallbackCurrency: String) -> [ParsedBankTransaction]
}

/// Universal format detector for automatic bank statement recognition
struct FormatDetector {
    static func detectBankFormat(from text: String, format: ImportFormat) -> BankFormat? {
        switch format {
        case .pdf:
            return detectPDFFormat(text)
        case .csv:
            return detectCSVFormat(text)
        case .plainText:
            return detectPlainTextFormat(text)
        }
    }
    
    private static func detectPDFFormat(_ text: String) -> BankFormat? {
        // Generic pattern detection for various banks
        let lines = text.components(separatedBy: .newlines).prefix(20) // Check first 20 lines
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Detect common bank statement patterns
            if trimmed.contains("CHASE") || trimmed.contains("JPMORGAN") {
                return .chase
            } else if trimmed.contains("BANK OF AMERICA") || trimmed.contains("BANKOFAMERICA") {
                return .bankOfAmerica
            } else if trimmed.contains("WELLS FARGO") || trimmed.contains("WELLSFARGO") {
                return .wellsFargo
            } else if trimmed.contains("BARCLAYS") {
                return .barclays
            } else if trimmed.contains("HSBC") {
                return .hsbc
            } else if trimmed.contains("SANTANDER") {
                return .santander
            } else if trimmed.contains("DBS") || trimmed.contains("DIGITAL BANKING") {
                return .dbs
            } else if trimmed.contains("OCBC") {
                return .ocbc
            } else if trimmed.contains("COMMONWEALTH") || trimmed.contains("CBA") {
                return .commonwealth
            } else if trimmed.contains("HDFC") {
                return .hdfc
            } else if trimmed.contains("ICICI") {
                return .icici
            } else if trimmed.contains("SBI") {
                return .sbi
            } else if trimmed.contains("EMIRATES NBD") || trimmed.contains("ENBD") {
                return .emiratesNBD
            } else if trimmed.contains("FAB") || trimmed.contains("FIRST ABU DHABI") {
                return .firstAbuDhabi
            }
        }
        
        return nil
    }
    
    private static func detectCSVFormat(_ text: String) -> BankFormat? {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard let header = lines.first else { return nil }
        
        let headers = header.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndQuotes).lowercased() }
        
        // Detect based on common column names
        if headers.contains("transaction date") && headers.contains("description") && (headers.contains("amount") || headers.contains("debit") || headers.contains("credit")) {
            // Try to identify specific bank based on additional columns or bank-specific terms
            let headerText = header.lowercased()
            if headerText.contains("chase") {
                return .chase
            } else if headerText.contains("bank of america") {
                return .bankOfAmerica
            } else if headerText.contains("wells fargo") {
                return .wellsFargo
            } else if headerText.contains("barclays") {
                return .barclays
            } else if headerText.contains("hsbc") {
                return .hsbc
            }
        }
        
        return .genericCSV
    }
    
    private static func detectPlainTextFormat(_ text: String) -> BankFormat? {
        // For plain text, look for common banking SMS/notification patterns
        let lowerText = text.lowercased()
        
        if lowerText.contains("balance") && lowerText.contains("account") {
            return .smsNotification
        }
        
        return .genericPlainText
    }
}

enum BankFormat {
    // US Banks
    case chase
    case bankOfAmerica
    case wellsFargo
    
    // UK/European Banks
    case barclays
    case hsbc
    case santander
    
    // Asian Banks
    case dbs
    case ocbc
    case commonwealth
    case hdfc
    case icici
    case sbi
    
    // Middle Eastern Banks
    case emiratesNBD
    case firstAbuDhabi
    
    // Generic formats
    case genericCSV
    case genericPlainText
    case smsNotification
}

// MARK: - Universal Import Parser

enum UniversalImportParserError: LocalizedError {
    case unreadableFile
    case unsupportedSpreadsheet
    case noTransactionsFound
    case unsupportedBankFormat
    
    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            "Could not read this file."
        case .unsupportedSpreadsheet:
            "Excel .xlsx files are not parsed directly yet. Export the sheet as CSV and import that file."
        case .noTransactionsFound:
            "No transaction rows were found. Try CSV, a searchable PDF, or paste bank SMS messages."
        case .unsupportedBankFormat:
            "Unsupported bank statement format. Please try a different file or contact support."
        }
    }
}

struct UniversalImportParser {
    private let bankAdapters: [BankFormat: BankAdapter] = [
        .genericCSV: GenericCSVAdapter(),
        .genericPlainText: GenericPlainTextAdapter()
        // Additional adapters can be added here
    ]
    
    func parsePastedMessages(
        _ text: String,
        rules: [MerchantRule],
        existingTransactions: [FinanceTransaction],
        accountName: String,
        fallbackCurrency: String = "USD"
    ) throws -> [ParsedBankTransaction] {
        try parsePastedMessages(
            text,
            ruleSnapshots: rules.map(MerchantRuleSnapshot.init),
            existingSnapshots: existingTransactions.map(TransactionSnapshot.init),
            accountName: accountName,
            fallbackCurrency: fallbackCurrency
        )
    }
    
    /// Off-main-safe pasted-messages entry point.
    func parsePastedMessages(
        _ text: String,
        ruleSnapshots: [MerchantRuleSnapshot],
        existingSnapshots: [TransactionSnapshot],
        accountName: String,
        fallbackCurrency: String = "USD"
    ) throws -> [ParsedBankTransaction] {
        let rows = parsePlainText(text, ruleSnapshots: ruleSnapshots, existingSnapshots: existingSnapshots, accountName: accountName, requireDate: false, fallbackCurrency: fallbackCurrency)
        guard !rows.isEmpty else { throw UniversalImportParserError.noTransactionsFound }
        return rows
    }
    
    func parseText(
        _ text: String,
        format: ImportFormat,
        ruleSnapshots: [MerchantRuleSnapshot],
        existingSnapshots: [TransactionSnapshot],
        accountName: String,
        fallbackCurrency: String = "USD"
    ) throws -> [ParsedBankTransaction] {
        // Detect bank format from the already-extracted text
        let bankFormat = FormatDetector.detectBankFormat(from: text, format: format)

        // For PDF: always parse the extracted text directly — never re-read the file.
        if format == .pdf {
            let strictRows = BankStatementPDFParser().parseText(
                text,
                ruleSnapshots: ruleSnapshots,
                existingSnapshots: existingSnapshots,
                accountName: accountName,
                fallbackCurrency: fallbackCurrency
            )
            if !strictRows.isEmpty {
                return strictRows
            }
            let rows = parsePlainText(text, ruleSnapshots: ruleSnapshots, existingSnapshots: existingSnapshots, accountName: accountName, requireDate: true, fallbackCurrency: fallbackCurrency)
            guard !rows.isEmpty else { throw UniversalImportParserError.noTransactionsFound }
            return rows
        }

        guard let detectedFormat = bankFormat else {
            return try parseWithGenericAdapter(text, format: format, ruleSnapshots: ruleSnapshots, existingSnapshots: existingSnapshots, accountName: accountName, fallbackCurrency: fallbackCurrency)
        }

        if let adapter = bankAdapters[detectedFormat] {
            switch format {
            case .pdf:
                // Already handled above
                break
            case .csv:
                return adapter.parseCSV(text, ruleSnapshots: ruleSnapshots, existingSnapshots: existingSnapshots, accountName: accountName, fallbackCurrency: fallbackCurrency)
            case .plainText:
                return adapter.parsePlainText(text, ruleSnapshots: ruleSnapshots, existingSnapshots: existingSnapshots, accountName: accountName, requireDate: true, fallbackCurrency: fallbackCurrency)
            }
        }

        return try parseWithGenericAdapter(text, format: format, ruleSnapshots: ruleSnapshots, existingSnapshots: existingSnapshots, accountName: accountName, fallbackCurrency: fallbackCurrency)
    }
    
    private func parseWithGenericAdapter(
        _ text: String,
        format: ImportFormat,
        ruleSnapshots: [MerchantRuleSnapshot],
        existingSnapshots: [TransactionSnapshot],
        accountName: String,
        fallbackCurrency: String
    ) throws -> [ParsedBankTransaction] {
        switch format {
        case .pdf:
            // Try generic PDF parsing
            let rows = parsePlainText(text, ruleSnapshots: ruleSnapshots, existingSnapshots: existingSnapshots, accountName: accountName, requireDate: true, fallbackCurrency: fallbackCurrency)
            guard !rows.isEmpty else { throw UniversalImportParserError.noTransactionsFound }
            return rows
        case .csv:
            let rows = parseCSV(text, ruleSnapshots: ruleSnapshots, existingSnapshots: existingSnapshots, accountName: accountName, fallbackCurrency: fallbackCurrency)
            guard !rows.isEmpty else { throw UniversalImportParserError.noTransactionsFound }
            return rows
        case .plainText:
            let rows = parsePlainText(text, ruleSnapshots: ruleSnapshots, existingSnapshots: existingSnapshots, accountName: accountName, requireDate: true, fallbackCurrency: fallbackCurrency)
            guard !rows.isEmpty else { throw UniversalImportParserError.noTransactionsFound }
            return rows
        }
    }
    
    func parseCSV(
        _ text: String,
        ruleSnapshots: [MerchantRuleSnapshot],
        existingSnapshots: [TransactionSnapshot],
        accountName: String,
        fallbackCurrency: String = "USD"
    ) -> [ParsedBankTransaction] {
        let duplicateLookup = DuplicateTransactionLookup(snapshots: existingSnapshots)
        let rows = text
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(parseCSVLine)
        guard let header = rows.first?.map({ normalizeHeader($0) }), rows.count > 1 else { return [] }
        
        var parsed: [ParsedBankTransaction] = []
        parsed.reserveCapacity(rows.count - 1)
        
        for row in rows.dropFirst() {
            let pairs: [(String, String)] = header.enumerated().compactMap { index, name in
                guard index < row.count else { return nil }
                return (name, row[index].trimmingCharacters(in: .whitespacesAndNewlines))
            }
            let fields = Dictionary(uniqueKeysWithValues: pairs)
            
            guard let date = parseDate(firstValue(in: fields, keys: ["date", "transaction date", "posted date", "value date", "period"])) else {
                continue
            }
            let merchant = firstValue(in: fields, keys: ["merchant", "description", "details", "narration", "note", "payee"]) ?? "Imported transaction"
            let currency = firstValue(in: fields, keys: ["currency", "ccy"]) ?? detectCurrencyFromContext(text: text, fields: fields, fallbackCurrency: fallbackCurrency)
            let amountInfo = amountAndKind(from: fields)
            guard let amountInfo else { continue }
            parsed.append(
                makeParsed(
                    date: date,
                    description: merchant,
                    kind: amountInfo.kind,
                    amount: amountInfo.amount,
                    currency: currency,
                    fallbackCurrency: fallbackCurrency,
                    accountName: accountName,
                    rules: ruleSnapshots,
                    duplicateLookup: duplicateLookup
                )
            )
        }
        return parsed
    }
    
    func parsePlainText(
        _ text: String,
        ruleSnapshots: [MerchantRuleSnapshot],
        existingSnapshots: [TransactionSnapshot],
        accountName: String,
        requireDate: Bool,
        fallbackCurrency: String = "USD"
    ) -> [ParsedBankTransaction] {
        let duplicateLookup = DuplicateTransactionLookup(snapshots: existingSnapshots)
        let chunks = text
            .components(separatedBy: CharacterSet.newlines)
            .flatMap { $0.components(separatedBy: "\n\n") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var rows: [ParsedBankTransaction] = []
        rows.reserveCapacity(chunks.count)
        for line in chunks {
            if let parsed = parsePlainTextLine(line, rules: ruleSnapshots, duplicateLookup: duplicateLookup, accountName: accountName, requireDate: requireDate, fallbackCurrency: fallbackCurrency) {
                rows.append(parsed)
            }
        }
        return rows
    }
    
    private func parsePlainTextLine(
        _ line: String,
        rules: [MerchantRuleSnapshot],
        duplicateLookup: DuplicateTransactionLookup,
        accountName: String,
        requireDate: Bool,
        fallbackCurrency: String
    ) -> ParsedBankTransaction? {
        let cleaned = Self.whitespaceRegex.stringByReplacingMatches(
            in: line,
            range: NSRange(line.startIndex..<line.endIndex, in: line),
            withTemplate: " "
        )
        guard !isStatementNoise(cleaned),
              let amountMatch = moneyMatch(in: cleaned),
              let amount = Decimal(string: amountMatch.amount.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        
        let lower = cleaned.lowercased()
        let kind: TransactionKind = lower.contains("credit") || lower.contains("credited") || lower.contains("refund") || lower.contains("received") || lower.contains("deposit")
            ? .income
            : .expense
        let currency = normalizedCurrency(amountMatch.currency, fallbackCurrency: fallbackCurrency)
        
        // For file imports, require a real date so standalone page numbers / footers don't become transactions.
        guard let date = parseDate(cleaned) else {
            if requireDate { return nil }
            // Pasted messages may omit a date; fall back to now.
            return makeParsed(
                date: .now,
                description: extractMerchant(from: cleaned) ?? cleaned,
                kind: kind,
                amount: amount,
                currency: currency,
                fallbackCurrency: fallbackCurrency,
                accountName: accountName,
                rules: rules,
                duplicateLookup: duplicateLookup
            )
        }
        
        let merchant = extractMerchant(from: cleaned) ?? cleaned
        
        // Reject page numbers or other numeric-only noise (e.g. "5", "12", "1,234").
        let normalizedMerchant = MerchantNormalizer.normalize(merchant)
        guard !normalizedMerchant.isEmpty, normalizedMerchant.range(of: #"^[0-9,.]+$"#, options: .regularExpression) == nil else {
            return nil
        }
        
        return makeParsed(
            date: date,
            description: merchant,
            kind: kind,
            amount: amount,
            currency: currency,
            fallbackCurrency: fallbackCurrency,
            accountName: accountName,
            rules: rules,
            duplicateLookup: duplicateLookup
        )
    }
    
    private func makeParsed(
        date: Date,
        description: String,
        kind: TransactionKind,
        amount: Decimal,
        currency: String,
        fallbackCurrency: String,
        accountName: String,
        rules: [MerchantRuleSnapshot],
        duplicateLookup: DuplicateTransactionLookup
    ) -> ParsedBankTransaction {
        let normalized = MerchantNormalizer.normalize(description)
        let suggestion = CategoryMatcher.match(merchant: normalized, ruleSnapshots: rules, fallbackKind: kind)
        let duplicate = duplicateLookup.contains(
            accountName: accountName,
            date: date,
            amount: amount,
            normalizedMerchant: normalized
        )
        var parsed = ParsedBankTransaction(
            date: date,
            description: description,
            normalizedMerchant: normalized,
            kind: suggestion?.kind ?? kind,
            amount: amount,
            currency: normalizedCurrency(currency, fallbackCurrency: fallbackCurrency),
            suggestedCategory: suggestion?.category,
            suggestedSubcategory: suggestion?.subcategory,
            confidence: suggestion?.confidence ?? 0,
            isSelected: true,
            isDuplicate: duplicate
        )
        if parsed.isReviewOnly || duplicate {
            parsed.isSelected = false
        }
        return parsed
    }
    
    // MARK: - Helper Methods
    
    private static let whitespaceRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"\s+"#)
    }()
    
    private static let decimalAmountRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"(?i)\b([A-Z]{3})?\s*([0-9][0-9,]*\.[0-9]{1,2})\s*([A-Z]{3})?\b"#)
    }()

    private static let currencyWholeAmountRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"(?i)\b([A-Z]{3})\s*([0-9][0-9,]*)\b(?![.,])"#)
    }()
    
    private static let merchantPatterns: [NSRegularExpression] = {
        let patterns = [
            #"(?i)\bat\s+(.+?)(?:\s+on\s+\d|\s+for\s+[A-Z]{3}?\s*[0-9]|$)"#,
            #"(?i)\bfrom\s+(.+?)(?:\s+on\s+\d|\s+for\s+[A-Z]{3}?\s*[0-9]|$)"#,
            #"(?i)\bto\s+(.+?)(?:\s+on\s+\d|\s+for\s+[A-Z]{3}?\s*[0-9]|$)"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0) }
    }()
    
    private static let dateFallbackPattern: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}-\d{1,2}-\d{1,2})"#)
    }()

    private struct MoneyMatch {
        var amount: String
        var currency: String
        var location: Int
    }

    private func moneyMatch(in value: String) -> MoneyMatch? {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        var matches: [MoneyMatch] = []

        for match in Self.decimalAmountRegex.matches(in: value, range: range) {
            guard let amount = capture(2, in: value, match: match), !amount.isEmpty else { continue }
            let leadingCurrency = capture(1, in: value, match: match) ?? ""
            let trailingCurrency = capture(3, in: value, match: match) ?? ""
            matches.append(MoneyMatch(
                amount: amount,
                currency: leadingCurrency.isEmpty ? trailingCurrency : leadingCurrency,
                location: match.range.location
            ))
        }

        for match in Self.currencyWholeAmountRegex.matches(in: value, range: range) {
            guard let currency = capture(1, in: value, match: match),
                  let amount = capture(2, in: value, match: match),
                  !currency.isEmpty,
                  !amount.isEmpty else { continue }
            matches.append(MoneyMatch(amount: amount, currency: currency, location: match.range.location))
        }

        return matches.sorted { $0.location < $1.location }.last
    }

    private func isStatementNoise(_ value: String) -> Bool {
        let lower = value.lowercased()
        let noisePhrases = [
            "statement date",
            "statement period",
            "statement summary",
            "statement balance",
            "payment due date",
            "minimum payment",
            "opening balance",
            "closing balance",
            "available balance",
            "credit limit",
            "page "
        ]
        if noisePhrases.contains(where: lower.contains) {
            return true
        }
        return lower.range(of: #"^page\s+\d+\s*(?:of|/)\s*\d+$"#, options: .regularExpression) != nil
    }
    
    private func amountAndKind(from fields: [String: String]) -> (amount: Decimal, kind: TransactionKind)? {
        if let debit = decimal(firstValue(in: fields, keys: ["debit", "withdrawal", "paid out", "expense"])), debit > 0 {
            return (debit, .expense)
        }
        if let credit = decimal(firstValue(in: fields, keys: ["credit", "deposit", "paid in", "income"])), credit > 0 {
            return (credit, .income)
        }
        guard let amount = decimal(firstValue(in: fields, keys: ["amount", "value", "transaction amount"])) else {
            return nil
        }
        let type = (firstValue(in: fields, keys: ["type", "cr/dr", "dr/cr", "direction", "income/expense"]) ?? "").lowercased()
        if amount < 0 { return (-amount, .expense) }
        if type.contains("cr") || type.contains("income") || type.contains("credit") {
            return (amount, .income)
        }
        return (amount, .expense)
    }
    
    /// RFC-4180-aware CSV line parser that correctly handles escaped double quotes (`""`).
    func parseCSVLine(_ line: String) -> [String] {
        var values: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()
        while let character = iterator.next() {
            if character == "\"" {
                if inQuotes {
                    // Peek at the next character; a second quote is an escaped quote.
                    if let next = iterator.next() {
                        if next == "\"" {
                            current.append("\"")
                        } else {
                            inQuotes.toggle()
                            if next != "," {
                                current.append(next)
                            } else {
                                values.append(current)
                                current = ""
                            }
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
            } else if character == "," && !inQuotes {
                values.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        values.append(current)
        return values
    }
    
    private func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let formats = ["dd/MM/yyyy", "d/M/yyyy", "yyyy-MM-dd", "MM/dd/yyyy", "dd-MM-yyyy", "d MMM yyyy", "dd MMM yyyy", "MMM d, yyyy"]
        for format in formats {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: cleaned) {
                return date
            }
        }
        if let match = firstMatch(Self.dateFallbackPattern, in: cleaned) {
            return parseDate(match.captures[0])
        }
        return nil
    }
    
    private func extractMerchant(from value: String) -> String? {
        for regex in Self.merchantPatterns {
            if let match = firstMatch(regex, in: value), !match.captures[0].isEmpty {
                return match.captures[0].trimmingCharacters(in: CharacterSet(charactersIn: " .,-"))
            }
        }
        return nil
    }
    
    private func normalizeHeader(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    private func firstValue(in fields: [String: String], keys: [String]) -> String? {
        for key in keys {
            if let value = fields[key], !value.isEmpty {
                return value
            }
        }
        return nil
    }
    
    private func decimal(_ value: String?) -> Decimal? {
        guard let value else { return nil }
        let cleaned = value
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: #"\b[A-Z]{3}\b"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: CharacterSet(charactersIn: " +"))
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }
    
    private func normalizedCurrency(_ value: String, fallbackCurrency: String = "USD") -> String {
        let upper = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if upper.isEmpty {
            let fallback = fallbackCurrency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            return fallback.isEmpty ? "USD" : fallback
        }
        return upper
    }
    
    private func detectCurrencyFromContext(text: String, fields: [String: String], fallbackCurrency: String = "USD") -> String {
        // Try to detect currency from the text context
        let upperText = text.uppercased()
        
        // Common currency codes
        let currencyCodes = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "SEK", "NZD", "MXN", "SGD", "HKD", "NOK", "KRW", "TRY", "INR", "BRL", "ZAR", "AED", "SAR", "QAR", "KWD", "BHD", "OMR", "EGP", "PHP", "THB", "IDR", "MYR"]
        
        for code in currencyCodes {
            if upperText.contains(code) {
                return code
            }
        }
        
        // Check fields for currency indicators
        for (_, value) in fields {
            let upperValue = value.uppercased()
            for code in currencyCodes {
                if upperValue.contains(code) {
                    return code
                }
            }
        }
        
        return normalizedCurrency("", fallbackCurrency: fallbackCurrency)
    }
    
    func firstMatch(_ pattern: String, in text: String) -> RegexMatch? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        return firstMatch(regex, in: text)
    }
    
    func firstMatch(_ regex: NSRegularExpression, in text: String) -> RegexMatch? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        let captures = (1..<match.numberOfRanges).map { index -> String in
            guard let range = Range(match.range(at: index), in: text) else { return "" }
            return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return RegexMatch(captures: captures)
    }

    private func capture(_ index: Int, in text: String, match: NSTextCheckingResult) -> String? {
        guard index < match.numberOfRanges,
              match.range(at: index).location != NSNotFound,
              let range = Range(match.range(at: index), in: text) else {
            return nil
        }
        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Bank Adapters

class StrictStatementBankAdapter: BankAdapter {
    let name = "Strict Statement"
    let supportedFormats: [ImportFormat] = [.pdf, .csv, .plainText]

    func parsePDF(at url: URL, ruleSnapshots: [MerchantRuleSnapshot], existingSnapshots: [TransactionSnapshot], accountName: String) throws -> [ParsedBankTransaction] {
        // parsePDF(at:) must not be called from a background thread because PDFKit is not thread-safe.
        // Use parseText(_:format:...) instead, passing pre-extracted text.
        throw UniversalImportParserError.unsupportedBankFormat
    }

    func parseCSV(_ text: String, ruleSnapshots: [MerchantRuleSnapshot], existingSnapshots: [TransactionSnapshot], accountName: String, fallbackCurrency: String) -> [ParsedBankTransaction] {
        UniversalImportParser().parseCSV(text, ruleSnapshots: ruleSnapshots, existingSnapshots: existingSnapshots, accountName: accountName, fallbackCurrency: fallbackCurrency)
    }

    func parsePlainText(_ text: String, ruleSnapshots: [MerchantRuleSnapshot], existingSnapshots: [TransactionSnapshot], accountName: String, requireDate: Bool, fallbackCurrency: String) -> [ParsedBankTransaction] {
        UniversalImportParser().parsePlainText(text, ruleSnapshots: ruleSnapshots, existingSnapshots: existingSnapshots, accountName: accountName, requireDate: requireDate, fallbackCurrency: fallbackCurrency)
    }
}

class GenericCSVAdapter: BankAdapter {
    let name = "Generic CSV"
    let supportedFormats: [ImportFormat] = [.csv]
    
    func parsePDF(at url: URL, ruleSnapshots: [MerchantRuleSnapshot], existingSnapshots: [TransactionSnapshot], accountName: String) throws -> [ParsedBankTransaction] {
        throw UniversalImportParserError.unsupportedBankFormat
    }
    
    func parseCSV(_ text: String, ruleSnapshots: [MerchantRuleSnapshot], existingSnapshots: [TransactionSnapshot], accountName: String, fallbackCurrency: String) -> [ParsedBankTransaction] {
        return UniversalImportParser().parseCSV(text, ruleSnapshots: ruleSnapshots, existingSnapshots: existingSnapshots, accountName: accountName, fallbackCurrency: fallbackCurrency)
    }
    
    func parsePlainText(_ text: String, ruleSnapshots: [MerchantRuleSnapshot], existingSnapshots: [TransactionSnapshot], accountName: String, requireDate: Bool, fallbackCurrency: String) -> [ParsedBankTransaction] {
        return []
    }
}

class GenericPlainTextAdapter: BankAdapter {
    let name = "Generic Plain Text"
    let supportedFormats: [ImportFormat] = [.plainText]
    
    func parsePDF(at url: URL, ruleSnapshots: [MerchantRuleSnapshot], existingSnapshots: [TransactionSnapshot], accountName: String) throws -> [ParsedBankTransaction] {
        throw UniversalImportParserError.unsupportedBankFormat
    }
    
    func parseCSV(_ text: String, ruleSnapshots: [MerchantRuleSnapshot], existingSnapshots: [TransactionSnapshot], accountName: String, fallbackCurrency: String) -> [ParsedBankTransaction] {
        return []
    }
    
    func parsePlainText(_ text: String, ruleSnapshots: [MerchantRuleSnapshot], existingSnapshots: [TransactionSnapshot], accountName: String, requireDate: Bool, fallbackCurrency: String) -> [ParsedBankTransaction] {
        return UniversalImportParser().parsePlainText(text, ruleSnapshots: ruleSnapshots, existingSnapshots: existingSnapshots, accountName: accountName, requireDate: requireDate, fallbackCurrency: fallbackCurrency)
    }
}

// MARK: - Extensions

extension CharacterSet {
    static let whitespacesAndQuotes = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\""))
}
