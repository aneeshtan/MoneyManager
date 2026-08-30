import Foundation
import UserNotifications
import SwiftUI

struct NotificationReminderPayload: Sendable, Equatable {
    var title: String
    var body: String
    var scheduledDate: Date
    var identifier: String
}

enum NotificationService {
    static var notificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "notificationsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "notificationsEnabled") }
    }

    static func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            notificationsEnabled = granted
            return granted
        } catch {
            return false
        }
    }

    static func requestAuthorizationIfNeeded() {
        guard notificationsEnabled else { return }
        Task {
            _ = await requestPermission()
        }
    }

    @MainActor
    static func checkAuthorizationStatus() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    static func scheduleBillReminder(
        title: String,
        body: String,
        scheduledDate: Date,
        identifier: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: scheduledDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { _ in }
    }

    static func scheduleBudgetWarning(
        categoryName: String,
        spent: Decimal,
        budget: Decimal,
        currency: String
    ) {
        let remaining = budget - spent
        let title = "Budget warning: \(categoryName)"
        let body = "You've spent \(AppFormatters.statMoney(spent, currency: currency)) of \(AppFormatters.statMoney(budget, currency: currency)). \(AppFormatters.statMoney(remaining, currency: currency)) remaining this month."

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "budget-\(categoryName)-\(UUID().uuidString)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { _ in }
    }

    static func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    static func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    static func scheduledReminderPayloads(
        for scheduled: [ScheduledTransaction],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> [NotificationReminderPayload] {
        let startOfToday = calendar.startOfDay(for: now)

        return scheduled.compactMap { item -> NotificationReminderPayload? in
            guard item.isEnabled,
                  let reminderDate = calendar.date(byAdding: .day, value: -1, to: item.nextDate),
                  reminderDate >= startOfToday else {
                return nil
            }

            let title = item.kind == .income ? "Expected income" : "Upcoming bill"
            let body = "\(item.merchant) — \(AppFormatters.statMoney(item.amount, currency: item.currency)) on \(AppFormatters.dayString(from: item.nextDate))"
            let scheduledDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: reminderDate) ?? reminderDate

            return NotificationReminderPayload(
                title: title,
                body: body,
                scheduledDate: scheduledDate,
                identifier: "scheduled-\(item.id.uuidString)"
            )
        }
    }

    static func updateScheduledTransactionReminders(scheduled: [ScheduledTransaction]) {
        let reminders = scheduledReminderPayloads(for: scheduled)

        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("scheduled-") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)

            for reminder in reminders {
                scheduleBillReminder(
                    title: reminder.title,
                    body: reminder.body,
                    scheduledDate: reminder.scheduledDate,
                    identifier: reminder.identifier
                )
            }
        }
    }

    static func updateRecurringBillReminders(transactions: [FinanceTransaction], currency: String) {
        let recurring = RecurringBillDetector.detect(from: transactions)
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("recurring-") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)

            for bill in recurring {
                let calendar = Calendar.current
                let now = calendar.startOfDay(for: .now)

                if let reminderDate = calendar.date(byAdding: .day, value: -1, to: bill.nextDate),
                   reminderDate >= now {
                    scheduleBillReminder(
                        title: "Upcoming bill",
                        body: "\(bill.merchant) — \(AppFormatters.statMoney(bill.amount, currency: AppFormatters.resolvedCurrency(bill.currency, fallback: currency))) expected \(AppFormatters.dayString(from: bill.nextDate))",
                        scheduledDate: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: reminderDate) ?? reminderDate,
                        identifier: "recurring-\(bill.id)"
                    )
                }
            }
        }
    }
}

struct RecurringBill: Identifiable {
    var id: String { normalizedMerchant }
    var merchant: String
    var normalizedMerchant: String
    var amount: Decimal
    var currency: String
    var nextDate: Date
    var sampleCount: Int
}

private struct MerchantCurrencyKey: Hashable {
    var merchant: String
    var currency: String
}

enum RecurringBillDetector {
    static func detect(from transactions: [FinanceTransaction]) -> [RecurringBill] {
        // Keyed by merchant *and* currency: the same merchant billed in two currencies
        // is two bills, and averaging across them would invent an amount.
        let grouped = Dictionary(grouping: transactions.filter { $0.kind == .expense && !$0.normalizedMerchant.isEmpty }) {
            MerchantCurrencyKey(merchant: $0.normalizedMerchant, currency: $0.currency.uppercased())
        }
        return grouped.compactMap { key, rows in
            let merchant = key.merchant
            let sorted = rows.sorted { $0.date < $1.date }
            guard sorted.count >= 2 else { return nil }
            let calendar = Calendar.current
            let monthKeys = Set(sorted.map { calendar.component(.month, from: $0.date) + calendar.component(.year, from: $0.date) * 100 })
            guard monthKeys.count >= 2 else { return nil }
            let recent = sorted.suffix(3)
            let amounts = recent.map(\.amount)
            let average = amounts.reduce(Decimal(0), +) / Decimal(amounts.count)
            guard let last = sorted.last else { return nil }
            let next = calendar.date(byAdding: .month, value: 1, to: last.date) ?? last.date
            return RecurringBill(
                merchant: last.merchant.isEmpty ? merchant : last.merchant,
                normalizedMerchant: merchant,
                amount: average,
                currency: last.currency,
                nextDate: next,
                sampleCount: sorted.count
            )
        }
        .sorted { $0.nextDate < $1.nextDate }
    }
}
