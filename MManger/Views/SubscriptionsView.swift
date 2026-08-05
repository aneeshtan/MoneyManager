import SwiftUI
import SwiftData

struct SubscriptionsView: View {
    @Environment(\.appCurrency) private var currency
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]

    private var subscriptions: [DetectedSubscription] {
        SubscriptionDetector.detect(from: transactions)
    }

    private var totalMonthly: Decimal {
        subscriptions.reduce(Decimal(0)) { $0 + $1.monthlyAmount }
    }

    private var totalYearly: Decimal {
        totalMonthly * 12
    }

    private var increasedSubscriptions: [DetectedSubscription] {
        subscriptions.filter { $0.increased }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        heroCard

                        if !increasedSubscriptions.isEmpty {
                            increasedSection
                        }

                        if subscriptions.isEmpty {
                            EmptyStateView(
                                systemImage: "creditcard.and.123",
                                title: NSLocalizedString("No subscriptions detected", comment: ""),
                                message: NSLocalizedString("Recurring charges that appear at least 2 months will be detected automatically and shown here.", comment: "")
                            )
                        } else {
                            VStack(spacing: 12) {
                                SectionTitle(NSLocalizedString("Active subscriptions", comment: ""), subtitle: String(format: NSLocalizedString("%d detected recurring charges", comment: ""), subscriptions.count))
                                LazyVStack(spacing: 12) {
                                    ForEach(subscriptions) { sub in
                                        SubscriptionCard(subscription: sub, currency: currency)
                                    }
                                }
                            }
                        }
                    }
                    .adaptiveScreenContent()
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(NSLocalizedString("Subscriptions", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var heroCard: some View {
        GlassSurface(padding: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("Subscriptions", comment: ""))
                            .font(.caption.weight(.semibold))
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.violet)
                        Text(NSLocalizedString("Recurring charges", comment: ""))
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                    }
                    Spacer()
                    Image(systemName: "creditcard.and.123")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.violet)
                        .frame(width: 50, height: 50)
                        .background(AppTheme.lavender.opacity(0.14), in: Circle())
                }

                HStack(spacing: 10) {
                    MetricCapsule(title: NSLocalizedString("Monthly cost", comment: ""), value: AppFormatters.statMoney(totalMonthly, currency: currency), tint: AppTheme.coral)
                    MetricCapsule(title: NSLocalizedString("Yearly cost", comment: ""), value: AppFormatters.statMoney(totalYearly, currency: currency), tint: AppTheme.gold)
                }

                HStack(spacing: 10) {
                    MetricCapsule(title: NSLocalizedString("Active subs", comment: ""), value: "\(subscriptions.count)", tint: AppTheme.lavender)
                    MetricCapsule(title: NSLocalizedString("Price increases", comment: ""), value: "\(increasedSubscriptions.count)", tint: increasedSubscriptions.isEmpty ? AppTheme.mint : AppTheme.coral)
                }
            }
            .padding(20)
            .appHeroBackground()
        }
    }

    private var increasedSection: some View {
        VStack(spacing: 12) {
            SectionTitle(NSLocalizedString("Price increases", comment: ""), subtitle: String(format: NSLocalizedString("%d subscriptions went up", comment: ""), increasedSubscriptions.count))
            GlassSurface(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(increasedSubscriptions) { sub in
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppTheme.coral)
                                .frame(width: 38, height: 38)
                                .background(AppTheme.coral.opacity(0.13), in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text(sub.merchant)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.ink)
                                    .lineLimit(1)
                                Text(String(format: NSLocalizedString("Was %@ → now %@", comment: ""), AppFormatters.statMoney(sub.previousAmount, currency: currency), AppFormatters.statMoney(sub.lastAmount, currency: currency)))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.coral)
                            }
                            Spacer()
                        }
                        .padding(16)
                        Divider().overlay(AppTheme.line.opacity(0.45))
                    }
                }
            }
        }
    }
}

struct DetectedSubscription: Identifiable {
    var id: String { normalizedMerchant }
    var merchant: String
    var normalizedMerchant: String
    var lastAmount: Decimal
    var previousAmount: Decimal
    var monthlyAmount: Decimal
    var sampleCount: Int
    var lastDate: Date
    var increased: Bool
}

enum SubscriptionDetector {
    static func detect(from transactions: [FinanceTransaction]) -> [DetectedSubscription] {
        let grouped = Dictionary(grouping: transactions.filter { $0.kind == .expense && !$0.normalizedMerchant.isEmpty }) { $0.normalizedMerchant }
        return grouped.compactMap { merchant, rows in
            let sorted = rows.sorted { $0.date < $1.date }
            guard sorted.count >= 2 else { return nil }
            let calendar = Calendar.current
            let monthKeys = Set(sorted.map { calendar.component(.month, from: $0.date) + calendar.component(.year, from: $0.date) * 100 })
            guard monthKeys.count >= 2 else { return nil }
            let recent = sorted.suffix(3)
            let amounts = recent.map(\.amount)
            let average = amounts.reduce(Decimal(0), +) / Decimal(amounts.count)
            guard let last = sorted.last else { return nil }
            let previousAmount = sorted.dropLast().last?.amount ?? last.amount
            let increased = last.amount > previousAmount * Decimal(1.1)
            return DetectedSubscription(
                merchant: last.merchant.isEmpty ? merchant : last.merchant,
                normalizedMerchant: merchant,
                lastAmount: last.amount,
                previousAmount: previousAmount,
                monthlyAmount: average,
                sampleCount: sorted.count,
                lastDate: last.date,
                increased: increased
            )
        }
        .sorted { $0.monthlyAmount > $1.monthlyAmount }
    }
}

private struct SubscriptionCard: View {
    var subscription: DetectedSubscription
    var currency: String

    var body: some View {
        GlassSurface {
            HStack(spacing: 12) {
                Image(systemName: subscription.increased ? "exclamationmark.arrow.triangle.2.circlepath" : "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(subscription.increased ? AppTheme.coral : AppTheme.violet)
                    .frame(width: 44, height: 44)
                    .background((subscription.increased ? AppTheme.coral : AppTheme.violet).opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(subscription.merchant)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                    Text(String(format: NSLocalizedString("%d charges • last %@", comment: ""), subscription.sampleCount, AppFormatters.dayString(from: subscription.lastDate)))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(AppFormatters.statMoney(subscription.lastAmount, currency: currency))
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(subscription.increased ? AppTheme.coral : AppTheme.ink)
                    Text(NSLocalizedString("/ month", comment: ""))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.muted)
                }
            }
        }
    }
}
