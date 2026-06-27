import SwiftUI
import SwiftData

struct GlobalSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \FinanceCategory.sortOrder) private var categories: [FinanceCategory]
    @Query(sort: \MerchantRule.sampleCount, order: .reverse) private var rules: [MerchantRule]
    @Query(sort: \ImportBatch.importedAt, order: .reverse) private var batches: [ImportBatch]
    @State private var searchText = ""
    @State private var selectedFilter: SavedSearchFilter = .all
    @State private var editingTransaction: FinanceTransaction?

    private var filteredTransactions: [FinanceTransaction] {
        transactions.filter { transaction in
            selectedFilter.matches(transaction, in: transactions)
                && (searchText.isEmpty || matchesSearch(transaction))
        }
    }

    private var matchedAccounts: [Account] {
        guard !searchText.isEmpty else { return [] }
        return accounts.filter { !$0.isArchived && $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var matchedCategories: [FinanceCategory] {
        guard !searchText.isEmpty else { return [] }
        return categories.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || ($0.parentName ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    private var matchedBatches: [ImportBatch] {
        guard !searchText.isEmpty else { return [] }
        return batches.filter { $0.sourceFileName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        GlassSurface {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionTitle("Global search", subtitle: "Find transactions, accounts, categories, and imports")
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(SavedSearchFilter.allCases) { filter in
                                            Button {
                                                selectedFilter = filter
                                            } label: {
                                                Label(filter.title, systemImage: filter.systemImage)
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(selectedFilter == filter ? .white : AppTheme.ink)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 9)
                                                    .background(selectedFilter == filter ? AppTheme.violet : .white.opacity(0.72), in: Capsule())
                                                    .overlay(Capsule().stroke(AppTheme.line.opacity(0.7), lineWidth: 1))
                                            }
                                            .buttonStyle(PrimaryPressStyle())
                                        }
                                    }
                                }
                            }
                        }

                        if !matchedAccounts.isEmpty || !matchedCategories.isEmpty || !matchedBatches.isEmpty {
                            SearchDirectorySection(accounts: matchedAccounts, categories: matchedCategories, batches: matchedBatches)
                        }

                        SectionTitle("Transactions", subtitle: "\(filteredTransactions.count) matches")

                        if filteredTransactions.isEmpty {
                            EmptyStateView(
                                systemImage: "magnifyingglass",
                                title: "No matches",
                                message: "Search merchant, note, category, account, amount, or use a saved filter."
                            )
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredTransactions.prefix(160)) { transaction in
                                    if selectedFilter == .uncategorized {
                                        UncategorizedSuggestionCard(
                                            transaction: transaction,
                                            suggestion: suggestion(for: transaction),
                                            openAction: { editingTransaction = transaction },
                                            applyAction: { suggestion in apply(suggestion, to: transaction) },
                                            deleteAction: { delete(transaction) }
                                        )
                                    } else {
                                        SwipeableTransactionRow(
                                            transaction: transaction,
                                            openAction: { editingTransaction = transaction },
                                            deleteAction: { delete(transaction) }
                                        )
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
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Merchant, category, account, note")
            .sheet(item: $editingTransaction) { transaction in
                TransactionEditorView(transaction: transaction, accounts: accounts, categories: categories)
            }
        }
    }

    private func matchesSearch(_ transaction: FinanceTransaction) -> Bool {
        let amount = NSDecimalNumber(decimal: transaction.amount).stringValue
        return transaction.merchant.localizedCaseInsensitiveContains(searchText)
            || transaction.rawDescription.localizedCaseInsensitiveContains(searchText)
            || transaction.note.localizedCaseInsensitiveContains(searchText)
            || transaction.accountName.localizedCaseInsensitiveContains(searchText)
            || (transaction.categoryName ?? "").localizedCaseInsensitiveContains(searchText)
            || (transaction.subcategoryName ?? "").localizedCaseInsensitiveContains(searchText)
            || amount.localizedCaseInsensitiveContains(searchText)
    }

    private func suggestion(for transaction: FinanceTransaction) -> CategorySuggestion? {
        let merchant = transaction.normalizedMerchant.isEmpty
            ? MerchantNormalizer.normalize(transaction.merchant)
            : transaction.normalizedMerchant

        if let ruleSuggestion = CategoryMatcher.match(merchant: merchant, rules: rules, fallbackKind: transaction.kind) {
            return ruleSuggestion
        }

        return historicalSuggestion(for: merchant, fallbackKind: transaction.kind, excluding: transaction.id)
    }

    private func historicalSuggestion(for merchant: String, fallbackKind: TransactionKind, excluding transactionId: UUID) -> CategorySuggestion? {
        let matches = transactions.filter { transaction in
            guard transaction.id != transactionId, transaction.categoryName?.isEmpty == false else { return false }
            let candidateMerchant = transaction.normalizedMerchant.isEmpty
                ? MerchantNormalizer.normalize(transaction.merchant)
                : transaction.normalizedMerchant
            return candidateMerchant == merchant
        }
        guard !matches.isEmpty else { return nil }

        let grouped = Dictionary(grouping: matches) { transaction in
            HistoricalCategoryKey(
                category: transaction.categoryName ?? "",
                subcategory: transaction.subcategoryName,
                kind: transaction.kind
            )
        }
        guard let winner = grouped.max(by: { $0.value.count < $1.value.count }) else { return nil }
        let share = Double(winner.value.count) / Double(matches.count)
        guard share >= 0.5 else { return nil }

        return CategorySuggestion(
            category: winner.key.category,
            subcategory: winner.key.subcategory,
            kind: winner.key.kind,
            confidence: winner.value.count >= 2 ? 0.9 : 0.78
        )
    }

    private func apply(_ suggestion: CategorySuggestion, to transaction: FinanceTransaction) {
        let normalized = transaction.normalizedMerchant.isEmpty
            ? MerchantNormalizer.normalize(transaction.merchant)
            : transaction.normalizedMerchant

        transaction.categoryName = suggestion.category
        transaction.subcategoryName = suggestion.subcategory
        transaction.kind = suggestion.kind
        transaction.normalizedMerchant = normalized
        transaction.updatedAt = .now

        guard !normalized.isEmpty else {
            try? modelContext.save()
            return
        }

        if let rule = rules.first(where: { MerchantNormalizer.normalize($0.pattern) == normalized }) {
            rule.categoryName = suggestion.category
            rule.subcategoryName = suggestion.subcategory
            rule.kind = suggestion.kind
            rule.confidence = max(rule.confidence, suggestion.confidence)
            rule.sampleCount += 1
        } else {
            modelContext.insert(
                MerchantRule(
                    pattern: normalized,
                    matchType: .exact,
                    categoryName: suggestion.category,
                    subcategoryName: suggestion.subcategory,
                    kind: suggestion.kind,
                    confidence: max(suggestion.confidence, 0.85),
                    sampleCount: 1
                )
            )
        }

        try? modelContext.save()
    }

    private func delete(_ transaction: FinanceTransaction) {
        modelContext.delete(transaction)
        try? modelContext.save()
    }
}

private struct HistoricalCategoryKey: Hashable {
    var category: String
    var subcategory: String?
    var kind: TransactionKind
}

private enum SavedSearchFilter: CaseIterable, Identifiable {
    case all
    case uncategorized
    case duplicates
    case highSpending
    case importedToday
    case recurring
    case cash
    case card

    var id: String { title }

    var title: String {
        switch self {
        case .all: "All"
        case .uncategorized: "Uncategorized"
        case .duplicates: "Duplicates"
        case .highSpending: "High spend"
        case .importedToday: "Imported today"
        case .recurring: "Recurring"
        case .cash: "Cash"
        case .card: "Card"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "line.3.horizontal.decrease.circle"
        case .uncategorized: "tag.slash"
        case .duplicates: "doc.on.doc"
        case .highSpending: "arrow.up.right.circle"
        case .importedToday: "tray.and.arrow.down"
        case .recurring: "repeat"
        case .cash: "banknote"
        case .card: "creditcard"
        }
    }

    func matches(_ transaction: FinanceTransaction, in all: [FinanceTransaction]) -> Bool {
        switch self {
        case .all:
            return true
        case .uncategorized:
            return transaction.categoryName?.isEmpty != false
        case .duplicates:
            return all.contains { other in
                other.id != transaction.id
                    && other.accountName == transaction.accountName
                    && Calendar.current.isDate(other.date, inSameDayAs: transaction.date)
                    && other.amount == transaction.amount
                    && other.normalizedMerchant == transaction.normalizedMerchant
            }
        case .highSpending:
            return NSDecimalNumber(decimal: transaction.amount).doubleValue >= 1000
        case .importedToday:
            return Calendar.current.isDateInToday(transaction.createdAt)
        case .recurring:
            return all.filter { $0.normalizedMerchant == transaction.normalizedMerchant }.count >= 2
        case .cash:
            return transaction.accountName.localizedCaseInsensitiveContains("cash")
        case .card:
            let name = transaction.accountName.lowercased()
            return name.contains("card") || name.contains("tabby")
        }
    }
}

// MARK: - Uncategorized Suggestion Card

private struct UncategorizedSuggestionCard: View {
    var transaction: FinanceTransaction
    var suggestion: CategorySuggestion?
    var openAction: () -> Void
    var applyAction: (CategorySuggestion) -> Void
    var deleteAction: () -> Void

    var body: some View {
        GlassSurface(padding: 0) {
            VStack(spacing: 0) {
                Button(action: openAction) {
                    TransactionSuggestionSummary(transaction: transaction)
                }
                .buttonStyle(PrimaryPressStyle())

                Divider().overlay(AppTheme.line.opacity(0.45))

                HStack(spacing: 10) {
                    Image(systemName: suggestion == nil ? "sparkle.magnifyingglass" : "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(suggestion == nil ? AppTheme.muted : AppTheme.violet)
                        .frame(width: 30, height: 30)
                        .background((suggestion == nil ? AppTheme.muted : AppTheme.violet).opacity(0.11), in: Circle())
                    if let suggestion {
                        Button("Apply \(suggestion.category)") {
                            applyAction(suggestion)
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppTheme.violet, in: Capsule())
                    } else {
                        Text("No AI suggestion")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                    }
                    Spacer(minLength: 6)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
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

// MARK: - Transaction Suggestion Summary

private struct TransactionSuggestionSummary: View {
    @Environment(\.appCurrency) private var currency
    var transaction: FinanceTransaction

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            Image(systemName: transaction.kind == .income ? "arrow.down.left" : "arrow.up.right")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(transaction.kind == .income ? AppTheme.teal : AppTheme.coral)
                .frame(width: 38, height: 38)
                .background((transaction.kind == .income ? AppTheme.teal : AppTheme.coral).opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(transaction.merchant.isEmpty ? transaction.rawDescription : transaction.merchant)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(transaction.accountName)
                    Text("•")
                    Text(AppFormatters.day.string(from: transaction.date))
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.muted)
                .lineLimit(1)
            }

            Spacer(minLength: 10)

            Text(AppFormatters.money(transaction.amount, currency: AppFormatters.resolvedCurrency(transaction.currency, fallback: currency)))
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(transaction.kind == .income ? AppTheme.teal : AppTheme.ink)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.68)
        }
        .padding(14)
    }
}

private struct ConfidenceBadge: View {
    var confidence: Double

    private var title: String {
        if confidence >= 0.85 { return "High" }
        if confidence >= 0.65 { return "Medium" }
        return "Low"
    }

    private var tint: Color {
        if confidence >= 0.85 { return AppTheme.mint }
        if confidence >= 0.65 { return AppTheme.gold }
        return AppTheme.coral
    }

    var body: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

// MARK: - Search Directory Section

private struct SearchDirectorySection: View {
    var accounts: [Account]
    var categories: [FinanceCategory]
    var batches: [ImportBatch]

    var body: some View {
        GlassSurface(padding: 0) {
            VStack(spacing: 0) {
                ForEach(accounts) { account in
                    DirectoryRow(title: account.name, subtitle: "Account • \(account.currency)", systemImage: "creditcard")
                }
                ForEach(categories) { category in
                    DirectoryRow(title: category.name, subtitle: category.parentName.map { "Category • \($0)" } ?? "Category", systemImage: "tag")
                }
                ForEach(batches) { batch in
                    DirectoryRow(title: batch.sourceFileName, subtitle: "Import • \(batch.savedCount) saved", systemImage: "tray.and.arrow.down")
                }
            }
        }
    }
}

private struct DirectoryRow: View {
    var title: String
    var subtitle: String
    var systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.violet)
                .frame(width: 36, height: 36)
                .background(AppTheme.lavender.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
        }
        .padding(14)
        Divider().overlay(AppTheme.line.opacity(0.45))
    }
}
