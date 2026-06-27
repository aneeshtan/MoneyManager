import Foundation
import PDFKit

enum BankStatementPDFParserError: Error {
    case unreadablePDF
}

enum ImportFormat {
    case pdf
    case csv
    case plainText
}

struct BankStatementPDFParser {
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    private static let statementRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"^(\d{2}/\d{2}/\d{4})\s+(.+?)\s+(CR|DR)\s+([\d,]+(?:\.\d+)?)$"#)
    }()

    private static let currencyHeaderRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"(?i)\bAmount\s+in\s+([A-Z]{3})\b"#)
    }()

    /// Extract PDF text. MUST be called on the main thread because PDFKit is not thread-safe.
    @MainActor
    static func extractText(from url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw BankStatementPDFParserError.unreadablePDF
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

    /// Parse strict date-description-direction-amount statement lines. Safe to call on any thread.
    func parseText(
        _ text: String,
        ruleSnapshots: [MerchantRuleSnapshot],
        existingSnapshots: [TransactionSnapshot],
        accountName: String = SeedStore.defaultImportAccountName
    ) -> [ParsedBankTransaction] {
        guard let regex = Self.statementRegex else { return [] }
        let duplicateLookup = DuplicateTransactionLookup(snapshots: existingSnapshots)
        let currency = detectedCurrency(in: text)
        let lines = text.components(separatedBy: .newlines)
        var rows: [ParsedBankTransaction] = []
        rows.reserveCapacity(min(lines.count / 4, 2000))

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            guard let match = regex.firstMatch(in: trimmed, range: range), match.numberOfRanges == 5 else { continue }

            let dateText = capture(1, in: trimmed, match: match)
            let description = capture(2, in: trimmed, match: match)
            let direction = capture(3, in: trimmed, match: match)
            let amountText = capture(4, in: trimmed, match: match).replacingOccurrences(of: ",", with: "")
            guard let date = dateFormatter.date(from: dateText),
                  let amount = Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX")) else { continue }

            let kind: TransactionKind = direction == "CR" ? .income : .expense
            let normalized = MerchantNormalizer.normalize(description)
            let suggestion = CategoryMatcher.match(merchant: normalized, ruleSnapshots: ruleSnapshots, fallbackKind: kind)
            let duplicate = duplicateLookup.contains(accountName: accountName, date: date, amount: amount, normalizedMerchant: normalized)

            var parsed = ParsedBankTransaction(
                date: date,
                description: description,
                normalizedMerchant: normalized,
                kind: suggestion?.kind ?? kind,
                amount: amount,
                currency: currency,
                suggestedCategory: suggestion?.category,
                suggestedSubcategory: suggestion?.subcategory,
                confidence: suggestion?.confidence ?? 0,
                isSelected: !duplicate,
                isDuplicate: duplicate
            )
            if parsed.isReviewOnly { parsed.isSelected = false }
            rows.append(parsed)
        }
        return rows
    }

    private func detectedCurrency(in text: String) -> String {
        guard let regex = Self.currencyHeaderRegex else { return "USD" }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return "USD" }
        return capture(1, in: text, match: match).uppercased()
    }

    private func capture(_ index: Int, in line: String, match: NSTextCheckingResult) -> String {
        guard let range = Range(match.range(at: index), in: line) else { return "" }
        return String(line[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum DuplicateDetector {
    static func isDuplicate(accountName: String, date: Date, amount: Decimal, normalizedMerchant: String, existingTransactions: [FinanceTransaction]) -> Bool {
        DuplicateTransactionLookup(existingTransactions: existingTransactions)
            .contains(accountName: accountName, date: date, amount: amount, normalizedMerchant: normalizedMerchant)
    }
}

// UniversalImportParser is handled by BankingIntegrationService.

struct RegexMatch {
    var captures: [String]
}
