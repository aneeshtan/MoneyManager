import XCTest
@testable import MManger

final class CurrencyFormattingTests: XCTestCase {

    /// Trends and the budget bars used to call money() with no currency, which silently
    /// formatted every amount as USD. The parameter is now required, so this just pins
    /// down that a non-USD code actually reaches the output.
    func testMoneyUsesTheGivenCurrencyRatherThanDollars() {
        let aed = AppFormatters.money(1234.5, currency: "AED")

        XCTAssertFalse(aed.contains("$"), "AED must not render with a dollar sign: \(aed)")
        XCTAssertTrue(aed.contains("1,234.5") || aed.contains("1234.5"), aed)

        XCTAssertTrue(AppFormatters.money(10, currency: "USD").contains("$"))
    }

    func testResolvedCurrencyFallsBackToTheConfiguredCodeNotUSD() {
        XCTAssertEqual(AppFormatters.resolvedCurrency(nil, fallback: "AED"), "AED")
        XCTAssertEqual(AppFormatters.resolvedCurrency("   ", fallback: "AED"), "AED")
        XCTAssertEqual(AppFormatters.resolvedCurrency("eur", fallback: "AED"), "EUR")
    }

    /// A screen with a single total has to pick one currency and report only that,
    /// rather than adding amounts from different currencies together.
    func testDominantCurrencyPicksTheLargestByValue() {
        let rows: [(String, Decimal)] = [
            ("AED", 5000), ("AED", 3000), ("USD", 400), ("IRR", 100)
        ]

        let dominant = CurrencyReporting.dominantCurrency(
            in: rows, fallback: "USD", currency: { $0.0 }, amount: { $0.1 }
        )

        XCTAssertEqual(dominant, "AED")
    }

    func testDominantCurrencyFallsBackWhenThereIsNothingToRankOn() {
        let dominant = CurrencyReporting.dominantCurrency(
            in: [(String, Decimal)](), fallback: "AED", currency: { $0.0 }, amount: { $0.1 }
        )

        XCTAssertEqual(dominant, "AED")
    }

    /// The same merchant billed in two currencies is two bills; averaging across them
    /// would invent an amount that was never charged.
    func testRecurringBillsAreDetectedPerCurrency() {
        let calendar = Calendar.current
        func txn(_ amount: Decimal, _ currency: String, monthsAgo: Int) -> FinanceTransaction {
            FinanceTransaction(
                date: calendar.date(byAdding: .month, value: -monthsAgo, to: .now) ?? .now,
                kind: .expense, amount: amount, currency: currency,
                merchant: "NETFLIX", normalizedMerchant: "NETFLIX",
                accountName: "Card", categoryName: "Entertainment"
            )
        }

        let bills = RecurringBillDetector.detect(from: [
            txn(50, "AED", monthsAgo: 1), txn(50, "AED", monthsAgo: 2),
            txn(15, "USD", monthsAgo: 1), txn(15, "USD", monthsAgo: 2)
        ])

        XCTAssertEqual(bills.count, 2, "one bill per currency, not one blended bill")
        XCTAssertEqual(Set(bills.map(\.currency)), ["AED", "USD"])
        XCTAssertEqual(bills.first { $0.currency == "AED" }?.amount, 50)
        XCTAssertEqual(bills.first { $0.currency == "USD" }?.amount, 15)
    }
}
