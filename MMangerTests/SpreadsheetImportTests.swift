import XCTest
import SwiftData
@testable import MManger

final class SpreadsheetImportTests: XCTestCase {

    // MARK: - Workbook reading

    func testReadsWorksheetRowsAndSharedStrings() throws {
        let url = try makeWorkbook(
            sharedStrings: ["Period", "Category", "Amount", "Food"],
            sheetRows: [
                ["A1": .shared(0), "B1": .shared(1), "C1": .shared(2)],
                ["A2": .number("45000"), "B2": .shared(3), "C2": .number("12.5")]
            ]
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let rows = try XLSXParser.firstSheetRows(from: url)

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0], ["Period", "Category", "Amount"])
        XCTAssertEqual(rows[1], ["45000", "Food", "12.5"])
    }

    /// Exporters omit empty cells entirely, so a reader that appends in document order
    /// shifts every later column left. This is the exact shape of a Money Manager export
    /// where `Subcategory` is blank.
    func testPadsOmittedCellsSoColumnsStayAligned() throws {
        let url = try makeWorkbook(
            sharedStrings: ["Travel", "AED"],
            sheetRows: [
                ["A1": .number("46169"), "C1": .shared(0), "E1": .shared(1)]
            ]
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let rows = try XLSXParser.firstSheetRows(from: url)

        XCTAssertEqual(rows[0], ["46169", "", "Travel", "", "AED"])
    }

    func testRejectsNonWorkbookFile() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "not-a-workbook-\(UUID().uuidString).xlsx")
        try Data("plain text, definitely not a zip".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try XLSXParser.firstSheetRows(from: url))
    }

    func testExcelSerialConvertsToDate() throws {
        let date = try XCTUnwrap(XLSXParser.date(fromSerial: 46_169.53472222222))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let parts = calendar.dateComponents([.year, .month, .day], from: date)

        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 5)
        XCTAssertEqual(parts.day, 27)

        // Below the 1900 leap-year bug boundary the serial is not a trustworthy date.
        XCTAssertNil(XLSXParser.date(fromSerial: 12))
    }

    // MARK: - Row mapping

    func testKeepsCategoryAndAccountColumnsFromTheFile() {
        let table = SpreadsheetImportParser.table(fromCSV: """
        Period,Accounts,Category,Subcategory,Note,Income/Expense,Amount,Currency
        2026-05-27,ADCB 365,Travel,Flights,AGODA BERLIN DE,Exp.,2895.04,AED
        2026-05-26,ADIB Current,Salary,,MONTHLY PAY,Income,23675,AED
        """)

        let rows = SpreadsheetImportParser.parse(
            table,
            ruleSnapshots: [],
            existingSnapshots: [],
            defaultAccountName: "Credit Card",
            fallbackCurrency: "USD"
        )

        XCTAssertEqual(rows.count, 2)

        XCTAssertEqual(rows[0].suggestedCategory, "Travel")
        XCTAssertEqual(rows[0].suggestedSubcategory, "Flights")
        XCTAssertEqual(rows[0].accountName, "ADCB 365")
        XCTAssertEqual(rows[0].currency, "AED")
        XCTAssertEqual(rows[0].kind, .expense)
        XCTAssertTrue(rows[0].isPreCategorized)

        XCTAssertEqual(rows[1].kind, .income)
        XCTAssertEqual(rows[1].accountName, "ADIB Current")
        XCTAssertNil(rows[1].suggestedSubcategory)
    }

    /// The file's own category must win over a rule that says otherwise, otherwise
    /// importing an already-categorized export would silently relabel it.
    func testFileCategoryOverridesMatchingRule() {
        let rule = MerchantRule(
            pattern: "AGODA",
            categoryName: "Entertainment",
            kind: .expense,
            confidence: 0.95,
            sampleCount: 40
        )
        let table = SpreadsheetImportParser.table(fromCSV: """
        Date,Category,Note,Amount
        2026-05-27,Travel,AGODA BERLIN DE,2895.04
        """)

        let rows = SpreadsheetImportParser.parse(
            table,
            ruleSnapshots: [MerchantRuleSnapshot(rule)],
            existingSnapshots: [],
            defaultAccountName: "Credit Card",
            fallbackCurrency: "AED"
        )

        XCTAssertEqual(rows.first?.suggestedCategory, "Travel")
        XCTAssertEqual(rows.first?.confidence, 1)
    }

    func testFallsBackToRulesWhenFileHasNoCategoryColumn() {
        let table = SpreadsheetImportParser.table(fromCSV: """
        Date,Description,Amount
        2026-05-27,CAREEM HALA RIDE DUBAI AE,22.00
        """)

        let rows = SpreadsheetImportParser.parse(
            table,
            ruleSnapshots: [],
            existingSnapshots: [],
            defaultAccountName: "Credit Card",
            fallbackCurrency: "AED"
        )

        XCTAssertEqual(rows.first?.suggestedCategory, "Transportation")
        XCTAssertFalse(try XCTUnwrap(rows.first).isPreCategorized)
        XCTAssertNil(rows.first?.accountName, "no account column means the picked account is used")
    }

    func testSkipsBannerRowsAboveTheHeader() {
        let table = SpreadsheetImportParser.table(fromCSV: """
        My Budget Export
        Generated 2026-08-24
        ,,
        Date,Category,Note,Amount
        2026-05-27,Food,UNION COOP,521.93
        """)

        XCTAssertTrue(SpreadsheetImportParser.isSupported(table))
        XCTAssertEqual(table.headers, ["date", "category", "note", "amount"])
        XCTAssertEqual(table.rows.count, 1)
    }

    func testUsesDebitAndCreditColumnsWhenPresent() {
        let table = SpreadsheetImportParser.table(fromCSV: """
        Date,Description,Debit,Credit
        2026-05-27,GROCERIES,120.00,
        2026-05-28,REFUND,,45.00
        """)

        let rows = SpreadsheetImportParser.parse(
            table,
            ruleSnapshots: [],
            existingSnapshots: [],
            defaultAccountName: "Credit Card",
            fallbackCurrency: "AED"
        )

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].kind, .expense)
        XCTAssertEqual(rows[0].amount, Decimal(string: "120.00"))
        XCTAssertEqual(rows[1].kind, .income)
        XCTAssertEqual(rows[1].amount, Decimal(string: "45.00"))
    }

    // MARK: - Normalization

    /// Some exports strip every space out of the narration; without unspaced handling
    /// each row keeps its own running balance and normalizes to a unique merchant.
    func testNormalizesSpaceStrippedBankNarration() {
        XCTAssertEqual(
            MerchantNormalizer.normalize("CrCardXXX6201usedUNIONCOOPDUBAIAEAvlCrlimitisAED3173743"),
            "UNIONCOOP"
        )
        XCTAssertEqual(
            MerchantNormalizer.normalize("CrCardXXX6201usedALMAYASUPERMARKETDUBAIAEAvlCrlimitisAED2000"),
            "ALMAYASUPERMARKET"
        )
    }

    func testSpaceStrippedMerchantsStillHitBuiltInDictionary() {
        let suggestion = CategoryMatcher.match(
            merchant: "CrCardXXX6201usedUNIONCOOPDUBAIAEAvlCrlimitisAED3173743",
            rules: [],
            fallbackKind: .expense
        )
        XCTAssertEqual(suggestion?.category, "Food")
        XCTAssertEqual(suggestion?.subcategory, "Groceries")
    }

    /// Duplicate detection re-normalizes stored merchants, so a second pass has to be a
    /// no-op. Stripping trailing reference digits can expose a location suffix, which is
    /// the case that used to diverge.
    func testNormalizationIsIdempotent() {
        let samples = [
            "CrCardXXX6201usedTHINCRUSTRESTAURANDubaiAEAvlCrlimitisAED3118002",
            "STOREUAE1234",
            "transferredviaADCBPersonalInternetBankingMobileAppaccnoXXX920001May202026AvlbalAED57",
            "NATIONAL TAXI DUBAI ARE",
            "CAREEM HALA RIDE Dubai-AE"
        ]
        for sample in samples {
            let once = MerchantNormalizer.normalize(sample)
            XCTAssertEqual(MerchantNormalizer.normalize(once), once, "not idempotent: \(sample)")
        }
    }

    func testShortPatternsDoNotMatchEverything() {
        let rule = MerchantRule(pattern: "AE", categoryName: "Bogus", kind: .expense, sampleCount: 99)
        let suggestion = CategoryMatcher.match(
            merchant: "SOME UNRELATED MERCHANT",
            rules: [rule],
            fallbackKind: .expense
        )
        XCTAssertNotEqual(suggestion?.category, "Bogus")
    }

    // MARK: - Learning

    func testLearnsDominantCategoryForAMixedMerchant() {
        let transactions = (0..<8).map { index in
            makeTransaction(
                merchant: "ALLDAYMARKETSUPER",
                category: index < 6 ? "Food" : "Gift",
                subcategory: index < 6 ? "Groceries" : nil
            )
        }

        let learned = SmartCategorizationService.learnRules(from: transactions, existingRules: [])

        XCTAssertEqual(learned.count, 1, "a mixed merchant should yield one rule, not competing ones")
        XCTAssertEqual(learned.first?.categoryName, "Food")
        XCTAssertEqual(learned.first?.subcategoryName, "Groceries")
        XCTAssertEqual(learned.first?.sampleCount, 6)
    }

    func testSkipsMerchantsWithNoDominantCategory() {
        let transactions = ["Food", "Gift", "Travel", "Household"].map {
            makeTransaction(merchant: "AMBIGUOUS", category: $0, subcategory: nil)
        }

        let learned = SmartCategorizationService.learnRules(from: transactions, existingRules: [])

        XCTAssertTrue(learned.isEmpty)
    }

    func testDoesNotOverrideAUserAuthoredRule() {
        let existing = MerchantRule(pattern: "TIARA", categoryName: "Food", kind: .expense)
        let transactions = (0..<4).map { _ in
            makeTransaction(merchant: "TIARA", category: "Entertainment", subcategory: nil)
        }

        let learned = SmartCategorizationService.learnRules(from: transactions, existingRules: [existing])

        XCTAssertTrue(learned.isEmpty)
    }

    // MARK: - Helpers

    private func makeTransaction(merchant: String, category: String, subcategory: String?) -> FinanceTransaction {
        FinanceTransaction(
            date: .now,
            kind: .expense,
            amount: 10,
            merchant: merchant,
            normalizedMerchant: MerchantNormalizer.normalize(merchant),
            accountName: "ADCB 365",
            categoryName: category,
            subcategoryName: subcategory
        )
    }

    private enum Cell {
        case shared(Int)
        case number(String)
    }

    /// Writes a real (uncompressed) .xlsx so the ZIP reader is exercised end to end
    /// rather than stubbed.
    private func makeWorkbook(sharedStrings: [String], sheetRows: [[String: Cell]]) throws -> URL {
        let stringsXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
        \(sharedStrings.map { "<si><t>\($0)</t></si>" }.joined())\
        </sst>
        """

        let rowsXML = sheetRows.enumerated().map { offset, cells in
            let cellXML = cells.sorted { $0.key < $1.key }.map { reference, cell -> String in
                switch cell {
                case .shared(let index): "<c r=\"\(reference)\" t=\"s\"><v>\(index)</v></c>"
                case .number(let value): "<c r=\"\(reference)\"><v>\(value)</v></c>"
                }
            }.joined()
            return "<row r=\"\(offset + 1)\">\(cellXML)</row>"
        }.joined()

        let sheetXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>\(rowsXML)</sheetData></worksheet>
        """

        let archive = makeStoredZip(entries: [
            ("xl/sharedStrings.xml", Data(stringsXML.utf8)),
            ("xl/worksheets/sheet1.xml", Data(sheetXML.utf8))
        ])

        let url = FileManager.default.temporaryDirectory.appending(path: "test-\(UUID().uuidString).xlsx")
        try archive.write(to: url)
        return url
    }

    private func makeStoredZip(entries: [(String, Data)]) -> Data {
        var archive = Data()
        var directory = Data()

        for (name, payload) in entries {
            let nameBytes = Data(name.utf8)
            let offset = archive.count

            archive.append(uint32: 0x0403_4b50)
            archive.append(uint16: 20)
            archive.append(uint16: 0)
            archive.append(uint16: 0)  // stored
            archive.append(uint16: 0)
            archive.append(uint16: 0)
            archive.append(uint32: 0)  // CRC is not verified by the reader
            archive.append(uint32: UInt32(payload.count))
            archive.append(uint32: UInt32(payload.count))
            archive.append(uint16: UInt16(nameBytes.count))
            archive.append(uint16: 0)
            archive.append(nameBytes)
            archive.append(payload)

            directory.append(uint32: 0x0201_4b50)
            directory.append(uint16: 20)
            directory.append(uint16: 20)
            directory.append(uint16: 0)
            directory.append(uint16: 0)
            directory.append(uint16: 0)
            directory.append(uint16: 0)
            directory.append(uint32: 0)
            directory.append(uint32: UInt32(payload.count))
            directory.append(uint32: UInt32(payload.count))
            directory.append(uint16: UInt16(nameBytes.count))
            directory.append(uint16: 0)
            directory.append(uint16: 0)
            directory.append(uint16: 0)
            directory.append(uint16: 0)
            directory.append(uint32: 0)
            directory.append(uint32: UInt32(offset))
            directory.append(nameBytes)
        }

        let directoryOffset = archive.count
        archive.append(directory)
        archive.append(uint32: 0x0605_4b50)
        archive.append(uint16: 0)
        archive.append(uint16: 0)
        archive.append(uint16: UInt16(entries.count))
        archive.append(uint16: UInt16(entries.count))
        archive.append(uint32: UInt32(directory.count))
        archive.append(uint32: UInt32(directoryOffset))
        archive.append(uint16: 0)
        return archive
    }
}

private extension Data {
    mutating func append(uint16 value: UInt16) {
        append(contentsOf: [UInt8(value & 0xff), UInt8((value >> 8) & 0xff)])
    }

    mutating func append(uint32 value: UInt32) {
        append(contentsOf: [
            UInt8(value & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 24) & 0xff)
        ])
    }
}

// MARK: - End-to-end persistence

final class SpreadsheetImportPersistenceTests: XCTestCase {

    /// Walks a categorized export all the way through the real save path: parse -> draft
    /// -> SwiftData insert -> learn rules, then checks the learned rules actually
    /// categorize a later statement-style import that carries no categories of its own.
    @MainActor
    func testImportedFileTeachesCategorizationForLaterImports() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let table = SpreadsheetImportParser.table(fromCSV: """
        Period,Accounts,Category,Subcategory,Note,Income/Expense,Amount,Currency
        2026-05-01,ADCB 365,Food,Groceries,CrCardXXX6201usedUNIONCOOPDUBAIAEAvlCrlimitisAED100,Exp.,120.00,AED
        2026-05-02,ADCB 365,Food,Groceries,CrCardXXX6201usedUNIONCOOPDUBAIAEAvlCrlimitisAED200,Exp.,80.00,AED
        2026-05-03,ADIB Current,Salary,,MONTHLY PAYROLL CREDIT,Income,23675,AED
        """)

        let rows = SpreadsheetImportParser.parse(
            table,
            ruleSnapshots: [],
            existingSnapshots: [],
            defaultAccountName: "Credit Card",
            fallbackCurrency: "AED"
        )
        XCTAssertEqual(rows.count, 3)

        let batch = ImportBatch(sourceFileName: "export.xlsx", parsedCount: 3, savedCount: 3, ignoredCount: 0)
        context.insert(batch)

        var saved: [FinanceTransaction] = []
        for row in rows {
            let draft = ImportSaveDraft(row: row, accountName: "Credit Card", fallbackCurrency: "AED")
            let transaction = draft.transaction(importBatchId: batch.id)
            context.insert(transaction)
            saved.append(transaction)
        }
        try context.save()

        // Per-row accounts survive persistence rather than collapsing onto the picker.
        let stored = try context.fetch(FetchDescriptor<FinanceTransaction>())
        XCTAssertEqual(stored.count, 3)
        XCTAssertEqual(Set(stored.map(\.accountName)), ["ADCB 365", "ADIB Current"])
        XCTAssertNil(stored.first { $0.accountName == "Credit Card" }, "no row should fall back to the picked account")
        XCTAssertEqual(stored.filter { $0.kind == .income }.count, 1)

        let learned = SmartCategorizationService.learnRules(from: saved, existingRules: [], minSamples: 1)
        for rule in learned { context.insert(rule) }
        try context.save()

        let storedRules = try context.fetch(FetchDescriptor<MerchantRule>())
        XCTAssertFalse(storedRules.isEmpty, "an already-categorized file should teach at least one rule")

        // A later statement import, with no categories of its own, should now self-categorize.
        let statement = SpreadsheetImportParser.table(fromCSV: """
        Date,Description,Amount
        2026-06-01,CrCardXXX6201usedUNIONCOOPDUBAIAEAvlCrlimitisAED900,55.25
        """)
        let followUp = SpreadsheetImportParser.parse(
            statement,
            ruleSnapshots: storedRules.map(MerchantRuleSnapshot.init),
            existingSnapshots: stored.map(TransactionSnapshot.init),
            defaultAccountName: "ADCB 365",
            fallbackCurrency: "AED"
        )

        XCTAssertEqual(followUp.first?.suggestedCategory, "Food")
        XCTAssertEqual(followUp.first?.suggestedSubcategory, "Groceries")
        XCTAssertFalse(try XCTUnwrap(followUp.first).isDuplicate)
    }

    /// Re-importing the same file must not create a second copy of every row.
    @MainActor
    func testReimportingTheSameFileFlagsEveryRowAsDuplicate() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let csv = """
        Period,Accounts,Category,Note,Income/Expense,Amount,Currency
        2026-05-01,ADCB 365,Food,CrCardXXX6201usedUNIONCOOPDUBAIAEAvlCrlimitisAED100,Exp.,120.00,AED
        """
        let first = SpreadsheetImportParser.parse(
            SpreadsheetImportParser.table(fromCSV: csv),
            ruleSnapshots: [], existingSnapshots: [],
            defaultAccountName: "Credit Card", fallbackCurrency: "AED"
        )
        let batch = ImportBatch(sourceFileName: "export.xlsx", parsedCount: 1, savedCount: 1, ignoredCount: 0)
        context.insert(batch)
        for row in first {
            context.insert(ImportSaveDraft(row: row, accountName: "Credit Card", fallbackCurrency: "AED")
                .transaction(importBatchId: batch.id))
        }
        try context.save()

        let stored = try context.fetch(FetchDescriptor<FinanceTransaction>())
        let second = SpreadsheetImportParser.parse(
            SpreadsheetImportParser.table(fromCSV: csv),
            ruleSnapshots: [], existingSnapshots: stored.map(TransactionSnapshot.init),
            defaultAccountName: "Credit Card", fallbackCurrency: "AED"
        )

        XCTAssertEqual(second.count, 1)
        XCTAssertTrue(try XCTUnwrap(second.first).isDuplicate)
        XCTAssertFalse(try XCTUnwrap(second.first).isSelected, "duplicates must not be pre-selected for saving")
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            UserProfile.self, Account.self, FinanceCategory.self, FinanceTransaction.self,
            MerchantRule.self, TransactionAttachment.self, ImportBatch.self, Budget.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
