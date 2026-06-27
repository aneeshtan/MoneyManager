import XCTest
@testable import MManger

final class CategoryMatcherTests: XCTestCase {
    func testNormalizerTrimsBankNoiseAndLocations() {
        XCTAssertEqual(
            MerchantNormalizer.normalize("Cr.Card XXX1234 used for AED22.00 at CAREEM HALA RIDE Dubai-AE. Avl. Cr.limit is AED1000.00"),
            "CAREEM HALA RIDE"
        )
        XCTAssertEqual(MerchantNormalizer.normalize("NATIONAL TAXI DUBAI ARE"), "NATIONAL TAXI")
    }

    func testRulesBeatFallbacks() {
        let rules = [
            MerchantRule(pattern: "MATOVI DIGITAL FZCO", categoryName: "Entertainment", subcategoryName: "Subscriptions", confidence: 0.95, sampleCount: 41)
        ]

        let suggestion = CategoryMatcher.match(merchant: "MATOVI DIGITAL FZCO DUBAI ARE", rules: rules, fallbackKind: .expense)

        XCTAssertEqual(suggestion?.category, "Entertainment")
        XCTAssertEqual(suggestion?.subcategory, "Subscriptions")
        XCTAssertEqual(suggestion?.confidence, 0.95)
    }

    func testFallbacksCoverCoreStatementMerchants() {
        XCTAssertEqual(CategoryMatcher.match(merchant: "DUBAI TAXI", rules: [], fallbackKind: .expense)?.subcategory, "Taxi")
        XCTAssertEqual(CategoryMatcher.match(merchant: "Amazon Grocery Dubai", rules: [], fallbackKind: .expense)?.category, "Food")
        XCTAssertEqual(CategoryMatcher.match(merchant: "Hotel at Booking.com Amsterdam", rules: [], fallbackKind: .expense)?.category, "Travel")
    }
}
