import XCTest
@testable import MManger

final class BankStatementPDFParserTests: XCTestCase {
    func testParsesStatementLinesAndClassifiesKnownMerchants() {
        let text = """
        Transaction Date Description Cr/Dr Amount in AED
        10/06/2026 CAREEM HALA RIDE DUBAI ARE DR 58.00
        10/06/2026 Amazon.ae DR 265.90
        10/06/2026 5% CASHBACK - GROCERY MAY-26 CR 208.21
        09/06/2026 AGODA.COM DR 1,161.00
        """
        let rules = [
            MerchantRule(pattern: "CAREEM HALA", categoryName: "Transportation", subcategoryName: "Taxi", sampleCount: 10),
            MerchantRule(pattern: "AGODA", categoryName: "Travel", sampleCount: 3)
        ]

        let rows = BankStatementPDFParser().parseText(
            text,
            ruleSnapshots: rules.map(MerchantRuleSnapshot.init),
            existingSnapshots: []
        )

        XCTAssertEqual(rows.count, 4)
        XCTAssertEqual(rows[0].suggestedCategory, "Transportation")
        XCTAssertEqual(rows[0].suggestedSubcategory, "Taxi")
        XCTAssertEqual(rows[2].kind, .income)
        XCTAssertTrue(rows[2].isReviewOnly)
        XCTAssertFalse(rows[2].isSelected)
        XCTAssertEqual(rows[3].amount, Decimal(1161))
        XCTAssertEqual(rows[3].suggestedCategory, "Travel")
    }

    func testStrictStatementParserInfersCurrencyFromHeader() {
        let text = """
        Transaction Date Description Cr/Dr Amount in USD
        10/06/2026 Coffee Shop DR 12.50
        """

        let rows = BankStatementPDFParser().parseText(
            text,
            ruleSnapshots: [],
            existingSnapshots: []
        )

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].currency, "USD")
    }

    func testDuplicateDetectionUsesAccountDateAmountAndMerchant() throws {
        let date = try XCTUnwrap(statementDate("10/06/2026"))
        let existing = FinanceTransaction(
            date: date,
            kind: .expense,
            amount: Decimal(58),
            merchant: "CAREEM HALA RIDE",
            normalizedMerchant: "CAREEM HALA RIDE",
            accountName: SeedStore.defaultImportAccountName
        )

        XCTAssertTrue(
            DuplicateDetector.isDuplicate(
                accountName: SeedStore.defaultImportAccountName,
                date: date,
                amount: Decimal(58),
                normalizedMerchant: "CAREEM HALA RIDE",
                existingTransactions: [existing]
            )
        )
        XCTAssertFalse(
            DuplicateDetector.isDuplicate(
                accountName: "Cash",
                date: date,
                amount: Decimal(58),
                normalizedMerchant: "CAREEM HALA RIDE",
                existingTransactions: [existing]
            )
        )
    }

    @MainActor
    func testProvidedStatementPDFWhenPathIsAvailable() throws {
        guard let path = ProcessInfo.processInfo.environment["BANK_STATEMENT_PDF_PATH"], !path.isEmpty else {
            throw XCTSkip("Set BANK_STATEMENT_PDF_PATH to validate the full bank PDF fixture.")
        }
        let text = try BankStatementPDFParser.extractText(from: URL(fileURLWithPath: path))
        let rows = BankStatementPDFParser().parseText(text, ruleSnapshots: [], existingSnapshots: [])
        XCTAssertEqual(rows.count, 1333)
        XCTAssertEqual(rows.first?.description, "Amazon.ae")
    }

    func testPlainTextImportRejectsPageNumbersAndKeepsValidTransactions() throws {
        let text = """
        10/06/2026 CAREEM HALA RIDE DUBAI ARE DR 58.00
        5
        12
        Page 3 of 12
        09/06/2026 AGODA.COM DR 1,161.00
        """

        let rows = try UniversalImportParser().parseText(
            text,
            format: .pdf,
            ruleSnapshots: [],
            existingSnapshots: [],
            accountName: SeedStore.defaultImportAccountName
        )

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].description, "CAREEM HALA RIDE DUBAI ARE")
        XCTAssertEqual(rows[1].description, "AGODA.COM")
    }

    func testPlainTextImportRejectsStatementMetadataAndPaginationRows() throws {
        let text = """
        Statement Date 10/06/2026
        Statement Period 01/06/2026 - 10/06/2026
        Page 1 of 12
        Page 2 / 12
        10/06/2026 CAREEM HALA RIDE DUBAI ARE DR 58.00
        """

        let rows = try UniversalImportParser().parseText(
            text,
            format: .pdf,
            ruleSnapshots: [],
            existingSnapshots: [],
            accountName: SeedStore.defaultImportAccountName
        )

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.description, "CAREEM HALA RIDE DUBAI ARE")
        XCTAssertEqual(rows.first?.amount, Decimal(58))
    }

    func testPlainTextPDFImportUsesFallbackCurrencyWhenStatementOmitsCurrency() throws {
        let text = """
        10/06/2026 CAREEM HALA RIDE DUBAI ARE DR 58.00
        """

        let rows = try UniversalImportParser().parseText(
            text,
            format: .pdf,
            ruleSnapshots: [],
            existingSnapshots: [],
            accountName: SeedStore.defaultImportAccountName,
            fallbackCurrency: "AED"
        )

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.currency, "AED")
    }

    func testPastedMessagesAllowDatelessRows() throws {
        let text = "AED 58.00 spent at CAREEM HALA RIDE"

        let rows = try UniversalImportParser().parsePastedMessages(
            text,
            ruleSnapshots: [],
            existingSnapshots: [],
            accountName: SeedStore.defaultImportAccountName
        )

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].amount, Decimal(58))
        XCTAssertEqual(rows[0].normalizedMerchant, "CAREEM HALA RIDE")
    }

    func testResolvedCurrencyFallsBackWhenBlank() {
        XCTAssertEqual(AppFormatters.resolvedCurrency("", fallback: "EUR"), "EUR")
        XCTAssertEqual(AppFormatters.resolvedCurrency(" usd "), "USD")
    }

    func testImportSaveDraftUsesStableValueSnapshot() throws {
        let date = try XCTUnwrap(statementDate("10/06/2026"))
        let row = ParsedBankTransaction(
            date: date,
            description: "  Grocery Market  ",
            normalizedMerchant: "GROCERY MARKET",
            kind: .expense,
            amount: Decimal(186.40),
            currency: "  ",
            suggestedCategory: "Food",
            suggestedSubcategory: "Groceries",
            confidence: 0.92,
            isSelected: true,
            isDuplicate: false
        )

        let draft = ImportSaveDraft(row: row, accountName: "Daily Card", fallbackCurrency: "AED")

        XCTAssertEqual(draft.merchant, "Grocery Market")
        XCTAssertEqual(draft.currency, "AED")
        XCTAssertEqual(draft.accountName, "Daily Card")
        XCTAssertEqual(draft.normalizedMerchant, "GROCERY MARKET")
    }

    private func statementDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.date(from: value)
    }
}
