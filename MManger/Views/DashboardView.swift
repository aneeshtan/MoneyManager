import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]
    @Query(sort: \Budget.monthStart, order: .reverse) private var budgets: [Budget]
    @Query(sort: \FinanceCategory.sortOrder) private var categories: [FinanceCategory]
    @Environment(\.appCurrency) private var currency

    @State private var selectedMode: StatsMode = .stats
    @State private var visibleMonth: Date = .now

    private var calendar: Calendar { .current }

    private var monthTransactions: [FinanceTransaction] {
        transactions.filter { calendar.isDate($0.date, equalTo: visibleMonth, toGranularity: .month) }
    }

    private var monthlyExpense: Decimal {
        monthTransactions.filter { $0.kind == .expense }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var monthlyIncome: Decimal {
        monthTransactions.filter { $0.kind == .income }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var previousMonthTransactions: [FinanceTransaction] {
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: visibleMonth) else { return [] }
        return transactions.filter { calendar.isDate($0.date, equalTo: previousMonth, toGranularity: .month) }
    }

    private var previousMonthlyExpense: Decimal {
        previousMonthTransactions.filter { $0.kind == .expense }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var categoryShares: [CategoryShare] {
        let grouped = Dictionary(grouping: monthTransactions.filter { $0.kind == .expense }) { transaction in
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
            monthTransactions: monthTransactions,
            previousMonthTransactions: previousMonthTransactions,
            categoryShares: categoryShares,
            monthlyExpense: monthlyExpense,
            currency: currency
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        StatsHero(
                            mode: $selectedMode,
                            monthTitle: monthTitle,
                            income: monthlyIncome,
                            expense: monthlyExpense,
                            moveMonth: moveMonth
                        )

                        SmartInsightsSection(insights: smartInsights)

                        MonthlySummarySection(
                            monthTitle: monthTitle,
                            income: monthlyIncome,
                            expense: monthlyExpense,
                            previousExpense: previousMonthlyExpense,
                            categoryShares: categoryShares,
                            transactionCount: monthTransactions.count
                        )

                        switch selectedMode {
                        case .stats:
                            CategoryStatsSection(
                                categoryShares: categoryShares,
                                totalExpense: monthlyExpense,
                                visibleMonth: visibleMonth,
                                transactions: transactions
                            )
                        case .budget:
                            BudgetStatsSection(
                                budgets: budgets,
                                categories: categories,
                                monthTransactions: monthTransactions,
                                allTransactions: transactions,
                                monthlyIncome: monthlyIncome,
                                monthlyExpense: monthlyExpense,
                                visibleMonth: visibleMonth
                            )
                        case .note:
                            NoteStatsSection(monthTransactions: monthTransactions)
                        }
                    }
                    .environment(\.appCurrency, currency)
                    .adaptiveScreenContent()
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: visibleMonth)
    }

    private func moveMonth(by value: Int) {
        visibleMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) ?? visibleMonth
    }
}

private enum StatsMode: String, CaseIterable, Identifiable {
    case stats = "Stats"
    case budget = "Budget"
    case note = "Note"

    var id: String { rawValue }
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
                        title: "Needs review",
                        message: "\(uncategorized.count) transactions are uncategorized. Fixing them will improve future auto-categorization.",
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
                let direction = delta > 0 ? "up" : "down"
                insights.append(
                    SmartInsight(
                        title: "Spending \(direction) \(Int(abs(delta * 100).rounded()))%",
                        message: "Compared with the previous month, expenses moved from \(AppFormatters.statMoney(previousExpense, currency: currency)) to \(AppFormatters.statMoney(monthlyExpense, currency: currency)).",
                        systemImage: delta > 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                        tint: delta > 0 ? AppTheme.coral : AppTheme.teal
                    )
                )
            }
        }

        if let top = categoryShares.first, top.percent >= 0.45 {
            insights.append(
                SmartInsight(
                    title: "\(top.name) dominates",
                    message: "\(AppFormatters.percent(top.percent)) of this month’s spending is in this category.",
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
                    title: "Possible duplicates",
                    message: "\(possibleDuplicates) same-day transactions share the same account, merchant, and amount.",
                    systemImage: "doc.on.doc",
                    tint: AppTheme.rose
                )
            )
        }

        if insights.isEmpty {
            insights.append(
                SmartInsight(
                    title: "AI watch is clear",
                    message: "No unusual category, duplicate, or review signals found for this month.",
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
        var parts = ["In \(monthTitle), \(transactionCount) transactions produced \(AppFormatters.statMoney(income, currency: currency)) income and \(AppFormatters.statMoney(expense, currency: currency)) spending."]
        if let topCategory {
            parts.append("\(topCategory.name) is the biggest category at \(AppFormatters.percent(topCategory.percent)) of spending.")
        }
        if let expenseDelta {
            let direction = expenseDelta >= 0 ? "higher" : "lower"
            parts.append("Expenses are \(Int(abs(expenseDelta * 100).rounded()))% \(direction) than the previous month.")
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
                        Text("AI monthly summary")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                        Text("Plain-language readout")
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

private struct StatsHero: View {
    @Environment(\.appCurrency) private var currency
    @Binding var mode: StatsMode
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
                        Text("Pro Money Manager")
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
                        monthButton(systemImage: "chevron.left") { moveMonth(-1) }
                        monthButton(systemImage: "chevron.right") { moveMonth(1) }
                    }
                }

                Picker("Stats mode", selection: $mode) {
                    ForEach(StatsMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 10) {
                    MetricCapsule(title: "Income", value: AppFormatters.statMoney(income, currency: currency), tint: AppTheme.teal)
                    MetricCapsule(title: "Expense", value: AppFormatters.statMoney(expense, currency: currency), tint: AppTheme.coral)
                }

                HStack {
                    Text("Net position")
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
            .background(
                LinearGradient(
                    colors: [
                        .white.opacity(0.88),
                        AppTheme.lavender.opacity(0.13),
                        AppTheme.mint.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private func monthButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 38, height: 38)
                .background(.white.opacity(0.72), in: Circle())
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
                                    Text("Expense")
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
                                    transactions: transactions
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

    @State private var visibleMonth: Date
    @State private var editingTransaction: FinanceTransaction?

    private var calendar: Calendar { .current }

    init(categoryName: String, initialMonth: Date, transactions: [FinanceTransaction]) {
        self.categoryName = categoryName
        self.initialMonth = initialMonth
        self.transactions = transactions
        _visibleMonth = State(initialValue: initialMonth)
    }

    private var monthTransactions: [FinanceTransaction] {
        transactions
            .filter { transaction in
                calendar.isDate(transaction.date, equalTo: visibleMonth, toGranularity: .month)
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
                        monthButton(systemImage: "chevron.left") { moveMonth(by: -1) }
                        monthButton(systemImage: "chevron.right") { moveMonth(by: 1) }
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
            .background(
                LinearGradient(
                    colors: [
                        .white.opacity(0.9),
                        AppTheme.lavender.opacity(0.15),
                        AppTheme.mint.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
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
                .background(.white.opacity(0.72), in: Circle())
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
                        Label("Add budget", systemImage: "plus")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(PrimaryPressStyle())

                    if !monthBudgets.isEmpty {
                        Button(action: rolloverBudgets) {
                            Label("Copy to next month", systemImage: "arrow.right.circle")
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
                Section("Budget") {
                    Picker("Category", selection: $categoryName) {
                        ForEach(parentCategories) { category in
                            Text(category.name).tag(category.name)
                        }
                    }
                    Picker("Subcategory", selection: $subcategoryName) {
                        Text("All").tag("")
                        ForEach(subcategories) { category in
                            Text(category.name).tag(category.name)
                        }
                    }
                    TextField("Monthly limit", text: $amountText)
                        .keyboardType(.decimalPad)
                    TextField("Currency", text: $currency)
                        .textInputAutocapitalization(.characters)
                }

                if budget != nil {
                    Section {
                        Button("Delete budget", role: .destructive, action: deleteBudget)
                    }
                }
            }
            .navigationTitle(budget == nil ? "Add Budget" : "Edit Budget")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
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
                                    Text("Expected \(AppFormatters.day.string(from: charge.nextDate)) • \(charge.sampleCount) samples")
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
                                Text(AppFormatters.day.string(from: transaction.date))
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
