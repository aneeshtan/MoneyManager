import Foundation
import PDFKit

enum ADCBPDFParserError: Error {
    case unreadablePDF
}

enum ImportFormat {
    case pdf
    case csv
    case plainText
}

struct ADCBPDFParser {
    private let transactionPattern = #"^(\d{2}/\d{2}/\d{4})\s+(.+?)\s+(CR|DR)\s+([\d,]+(?:\.\d+)?)$"#
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    /// Cached, thread-safe compiled regex used for ADCB statement lines.
    private static let statementRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"^(\d{2}/\d{2}/\d{4})\s+(.+?)\s+(CR|DR)\s+([\d,]+(?:\.\d+)?)$"#)
    }()

    /// Extracts searchable text from a PDF. Must be called on the main actor because PDFKit is not thread-safe.
    static func extractText(from url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw ADCBPDFParserError.unreadablePDF
        }
        var pieces: [String] = []
        pieces.reserveCapacity(document.pageCount)
        for index in 0..<document.pageCount {
            if let pageText = document.page(at: index)?.string {
                pieces.append(pageText)
            }
        }
        return pieces.joined(separator: "\n")
    }

    func parsePDF(at url: URL, rules: [MerchantRule], existingTransactions: [FinanceTransaction], accountName: String = SeedStore.defaultImportAccountName, fileName: String? = nil) throws -> [ParsedBankTransaction] {
        try parsePDF(at: url, ruleSnapshots: rules.map(MerchantRuleSnapshot.init), existingSnapshots: existingTransactions.map(TransactionSnapshot.init), accountName: accountName)
    }

    /// Off-main-safe parser entry point using value-type snapshots.
    func parsePDF(at url: URL, ruleSnapshots: [MerchantRuleSnapshot], existingSnapshots: [TransactionSnapshot], accountName: String = SeedStore.defaultImportAccountName) throws -> [ParsedBankTransaction] {
        let text = try Self.extractText(from: url)
        return parseText(text, ruleSnapshots: ruleSnapshots, existingSnapshots: existingSnapshots, accountName: accountName)
    }

    func parseText(_ text: String, rules: [MerchantRule], existingTransactions: [FinanceTransaction], accountName: String = SeedStore.defaultImportAccountName) -> [ParsedBankTransaction] {
        parseText(text, ruleSnapshots: rules.map(MerchantRuleSnapshot.init), existingSnapshots: existingTransactions.map(TransactionSnapshot.init), accountName: accountName)
    }

    /// Off-main-safe text parser using value-type snapshots.
    func parseText(_ text: String, ruleSnapshots: [MerchantRuleSnapshot], existingSnapshots: [TransactionSnapshot], accountName: String = SeedStore.defaultImportAccountName) -> [ParsedBankTransaction] {
        guard let regex = Self.statementRegex else { return [] }
        let duplicateLookup = DuplicateTransactionLookup(snapshots: existingSnapshots)
        let lines = text.components(separatedBy: .newlines)
        var rows: [ParsedBankTransaction] = []
        rows.reserveCapacity(lines.count / 4)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            guard let match = regex.firstMatch(in: trimmed, range: range), match.numberOfRanges == 5 else {
                continue
            }

            let dateText = capture(1, in: trimmed, match: match)
            let description = capture(2, in: trimmed, match: match)
            let direction = capture(3, in: trimmed, match: match)
            let amountText = capture(4, in: trimmed, match: match).replacingOccurrences(of: ",", with: "")
            guard let date = dateFormatter.date(from: dateText), let amount = Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX")) else {
                continue
            }

            let kind: TransactionKind = direction == "CR" ? .income : .expense
            let normalized = MerchantNormalizer.normalize(description)
            let suggestion = CategoryMatcher.match(merchant: normalized, ruleSnapshots: ruleSnapshots, fallbackKind: kind)
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
                currency: "AED",
                suggestedCategory: suggestion?.category,
                suggestedSubcategory: suggestion?.subcategory,
                confidence: suggestion?.confidence ?? 0,
                isSelected: true,
                isDuplicate: duplicate
            )
            if parsed.isReviewOnly || duplicate {
                parsed.isSelected = false
            }
            rows.append(parsed)
        }
        return rows
    }

    private func capture(_ index: Int, in line: String, match: NSTextCheckingResult) -> String {
        guard let range = Range(match.range(at: index), in: line) else {
            return ""
        }
        return String(line[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum DuplicateDetector {
    static func isDuplicate(accountName: String, date: Date, amount: Decimal, normalizedMerchant: String, existingTransactions: [FinanceTransaction]) -> Bool {
        DuplicateTransactionLookup(existingTransactions: existingTransactions)
            .contains(accountName: accountName, date: date, amount: amount, normalizedMerchant: normalizedMerchant)
    }
}

enum UniversalImportParserError: LocalizedError {
    case unreadableFile
    case unsupportedSpreadsheet
    case noTransactionsFound

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            "Could not read this file."
        case .unsupportedSpreadsheet:
            "Excel .xlsx files are not parsed directly yet. Export the sheet as CSV and import that file."
        case .noTransactionsFound:
            "No transaction rows were found. Try CSV, a searchable PDF, or paste bank SMS messages."
        }
    }
}

struct UniversalImportParser {
    func parseFile(
        at url: URL,
        rules: [MerchantRule],
        existingTransactions: [FinanceTransaction],
        accountName: String
    ) throws -> [ParsedBankTransaction] {
        try parseFile(
            at: url,
            ruleSnapshots: rules.map(MerchantRuleSnapshot.init),
            existingSnapshots: existingTransactions.map(TransactionSnapshot.init),
            accountName: accountName
        )
    }

    /// Off-main-safe entry point using value-type snapshots.
    func parseFile(
        at url: URL,
        ruleSnapshots: [MerchantRuleSnapshot],
        existingSnapshots: [TransactionSnapshot],
        accountName: String
    ) throws -> [ParsedBankTransaction] {
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            let text = try ADCBPDFParser.extractText(from: url)
            return try parseText(text, format: .pdf, ruleSnapshots: ruleSnapshots, existingSnapshots: existingSnapshots, accountName: accountName)
        }

        if ["xlsx", "xls"].contains(ext) {
            throw UniversalImportParserError.unsupportedSpreadsheet
        }

        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw UniversalImportParserError.unreadableFile
        }
        let format: ImportFormat = ext == "csv" ? .csv : .plainText
        return try parseText(text, format: format, ruleSnapshots: ruleSnapshots, existingSnapshots: existingSnapshots, accountName: accountName)
    }

    func parsePastedMessages(
        _ text: String,
        rules: [MerchantRule],
        existingTransactions: [FinanceTransaction],
        accountName: String
    ) throws -> [ParsedBankTransaction] {
        try parsePastedMessages(
            text,
            ruleSnapshots: rules.map(MerchantRuleSnapshot.init),
            existingSnapshots: existingTransactions.map(TransactionSnapshot.init),
            accountName: accountName
        )
    }

    /// Off-main-safe pasted-messages entry point.
    func parsePastedMessages(
        _ text: String,
        ruleSnapshots: [MerchantRuleSnapshot],
        existingSnapshots: [TransactionSnapshot],
        accountName: String
    ) throws -> [ParsedBankTransaction] {
        let rows = parsePlainText(text, ruleSnapshots: ruleSnapshots, existingSnapshots: existingSnapshots, accountName: accountName, requireDate: false)
        guard !rows.isEmpty else { throw UniversalImportParserError.noTransactionsFound }
        return rows
    }

    /// Off-main-safe text parser. Caller must extract PDF contents on the main actor (PDFKit is not thread-safe).
    func parseText(
        _ text: String,
        format: ImportFormat,
        ruleSnapshots: [MerchantRuleSnapshot],
        existingSnapshots: [TransactionSnapshot],
        accountName: String
    ) throws -> [ParsedBankTransaction] {
        switch format {
        case .pdf:
            let adcbRows = ADCBPDFParser().parseText(text, ruleSnapshots: ruleSnapshots, existingSnapshots: existingSnapshots, accountName: accountName)
            if !adcbRows.isEmpty {
                return adcbRows
            }
            let rows = parsePlainText(text, ruleSnapshots: ruleSnapshots, existingSnapshots: existingSnapshots, accountName: accountName, requireDate: true)
            guard !rows.isEmpty else { throw UniversalImportParserError.noTransactionsFound }
            return rows
        case .csv:
            let rows = parseCSV(text, ruleSnapshots: ruleSnapshots, existingSnapshots: existingSnapshots, accountName: accountName)
            guard !rows.isEmpty else { throw UniversalImportParserError.noTransactionsFound }
            return rows
        case .plainText:
            // For pasted messages, dates are sometimes omitted; for imported text files we require them.
            let rows = parsePlainText(text, ruleSnapshots: ruleSnapshots, existingSnapshots: existingSnapshots, accountName: accountName, requireDate: true)
            guard !rows.isEmpty else { throw UniversalImportParserError.noTransactionsFound }
            return rows
        }
    }

    private func parseCSV(
        _ text: String,
        rules: [MerchantRule],
        existingTransactions: [FinanceTransaction],
        accountName: String
    ) -> [ParsedBankTransaction] {
        parseCSV(text, ruleSnapshots: rules.map(MerchantRuleSnapshot.init), existingSnapshots: existingTransactions.map(TransactionSnapshot.init), accountName: accountName)
    }

    private func parseCSV(
        _ text: String,
        ruleSnapshots: [MerchantRuleSnapshot],
        existingSnapshots: [TransactionSnapshot],
        accountName: String
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
            let currency = firstValue(in: fields, keys: ["currency", "ccy"]) ?? "AED"
            let amountInfo = amountAndKind(from: fields)
            guard let amountInfo else { continue }
            parsed.append(
                makeParsed(
                    date: date,
                    description: merchant,
                    kind: amountInfo.kind,
                    amount: amountInfo.amount,
                    currency: currency,
                    accountName: accountName,
                    rules: ruleSnapshots,
                    duplicateLookup: duplicateLookup
                )
            )
        }
        return parsed
    }

    private func parsePlainText(
        _ text: String,
        rules: [MerchantRule],
        existingTransactions: [FinanceTransaction],
        accountName: String,
        requireDate: Bool = false
    ) -> [ParsedBankTransaction] {
        parsePlainText(text, ruleSnapshots: rules.map(MerchantRuleSnapshot.init), existingSnapshots: existingTransactions.map(TransactionSnapshot.init), accountName: accountName, requireDate: requireDate)
    }

    private func parsePlainText(
        _ text: String,
        ruleSnapshots: [MerchantRuleSnapshot],
        existingSnapshots: [TransactionSnapshot],
        accountName: String,
        requireDate: Bool
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
            if let parsed = parsePlainTextLine(line, rules: ruleSnapshots, duplicateLookup: duplicateLookup, accountName: accountName, requireDate: requireDate) {
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
        requireDate: Bool
    ) -> ParsedBankTransaction? {
        let cleaned = Self.whitespaceRegex.stringByReplacingMatches(
            in: line,
            range: NSRange(line.startIndex..<line.endIndex, in: line),
            withTemplate: " "
        )
        guard let amountMatch = firstMatch(Self.amountPattern, in: cleaned),
              let amount = Decimal(string: amountMatch.captures[1].replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }

        let lower = cleaned.lowercased()
        let kind: TransactionKind = lower.contains("credit") || lower.contains("credited") || lower.contains("refund") || lower.contains("received") || lower.contains("deposit")
            ? .income
            : .expense
        let currency = normalizedCurrency(amountMatch.captures[0].isEmpty ? amountMatch.captures[2] : amountMatch.captures[0])

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
            currency: normalizedCurrency(currency),
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

    // MARK: - Cached compiled regexes

    private static let whitespaceRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"\s+"#)
    }()

    private static let amountPattern = #"(?i)\b(AED|USD|EUR|GBP|SAR|QAR|KWD|OMR|BHD|INR|PKR|DH|DHS)?\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*(AED|USD|EUR|GBP|SAR|QAR|KWD|OMR|BHD|INR|PKR|DH|DHS)?\b"#

    private static let merchantPatterns: [NSRegularExpression] = {
        let patterns = [
            #"(?i)\bat\s+(.+?)(?:\s+on\s+\d|\s+for\s+(?:AED|USD|EUR|GBP|DH|DHS)?\s*[0-9]|$)"#,
            #"(?i)\bfrom\s+(.+?)(?:\s+on\s+\d|\s+for\s+(?:AED|USD|EUR|GBP|DH|DHS)?\s*[0-9]|$)"#,
            #"(?i)\bto\s+(.+?)(?:\s+on\s+\d|\s+for\s+(?:AED|USD|EUR|GBP|DH|DHS)?\s*[0-9]|$)"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    private static let dateFallbackPattern: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}-\d{1,2}-\d{1,2})"#)
    }()

    private func amountAndKind(from fields: [String: String]) -> (amount: Decimal, kind: TransactionKind)? {
        if let debit = decimal(firstValue(in: fields, keys: ["debit", "withdrawal", "paid out", "expense"])), debit > 0 {
            return (debit, .expense)
        }
        if let credit = decimal(firstValue(in: fields, keys: ["credit", "deposit", "paid in", "income"])), credit > 0 {
            return (credit, .income)
        }
        guard let amount = decimal(firstValue(in: fields, keys: ["amount", "value", "aed", "transaction amount"])) else {
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
    private func parseCSVLine(_ line: String) -> [String] {
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
            .replacingOccurrences(of: "AED", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: CharacterSet(charactersIn: " +"))
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }

    private func normalizedCurrency(_ value: String) -> String {
        let upper = value.uppercased()
        if upper == "DH" || upper == "DHS" || upper.isEmpty {
            return "AED"
        }
        return upper
    }

    private func firstMatch(_ pattern: String, in text: String) -> RegexMatch? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        return firstMatch(regex, in: text)
    }

    private func firstMatch(_ regex: NSRegularExpression, in text: String) -> RegexMatch? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        let captures = (1..<match.numberOfRanges).map { index -> String in
            guard let range = Range(match.range(at: index), in: text) else { return "" }
            return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return RegexMatch(captures: captures)
    }
}

private struct RegexMatch {
    var captures: [String]
}
