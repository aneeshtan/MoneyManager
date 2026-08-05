import Foundation

struct ParsedReceipt {
    var merchantName: String
    var totalAmount: Decimal
    var taxAmount: Decimal?
    var subtotal: Decimal?
    var currency: String
    var receiptDate: Date?
    var lineItems: [ReceiptLineItem]
    var confidence: Double
    var rawText: String
}

enum ReceiptParserError: LocalizedError {
    case noAmountFound
    case invalidReceipt

    var errorDescription: String? {
        switch self {
        case .noAmountFound:
            "Could not find a total amount in the receipt."
        case .invalidReceipt:
            "The extracted text doesn't appear to be a valid receipt."
        }
    }
}

struct ReceiptParser {
    private static let amountPattern = try? NSRegularExpression(pattern: #"(?:Total|Grand Total|Amount|Price|Balance Due|Subtotal)[\s:]*([A-Z]{3})?\s*([0-9]{1,3}(?:[,][0-9]{3})*(?:\.[0-9]{1,2})?)"#, options: [.caseInsensitive])

    private static let datePatterns = [
        try? NSRegularExpression(pattern: #"(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})"#),
        try? NSRegularExpression(pattern: #"(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+(\d{1,2}),?\s+(\d{4})"#, options: .caseInsensitive)
    ].compactMap { $0 }

    private static let currencyCodePattern = try? NSRegularExpression(pattern: #"(USD|EUR|GBP|AED|INR|JPY|CAD|AUD|CHF|CNY|SEK|NZD|MXN|SGD|HKD|NOK|KRW|TRY|BRL|ZAR|SAR|QAR|KWD|BHD|OMR|EGP|PHP|THB|IDR|MYR|IRR|IQD)"#, options: .caseInsensitive)

    private static let merchantPatterns = [
        try? NSRegularExpression(pattern: #"(?:Store|Restaurant|Shop|Merchant|Vendor|Business|Company|Name)[\s:]*([A-Za-z0-9\s&'-]+?)(?:\n|$)"#, options: .caseInsensitive),
        try? NSRegularExpression(pattern: #"^([A-Za-z0-9\s&'-]{3,50})(?:\n|$)"#)
    ].compactMap { $0 }

    private static let taxPattern = try? NSRegularExpression(pattern: #"(?:Tax|VAT|GST|Sales Tax)[\s:]*([A-Z]{3})?\s*([0-9]{1,3}(?:[,][0-9]{3})*(?:\.[0-9]{1,2})?)"#, options: .caseInsensitive)

    /// Parse OCR text and extract structured receipt data.
    /// Safe to call from any thread.
    func parse(_ ocrText: String, fallbackCurrency: String = "USD", ruleSnapshots: [MerchantRuleSnapshot] = []) throws -> ParsedReceipt {
        guard !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReceiptParserError.invalidReceipt
        }

        // Extract currency
        let currency = extractCurrency(from: ocrText) ?? fallbackCurrency.uppercased()

        // Extract total amount (highest confidence extraction)
        guard let (totalAmount, totalConfidence) = extractTotalAmount(from: ocrText, currency: currency) else {
            throw ReceiptParserError.noAmountFound
        }

        // Extract merchant name
        let merchantName = extractMerchantName(from: ocrText)

        // Extract date
        let receiptDate = extractDate(from: ocrText)

        // Extract tax
        let (taxAmount, _) = extractTaxAmount(from: ocrText, currency: currency)

        // Calculate subtotal
        let subtotal: Decimal?
        if let tax = taxAmount {
            subtotal = totalAmount - tax
        } else {
            subtotal = nil
        }

        // Extract line items (basic extraction)
        let lineItems = extractLineItems(from: ocrText, currency: currency)

        // Calculate overall confidence
        let baseConfidence = totalConfidence
        let merchantConfidence = merchantName.isEmpty ? 0.5 : 0.9
        let dateConfidence = receiptDate != nil ? 0.9 : 0.6
        let overallConfidence = (baseConfidence + merchantConfidence + dateConfidence) / 3.0

        return ParsedReceipt(
            merchantName: merchantName,
            totalAmount: totalAmount,
            taxAmount: taxAmount,
            subtotal: subtotal,
            currency: currency,
            receiptDate: receiptDate,
            lineItems: lineItems,
            confidence: overallConfidence,
            rawText: ocrText
        )
    }

    // MARK: - Extraction Methods

    private func extractTotalAmount(from text: String, currency: String) -> (Decimal, Double)? {
        guard let pattern = Self.amountPattern else { return nil }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = pattern.matches(in: text, range: range)

        for match in matches.reversed() {
            guard let amountRange = Range(match.range(at: 2), in: text) else { continue }
            let amountText = String(text[amountRange]).replacingOccurrences(of: ",", with: "")

            if let amount = Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX")) {
                // Assume matches closer to the end of the text are more likely to be the total
                let position = Double(match.range.location) / Double(range.length)
                let confidence = 0.7 + (position * 0.3) // Boost confidence for later matches
                return (amount, confidence)
            }
        }

        return nil
    }

    private func extractTaxAmount(from text: String, currency: String) -> (Decimal?, Double) {
        guard let pattern = Self.taxPattern else { return (nil, 0) }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = pattern.firstMatch(in: text, range: range) else {
            return (nil, 0)
        }

        guard let amountRange = Range(match.range(at: 2), in: text) else {
            return (nil, 0)
        }

        let amountText = String(text[amountRange]).replacingOccurrences(of: ",", with: "")
        if let amount = Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX")) {
            return (amount, 0.85)
        }

        return (nil, 0)
    }

    private func extractCurrency(from text: String) -> String? {
        guard let pattern = Self.currencyCodePattern else { return nil }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = pattern.firstMatch(in: text, range: range) else {
            return nil
        }

        guard let currencyRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[currencyRange]).uppercased()
    }

    private func extractMerchantName(from text: String) -> String {
        // Try merchant patterns
        for pattern in Self.merchantPatterns {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = pattern.firstMatch(in: text, range: range) else { continue }
            guard let nameRange = Range(match.range(at: 1), in: text) else { continue }

            let name = String(text[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty && name.count < 100 {
                return name
            }
        }

        // Fallback: first line of text
        let lines = text.components(separatedBy: .newlines)
        if let firstNonEmpty = lines.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return firstNonEmpty.trimmingCharacters(in: .whitespacesAndNewlines).prefix(50).trimmingCharacters(in: .punctuationCharacters)
        }

        return "Receipt"
    }

    private func extractDate(from text: String) -> Date? {
        for pattern in Self.datePatterns {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = pattern.firstMatch(in: text, range: range) else {
                continue
            }

            if pattern == Self.datePatterns.first {
                // Numeric date: MM/DD/YYYY or DD/MM/YYYY
                guard let dayRange = Range(match.range(at: 1), in: text),
                      let monthRange = Range(match.range(at: 2), in: text),
                      let yearRange = Range(match.range(at: 3), in: text) else { continue }

                let dayStr = String(text[dayRange])
                let monthStr = String(text[monthRange])
                let yearStr = String(text[yearRange])

                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)

                // Try DD/MM/YYYY first
                formatter.dateFormat = "dd/MM/yyyy"
                if let date = formatter.date(from: "\(dayStr)/\(monthStr)/\(yearStr)") {
                    return date
                }

                // Try MM/DD/YYYY
                formatter.dateFormat = "MM/dd/yyyy"
                if let date = formatter.date(from: "\(dayStr)/\(monthStr)/\(yearStr)") {
                    return date
                }
            }
        }

        return nil
    }

    private func extractLineItems(from text: String, currency: String) -> [ReceiptLineItem] {
        var lineItems: [ReceiptLineItem] = []

        // Simple line item extraction: look for patterns like "Item Name ... Amount"
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip common non-item lines
            if trimmed.isEmpty || trimmed.lowercased().contains("total") ||
                trimmed.lowercased().contains("tax") || trimmed.lowercased().contains("subtotal") {
                continue
            }

            // Look for price at end of line
            if let amountPattern = try? NSRegularExpression(pattern: #"([0-9]{1,3}(?:[,][0-9]{3})*(?:\.[0-9]{1,2})?)$"#) {
                let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
                guard let match = amountPattern.firstMatch(in: trimmed, range: range),
                      let amountRange = Range(match.range(at: 1), in: trimmed) else { continue }

                let amountText = String(trimmed[amountRange]).replacingOccurrences(of: ",", with: "")
                guard let amount = Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX")) else { continue }

                // Extract item description (everything before amount)
                let endIndex = amountRange.lowerBound
                let description = String(trimmed[trimmed.startIndex..<endIndex])
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

                if !description.isEmpty && description.count < 100 {
                    let item = ReceiptLineItem(description: description, unitPrice: amount, quantity: 1, totalPrice: amount)
                    lineItems.append(item)
                }
            }
        }

        return Array(lineItems.prefix(20)) // Limit to first 20 items
    }
}
