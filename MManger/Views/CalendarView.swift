import SwiftUI
import SwiftData

struct CalendarDaySummary: Equatable {
    var date: Date
    var income: Decimal = 0
    var expense: Decimal = 0
    var transactionCount: Int = 0

    var net: Decimal { income - expense }
    var hasTransactions: Bool { transactionCount > 0 }

    mutating func add(_ transaction: FinanceTransaction) {
        transactionCount += 1
        switch transaction.kind {
        case .income:
            income += transaction.amount
        case .expense:
            expense += transaction.amount
        case .transfer:
            break
        }
    }
}

struct CalendarMonthSummary {
    var month: Date
    var days: [Date]
    var leadingBlankCount: Int
    var income: Decimal
    var expense: Decimal
    var transactionCount: Int
    var largestDailyMovement: Decimal

    private var summariesByDay: [Date: CalendarDaySummary]
    private var calendar: Calendar

    var net: Decimal { income - expense }

    var activeDayCount: Int {
        summariesByDay.values.filter(\.hasTransactions).count
    }

    init(month: Date, transactions: [FinanceTransaction], calendar: Calendar) {
        self.month = month
        self.calendar = calendar
        let monthComponents = calendar.dateComponents([.year, .month], from: month)
        let firstOfMonth = calendar.date(from: monthComponents) ?? month
        let range = calendar.range(of: .day, in: .month, for: month) ?? 1..<1
        self.days = range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)
        }

        let weekday = calendar.component(.weekday, from: firstOfMonth)
        self.leadingBlankCount = (weekday - calendar.firstWeekday + 7) % 7

        var summaries: [Date: CalendarDaySummary] = [:]
        var monthIncome = Decimal(0)
        var monthExpense = Decimal(0)
        var monthTransactionCount = 0

        for transaction in transactions where calendar.isDate(transaction.date, equalTo: month, toGranularity: .month) {
            let day = calendar.startOfDay(for: transaction.date)
            if summaries[day] == nil {
                summaries[day] = CalendarDaySummary(date: day)
            }
            summaries[day]?.add(transaction)
            monthTransactionCount += 1
            switch transaction.kind {
            case .income:
                monthIncome += transaction.amount
            case .expense:
                monthExpense += transaction.amount
            case .transfer:
                break
            }
        }

        self.summariesByDay = summaries
        self.income = monthIncome
        self.expense = monthExpense
        self.transactionCount = monthTransactionCount
        self.largestDailyMovement = summaries.values.reduce(Decimal(0)) { partial, summary in
            max(partial, summary.income, summary.expense)
        }
    }

    func summary(for day: Date) -> CalendarDaySummary {
        let startOfDay = calendar.startOfDay(for: day)
        return summariesByDay[startOfDay] ?? CalendarDaySummary(date: startOfDay)
    }
}

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appCurrency) private var currency
    @Environment(\.appCalendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \FinanceCategory.sortOrder) private var categories: [FinanceCategory]
    @State private var visibleMonth: Date = .now
    @State private var selectedDay: Date?
    @State private var showingEditor = false
    @State private var editingTransaction: FinanceTransaction?

    private var monthSummary: CalendarMonthSummary {
        CalendarMonthSummary(month: visibleMonth, transactions: transactions, calendar: calendar)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = AppLanguage.stored.locale
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: visibleMonth)
    }

    private func transactionsForDay(_ day: Date) -> [FinanceTransaction] {
        transactions.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    private func isToday(_ day: Date) -> Bool {
        calendar.isDateInToday(day)
    }

    private func isSelected(_ day: Date) -> Bool {
        guard let selectedDay else { return false }
        return calendar.isDate(day, inSameDayAs: selectedDay)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        heroCard

                        calendarGrid

                        if let selectedDay {
                            selectedDaySection(selectedDay)
                        } else {
                            calendarPrompt
                        }
                    }
                    .adaptiveScreenContent()
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(NSLocalizedString("Calendar", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(NSLocalizedString("Add transaction", comment: ""))
                }
            }
            .sheet(isPresented: $showingEditor) {
                TransactionEditorView(accounts: accounts, categories: categories)
            }
            .sheet(item: $editingTransaction) { transaction in
                TransactionEditorView(transaction: transaction, accounts: accounts, categories: categories)
            }
        }
    }

    private var heroCard: some View {
        GlassSurface(padding: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("Calendar", comment: ""))
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
                            monthButton(systemImage: "chevron.right") { moveMonth(by: -1) }
                            monthButton(systemImage: "chevron.left") { moveMonth(by: 1) }
                        } else {
                            monthButton(systemImage: "chevron.left") { moveMonth(by: -1) }
                            monthButton(systemImage: "chevron.right") { moveMonth(by: 1) }
                        }
                    }
                }

                HStack(spacing: 10) {
                    MetricCapsule(title: "Income", value: AppFormatters.statMoney(monthSummary.income, currency: currency), tint: AppTheme.teal)
                    MetricCapsule(title: "Expense", value: AppFormatters.statMoney(monthSummary.expense, currency: currency), tint: AppTheme.coral)
                }

                HStack(spacing: 10) {
                    MetricCapsule(title: "Net", value: AppFormatters.statMoney(abs(monthSummary.net), currency: currency), tint: monthSummary.net >= 0 ? AppTheme.teal : AppTheme.coral)
                    MetricCapsule(title: "Active days", value: "\(monthSummary.activeDayCount)", tint: AppTheme.lavender)
                }
            }
            .padding(20)
            .appHeroBackground()
        }
    }

    private var calendarGrid: some View {
        GlassSurface(padding: 14) {
            VStack(spacing: 14) {
                HStack(spacing: 6) {
                    ForEach(orderedWeekdaySymbols, id: \.self) { weekday in
                        Text(weekday)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.muted)
                            .frame(height: 20)
                            .frame(maxWidth: .infinity)
                    }
                }

                let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 7)
                LazyVGrid(columns: columns, spacing: 7) {
                    ForEach(0..<monthSummary.leadingBlankCount, id: \.self) { _ in
                        Color.clear
                            .aspectRatio(0.95, contentMode: .fit)
                    }

                    ForEach(monthSummary.days, id: \.self) { day in
                        dayCell(day, summary: monthSummary.summary(for: day))
                    }
                }
            }
        }
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard !symbols.isEmpty else { return [] }
        let start = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[start...] + symbols[..<start])
    }

    private func dayCell(_ day: Date, summary: CalendarDaySummary) -> some View {
        let isToday = isToday(day)
        let isSelected = isSelected(day)
        let selectedDayInk = Color(red: 0.965, green: 0.972, blue: 0.990)

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                selectedDay = day
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 4) {
                    Text("\(calendar.component(.day, from: day))")
                        .font(.system(size: 16, weight: isToday ? .bold : .semibold, design: .rounded))
                        .foregroundStyle(isToday ? selectedDayInk : AppTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if summary.hasTransactions {
                        Circle()
                            .fill(isToday ? selectedDayInk.opacity(0.92) : activityDotTint(for: summary))
                            .frame(width: 7, height: 7)
                            .padding(.top, 5)
                    }
                }

                Spacer(minLength: 3)

                CalendarActivityBars(
                    income: summary.income,
                    expense: summary.expense,
                    largestDailyMovement: monthSummary.largestDailyMovement,
                    isProminent: isToday
                )
            }
            .padding(8)
            .aspectRatio(0.95, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(dayCellFill(isToday: isToday, isSelected: isSelected))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(dayCellStroke(isToday: isToday, isSelected: isSelected), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(PrimaryPressStyle())
    }

    private var calendarPrompt: some View {
        GlassSurface(padding: 16) {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.violet)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.lavender.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(NSLocalizedString("Select a day", comment: ""))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text(NSLocalizedString("Tap a date to review its transactions.", comment: ""))
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func selectedDaySection(_ day: Date) -> some View {
        let dayTxns = transactionsForDay(day).sorted { $0.date > $1.date }
        let summary = monthSummary.summary(for: day)

        return VStack(spacing: 12) {
            SectionTitle(dayLabel(day), subtitle: String(format: NSLocalizedString("%d transactions", comment: ""), dayTxns.count))

            GlassSurface {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        MetricCapsule(title: "Income", value: AppFormatters.statMoney(summary.income, currency: currency), tint: AppTheme.teal)
                        MetricCapsule(title: "Expense", value: AppFormatters.statMoney(summary.expense, currency: currency), tint: AppTheme.coral)
                    }

                    HStack(spacing: 10) {
                        MetricCapsule(title: "Net", value: AppFormatters.statMoney(abs(summary.net), currency: currency), tint: summary.net >= 0 ? AppTheme.teal : AppTheme.coral)
                        MetricCapsule(title: "Count", value: "\(summary.transactionCount)", tint: AppTheme.lavender)
                    }
                }
            }

            if dayTxns.isEmpty {
                EmptyStateView(
                    systemImage: "tray",
                    title: "No transactions",
                    message: "Add a transaction for this day or select another date."
                )
            } else {
                GlassSurface(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(dayTxns) { transaction in
                            SwipeableTransactionRow(
                                transaction: transaction,
                                openAction: { editingTransaction = transaction },
                                deleteAction: { delete(transaction) }
                            )
                            .id(transaction.id)
                            if transaction.id != dayTxns.last?.id {
                                Divider()
                                    .overlay(AppTheme.line.opacity(0.5))
                                    .padding(.horizontal, 14)
                            }
                        }
                    }
                }
            }
        }
    }

    private func dayLabel(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = AppLanguage.stored.locale
        if calendar.isDateInToday(day) { return NSLocalizedString("Today", comment: "") }
        if calendar.isDateInYesterday(day) { return NSLocalizedString("Yesterday", comment: "") }
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: day)
    }

    private func moveMonth(by value: Int) {
        visibleMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) ?? visibleMonth
        selectedDay = nil
    }

    private func dayCellFill(isToday: Bool, isSelected: Bool) -> Color {
        if isToday {
            return AppTheme.violet
        }
        if isSelected {
            return colorScheme == .dark ? AppTheme.violet.opacity(0.26) : AppTheme.lavender.opacity(0.24)
        }
        return colorScheme == .dark ? AppTheme.surface.opacity(0.58) : AppTheme.surface.opacity(0.86)
    }

    private func dayCellStroke(isToday: Bool, isSelected: Bool) -> Color {
        if isToday || isSelected {
            return AppTheme.violet.opacity(colorScheme == .dark ? 0.86 : 0.72)
        }
        return AppTheme.line.opacity(colorScheme == .dark ? 0.72 : 0.55)
    }

    private func activityDotTint(for summary: CalendarDaySummary) -> Color {
        summary.net >= 0 ? AppTheme.teal : AppTheme.coral
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

    private func delete(_ transaction: FinanceTransaction) {
        modelContext.delete(transaction)
        try? modelContext.save()
    }
}

private struct CalendarActivityBars: View {
    var income: Decimal
    var expense: Decimal
    var largestDailyMovement: Decimal
    var isProminent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            activityBar(value: expense, tint: expenseTint)
            activityBar(value: income, tint: incomeTint)
        }
        .frame(height: 16, alignment: .bottomLeading)
    }

    private var expenseTint: Color {
        isProminent ? Color(red: 0.965, green: 0.972, blue: 0.990) : AppTheme.coral
    }

    private var incomeTint: Color {
        isProminent ? Color(red: 0.965, green: 0.972, blue: 0.990).opacity(0.84) : AppTheme.teal
    }

    private func activityBar(value: Decimal, tint: Color) -> some View {
        GeometryReader { proxy in
            Capsule()
                .fill(tint.opacity(value > 0 ? 0.92 : 0.16))
                .frame(width: max(proxy.size.width * progress(for: value), value > 0 ? 5 : 0))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 4)
        .background(tint.opacity(isProminent ? 0.16 : 0.10), in: Capsule())
    }

    private func progress(for value: Decimal) -> CGFloat {
        guard largestDailyMovement > 0, value > 0 else { return 0 }
        let current = NSDecimalNumber(decimal: value).doubleValue
        let largest = max(NSDecimalNumber(decimal: largestDailyMovement).doubleValue, 1)
        return CGFloat(min(max(current / largest, 0.08), 1))
    }
}
