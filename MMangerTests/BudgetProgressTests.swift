import XCTest
@testable import MManger

final class BudgetProgressTests: XCTestCase {
    func testBudgetProgressComputesSpentRemainingAndOverspent() {
        let progress = BudgetProgress(
            budget: Budget(categoryName: "Food", monthStart: Date(timeIntervalSince1970: 0), amount: Decimal(500)),
            spent: Decimal(625)
        )

        XCTAssertEqual(progress.remaining, Decimal(-125))
        XCTAssertEqual(progress.fractionUsed, 1.25)
        XCTAssertTrue(progress.isOverspent)
    }

    func testCategoryBudgetLookupMatchesParentAndSubcategory() {
        let month = Date(timeIntervalSince1970: 0)
        let budgets = [
            Budget(categoryName: "Food", subcategoryName: nil, monthStart: month, amount: Decimal(500)),
            Budget(categoryName: "Food", subcategoryName: "Coffee", monthStart: month, amount: Decimal(120))
        ]

        XCTAssertEqual(BudgetProgressCalculator.budget(forCategory: "Food", subcategory: nil, monthStart: month, budgets: budgets)?.amount, Decimal(500))
        XCTAssertEqual(BudgetProgressCalculator.budget(forCategory: "Food", subcategory: "Coffee", monthStart: month, budgets: budgets)?.amount, Decimal(120))
    }
}
