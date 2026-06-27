import SwiftUI
import SwiftData
import Charts

struct TrendsView: View {
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    @State private var selectedChart: ChartMode = .spending
    @State private var monthCount = 12

    private var calendar: Calendar { .current }

    // MARK: - Data

    private var months: [Date] {
        (0..<monthCount).compactMap {
            calendar.date(byAdding: .month, value: -($0), to: monthStart(.now))
        }.reversed()
    }

    private func monthStart(_ date: Date) -> Date {
        let c = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: c) ?? date
    }

    private struct MonthPoint: Identifiable {
        var id: Date { month }
        var month: Date
        var income: Double
        var expense: Double
        var net: Double
        var netWorth: Double
    }

    private var points: [MonthPoint] {
        var runningNetWorth: Double = {
            accounts.reduce(0.0) { $0 + NSDecimalNumber(decimal: $1.openingBalance).doubleValue }
        }()

        return months.map { month in
            let monthTxns = transactions.filter {
                calendar.isDate($0.date, equalTo: month, toGranularity: .month)
            }
            let income = monthTxns.filter { $0.kind == .income }
                .reduce(0.0) { $0 + NSDecimalNumber(decimal: $1.amount).doubleValue }
            let expense = monthTxns.filter { $0.kind == .expense }
                .reduce(0.0) { $0 + NSDecimalNumber(decimal: $1.amount).doubleValue }
            runningNetWorth += income - expense
            return MonthPoint(
                month: month,
                income: income,
                expense: expense,
                net: income - expense,
                netWorth: runningNetWorth
            )
        }
    }

    private var totalIncome: Double { points.reduce(0) { $0 + $1.income } }
    private var totalExpense: Double { points.reduce(0) { $0 + $1.expense } }
    private var avgMonthlyExpense: Double { points.isEmpty ? 0 : totalExpense / Double(points.count) }
    private var bestMonth: MonthPoint? { points.min(by: { $0.expense < $1.expense }) }
    private var worstMonth: MonthPoint? { points.max(by: { $0.expense < $1.expense }) }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        heroCard
                        chartCard
                        summaryCards
                        categoryTrendSection
                    }
                    .adaptiveScreenContent()
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach([6, 12, 24], id: \.self) { n in
                            Button("\(n) months") { monthCount = n }
                        }
                    } label: {
                        Label("\(monthCount)M", systemImage: "calendar")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        GlassSurface(padding: 0) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Trends")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(AppTheme.violet)
                    Text("Last \(monthCount) months")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                }

                HStack(spacing: 10) {
                    MetricCapsule(title: "Total income", value: AppFormatters.money(Decimal(totalIncome)), tint: AppTheme.teal)
                    MetricCapsule(title: "Total expense", value: AppFormatters.money(Decimal(totalExpense)), tint: AppTheme.coral)
                }

                HStack(spacing: 10) {
                    MetricCapsule(title: "Avg/month", value: AppFormatters.money(Decimal(avgMonthlyExpense)), tint: AppTheme.gold)
                    MetricCapsule(
                        title: "Net savings",
                        value: AppFormatters.money(Decimal(totalIncome - totalExpense)),
                        tint: (totalIncome - totalExpense) >= 0 ? AppTheme.mint : AppTheme.rose
                    )
                }

                Picker("Chart", selection: $selectedChart) {
                    ForEach(ChartMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [.white.opacity(0.88), AppTheme.lavender.opacity(0.12), AppTheme.mint.opacity(0.1)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
        }
    }

    // MARK: - Chart

    private var chartCard: some View {
        GlassSurface {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(selectedChart.label, subtitle: selectedChart.subtitle)
                Chart(points) { point in
                    switch selectedChart {
                    case .spending:
                        LineMark(
                            x: .value("Month", point.month, unit: .month),
                            y: .value("Expense", point.expense)
                        )
                        .foregroundStyle(AppTheme.coral)
                        .interpolationMethod(.catmullRom)
                        AreaMark(
                            x: .value("Month", point.month, unit: .month),
                            y: .value("Expense", point.expense)
                        )
                        .foregroundStyle(AppTheme.coral.opacity(0.08))
                        .interpolationMethod(.catmullRom)
                        LineMark(
                            x: .value("Month", point.month, unit: .month),
                            y: .value("Income", point.income)
                        )
                        .foregroundStyle(AppTheme.teal)
                        .interpolationMethod(.catmullRom)

                    case .netWorth:
                        LineMark(
                            x: .value("Month", point.month, unit: .month),
                            y: .value("Net worth", point.netWorth)
                        )
                        .foregroundStyle(point.netWorth >= 0 ? AppTheme.violet : AppTheme.coral)
                        .interpolationMethod(.catmullRom)
                        AreaMark(
                            x: .value("Month", point.month, unit: .month),
                            y: .value("Net worth", point.netWorth)
                        )
                        .foregroundStyle((point.netWorth >= 0 ? AppTheme.violet : AppTheme.coral).opacity(0.08))
                        .interpolationMethod(.catmullRom)

                    case .net:
                        BarMark(
                            x: .value("Month", point.month, unit: .month),
                            y: .value("Net", point.net)
                        )
                        .foregroundStyle(point.net >= 0 ? AppTheme.teal : AppTheme.coral)
                        .cornerRadius(4)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: monthCount > 12 ? 3 : 2)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) {
                        AxisValueLabel()
                            .font(.caption2)
                        AxisGridLine()
                    }
                }
                .frame(height: 220)

                if selectedChart == .spending {
                    HStack(spacing: 16) {
                        legendDot(color: AppTheme.coral, label: "Expense")
                        legendDot(color: AppTheme.teal, label: "Income")
                    }
                }
            }
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption.weight(.medium)).foregroundStyle(AppTheme.muted)
        }
    }

    // MARK: - Summary cards

    private var summaryCards: some View {
        VStack(spacing: 12) {
            SectionTitle("Highlights", subtitle: "Best and worst months in the period")
            HStack(spacing: 12) {
                if let best = bestMonth {
                    highlightCard(
                        title: "Lowest spend",
                        month: best.month,
                        amount: best.expense,
                        tint: AppTheme.teal,
                        icon: "arrow.down.circle.fill"
                    )
                }
                if let worst = worstMonth {
                    highlightCard(
                        title: "Highest spend",
                        month: worst.month,
                        amount: worst.expense,
                        tint: AppTheme.coral,
                        icon: "arrow.up.circle.fill"
                    )
                }
            }
        }
    }

    private func highlightCard(title: String, month: Date, amount: Double, tint: Color, icon: String) -> some View {
        GlassSurface(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                    Text(AppFormatters.money(Decimal(amount)))
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(monthLabel(month))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Category trend

    private var categoryTrendSection: some View {
        VStack(spacing: 12) {
            SectionTitle("Category breakdown", subtitle: "Total spending per category over \(monthCount) months")
            let shares = categoryTotals()
            if shares.isEmpty {
                EmptyStateView(systemImage: "chart.line.uptrend.xyaxis", title: "No data", message: "Import transactions to see trends.")
            } else {
                GlassSurface(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(shares.enumerated()), id: \.element.name) { index, item in
                            HStack(spacing: 14) {
                                Text(AppFormatters.percent(item.share))
                                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 54, height: 34)
                                    .background(AppTheme.categoryPalette[index % AppTheme.categoryPalette.count], in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.ink)
                                        .lineLimit(1)
                                    ProgressView(value: item.share)
                                        .tint(AppTheme.categoryPalette[index % AppTheme.categoryPalette.count])
                                        .scaleEffect(x: 1, y: 0.7, anchor: .center)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Text(AppFormatters.money(Decimal(item.total)))
                                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                                    .foregroundStyle(AppTheme.ink.opacity(0.78))
                                    .minimumScaleFactor(0.65)
                                    .lineLimit(1)
                                    .layoutPriority(1)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            if index < shares.count - 1 {
                                Divider().overlay(AppTheme.line.opacity(0.5)).padding(.leading, 86)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private struct CategoryTotal {
        var name: String
        var total: Double
        var share: Double
    }

    private func categoryTotals() -> [CategoryTotal] {
        let start = months.first ?? .now
        let periodTxns = transactions.filter {
            $0.kind == .expense && $0.date >= start
        }
        let grouped = Dictionary(grouping: periodTxns) {
            $0.categoryName?.isEmpty == false ? $0.categoryName! : "Uncategorized"
        }
        let totalAll = periodTxns.reduce(0.0) { $0 + NSDecimalNumber(decimal: $1.amount).doubleValue }
        guard totalAll > 0 else { return [] }
        return grouped
            .map { name, txns in
                let t = txns.reduce(0.0) { $0 + NSDecimalNumber(decimal: $1.amount).doubleValue }
                return CategoryTotal(name: name, total: t, share: t / totalAll)
            }
            .sorted { $0.total > $1.total }
            .prefix(10)
            .map { $0 }
    }

    private func monthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: date)
    }
}

private enum ChartMode: String, CaseIterable, Identifiable {
    case spending, netWorth, net
    var id: String { rawValue }
    var label: String {
        switch self {
        case .spending: "Income vs Expense"
        case .netWorth: "Net Worth"
        case .net: "Monthly Net"
        }
    }
    var subtitle: String {
        switch self {
        case .spending: "Income and expense lines over time"
        case .netWorth: "Cumulative net worth over time"
        case .net: "Monthly surplus or deficit"
        }
    }
}
