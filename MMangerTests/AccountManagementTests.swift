import XCTest
@testable import MManger

final class AccountManagementTests: XCTestCase {
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
}
