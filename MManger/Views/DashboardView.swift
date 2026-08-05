import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]
    @Query(sort: \Budget.monthStart, order: .reverse) private var budgets: [Budget]
    @Query(sort: \FinanceCategory.sortOrder) private var categories: [FinanceCategory]
    @Environment(\.appCurrency) private var currency

    @State private var visibleMonth: Date = .now
    @State private var showingLayoutEditor = false
    @AppStorage("dashboardCardOrder") private var cardOrderData: String = "hero,insights,summary,content,budget,notes"
    @AppStorage("dashboardHiddenCards") private var hiddenCardsData: String = ""

    private var cardOrder: [DashboardCard] {
        let raw = cardOrderData.split(separator: ",").map(String.init)
        let all: [DashboardCard] = [.hero, .insights, .summary, .content, .budget, .notes]
        let ordered = raw.compactMap { DashboardCard(rawValue: $0) }
        return Array(NSOrderedSet(array: ordered + all).array as? [DashboardCard] ?? all)
    }

    private var hiddenCards: Set<DashboardCard> {
        Set(hiddenCardsData.split(separator: ",").compactMap { DashboardCard(rawValue: String($0)) })
    }

    private var calendar: Calendar { .current }

    private var monthTransactions: [FinanceTransaction] {
        transactions.filter { calendar.isDate($0.date, equalTo: visibleMonth, toGranularity: .month) }
    }

    private var reportingCurrency: String {
        let expenseTransactions = monthTransactions.filter { $0.kind == .expense }
        if !expenseTransactions.isEmpty {
            return CurrencyReporting.dominantCurrency(
                in: expenseTransactions,
                fallback: currency,
                currency: { $0.currency },
                amount: { $0.amount }
            )
        }
        return CurrencyReporting.dominantCurrency(
            in: monthTransactions.filter { $0.kind == .income },
            fallback: currency,
            currency: { $0.currency },
            amount: { $0.amount }
        )
    }

    private var reportingMonthTransactions: [FinanceTransaction] {
        monthTransactions.filter { transactionCurrency($0) == reportingCurrency }
    }

    private var reportingPreviousMonthTransactions: [FinanceTransaction] {
        previousMonthTransactions.filter { transactionCurrency($0) == reportingCurrency }
    }

    private var monthlyExpense: Decimal {
        reportingMonthTransactions.filter { $0.kind == .expense }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var monthlyIncome: Decimal {
        reportingMonthTransactions.filter { $0.kind == .income }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var previousMonthTransactions: [FinanceTransaction] {
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: visibleMonth) else { return [] }
        return transactions.filter { calendar.isDate($0.date, equalTo: previousMonth, toGranularity: .month) }
    }

    private var previousMonthlyExpense: Decimal {
        reportingPreviousMonthTransactions.filter { $0.kind == .expense }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var categoryShares: [CategoryShare] {
        let grouped = Dictionary(grouping: reportingMonthTransactions.filter { $0.kind == .expense }) { transaction in
            transaction.categoryName?.isEmpty == false ? transaction.categoryName! : "Uncategorized"
        }
        let total = max(NSDecimalNumber(decimal: monthlyExpense).doubleValue, 0)
        return grouped
            .map { name, transactions in
                let amount = transactions.reduce(Decimal(0)) { $0 + $1.amount }
                let amountValue = NSDecimalNumber(decimal: amount).doubleValue
                return CategoryShare(name: name, amount: amount, percent: total > 0 ? amountValue / total : 0)
            }
            .sorted { $0.amount > $1.amount }
    }

    private var smartInsights: [SmartInsight] {
        SmartInsightEngine.insights(
            monthTransactions: reportingMonthTransactions,
            previousMonthTransactions: reportingPreviousMonthTransactions,
            categoryShares: categoryShares,
            monthlyExpense: monthlyExpense,
            currency: reportingCurrency
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        ForEach(cardOrder) { card in
                            if !hiddenCards.contains(card) {
                                cardView(for: card)
                            }
                        }
                    }
                    .environment(\.appCurrency, reportingCurrency)
                    .adaptiveScreenContent()
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(NSLocalizedString("Stats", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingLayoutEditor = true
                    } label: {
                        Image(systemName: "rectangle.3.offgrid.bubble.left")
                    }
                    .accessibilityLabel(NSLocalizedString("Customize dashboard", comment: ""))
                }
            }
            .sheet(isPresented: $showingLayoutEditor) {
                DashboardLayoutEditor(
                    cardOrder: cardOrder,
                    hiddenCards: hiddenCards,
                    onSave: { order, hidden in
                        cardOrderData = order.map(\.rawValue).joined(separator: ",")
                        hiddenCardsData = hidden.map(\.rawValue).joined(separator: ",")
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func cardView(for card: DashboardCard) -> some View {
        switch card {
        case .hero:
            VStack(spacing: 12) {
                StatsHero(
                    monthTitle: monthTitle,
                    income: monthlyIncome,
                    expense: monthlyExpense,
                    moveMonth: moveMonth
                )
                StatsShortcutStrip()
            }
        case .insights:
            SmartInsightsSection(insights: smartInsights)
        case .summary:
            MonthlySummarySection(
                monthTitle: monthTitle,
                income: monthlyIncome,
                expense: monthlyExpense,
                previousExpense: previousMonthlyExpense,
                categoryShares: categoryShares,
                transactionCount: monthTransactions.count
            )
        case .content:
            CategoryStatsSection(
                categoryShares: categoryShares,
                totalExpense: monthlyExpense,
                visibleMonth: visibleMonth,
                transactions: transactions,
                reportingCurrency: reportingCurrency
            )
        case .budget:
            if shouldShowBudgetCard {
                BudgetStatsSection(
                    budgets: budgets,
                    categories: categories,
                    monthTransactions: monthTransactions,
                    allTransactions: transactions,
                    monthlyIncome: monthlyIncome,
                    monthlyExpense: monthlyExpense,
                    visibleMonth: visibleMonth
                )
            }
        case .notes:
            if shouldShowNotesCard {
                NoteStatsSection(monthTransactions: monthTransactions)
            }
        }
    }

    private var shouldShowBudgetCard: Bool {
        budgets.contains { calendar.isDate($0.monthStart, equalTo: visibleMonth, toGranularity: .month) }
    }

    private var shouldShowNotesCard: Bool {
        monthTransactions.contains { !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = AppLanguage.stored.calendar
        formatter.locale = AppLanguage.stored.locale
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: visibleMonth)
    }

    private func moveMonth(by value: Int) {
        visibleMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) ?? visibleMonth
    }

    private func transactionCurrency(_ transaction: FinanceTransaction) -> String {
        AppFormatters.resolvedCurrency(transaction.currency, fallback: currency)
    }

}

private struct CategoryShare: Identifiable {
    var id: String { name }
    var name: String
    var amount: Decimal
    var percent: Double
}

private struct SmartInsight: Identifiable {
    let id = UUID()
    var title: String
    var message: String
    var systemImage: String
    var tint: Color
}

private enum SmartInsightEngine {
    static func insights(
        monthTransactions: [FinanceTransaction],
        previousMonthTransactions: [FinanceTransaction],
        categoryShares: [CategoryShare],
        monthlyExpense: Decimal,
        currency: String
    ) -> [SmartInsight] {
        var insights: [SmartInsight] = []
        let expenseTransactions = monthTransactions.filter { $0.kind == .expense }
        let previousExpense = previousMonthTransactions
            .filter { $0.kind == .expense }
            .reduce(Decimal(0)) { $0 + $1.amount }

        if !monthTransactions.isEmpty {
            let uncategorized = monthTransactions.filter { $0.categoryName?.isEmpty != false }
            if !uncategorized.isEmpty {
                insights.append(
                    SmartInsight(
                        title: NSLocalizedString("Needs review", comment: ""),
                        message: DashboardText.uncategorizedMessage(count: uncategorized.count),
                        systemImage: "wand.and.sparkles",
                        tint: AppTheme.violet
                    )
                )
            }
        }

        if previousExpense > 0 {
            let currentValue = decimalValue(monthlyExpense)
            let previousValue = decimalValue(previousExpense)
            let delta = (currentValue - previousValue) / previousValue
            if abs(delta) >= 0.15 {
                insights.append(
                    SmartInsight(
                        title: DashboardText.spendingChangeTitle(delta: delta),
                        message: DashboardText.spendingChangeMessage(
                            previousExpense: AppFormatters.statMoney(previousExpense, currency: currency),
                            monthlyExpense: AppFormatters.statMoney(monthlyExpense, currency: currency)
                        ),
                        systemImage: delta > 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                        tint: delta > 0 ? AppTheme.coral : AppTheme.teal
                    )
                )
            }
        }

        if let top = categoryShares.first, top.percent >= 0.45 {
            insights.append(
                SmartInsight(
                    title: DashboardText.dominantCategoryTitle(name: top.name),
                    message: DashboardText.dominantCategoryMessage(percent: AppFormatters.percent(top.percent)),
                    systemImage: "chart.pie.fill",
                    tint: AppTheme.gold
                )
            )
        }

        let duplicateGroups = Dictionary(grouping: expenseTransactions) { transaction in
            "\(Calendar.current.startOfDay(for: transaction.date).timeIntervalSince1970)|\(transaction.accountName)|\(transaction.normalizedMerchant)|\(NSDecimalNumber(decimal: transaction.amount).stringValue)"
        }
        let possibleDuplicates = duplicateGroups.values.filter { $0.count > 1 }.reduce(0) { $0 + $1.count }
        if possibleDuplicates > 0 {
            insights.append(
                SmartInsight(
                    title: NSLocalizedString("Possible duplicates", comment: ""),
                    message: DashboardText.possibleDuplicatesMessage(count: possibleDuplicates),
                    systemImage: "doc.on.doc",
                    tint: AppTheme.rose
                )
            )
        }

        if insights.isEmpty {
            insights.append(
                SmartInsight(
                    title: NSLocalizedString("AI watch is clear", comment: ""),
                    message: NSLocalizedString("No unusual category, duplicate, or review signals found for this month.", comment: ""),
                    systemImage: "checkmark.seal",
                    tint: AppTheme.teal
                )
            )
        }

        return Array(insights.prefix(4))
    }

    private static func decimalValue(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}

enum DashboardText {
    static func monthlySummary(monthTitle: String, transactionCount: Int, income: String, expense: String) -> String {
        String(
            format: NSLocalizedString("In %@, %d transactions produced %@ income and %@ spending.", comment: ""),
            monthTitle,
            transactionCount,
            income,
            expense
        )
    }

    static func biggestCategory(name: String, percent: String) -> String {
        String(
            format: NSLocalizedString("%@ is the biggest category at %@ of spending.", comment: ""),
            name,
            percent
        )
    }

    static func expenseDelta(percent: Int, direction: String) -> String {
        String(
            format: NSLocalizedString("Expenses are %d%% %@ than the previous month.", comment: ""),
            percent,
            direction
        )
    }

    static func uncategorizedMessage(count: Int) -> String {
        String(
            format: NSLocalizedString("%d transactions are uncategorized. Fixing them will improve future auto-categorization.", comment: ""),
            count
        )
    }

    static func spendingChangeTitle(delta: Double) -> String {
        String(
            format: NSLocalizedString(delta > 0 ? "Spending up %d%%" : "Spending down %d%%", comment: ""),
            Int(abs(delta * 100).rounded())
        )
    }

    static func spendingChangeMessage(previousExpense: String, monthlyExpense: String) -> String {
        String(
            format: NSLocalizedString("Compared with the previous month, expenses moved from %@ to %@.", comment: ""),
            previousExpense,
            monthlyExpense
        )
    }

    static func dominantCategoryTitle(name: String) -> String {
        String(format: NSLocalizedString("%@ dominates", comment: ""), name)
    }

    static func dominantCategoryMessage(percent: String) -> String {
        String(format: NSLocalizedString("%@ of this month's spending is in this category.", comment: ""), percent)
    }

    static func possibleDuplicatesMessage(count: Int) -> String {
        String(
            format: NSLocalizedString("%d same-day transactions share the same account, merchant, and amount.", comment: ""),
            count
        )
    }
}

private struct SmartInsightsSection: View {
    var insights: [SmartInsight]

    var body: some View {
        VStack(spacing: 12) {
            SectionTitle("AI insights", subtitle: "Local suggestions from your spending patterns")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(insights) { insight in
                        SmartInsightCard(insight: insight)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct SmartInsightCard: View {
    var insight: SmartInsight

    var body: some View {
        GlassSurface(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: insight.systemImage)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(insight.tint)
                    .frame(width: 38, height: 38)
                    .background(insight.tint.opacity(0.13), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(insight.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(2)
                    Text(insight.message)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: 230, alignment: .leading)
        }
    }
}

private struct MonthlySummarySection: View {
    @Environment(\.appCurrency) private var currency
    var monthTitle: String
    var income: Decimal
    var expense: Decimal
    var previousExpense: Decimal
    var categoryShares: [CategoryShare]
    var transactionCount: Int

    private var expenseDelta: Double? {
        let previous = NSDecimalNumber(decimal: previousExpense).doubleValue
        guard previous > 0 else { return nil }
        let current = NSDecimalNumber(decimal: expense).doubleValue
        return (current - previous) / previous
    }

    private var summaryText: String {
        let topCategory = categoryShares.first
        var parts = [
            DashboardText.monthlySummary(
                monthTitle: monthTitle,
                transactionCount: transactionCount,
                income: AppFormatters.statMoney(income, currency: currency),
                expense: AppFormatters.statMoney(expense, currency: currency)
            )
        ]
        if let topCategory {
            parts.append(DashboardText.biggestCategory(name: topCategory.name, percent: AppFormatters.percent(topCategory.percent)))
        }
        if let expenseDelta {
            let direction = NSLocalizedString(expenseDelta >= 0 ? "higher" : "lower", comment: "")
            parts.append(DashboardText.expenseDelta(percent: Int(abs(expenseDelta * 100).rounded()), direction: direction))
        }
        return parts.joined(separator: " ")
    }

    var body: some View {
        GlassSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.violet)
                        .frame(width: 42, height: 42)
                        .background(AppTheme.lavender.opacity(0.14), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(NSLocalizedString("AI monthly summary", comment: ""))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                        Text(NSLocalizedString("Plain-language readout", comment: ""))
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }
                }

                Text(summaryText)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.ink.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct StatsShortcutStrip: View {
    var body: some View {
        GlassSurface(padding: 10) {
            HStack(spacing: 10) {
                StatsShortcutTile(
                    title: "Calendar",
                    systemImage: "calendar",
                    tint: AppTheme.violet
                ) {
                    CalendarView()
                }

                StatsShortcutTile(
                    title: "Trends",
                    systemImage: "chart.line.uptrend.xyaxis",
                    tint: AppTheme.teal
                ) {
                    TrendsView()
                }

                StatsShortcutTile(
                    title: "Categories",
                    systemImage: "square.grid.2x2",
                    tint: AppTheme.gold
                ) {
                    CategoriesView()
                }
            }
        }
    }
}

private struct StatsShortcutTile<Destination: View>: View {
    var title: String
    var systemImage: String
    var tint: Color
    @ViewBuilder var destination: Destination

    var body: some View {
        NavigationLink {
            destination
        } label: {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(tint.opacity(0.18), lineWidth: 1)
                    )

                Text(NSLocalizedString(title, comment: ""))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PrimaryPressStyle())
    }
}

private struct StatsHero: View {
    @Environment(\.appCurrency) private var currency
    var monthTitle: String
    var income: Decimal
    var expense: Decimal
    var moveMonth: (Int) -> Void

    private var net: Decimal { income - expense }

    var body: some View {
        GlassSurface(padding: 0) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("Pro Money Manager", comment: ""))
                            .font(.caption.weight(.semibold))
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.violet)
                        Text(monthTitle)
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        if AppLanguage.stored.isRightToLeft {
                            monthButton(systemImage: "chevron.right") { moveMonth(-1) }
                            monthButton(systemImage: "chevron.left") { moveMonth(1) }
                        } else {
                            monthButton(systemImage: "chevron.left") { moveMonth(-1) }
                            monthButton(systemImage: "chevron.right") { moveMonth(1) }
                        }
                    }
                }

                HStack(spacing: 10) {
                    MetricCapsule(title: "Income", value: AppFormatters.statMoney(income, currency: currency), tint: AppTheme.teal)
                    MetricCapsule(title: "Expense", value: AppFormatters.statMoney(expense, currency: currency), tint: AppTheme.coral)
                }

                HStack {
                    Text(NSLocalizedString("Net position", comment: ""))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.muted)
                    Spacer()
                    Text(AppFormatters.statMoney(net, currency: currency))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(net >= 0 ? AppTheme.teal : AppTheme.coral)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.top, 2)
            }
            .padding(20)
            .appHeroBackground()
        }
    }

    private func monthButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 38, height: 38)
                .background(AppTheme.controlSurface, in: Circle())
                .overlay(Circle().stroke(AppTheme.line.opacity(0.72), lineWidth: 1))
        }
        .buttonStyle(PrimaryPressStyle())
    }
}

private struct CategoryStatsSection: View {
    @Environment(\.appCurrency) private var currency
    var categoryShares: [CategoryShare]
    var totalExpense: Decimal
    var visibleMonth: Date
    var transactions: [FinanceTransaction]
    var reportingCurrency: String

    var body: some View {
        VStack(spacing: 16) {
            SectionTitle("Spending by category", subtitle: "Ranked by the selected month")

            if categoryShares.isEmpty {
                EmptyStateView(
                    systemImage: "chart.pie",
                    title: "No category stats",
                    message: "Transactions for this month will appear here after you import or add spending."
                )
            } else {
                GlassSurface {
                    Chart(Array(categoryShares.enumerated()), id: \.element.id) { index, share in
                        SectorMark(
                            angle: .value("Expense", NSDecimalNumber(decimal: share.amount).doubleValue),
                            innerRadius: .ratio(0.58),
                            angularInset: 1.5
                        )
                        .foregroundStyle(AppTheme.categoryPalette[index % AppTheme.categoryPalette.count])
                        .cornerRadius(4)
                    }
                    .chartLegend(.hidden)
                    .frame(height: 268)
                    .chartBackground { proxy in
                        GeometryReader { geometry in
                            if let frame = proxy.plotFrame {
                                let rect = geometry[frame]
                                VStack(spacing: 4) {
                                    Text(NSLocalizedString("Expense", comment: ""))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.muted)
                                    Text(AppFormatters.statMoney(totalExpense, currency: currency))
                                        .font(.system(.headline, design: .rounded).weight(.bold))
                                        .foregroundStyle(AppTheme.ink)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.62)
                                }
                                .frame(width: rect.width * 0.55)
                                .position(x: rect.midX, y: rect.midY)
                            }
                        }
                    }
                }

                GlassSurface(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(categoryShares.enumerated()), id: \.element.id) { index, share in
                            NavigationLink {
                                StatsCategoryDetailView(
                                    categoryName: share.name,
                                    initialMonth: visibleMonth,
                                    transactions: transactions,
                                    reportingCurrency: reportingCurrency
                                )
                            } label: {
                                CategoryShareRow(
                                    share: share,
                                    color: AppTheme.categoryPalette[index % AppTheme.categoryPalette.count],
                                    showDivider: index < categoryShares.count - 1
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

private struct CategoryShareRow: View {
    @Environment(\.appCurrency) private var currency
    var share: CategoryShare
    var color: Color
    var showDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text(AppFormatters.percent(share.percent))
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 34)
                    .background(color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(share.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                    ProgressView(value: min(max(share.percent, 0), 1))
                        .tint(color)
                        .scaleEffect(x: 1, y: 0.7, anchor: .center)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(AppFormatters.statMoney(share.amount, currency: currency))
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.ink.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .layoutPriority(1)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            if showDivider {
                Divider()
                    .overlay(AppTheme.line.opacity(0.5))
                    .padding(.leading, 86)
            }
        }
    }
}

private struct StatsCategoryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appCurrency) private var currency
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \FinanceCategory.sortOrder) private var categories: [FinanceCategory]

    var categoryName: String
    var initialMonth: Date
    var transactions: [FinanceTransaction]
    var reportingCurrency: String

    @State private var visibleMonth: Date
    @State private var editingTransaction: FinanceTransaction?

    private var calendar: Calendar { .current }

    init(categoryName: String, initialMonth: Date, transactions: [FinanceTransaction], reportingCurrency: String) {
        self.categoryName = categoryName
        self.initialMonth = initialMonth
        self.transactions = transactions
        self.reportingCurrency = reportingCurrency
        _visibleMonth = State(initialValue: initialMonth)
    }

    private var monthTransactions: [FinanceTransaction] {
        transactions
            .filter { transaction in
                calendar.isDate(transaction.date, equalTo: visibleMonth, toGranularity: .month)
                && AppFormatters.resolvedCurrency(transaction.currency, fallback: currency) == reportingCurrency
                && matchesCategory(transaction)
            }
            .sorted { $0.date > $1.date }
    }

    private var expense: Decimal {
        monthTransactions
            .filter { $0.kind == .expense }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var income: Decimal {
        monthTransactions
            .filter { $0.kind == .income }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var net: Decimal {
        income - expense
    }

    private var subcategoryTotals: [(name: String, amount: Decimal)] {
        let grouped = Dictionary(grouping: monthTransactions.filter { $0.kind == .expense }) { transaction in
            transaction.subcategoryName?.isEmpty == false ? transaction.subcategoryName! : "No subcategory"
        }
        return grouped
            .map { name, transactions in
                (name: name, amount: transactions.reduce(Decimal(0)) { $0 + $1.amount })
            }
            .sorted { $0.amount > $1.amount }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = AppLanguage.stored.calendar
        formatter.locale = AppLanguage.stored.locale
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: visibleMonth)
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 18) {
                    detailHero

                    if !subcategoryTotals.isEmpty {
                        subcategorySection
                    }

                    SectionTitle("Transactions", subtitle: "\(monthTransactions.count) in \(monthTitle)")

                    if monthTransactions.isEmpty {
                        EmptyStateView(
                            systemImage: "tray",
                            title: "No transactions",
                            message: "Use the month arrows to review this category across other months."
                        )
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(monthTransactions) { transaction in
                                SwipeableTransactionRow(
                                    transaction: transaction,
                                    openAction: { editingTransaction = transaction },
                                    deleteAction: { delete(transaction) }
                                )
                                .id(transaction.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(categoryName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingTransaction) { transaction in
            TransactionEditorView(transaction: transaction, accounts: accounts, categories: categories)
        }
    }

    private func delete(_ transaction: FinanceTransaction) {
        modelContext.delete(transaction)
        try? modelContext.save()
    }

    private var detailHero: some View {
        GlassSurface(padding: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(categoryName)
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text(monthTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.muted)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        if AppLanguage.stored.isRightToLeft {
                            monthButton(systemImage: "chevron.right") { moveMonth(by: -1) }
                            monthButton(systemImage: "chevron.left") { moveMonth(by: 1) }
                        } else {
                            monthButton(systemImage: "chevron.left") { moveMonth(by: -1) }
                            monthButton(systemImage: "chevron.right") { moveMonth(by: 1) }
                        }
                    }
                }

                HStack(spacing: 10) {
                    MetricCapsule(title: "Expense", value: AppFormatters.statMoney(expense, currency: currency), tint: AppTheme.coral)
                    MetricCapsule(title: "Income", value: AppFormatters.statMoney(income, currency: currency), tint: AppTheme.teal)
                }

                HStack(spacing: 10) {
                    MetricCapsule(title: "Net", value: AppFormatters.statMoney(net, currency: currency), tint: net >= 0 ? AppTheme.teal : AppTheme.coral)
                    MetricCapsule(title: "Count", value: "\(monthTransactions.count)", tint: AppTheme.violet)
                }
            }
            .padding(20)
            .appHeroBackground()
        }
    }

    private var subcategorySection: some View {
        VStack(spacing: 12) {
            SectionTitle("Breakdown", subtitle: "Expense inside this category")

            GlassSurface(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(subcategoryTotals.enumerated()), id: \.element.name) { index, item in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(AppTheme.categoryPalette[index % AppTheme.categoryPalette.count])
                                .frame(width: 10, height: 10)

                            Text(item.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                                .lineLimit(1)

                            Spacer()

                            Text(AppFormatters.statMoney(item.amount, currency: currency))
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(AppTheme.ink.opacity(0.78))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)

                        if index < subcategoryTotals.count - 1 {
                            Divider()
                                .overlay(AppTheme.line.opacity(0.5))
                                .padding(.leading, 40)
                        }
                    }
                }
            }
        }
    }

    private func matchesCategory(_ transaction: FinanceTransaction) -> Bool {
        if categoryName == "Uncategorized" {
            return transaction.categoryName?.isEmpty != false
        }
        return transaction.categoryName == categoryName
    }

    private func moveMonth(by value: Int) {
        visibleMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) ?? visibleMonth
    }

    private func monthButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 38, height: 38)
                .background(AppTheme.controlSurface, in: Circle())
                .overlay(Circle().stroke(AppTheme.line.opacity(0.72), lineWidth: 1))
        }
        .buttonStyle(PrimaryPressStyle())
    }
}

private struct BudgetStatsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appCurrency) private var currency
    var budgets: [Budget]
    var categories: [FinanceCategory]
    var monthTransactions: [FinanceTransaction]
    var allTransactions: [FinanceTransaction]
    var monthlyIncome: Decimal
    var monthlyExpense: Decimal
    var visibleMonth: Date

    @State private var showingBudgetEditor = false
    @State private var editingBudget: Budget?

    private var monthBudgets: [Budget] {
        budgets.filter { Calendar.current.isDate($0.monthStart, equalTo: visibleMonth, toGranularity: .month) }
    }

    private var totalBudgeted: Decimal {
        monthBudgets.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var budgetRemaining: Decimal {
        totalBudgeted - monthlyExpense
    }

    private var safeToSpend: Decimal {
        monthlyIncome - monthlyExpense - max(Decimal(0), remainingUpcomingRecurring)
    }

    private var recurringBills: [RecurringCharge] {
        RecurringChargeDetector.detect(from: allTransactions)
    }

    private var remainingUpcomingRecurring: Decimal {
        let today = Date()
        return recurringBills
            .filter { Calendar.current.isDate($0.nextDate, equalTo: visibleMonth, toGranularity: .month) && $0.nextDate >= Calendar.current.startOfDay(for: today) }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    var body: some View {
        VStack(spacing: 16) {
            GlassSurface {
                VStack(alignment: .leading, spacing: 14) {
                    SectionTitle("Budget plan", subtitle: "Monthly limits, remaining spend, and detected recurring charges")
                    HStack(spacing: 10) {
                        MetricCapsule(title: "Safe to spend", value: AppFormatters.statMoney(safeToSpend, currency: currency), tint: safeToSpend >= 0 ? AppTheme.teal : AppTheme.coral)
                        MetricCapsule(title: "Budget left", value: AppFormatters.statMoney(budgetRemaining, currency: currency), tint: budgetRemaining >= 0 ? AppTheme.mint : AppTheme.coral)
                    }
                    HStack(spacing: 10) {
                        MetricCapsule(title: "Budgeted", value: AppFormatters.statMoney(totalBudgeted, currency: currency), tint: AppTheme.lavender)
                        MetricCapsule(title: "Upcoming bills", value: AppFormatters.statMoney(remainingUpcomingRecurring, currency: currency), tint: AppTheme.gold)
                    }
                    Button {
                        showingBudgetEditor = true
                    } label: {
                        Label(NSLocalizedString("Add budget", comment: ""), systemImage: "plus")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(PrimaryPressStyle())

                    if !monthBudgets.isEmpty {
                        Button(action: rolloverBudgets) {
                            Label(NSLocalizedString("Copy to next month", comment: ""), systemImage: "arrow.right.circle")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppTheme.violet)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.lavender.opacity(0.15), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(PrimaryPressStyle())
                    }
                }
            }

            if monthBudgets.isEmpty {
                EmptyStateView(
                    systemImage: "target",
                    title: "No budgets yet",
                    message: "Add category budgets to see remaining spend and overspend warnings."
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(monthBudgets) { budget in
                        let spent = spentAmount(for: budget)
                        Button {
                            editingBudget = budget
                        } label: {
                            GlassSurface {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(budget.categoryName)
                                                .font(.headline.weight(.semibold))
                                                .foregroundStyle(AppTheme.ink)
                                            if let subcategory = budget.subcategoryName {
                                                Text(subcategory)
                                                    .font(.caption.weight(.medium))
                                                    .foregroundStyle(AppTheme.muted)
                                            }
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text("\(AppFormatters.statMoney(spent, currency: currency)) / \(AppFormatters.statMoney(budget.amount, currency: currency))")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(AppTheme.muted)
                                            Text(AppFormatters.statMoney(budget.amount - spent, currency: currency))
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(spent > budget.amount ? AppTheme.coral : AppTheme.teal)
                                        }
                                    }
                                    ProgressView(value: progress(spent: spent, limit: budget.amount))
                                        .tint(progress(spent: spent, limit: budget.amount) >= 1 ? AppTheme.coral : AppTheme.teal)
                                }
                            }
                        }
                        .buttonStyle(PrimaryPressStyle())
                    }
                }
            }

            RecurringBillsSection(charges: recurringBills, visibleMonth: visibleMonth)
        }
        .sheet(isPresented: $showingBudgetEditor) {
            BudgetEditorView(budget: nil, categories: categories, visibleMonth: visibleMonth)
        }
        .sheet(item: $editingBudget) { budget in
            BudgetEditorView(budget: budget, categories: categories, visibleMonth: visibleMonth)
        }
    }

    private func rolloverBudgets() {
        guard let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: visibleMonth) else { return }
        let components = Calendar.current.dateComponents([.year, .month], from: nextMonth)
        let nextMonthStart = Calendar.current.date(from: components) ?? nextMonth
        let existingNextMonth = budgets.filter {
            Calendar.current.isDate($0.monthStart, equalTo: nextMonthStart, toGranularity: .month)
        }
        for budget in monthBudgets {
            let alreadyExists = existingNextMonth.contains {
                $0.categoryName == budget.categoryName && $0.subcategoryName == budget.subcategoryName
            }
            guard !alreadyExists else { continue }
            modelContext.insert(Budget(
                categoryName: budget.categoryName,
                subcategoryName: budget.subcategoryName,
                monthStart: nextMonthStart,
                amount: budget.amount,
                currency: budget.currency
            ))
        }
        try? modelContext.save()
    }

    private func spentAmount(for budget: Budget) -> Decimal {
        monthTransactions
            .filter { $0.categoryName == budget.categoryName && $0.kind == .expense }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    private func progress(spent: Decimal, limit: Decimal) -> Double {
        let spentValue = NSDecimalNumber(decimal: spent).doubleValue
        let limitValue = max(NSDecimalNumber(decimal: limit).doubleValue, 1)
        return min(spentValue / limitValue, 1)
    }
}

private struct BudgetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var budget: Budget?
    var categories: [FinanceCategory]
    var visibleMonth: Date

    @State private var categoryName = ""
    @State private var subcategoryName = ""
    @State private var amountText = ""
    @State private var currency = "USD"

    private var parentCategories: [FinanceCategory] {
        categories.filter { $0.parentName == nil && $0.kind == .expense && !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var subcategories: [FinanceCategory] {
        categories.filter { $0.parentName == categoryName && !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var amount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX"))
    }

    private var monthStart: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: visibleMonth)
        return Calendar.current.date(from: components) ?? visibleMonth
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("Budget", comment: "")) {
                    Picker("Category", selection: $categoryName) {
                        ForEach(parentCategories) { category in
                            Text(category.name).tag(category.name)
                        }
                    }
                    Picker("Subcategory", selection: $subcategoryName) {
                        Text(NSLocalizedString("All", comment: "")).tag("")
                        ForEach(subcategories) { category in
                            Text(category.name).tag(category.name)
                        }
                    }
                    LabeledNumberField(label: "Monthly limit", text: $amountText, prompt: "0.00")
                    LabeledCurrencyButton(currency: $currency)
                }

                if budget != nil {
                    Section {
                        Button(NSLocalizedString("Delete budget", comment: ""), role: .destructive, action: deleteBudget)
                    }
                }
            }
            .appFormStyle()
            .navigationTitle(budget == nil ? "Add Budget" : "Edit Budget")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Save", comment: ""), action: save)
                        .disabled(categoryName.isEmpty || amount == nil)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let budget else {
            categoryName = parentCategories.first?.name ?? ""
            amountText = ""
            return
        }
        categoryName = budget.categoryName
        subcategoryName = budget.subcategoryName ?? ""
        amountText = NSDecimalNumber(decimal: budget.amount).stringValue
        currency = budget.currency
    }

    private func save() {
        guard let amount else { return }
        if let budget {
            budget.categoryName = categoryName
            budget.subcategoryName = subcategoryName.isEmpty ? nil : subcategoryName
            budget.amount = amount
            budget.currency = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().isEmpty ? "USD" : currency.uppercased()
        } else {
            modelContext.insert(
                Budget(
                    categoryName: categoryName,
                    subcategoryName: subcategoryName.isEmpty ? nil : subcategoryName,
                    monthStart: monthStart,
                    amount: amount,
                    currency: currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().isEmpty ? "USD" : currency.uppercased()
                )
            )
        }
        try? modelContext.save()
        dismiss()
    }

    private func deleteBudget() {
        guard let budget else { return }
        modelContext.delete(budget)
        try? modelContext.save()
        dismiss()
    }
}

private struct RecurringCharge: Identifiable {
    var id: String { normalizedMerchant }
    var merchant: String
    var normalizedMerchant: String
    var amount: Decimal
    var nextDate: Date
    var sampleCount: Int
    var increased: Bool
}

private enum RecurringChargeDetector {
    static func detect(from transactions: [FinanceTransaction]) -> [RecurringCharge] {
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
            let next = calendar.date(byAdding: .month, value: 1, to: last.date) ?? last.date
            let previousAmount = sorted.dropLast().last?.amount ?? last.amount
            return RecurringCharge(
                merchant: last.merchant.isEmpty ? merchant : last.merchant,
                normalizedMerchant: merchant,
                amount: average,
                nextDate: next,
                sampleCount: sorted.count,
                increased: last.amount > previousAmount * Decimal(1.1)
            )
        }
        .sorted { $0.nextDate < $1.nextDate }
    }
}

private struct RecurringBillsSection: View {
    @Environment(\.appCurrency) private var currency
    var charges: [RecurringCharge]
    var visibleMonth: Date

    private var monthCharges: [RecurringCharge] {
        charges.filter { Calendar.current.isDate($0.nextDate, equalTo: visibleMonth, toGranularity: .month) }
    }

    var body: some View {
        VStack(spacing: 12) {
            SectionTitle("Recurring bills", subtitle: "Detected from repeated merchant charges")
            if monthCharges.isEmpty {
                EmptyStateView(
                    systemImage: "repeat",
                    title: "No recurring bills detected",
                    message: "Repeated monthly merchants will appear here automatically."
                )
            } else {
                GlassSurface(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(monthCharges) { charge in
                            HStack(spacing: 12) {
                                Image(systemName: charge.increased ? "exclamationmark.arrow.triangle.2.circlepath" : "repeat")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(charge.increased ? AppTheme.coral : AppTheme.violet)
                                    .frame(width: 38, height: 38)
                                    .background((charge.increased ? AppTheme.coral : AppTheme.lavender).opacity(0.13), in: Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(charge.merchant)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.ink)
                                        .lineLimit(1)
                                    Text("Expected \(AppFormatters.dayString(from: charge.nextDate)) • \(charge.sampleCount) samples")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.muted)
                                }
                                Spacer()
                                Text(AppFormatters.statMoney(charge.amount, currency: currency))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppTheme.ink)
                            }
                            .padding(16)
                            Divider().overlay(AppTheme.line.opacity(0.45))
                        }
                    }
                }
            }
        }
    }
}

private struct NoteStatsSection: View {
    @Environment(\.appCurrency) private var currency
    var monthTransactions: [FinanceTransaction]

    private var notes: [FinanceTransaction] {
        monthTransactions
            .filter { !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 16) {
            SectionTitle("Notes", subtitle: "Context saved with this month’s transactions")

            if notes.isEmpty {
                EmptyStateView(
                    systemImage: "note.text",
                    title: "No notes",
                    message: "Transaction notes for the selected month will appear here."
                )
            } else {
                GlassSurface(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(notes) { transaction in
                            VStack(alignment: .leading, spacing: 7) {
                                HStack {
                                    Text(transaction.merchant)
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(AppTheme.ink)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(AppFormatters.statMoney(transaction.amount, currency: currency))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(transaction.kind == .income ? AppTheme.teal : AppTheme.coral)
                                }
                                Text(transaction.note)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.muted)
                                Text(AppFormatters.dayString(from: transaction.date))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.muted.opacity(0.72))
                            }
                            .padding(18)
                            Divider().overlay(AppTheme.line.opacity(0.5))
                        }
                    }
                }
            }
        }
    }
}

private enum DashboardCard: String, CaseIterable, Identifiable {
    case hero = "hero"
    case insights = "insights"
    case summary = "summary"
    case content = "content"
    case budget = "budget"
    case notes = "notes"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hero: "Month overview"
        case .insights: "AI insights"
        case .summary: "Monthly summary"
        case .content: "Spending by category"
        case .budget: "Budget plan"
        case .notes: "Notes"
        }
    }

    var icon: String {
        switch self {
        case .hero: "chart.bar"
        case .insights: "sparkles"
        case .summary: "text.quote"
        case .content: "chart.pie"
        case .budget: "target"
        case .notes: "note.text"
        }
    }
}

private struct DashboardLayoutEditor: View {
    @Environment(\.dismiss) private var dismiss
    var initialOrder: [DashboardCard]
    var initialHidden: Set<DashboardCard>
    var onSave: ([DashboardCard], Set<DashboardCard>) -> Void

    @State private var order: [DashboardCard]
    @State private var hidden: Set<DashboardCard>

    init(cardOrder: [DashboardCard], hiddenCards: Set<DashboardCard>, onSave: @escaping ([DashboardCard], Set<DashboardCard>) -> Void) {
        self.initialOrder = cardOrder
        self.initialHidden = hiddenCards
        self.onSave = onSave
        _order = State(initialValue: cardOrder)
        _hidden = State(initialValue: hiddenCards)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                List {
                    Section(NSLocalizedString("Visible cards (drag to reorder)", comment: "")) {
                        ForEach(order) { card in
                            HStack(spacing: 12) {
                                Image(systemName: card.icon)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppTheme.violet)
                                    .frame(width: 34, height: 34)
                                    .background(AppTheme.lavender.opacity(0.14), in: Circle())
                                Text(card.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.ink)
                                Spacer()
                                if hidden.contains(card) {
                                    Image(systemName: "eye.slash")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(AppTheme.muted)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if hidden.contains(card) {
                                    hidden.remove(card)
                                } else {
                                    hidden.insert(card)
                                }
                            }
                        }
                        .onMove(perform: move)
                    }

                    Section {
                        Button {
                            order = DashboardCard.allCases
                            hidden.removeAll()
                        } label: {
                            Label(NSLocalizedString("Reset to default", comment: ""), systemImage: "arrow.counterclockwise")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.violet)
                        }
                    }
                }
                .appListStyle()
            }
            .navigationTitle(NSLocalizedString("Customize Dashboard", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Save", comment: "")) {
                        onSave(order, hidden)
                        dismiss()
                    }
                }
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        order.move(fromOffsets: source, toOffset: destination)
    }
}
