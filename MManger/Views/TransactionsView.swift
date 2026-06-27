import SwiftUI
import SwiftData

// MARK: - Scrolling Performance

private enum ScrollCoordinateSpace {
    static let name = "TransactionsScroll"
}

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appCurrency) private var currency
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \FinanceCategory.sortOrder) private var categories: [FinanceCategory]
    @State private var searchText = ""
    @State private var showingEditor = false
    @State private var editingTransaction: FinanceTransaction?
    @State private var showingDuplicateReview = false
    @State private var showingFilter = false
    @State private var activeFilter = TransactionFilter()
    /// Cached duplicate candidates; regenerated when `transactions` changes.
    @State private var duplicateCache: [DuplicateReviewCandidate] = []

    // ── Single-pass monthly snapshot ──────────────────────────────────────
    private struct MonthSnapshot {
        var count: Int
        var expense: Decimal
        var income: Decimal
    }

    private var monthSnapshot: MonthSnapshot {
        let calendar = Calendar.current
        var expense = Decimal(0)
        var income = Decimal(0)
        var count = 0
        for t in transactions where calendar.isDate(t.date, equalTo: .now, toGranularity: .month) {
            if t.kind == .expense { expense += t.amount }
            else if t.kind == .income { income += t.amount }
            count += 1
        }
        return MonthSnapshot(count: count, expense: expense, income: income)
    }

    struct DayGroup {
        var day: Date
        var transactions: [FinanceTransaction]
        var dayTotal: Decimal
    }

    private var groupedByDay: [DayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.date) }
        return grouped
            .map { day, txns in
                let sorted = txns.sorted { $0.date > $1.date }
                let total = txns.filter { $0.kind == .expense }.reduce(Decimal(0)) { $0 + $1.amount }
                return DayGroup(day: day, transactions: sorted, dayTotal: total)
            }
            .sorted { $0.day > $1.day }
    }

    private var filtered: [FinanceTransaction] {
        var result = transactions
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.merchant.localizedCaseInsensitiveContains(query)
                    || $0.note.localizedCaseInsensitiveContains(query)
                    || ($0.categoryName ?? "").localizedCaseInsensitiveContains(query)
                    || $0.accountName.localizedCaseInsensitiveContains(query)
            }
        }
        if activeFilter.isActive {
            result = result.filter { t in
                // handle uncategorized sentinel
                if activeFilter.categoryName == "__uncategorized__" {
                    var f = activeFilter
                    f.categoryName = ""
                    return f.matches(t) && (t.categoryName == nil || t.categoryName!.isEmpty)
                }
                return activeFilter.matches(t)
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    LazyVStack(spacing: 14) {
                        TransactionSummaryHeader(
                            income: monthSnapshot.income,
                            expense: monthSnapshot.expense,
                            count: doubleCount
                        )

                        if !duplicateCache.isEmpty {
                            DuplicateReviewCallout(
                                count: duplicateCache.count,
                                transactionCount: duplicateCache.reduce(0) { $0 + $1.transactions.count },
                                action: { showingDuplicateReview = true }
                            )
                        }

                        if filtered.isEmpty {
                            EmptyStateView(
                                systemImage: "magnifyingglass",
                                title: searchText.isEmpty && !activeFilter.isActive ? "No transactions" : "No matches",
                                message: searchText.isEmpty && !activeFilter.isActive
                                    ? "Import a bank PDF or add a transaction manually."
                                    : "Try adjusting your search or filters."
                            )
                        } else {
                            ForEach(groupedByDay, id: \.day) { group in
                                DaySection(group: group, editAction: { editingTransaction = $0 }, deleteAction: { delete($0) })
                            }
                        }
                    }
                    .adaptiveScreenContent()
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
                .coordinateSpace(name: ScrollCoordinateSpace.name)
            }
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search merchant, note, category")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        Button {
                            showingFilter = true
                        } label: {
                            Image(systemName: activeFilter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(activeFilter.isActive ? AppTheme.violet : AppTheme.ink)
                                .frame(width: 34, height: 34)
                        }
                        .accessibilityLabel("Filter transactions")

                        Button {
                            showingEditor = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(AppTheme.violet, in: Circle())
                        }
                        .buttonStyle(PrimaryPressStyle())
                        .accessibilityLabel("Add transaction")
                    }
                }
            }
            .sheet(isPresented: $showingFilter) {
                TransactionFilterSheet(filter: $activeFilter, accounts: accounts, categories: categories)
            }
            .sheet(isPresented: $showingEditor) {
                TransactionEditorView(accounts: accounts, categories: categories)
            }
            .sheet(item: $editingTransaction) { transaction in
                TransactionEditorView(transaction: transaction, accounts: accounts, categories: categories)
            }
            .sheet(isPresented: $showingDuplicateReview) {
                DuplicateReviewView(
                    candidates: duplicateCache,
                    openAction: { transaction in editingTransaction = transaction },
                    keepNewestAction: keepNewest(in:)
                )
            }
            // Rebuild duplicate cache when transactions change.
            .onChange(of: transactions.count) { _, _ in
                rebuildDuplicateCache()
            }
            .onAppear {
                if duplicateCache.isEmpty {
                    rebuildDuplicateCache()
                }
            }
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    private var doubleCount: Int {
        guard searchText.isEmpty else { return filtered.count }
        return monthSnapshot.count
    }

    private func rebuildDuplicateCache() {
        Task(priority: .utility) {
            let candidates = DuplicateReviewService.candidates(in: transactions)
            await MainActor.run {
                duplicateCache = candidates
            }
        }
    }

    private func delete(_ transaction: FinanceTransaction) {
        modelContext.delete(transaction)
        try? modelContext.save()
        // Cache will be rebuilt via onChange(of: transactions.count)
    }

    private func keepNewest(in candidate: DuplicateReviewCandidate) {
        let sorted = candidate.transactions.sorted { $0.date > $1.date }
        for duplicate in sorted.dropFirst() {
            modelContext.delete(duplicate)
        }
        try? modelContext.save()
    }
}

// MARK: - Duplicate Review Callout

private struct DuplicateReviewCallout: View {
    var count: Int
    var transactionCount: Int
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "square.on.square")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.gold)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.gold.opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(count) duplicate groups")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text("\(transactionCount) transactions need review")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.muted)
            }
            .padding(14)
            .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.line.opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(PrimaryPressStyle())
    }
}

// MARK: - Duplicate Review Sheet

private struct DuplicateReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appCurrency) private var currency
    var candidates: [DuplicateReviewCandidate]
    var openAction: (FinanceTransaction) -> Void
    var keepNewestAction: (DuplicateReviewCandidate) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(candidates) { candidate in
                            GlassSurface(padding: 14) {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Label(candidate.isExact ? "Exact duplicate" : "Likely duplicate",
                                              systemImage: candidate.isExact ? "checkmark.seal" : "exclamationmark.triangle")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(candidate.isExact ? AppTheme.teal : AppTheme.gold)
                                        Spacer()
                                        Button("Keep newest") {
                                            keepNewestAction(candidate)
                                        }
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(AppTheme.violet, in: Capsule())
                                    }

                                    ForEach(candidate.transactions) { transaction in
                                        Button {
                                            dismiss()
                                            openAction(transaction)
                                        } label: {
                                            HStack(spacing: 10) {
                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(transaction.merchant.isEmpty ? transaction.rawDescription : transaction.merchant)
                                                        .font(.caption.weight(.semibold))
                                                        .foregroundStyle(AppTheme.ink)
                                                        .lineLimit(1)
                                                    Text("\(transaction.accountName) • \(AppFormatters.day.string(from: transaction.date))")
                                                        .font(.caption2)
                                                        .foregroundStyle(AppTheme.muted)
                                                }
                                                Spacer()
                                                Text(AppFormatters.money(transaction.amount, currency: AppFormatters.resolvedCurrency(transaction.currency, fallback: currency)))
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(AppTheme.ink)
                                            }
                                            .padding(.vertical, 6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Duplicates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Summary Header

private struct TransactionSummaryHeader: View {
    @Environment(\.appCurrency) private var currency
    var income: Decimal
    var expense: Decimal
    var count: Int

    var body: some View {
        GlassSurface {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Activity")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                        Text("\(count) visible transactions")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                    Image(systemName: "waveform.path.ecg.rectangle")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.violet)
                        .frame(width: 46, height: 46)
                        .background(AppTheme.lavender.opacity(0.14), in: Circle())
                }

                HStack(spacing: 10) {
                    MetricCapsule(title: "Income", value: AppFormatters.statMoney(income, currency: currency), tint: AppTheme.teal)
                    MetricCapsule(title: "Expense", value: AppFormatters.statMoney(expense, currency: currency), tint: AppTheme.coral)
                }
            }
        }
    }
}

// MARK: - Day Section

private struct DaySection: View {
    @Environment(\.appCurrency) private var currency
    var group: TransactionsView.DayGroup
    var editAction: (FinanceTransaction) -> Void
    var deleteAction: (FinanceTransaction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Date header
            HStack {
                Text(dayLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.muted)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                if group.dayTotal > 0 {
                    Text(AppFormatters.statMoney(group.dayTotal, currency: currency))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
            .padding(.top, 4)

            // Rows grouped inside one card
            GlassSurface(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(group.transactions) { transaction in
                        SwipeableTransactionRow(
                            transaction: transaction,
                            openAction: { editAction(transaction) },
                            deleteAction: { deleteAction(transaction) }
                        )
                        .id(transaction.id)
                        if transaction.id != group.transactions.last?.id {
                            Divider()
                                .overlay(AppTheme.line.opacity(0.5))
                                .padding(.horizontal, 14)
                        }
                    }
                }
            }
        }
    }

    private var dayLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(group.day) { return "Today" }
        if calendar.isDateInYesterday(group.day) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = calendar.isDate(group.day, equalTo: .now, toGranularity: .year)
            ? "EEEE, MMM d"
            : "EEEE, MMM d, yyyy"
        return formatter.string(from: group.day)
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    @Environment(\.appCurrency) private var currency
    var transaction: FinanceTransaction

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            TransactionIcon(kind: transaction.kind)

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.merchant.isEmpty ? transaction.rawDescription : transaction.merchant)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 4) {
                    Text(transaction.accountName)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("·")
                    Text(categoryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(AppFormatters.money(transaction.amount, currency: AppFormatters.resolvedCurrency(transaction.currency, fallback: currency)))
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(transaction.kind == .income ? AppTheme.teal : AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .layoutPriority(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var categoryText: String {
        if let sub = transaction.subcategoryName, !sub.isEmpty { return sub }
        return transaction.categoryName ?? "Uncategorized"
    }
}

// MARK: - Swipeable Row (Tap to edit, long-press for context menu)

struct SwipeableTransactionRow: View {
    var transaction: FinanceTransaction
    var openAction: () -> Void
    var deleteAction: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isSwiped = false
    @State private var showingDeleteConfirmation = false
    private let deleteButtonWidth: CGFloat = 72

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive, action: requestDelete) {
                Image(systemName: "trash")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: deleteButtonWidth)
                    .frame(maxHeight: .infinity)
                    .background(AppTheme.coral)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .opacity(isSwiped ? 1 : 0)
            .zIndex(1)

            TransactionRow(transaction: transaction)
                .offset(x: offset)
                .zIndex(0)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            guard value.translation.width < 0 else {
                                if isSwiped { snap(to: 0) }
                                return
                            }
                            let drag = max(value.translation.width, -deleteButtonWidth - 12)
                            offset = isSwiped ? drag - deleteButtonWidth : drag
                        }
                        .onEnded { value in
                            if value.translation.width < -(deleteButtonWidth / 2) {
                                snap(to: -deleteButtonWidth)
                            } else {
                                snap(to: 0)
                            }
                        }
                )
                .contentShape(Rectangle())
                .onTapGesture { if isSwiped { snap(to: 0) } else { openAction() } }
                .contextMenu {
                    Button(action: openAction) { Label("Edit", systemImage: "square.and.pencil") }
                    Button(role: .destructive, action: requestDelete) { Label("Delete", systemImage: "trash") }
                }
        }
        .clipped()
        .alert("Delete Transaction?", isPresented: $showingDeleteConfirmation) {
            Button("Delete Transaction", role: .destructive) {
                deleteAction()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this transaction? This action cannot be undone.")
        }
    }

    private func snap(to target: CGFloat) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            offset = target
            isSwiped = target != 0
        }
    }

    private func requestDelete() {
        showingDeleteConfirmation = true
    }
}

// MARK: - Transaction Icon

private struct TransactionIcon: View {
    var kind: TransactionKind

    var body: some View {
        let tint = kind == .income ? AppTheme.teal : AppTheme.coral
        Image(systemName: kind == .income ? "arrow.down.left" : "arrow.up.right")
            .font(.caption.weight(.bold))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background(tint.opacity(0.11), in: Circle())
            .overlay(Circle().stroke(tint.opacity(0.14), lineWidth: 1))
    }
}
