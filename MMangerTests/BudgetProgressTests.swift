import XCTest
import UIKit
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

final class AppThemeTests: XCTestCase {
    func testDarkModePaletteUsesReadableNativeSurfaces() {
        let palette = AppTheme.palette(for: .dark)

        XCTAssertLessThan(palette.canvas.luminance, 0.10)
        XCTAssertGreaterThan(palette.ink.luminance, 0.72)
        XCTAssertGreaterThan(palette.muted.luminance, 0.42)
        XCTAssertLessThan(palette.surface.luminance, 0.18)
        XCTAssertGreaterThan(palette.ink.luminance - palette.canvas.luminance, 0.65)
    }
}

final class AppFormPaletteTests: XCTestCase {
    func testDarkModeFormPaletteUsesNativeDarkSurfaces() {
        let palette = AppFormPalette.colors(for: .dark)

        XCTAssertLessThan(palette.background.luminance, 0.04)
        XCTAssertGreaterThan(palette.row.luminance, palette.background.luminance)
        XCTAssertLessThan(palette.row.luminance, 0.08)
        XCTAssertGreaterThan(palette.header.luminance, 0.25)
    }
}

final class CompactTabSelectionStateTests: XCTestCase {
    func testDismissingMoreRestoresPreviousContentTab() {
        var state = CompactTabSelectionState()

        XCTAssertFalse(state.select(.transactions))
        XCTAssertEqual(state.selected, .transactions)
        XCTAssertTrue(state.select(.more))
        XCTAssertEqual(state.selected, .more)

        state.dismissMore()

        XCTAssertEqual(state.selected, .transactions)
    }
}

final class AppHeroPaletteTests: XCTestCase {
    func testDarkHeroGradientAvoidsLightModeStops() {
        let colors = AppHeroPalette.backgroundColors(for: .dark)

        XCTAssertEqual(colors.count, 3)
        XCTAssertTrue(colors.allSatisfy { $0.luminance < 0.22 })
        XCTAssertGreaterThan(colors[0].luminance, colors[1].luminance)
    }
}

final class AppLocalizationDefaultsTests: XCTestCase {
    func testPersianLanguageDefaultsToTomanCurrency() {
        XCTAssertEqual(AppFormatters.defaultCurrency(for: .persian), "IRR")
        XCTAssertEqual(AppFormatters.defaultCurrency(for: .english, localeCurrency: nil), "USD")
        XCTAssertTrue(AppFormatters.money(12_340, currency: AppFormatters.defaultCurrency(for: .persian)).contains("تومان"))
    }

    func testPersianLanguageUsesJalaliDateFormatting() {
        let date = Date(timeIntervalSince1970: 1_704_067_200)
        let formatted = AppFormatters.dayString(from: date, language: .persian)

        XCTAssertFalse(formatted.contains("2024"))
        XCTAssertTrue(formatted.contains("۱۴۰۲") || formatted.contains("1402"))
        XCTAssertEqual(AppLanguage.persian.calendar.identifier, .persian)
        XCTAssertEqual(AppLanguage.persian.locale.identifier, "fa_IR@calendar=persian")
    }

    func testRightToLeftLanguagesAreMarkedForMirroredNavigation() {
        XCTAssertTrue(AppLanguage.persian.isRightToLeft)
        XCTAssertTrue(AppLanguage.arabic.isRightToLeft)
        XCTAssertFalse(AppLanguage.english.isRightToLeft)
    }

    func testUserProfileStoresLanguageMatchedRegionalDefaults() {
        let profile = UserProfile(id: "user", displayName: "User", baseCurrency: "USD")

        profile.applyRegionalDefaults(
            currency: AppFormatters.defaultCurrency(for: .persian, localeCurrency: nil),
            countryCode: AppLanguage.persian.suggestedRegion,
            timeZoneIdentifier: AppLanguage.persian.suggestedTimeZone
        )

        XCTAssertEqual(profile.baseCurrency, "IRR")
        XCTAssertEqual(profile.countryCode, "IR")
        XCTAssertEqual(profile.timeZoneIdentifier, "Asia/Tehran")
    }

    func testReportingCurrencyUsesImportedTransactionCurrencyOverAppBaseCurrency() {
        let transactions = [
            FinanceTransaction(date: .now, kind: .expense, amount: 800, currency: "AED", merchant: "Cafe", normalizedMerchant: "CAFE", accountName: "Card"),
            FinanceTransaction(date: .now, kind: .expense, amount: 250, currency: "AED", merchant: "Store", normalizedMerchant: "STORE", accountName: "Card")
        ]

        let reportingCurrency = CurrencyReporting.dominantCurrency(
            in: transactions,
            fallback: "IRR",
            currency: { $0.currency },
            amount: { $0.amount }
        )

        XCTAssertEqual(reportingCurrency, "AED")
    }
}

final class ImportCTAStateTests: XCTestCase {
    func testSaveBecomesPrimaryActionAfterRowsAreImported() {
        XCTAssertEqual(ImportCTAState(parsedCount: 0, selectedCount: 0, isBusy: false).primaryAction, .importRows)
        XCTAssertEqual(ImportCTAState(parsedCount: 12, selectedCount: 8, isBusy: false).primaryAction, .saveRows)
        XCTAssertFalse(ImportCTAState(parsedCount: 12, selectedCount: 8, isBusy: false).isSaveDisabled)
    }

    func testSaveStaysDisabledWhenNoRowsAreSelectedOrImportIsBusy() {
        XCTAssertTrue(ImportCTAState(parsedCount: 12, selectedCount: 0, isBusy: false).isSaveDisabled)
        XCTAssertTrue(ImportCTAState(parsedCount: 12, selectedCount: 8, isBusy: true).isSaveDisabled)
    }
}

final class DashboardTextTests: XCTestCase {
    func testDashboardSummaryUsesLocalizedFormatKeys() {
        let summary = DashboardText.monthlySummary(
            monthTitle: "تیر ۱۴۰۵",
            transactionCount: 19,
            income: "0.00 د.إ",
            expense: "1,141.78 د.إ"
        )

        XCTAssertEqual(summary, "In تیر ۱۴۰۵, 19 transactions produced 0.00 د.إ income and 1,141.78 د.إ spending.")
    }

    func testUncategorizedInsightUsesLocalizedFormatKey() {
        let message = DashboardText.uncategorizedMessage(count: 9)

        XCTAssertEqual(message, "9 transactions are uncategorized. Fixing them will improve future auto-categorization.")
    }
}

final class CalendarMonthSummaryTests: XCTestCase {
    func testBuildsDailySummariesAndLargestDailyMovement() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let june1Morning = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9))!
        let june1Evening = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 19))!
        let june2 = calendar.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 12))!
        let july1 = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 12))!

        let transactions = [
            FinanceTransaction(date: june1Morning, kind: .expense, amount: Decimal(40), currency: "AED", merchant: "Cafe", normalizedMerchant: "CAFE", accountName: "Card"),
            FinanceTransaction(date: june1Evening, kind: .income, amount: Decimal(120), currency: "AED", merchant: "Refund", normalizedMerchant: "REFUND", accountName: "Card"),
            FinanceTransaction(date: june2, kind: .expense, amount: Decimal(85), currency: "AED", merchant: "Market", normalizedMerchant: "MARKET", accountName: "Card"),
            FinanceTransaction(date: july1, kind: .expense, amount: Decimal(999), currency: "AED", merchant: "Ignored", normalizedMerchant: "IGNORED", accountName: "Card")
        ]

        let summary = CalendarMonthSummary(month: june1Morning, transactions: transactions, calendar: calendar)
        let firstDay = summary.summary(for: june1Morning)
        let secondDay = summary.summary(for: june2)

        XCTAssertEqual(summary.income, Decimal(120))
        XCTAssertEqual(summary.expense, Decimal(125))
        XCTAssertEqual(summary.net, Decimal(-5))
        XCTAssertEqual(summary.largestDailyMovement, Decimal(120))
        XCTAssertEqual(firstDay.transactionCount, 2)
        XCTAssertEqual(firstDay.expense, Decimal(40))
        XCTAssertEqual(firstDay.income, Decimal(120))
        XCTAssertEqual(firstDay.net, Decimal(80))
        XCTAssertEqual(secondDay.transactionCount, 1)
        XCTAssertEqual(secondDay.expense, Decimal(85))
    }
}

private extension UIColor {
    var luminance: CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }
}
