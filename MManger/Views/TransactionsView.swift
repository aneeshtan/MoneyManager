import SwiftUI
import SwiftData

// MARK: - Scrolling Performance

private enum ScrollCoordinateSpace {
    static let name = "TransactionsScroll"
}

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \FinanceCategory.sortOrder) private var categories: [FinanceCategory]
    @State private var searchText = ""
    @State private var showingEditor = false
    @State private var editingTransaction: FinanceTransaction?
    @State private var showingDuplicateReview = false
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

    private var filtered: [FinanceTransaction] {
        guard !searchText.isEmpty else { return transactions }
        let query = searchText.lowercased()
        return transactions.filter {
            $0.merchant.localizedCaseInsensitiveContains(query)
                || $0.note.localizedCaseInsensitiveContains(query)
                || ($0.categoryName ?? "").localizedCaseInsensitiveContains(query)
                || $0.accountName.localizedCaseInsensitiveContains(query)
        }
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
                                title: searchText.isEmpty ? "No transactions" : "No matches",
                                message: searchText.isEmpty
                                    ? "Import a bank PDF or add a transaction manually."
                                    : "Try a merchant, account, or category name."
                            )
                        } else {
                            ForEach(filtered) { transaction in
                                TransactionRow(transaction: transaction)
                                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .onTapGesture {
                                        editingTransaction = transaction
                                    }
                                    .contextMenu {
                                        Button {
                                            editingTransaction = transaction
                                        } label: {
                                            Label("Edit", systemImage: "square.and.pencil")
                                        }
                                        Button(role: .destructive) {
                                            delete(transaction)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .id(transaction.id)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
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
                                                Text(AppFormatters.money(transaction.amount, currency: transaction.currency))
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
                    MetricCapsule(title: "Income", value: AppFormatters.statMoney(income), tint: AppTheme.teal)
                    MetricCapsule(title: "Expense", value: AppFormatters.statMoney(expense), tint: AppTheme.coral)
                }
            }
        }
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    var transaction: FinanceTransaction

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            TransactionIcon(kind: transaction.kind)

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchant.isEmpty ? transaction.rawDescription : transaction.merchant)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text(transaction.accountName)
                        .lineLimit(1)
                    Circle()
                        .fill(AppTheme.muted.opacity(0.55))
                        .frame(width: 3, height: 3)
                    Text(categoryText)
                        .lineLimit(1)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.muted)

                Text(AppFormatters.day.string(from: transaction.date))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppTheme.muted.opacity(0.68))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            Text(amountString)
                .font(.system(.callout, design: .rounded).weight(.bold))
                .foregroundStyle(transaction.kind == .income ? AppTheme.teal : AppTheme.ink)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: 126, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.96))
                .shadow(color: AppTheme.violet.opacity(0.045), radius: 14, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.line.opacity(0.62), lineWidth: 1)
        )
    }

    private var categoryText: String {
        if let category = transaction.categoryName, let subcategory = transaction.subcategoryName {
            return "\(category) / \(subcategory)"
        }
        return transaction.categoryName ?? "Uncategorized"
    }

    private var amountString: String {
        AppFormatters.money(transaction.amount, currency: transaction.currency)
    }
}

// MARK: - Swipeable Row (Tap to edit, long-press for context menu)

struct SwipeableTransactionRow: View {
    var transaction: FinanceTransaction
    var openAction: () -> Void
    var deleteAction: () -> Void

    var body: some View {
        TransactionRow(transaction: transaction)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onTapGesture {
                openAction()
            }
            .contextMenu {
                Button(action: openAction) {
                    Label("Edit", systemImage: "square.and.pencil")
                }
                Button(role: .destructive, action: deleteAction) {
                    Label("Delete", systemImage: "trash")
                }
            }
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