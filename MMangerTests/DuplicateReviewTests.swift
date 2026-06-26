import XCTest
@testable import MManger

final class DuplicateReviewTests: XCTestCase {
    func testDuplicateReviewFindsExactAndLikelyMatches() {
        let exact = FinanceTransaction(
            date: Date(timeIntervalSince1970: 100),
            kind: .expense,
            amount: Decimal(55),
            merchant: "EMARAT 6440",
            normalizedMerchant: "EMARAT",
            accountName: "Credit Card"
        )
        let likely = FinanceTransaction(
            date: Date(timeIntervalSince1970: 100 + 86_400),
            kind: .expense,
            amount: Decimal(55),
            merchant: "EMARAT 6440 DUBAI",
            normalizedMerchant: "EMARAT 6440",
            accountName: "Credit Card"
        )
        let unrelated = FinanceTransaction(
            date: Date(timeIntervalSince1970: 100),
            kind: .expense,
            amount: Decimal(90),
            merchant: "Amazon.ae",
            normalizedMerchant: "AMAZON.AE",
            accountName: "Credit Card"
        )

        let candidates = DuplicateReviewService.candidates(in: [exact, likely, unrelated])

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].transactions.count, 2)
        XCTAssertTrue(candidates[0].isExact || candidates[0].isLikely)
    }
}
