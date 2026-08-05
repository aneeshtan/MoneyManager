import XCTest
@testable import MManger

final class NotificationServiceTests: XCTestCase {
    func testScheduledReminderPayloadsExcludeDisabledAndPastReminders() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 5, hour: 12)))
        let nextDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 7, hour: 10)))
        let disabledDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 8, hour: 10)))
        let pastDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 5, hour: 10)))
        let expectedReminderDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 6, hour: 9)))
        let activeId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        let scheduled = [
            ScheduledTransaction(
                id: activeId,
                merchant: "Power Utility",
                amount: 250,
                currency: "AED",
                kind: .expense,
                accountName: "Checking",
                nextDate: nextDate
            ),
            ScheduledTransaction(
                merchant: "Paused Bill",
                amount: 50,
                currency: "AED",
                kind: .expense,
                accountName: "Checking",
                nextDate: disabledDate,
                isEnabled: false
            ),
            ScheduledTransaction(
                merchant: "Past Bill",
                amount: 75,
                currency: "AED",
                kind: .expense,
                accountName: "Checking",
                nextDate: pastDate
            )
        ]

        let payloads = NotificationService.scheduledReminderPayloads(
            for: scheduled,
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(payloads.count, 1)
        XCTAssertEqual(payloads.first?.identifier, "scheduled-\(activeId.uuidString)")
        XCTAssertEqual(payloads.first?.title, "Upcoming bill")
        XCTAssertEqual(payloads.first?.scheduledDate, expectedReminderDate)
    }
}
