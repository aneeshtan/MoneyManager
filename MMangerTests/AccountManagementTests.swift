import XCTest
import SwiftData
@testable import MManger

final class AccountManagementTests: XCTestCase {
    @MainActor
    func testAccountDeletionRemovesAllLocalWorkspaceData() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let suiteName = "AccountDeletionServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let transactionId = UUID()
        context.insert(UserProfile(id: SeedStore.defaultUserId, displayName: "Local Tester", baseCurrency: "AED"))
        context.insert(Account(name: "Cash", currency: "AED"))
        context.insert(FinanceCategory(name: "Food", kind: .expense))
        context.insert(FinanceTransaction(id: transactionId, date: Date(timeIntervalSince1970: 1), kind: .expense, amount: 20, currency: "AED", merchant: "Cafe", normalizedMerchant: "CAFE", accountName: "Cash", categoryName: "Food"))
        context.insert(MerchantRule(pattern: "Cafe", categoryName: "Food", kind: .expense))
        context.insert(TransactionAttachment(transactionId: transactionId, fileName: "receipt.pdf", originalFileName: "receipt.pdf", contentType: "application/pdf"))
        context.insert(ImportBatch(sourceFileName: "statement.pdf", parsedCount: 1, savedCount: 1, ignoredCount: 0))
        context.insert(Budget(categoryName: "Food", monthStart: Date(timeIntervalSince1970: 1), amount: 500, currency: "AED"))
        try context.save()

        try AccountDeletionService.deleteLocalWorkspaceData(in: context, defaults: defaults)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserProfile>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Account>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FinanceCategory>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FinanceTransaction>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MerchantRule>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TransactionAttachment>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ImportBatch>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Budget>()), 0)
        XCTAssertTrue(defaults.bool(forKey: AccountDeletionService.didDeleteLocalAccountKey))
    }

    func testOpeningBalanceAdjustsToMatchTargetCurrentValue() {
        let transactions = [
            FinanceTransaction(date: Date(timeIntervalSince1970: 1), kind: .income, amount: 250, merchant: "Salary", normalizedMerchant: "SALARY", accountName: "Cash"),
            FinanceTransaction(date: Date(timeIntervalSince1970: 2), kind: .expense, amount: 40, merchant: "Groceries", normalizedMerchant: "GROCERIES", accountName: "Cash"),
            FinanceTransaction(date: Date(timeIntervalSince1970: 3), kind: .income, amount: 900, merchant: "Other", normalizedMerchant: "OTHER", accountName: "Savings")
        ]

        let openingBalance = AccountBalance.adjustedOpeningBalance(
            targetCurrentValue: 1_000,
            accountName: "Cash",
            transactions: transactions
        )

        XCTAssertEqual(openingBalance, 790)
    }

    func testBackupAccountDecodesLegacyPayloadWithDefaults() throws {
        let json = """
        {
          "name": "Old Cash",
          "currency": "AED",
          "openingBalance": "25"
        }
        """.data(using: .utf8)!

        let account = try JSONDecoder().decode(AccountBackupRecord.self, from: json)

        XCTAssertEqual(account.type, AccountType.other.rawValue)
        XCTAssertFalse(account.isArchived)
    }

    func testTransactionIdentityKeyMatchesSameDayDuplicate() {
        let calendar = Calendar(identifier: .gregorian)
        let firstDate = Date(timeIntervalSince1970: 1_704_110_400)
        let laterSameDay = firstDate.addingTimeInterval(60 * 60 * 5)

        let firstKey = TransactionIdentityKey.make(
            accountName: "Checking",
            date: firstDate,
            amount: 12.50,
            normalizedMerchant: "COFFEE SHOP",
            calendar: calendar
        )
        let secondKey = TransactionIdentityKey.make(
            accountName: "Checking",
            date: laterSameDay,
            amount: 12.50,
            normalizedMerchant: "COFFEE SHOP",
            calendar: calendar
        )

        XCTAssertEqual(firstKey, secondKey)
    }

    @MainActor
    func testSeedStoreBackfillsCategoriesWhenAccountsAlreadyExist() throws {
        let previousDeletionFlag = UserDefaults.standard.object(forKey: AccountDeletionService.didDeleteLocalAccountKey)
        UserDefaults.standard.set(false, forKey: AccountDeletionService.didDeleteLocalAccountKey)
        defer {
            if let previousDeletionFlag {
                UserDefaults.standard.set(previousDeletionFlag, forKey: AccountDeletionService.didDeleteLocalAccountKey)
            } else {
                UserDefaults.standard.removeObject(forKey: AccountDeletionService.didDeleteLocalAccountKey)
            }
        }

        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        context.insert(Account(name: SeedStore.defaultImportAccountName, currency: "AED"))
        try context.save()

        try SeedStore.seedIfNeeded(modelContext: context)

        XCTAssertGreaterThan(try context.fetchCount(FetchDescriptor<FinanceCategory>()), 0)
        XCTAssertGreaterThan(try context.fetchCount(FetchDescriptor<MerchantRule>()), 0)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            UserProfile.self,
            Account.self,
            FinanceCategory.self,
            FinanceTransaction.self,
            MerchantRule.self,
            TransactionAttachment.self,
            ImportBatch.self,
            Budget.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
