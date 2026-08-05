import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Environment(\.appCurrency) private var appCurrency
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FinanceCategory.sortOrder) private var categories: [FinanceCategory]
    @Query(sort: \MerchantRule.sampleCount, order: .reverse) private var rules: [MerchantRule]
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]
    @Query(sort: \Budget.monthStart, order: .reverse) private var budgets: [Budget]
    @State private var selectedTab = 0
    @State private var showingNewCategory = false
    @State private var showingRuleEditor = false
    @State private var showingSmartCategorize = false
    @State private var smartCategorizeMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        GlassSurface {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionTitle(NSLocalizedString("Categories", comment: ""), subtitle: NSLocalizedString("Tap any category to see spending, rules, and transactions", comment: ""))
                                Picker("View", selection: $selectedTab) {
                                    Text(NSLocalizedString("Categories", comment: "")).tag(0)
                                    Text(NSLocalizedString("Rules", comment: "")).tag(1)
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        if selectedTab == 0 {
                            categoryList
                        } else {
                            ruleList
                        }

                        if selectedTab == 1 {
                            smartCategorizeCard
                        }
                    }
                    .adaptiveScreenContent()
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(NSLocalizedString("Categories", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if selectedTab == 0 {
                            showingNewCategory = true
                        } else {
                            showingRuleEditor = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(selectedTab == 0 ? NSLocalizedString("Add category", comment: "") : NSLocalizedString("Add merchant rule", comment: ""))
                }
            }
            .sheet(isPresented: $showingNewCategory) {
                CategoryEditorView(
                    category: nil,
                    categories: categories,
                    transactions: transactions,
                    rules: rules,
                    budgets: budgets
                )
            }
            .sheet(isPresented: $showingRuleEditor) {
                RuleEditorView(rule: nil, categories: categories)
            }
            .sheet(isPresented: $showingSmartCategorize) {
                SmartCategorizeView(
                    transactions: transactions,
                    rules: rules,
                    onComplete: { message in
                        smartCategorizeMessage = message
                    }
                )
            }
            .alert("Smart Categorize", isPresented: Binding(
                get: { smartCategorizeMessage != nil },
                set: { if !$0 { smartCategorizeMessage = nil } }
            )) {
                Button(NSLocalizedString("OK", comment: ""), role: .cancel) {}
            } message: {
                Text(smartCategorizeMessage ?? "")
            }
        }
    }

    private var smartCategorizeCard: some View {
        let uncategorized = transactions.filter { $0.categoryName?.isEmpty != false }
        guard !uncategorized.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            GlassSurface {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles.rectangle.stack")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(AppTheme.violet, in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("Smart Categorize", comment: ""))
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                            Text(String(format: NSLocalizedString("%d uncategorized transactions • learn from past choices", comment: ""), uncategorized.count))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppTheme.muted)
                        }
                        Spacer()
                    }

                    Button {
                        showingSmartCategorize = true
                    } label: {
                        Label(NSLocalizedString("Review suggestions", comment: ""), systemImage: "wand.and.sparkles")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(PrimaryPressStyle())
                }
            }
        )
    }

    private var categoryList: some View {
        VStack(spacing: 12) {
            ForEach(parentCategories) { category in
                let children = categories.filter { $0.parentName == category.name }
                let categoryTotal = totalAmount(for: category)
                GlassSurface(padding: 0) {
                    VStack(spacing: 0) {
                        NavigationLink {
                            CategoryDetailView(
                                category: category,
                                categories: categories,
                                transactions: transactions,
                                rules: rules,
                                budgets: budgets
                            )
                        } label: {
                            CategoryRow(
                                category: category,
                                isParent: true,
                                transactionCount: transactionCount(for: category),
                                total: categoryTotal.amount,
                                currency: categoryTotal.currency,
                                budgetProgress: budgetProgress(for: category)
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(PrimaryPressStyle())

                        if !children.isEmpty {
                            Divider().overlay(AppTheme.line.opacity(0.55))
                            ForEach(children) { child in
                                let childTotal = totalAmount(for: child)
                                NavigationLink {
                                    CategoryDetailView(
                                        category: child,
                                        categories: categories,
                                        transactions: transactions,
                                        rules: rules,
                                        budgets: budgets
                                    )
                                } label: {
                                    CategoryRow(
                                        category: child,
                                        isParent: false,
                                        transactionCount: transactionCount(for: child),
                                        total: childTotal.amount,
                                        currency: childTotal.currency,
                                        budgetProgress: budgetProgress(for: child)
                                    )
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(PrimaryPressStyle())

                                if child.id != children.last?.id {
                                    Divider()
                                        .overlay(AppTheme.line.opacity(0.4))
                                        .padding(.leading, 68)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var ruleList: some View {
        LazyVStack(spacing: 12) {
            if rules.isEmpty {
                EmptyStateView(
                    systemImage: "tag",
                    title: "No merchant rules",
                    message: "Rules learned from imports and exports will appear here."
                )
            } else {
                ForEach(rules.prefix(160)) { rule in
                    NavigationLink {
                        RuleDetailView(rule: rule, transactions: transactions)
                    } label: {
                        RuleRow(rule: rule)
                    }
                    .buttonStyle(PrimaryPressStyle())
                }
            }
        }
    }

    private var parentCategories: [FinanceCategory] {
        categories.filter { $0.parentName == nil }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func matchingTransactions(for category: FinanceCategory) -> [FinanceTransaction] {
        if category.parentName == nil {
            return transactions.filter { $0.categoryName == category.name }
        }
        return transactions.filter { $0.categoryName == category.parentName && $0.subcategoryName == category.name }
    }

    private func transactionCount(for category: FinanceCategory) -> Int {
        matchingTransactions(for: category).count
    }

    private func totalAmount(for category: FinanceCategory) -> (amount: Decimal, currency: String) {
        let categoryTransactions = matchingTransactions(for: category)
        let currency = reportingCurrency(for: categoryTransactions)
        let amount = categoryTransactions
            .filter { transactionCurrency($0) == currency }
            .reduce(Decimal(0)) { $0 + $1.amount }
        return (amount, currency)
    }

    private func reportingCurrency(for transactions: [FinanceTransaction]) -> String {
        CurrencyReporting.dominantCurrency(
            in: transactions,
            fallback: appCurrency,
            currency: { $0.currency },
            amount: { $0.amount }
        )
    }

    private func transactionCurrency(_ transaction: FinanceTransaction) -> String {
        AppFormatters.resolvedCurrency(transaction.currency, fallback: appCurrency)
    }

    private func budgetProgress(for category: FinanceCategory) -> BudgetProgress? {
        let monthStart = BudgetProgressCalculator.monthStart(for: .now)
        let categoryName = category.parentName ?? category.name
        let subcategory = category.parentName == nil ? nil : category.name
        guard let budget = BudgetProgressCalculator.budget(
            forCategory: categoryName,
            subcategory: subcategory,
            monthStart: monthStart,
            budgets: budgets
        ) else { return nil }
        let spent = BudgetProgressCalculator.spent(
            forCategory: categoryName,
            subcategory: subcategory,
            monthStart: monthStart,
            transactions: transactions
        )
        return BudgetProgress(budget: budget, spent: spent)
    }
}

private struct CategoryRow: View {
    var category: FinanceCategory
    var isParent: Bool
    var transactionCount: Int
    var total: Decimal
    var currency: String
    var budgetProgress: BudgetProgress?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
            Image(systemName: category.kind == .income ? "arrow.down.left" : "arrow.up.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(category.kind == .income ? AppTheme.teal : AppTheme.coral)
                .frame(width: 38, height: 38)
                .background((category.kind == .income ? AppTheme.teal : AppTheme.coral).opacity(0.11), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                    .font((isParent ? Font.headline : Font.subheadline).weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 3) {
                Text(AppFormatters.statMoney(total, currency: currency))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.ink.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.muted.opacity(0.72))
            }
            }

            if let budgetProgress {
                BudgetProgressBar(progress: budgetProgress)
                    .padding(.leading, 50)
            }
        }
    }

    private var detailText: String {
        var parts = [category.kind.displayName, String(format: NSLocalizedString("%d txns", comment: ""), transactionCount)]
        if let parentName = category.parentName {
            parts.insert(parentName, at: 0)
        }
        if category.isArchived {
            parts.append(NSLocalizedString("Archived", comment: ""))
        }
        return parts.joined(separator: " • ")
    }
}

private struct BudgetProgressBar: View {
    var progress: BudgetProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.line.opacity(0.65))
                    Capsule()
                        .fill(progress.isOverspent ? AppTheme.coral : AppTheme.teal)
                        .frame(width: max(6, proxy.size.width * progress.clampedFractionUsed))
                }
            }
            .frame(height: 6)

            HStack {
                Text(String(format: NSLocalizedString("%@ of %@", comment: ""), AppFormatters.statMoney(progress.spent), AppFormatters.statMoney(progress.budget.amount)))
                Spacer()
                Text(progress.isOverspent ? String(format: NSLocalizedString("Over %@", comment: ""), AppFormatters.statMoney(abs(progress.remaining))) : String(format: NSLocalizedString("%@ left", comment: ""), AppFormatters.statMoney(progress.remaining)))
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(progress.isOverspent ? AppTheme.coral : AppTheme.muted)
        }
    }
}

private struct RuleRow: View {
    var rule: MerchantRule

    var body: some View {
        GlassSurface(padding: 14) {
            HStack(spacing: 12) {
                Image(systemName: "wand.and.sparkles")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.violet)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.lavender.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(rule.pattern)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                    Text("\(rule.isEnabled ? NSLocalizedString("Enabled", comment: "") : NSLocalizedString("Disabled", comment: "")) • \(rule.categoryName)\(rule.subcategoryName.map { " / \($0)" } ?? "") • \(Int(rule.confidence * 100))% • \(rule.sampleCount) \(NSLocalizedString("samples", comment: ""))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.muted.opacity(0.72))
            }
        }
    }
}

private struct CategoryDetailView: View {
    @Environment(\.appCurrency) private var appCurrency
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    var category: FinanceCategory
    var categories: [FinanceCategory]
    var transactions: [FinanceTransaction]
    var rules: [MerchantRule]
    var budgets: [Budget]
    @State private var showingEditor = false
    @State private var categoryMessage: String?
    @State private var editingTransaction: FinanceTransaction?

    private var children: [FinanceCategory] {
        categories.filter { $0.parentName == category.name }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var categoryTransactions: [FinanceTransaction] {
        if category.parentName == nil {
            return transactions.filter { $0.categoryName == category.name }
        }
        return transactions.filter { $0.categoryName == category.parentName && $0.subcategoryName == category.name }
    }

    private var categoryRules: [MerchantRule] {
        if category.parentName == nil {
            return rules.filter { $0.categoryName == category.name }
        }
        return rules.filter { $0.categoryName == category.parentName && $0.subcategoryName == category.name }
    }

    private var categoryBudgets: [Budget] {
        if category.parentName == nil {
            return budgets.filter { $0.categoryName == category.name }
        }
        return budgets.filter { $0.categoryName == category.parentName && $0.subcategoryName == category.name }
    }

    private var hasDependencies: Bool {
        !children.isEmpty || !categoryTransactions.isEmpty || !categoryRules.isEmpty || !categoryBudgets.isEmpty
    }

    private var reportingCurrency: String {
        CurrencyReporting.dominantCurrency(
            in: categoryTransactions,
            fallback: appCurrency,
            currency: { $0.currency },
            amount: { $0.amount }
        )
    }

    private var reportingCategoryTransactions: [FinanceTransaction] {
        categoryTransactions.filter { transactionCurrency($0) == reportingCurrency }
    }

    private var total: Decimal {
        reportingCategoryTransactions.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var income: Decimal {
        reportingCategoryTransactions.filter { $0.kind == .income }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var expense: Decimal {
        reportingCategoryTransactions.filter { $0.kind == .expense }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var currentBudgetProgress: BudgetProgress? {
        let monthStart = BudgetProgressCalculator.monthStart(for: .now)
        let categoryName = category.parentName ?? category.name
        let subcategory = category.parentName == nil ? nil : category.name
        guard let budget = BudgetProgressCalculator.budget(
            forCategory: categoryName,
            subcategory: subcategory,
            monthStart: monthStart,
            budgets: budgets
        ) else { return nil }
        return BudgetProgress(budget: budget, spent: expense)
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 16) {
                    GlassSurface {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: category.kind == .income ? "arrow.down.left" : "arrow.up.right")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(category.kind == .income ? AppTheme.teal : AppTheme.coral)
                                    .frame(width: 50, height: 50)
                                    .background((category.kind == .income ? AppTheme.teal : AppTheme.coral).opacity(0.12), in: Circle())

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(category.name)
                                        .font(.system(.title2, design: .rounded).weight(.bold))
                                        .foregroundStyle(AppTheme.ink)
                                    Text(subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.muted)
                                }
                                Spacer()
                            }

                            HStack(spacing: 10) {
                                MetricCapsule(title: NSLocalizedString("Total", comment: ""), value: AppFormatters.statMoney(total, currency: reportingCurrency), tint: AppTheme.lavender)
                                MetricCapsule(title: NSLocalizedString("Txns", comment: ""), value: "\(categoryTransactions.count)", tint: AppTheme.mint)
                            }
                            HStack(spacing: 10) {
                                MetricCapsule(title: NSLocalizedString("Income", comment: ""), value: AppFormatters.statMoney(income, currency: reportingCurrency), tint: AppTheme.teal)
                                MetricCapsule(title: NSLocalizedString("Expense", comment: ""), value: AppFormatters.statMoney(expense, currency: reportingCurrency), tint: AppTheme.coral)
                            }
                            if let currentBudgetProgress {
                                VStack(alignment: .leading, spacing: 8) {
                                    SectionTitle(NSLocalizedString("This month budget", comment: ""), subtitle: currentBudgetProgress.isOverspent ? NSLocalizedString("Over budget", comment: "") : NSLocalizedString("On track", comment: ""))
                                    BudgetProgressBar(progress: currentBudgetProgress)
                                }
                            }
                        }
                    }

                    if !children.isEmpty {
                        VStack(spacing: 10) {
                            SectionTitle(NSLocalizedString("Subcategories", comment: ""), subtitle: String(format: NSLocalizedString("%d linked under %@", comment: ""), children.count, category.name))
                            GlassSurface(padding: 0) {
                                VStack(spacing: 0) {
                                    ForEach(children) { child in
                                        let childTransactions = subcategoryTransactions(for: child)
                                        let childCurrency = reportingCurrency(for: childTransactions)
                                        let childAmount = childTransactions
                                            .filter { transactionCurrency($0) == childCurrency }
                                            .reduce(Decimal(0)) { $0 + $1.amount }
                                        NavigationLink {
                                            CategoryDetailView(
                                                category: child,
                                                categories: categories,
                                                transactions: transactions,
                                                rules: rules,
                                                budgets: budgets
                                            )
                                        } label: {
                                            CategoryMiniRow(
                                                category: child,
                                                transactionCount: childTransactions.count,
                                                amount: childAmount,
                                                currency: childCurrency
                                            )
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 13)
                                        }
                                        .buttonStyle(PrimaryPressStyle())
                                        if child.id != children.last?.id {
                                            Divider().overlay(AppTheme.line.opacity(0.45))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if !categoryRules.isEmpty {
                        VStack(spacing: 10) {
                            SectionTitle(NSLocalizedString("Matching rules", comment: ""), subtitle: String(format: NSLocalizedString("%d merchant patterns", comment: ""), categoryRules.count))
                            LazyVStack(spacing: 10) {
                                ForEach(categoryRules.prefix(24)) { rule in
                                    NavigationLink {
                                        RuleDetailView(rule: rule, transactions: transactions)
                                    } label: {
                                        RuleRow(rule: rule)
                                    }
                                    .buttonStyle(PrimaryPressStyle())
                                }
                            }
                        }
                    }

                    VStack(spacing: 10) {
                        SectionTitle(NSLocalizedString("Transactions", comment: ""), subtitle: String(format: NSLocalizedString("%d transactions", comment: ""), categoryTransactions.count))
                        if categoryTransactions.isEmpty {
                            EmptyStateView(
                                systemImage: "tray",
                                title: "No transactions",
                                message: "Transactions assigned to this category will appear here."
                            )
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(categoryTransactions.prefix(80)) { transaction in
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
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(NSLocalizedString("Edit", comment: ""), systemImage: "pencil") {
                        showingEditor = true
                    }
                    Button(category.isArchived ? NSLocalizedString("Restore", comment: "") : NSLocalizedString("Archive", comment: ""), systemImage: category.isArchived ? "arrow.uturn.backward" : "archivebox") {
                        category.isArchived.toggle()
                        try? modelContext.save()
                    }
                    Button(NSLocalizedString("Delete", comment: ""), systemImage: "trash", role: .destructive, action: deleteCategory)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            CategoryEditorView(
                category: category,
                categories: categories,
                transactions: transactions,
                rules: rules,
                budgets: budgets
            )
        }
        .sheet(item: $editingTransaction) { transaction in
            TransactionEditorView(transaction: transaction, accounts: accounts, categories: categories)
        }
        .alert("Category updated", isPresented: Binding(
            get: { categoryMessage != nil },
            set: { if !$0 { categoryMessage = nil } }
        )) {
            Button(NSLocalizedString("OK", comment: ""), role: .cancel) {}
        } message: {
            Text(categoryMessage ?? "")
        }
    }

    private var subtitle: String {
        if let parentName = category.parentName {
            return "\(parentName) • \(category.kind.displayName)"
        }
        return category.kind.displayName
    }

    private func subcategoryTransactions(for child: FinanceCategory) -> [FinanceTransaction] {
        transactions.filter { $0.categoryName == category.name && $0.subcategoryName == child.name }
    }

    private func reportingCurrency(for transactions: [FinanceTransaction]) -> String {
        CurrencyReporting.dominantCurrency(
            in: transactions,
            fallback: appCurrency,
            currency: { $0.currency },
            amount: { $0.amount }
        )
    }

    private func transactionCurrency(_ transaction: FinanceTransaction) -> String {
        AppFormatters.resolvedCurrency(transaction.currency, fallback: appCurrency)
    }

    private func deleteCategory() {
        guard !hasDependencies else {
            category.isArchived = true
            try? modelContext.save()
            categoryMessage = "This category is used by transactions, rules, budgets, or subcategories, so it was archived instead of deleted."
            return
        }
        modelContext.delete(category)
        try? modelContext.save()
    }

    private func delete(_ transaction: FinanceTransaction) {
        modelContext.delete(transaction)
        try? modelContext.save()
    }
}

private struct CategoryMiniRow: View {
    var category: FinanceCategory
    var transactionCount: Int
    var amount: Decimal
    var currency: String

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill((category.kind == .income ? AppTheme.teal : AppTheme.coral).opacity(0.18))
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(String(format: NSLocalizedString("%d transactions", comment: ""), transactionCount))
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
            Text(AppFormatters.statMoney(amount, currency: currency))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.ink.opacity(0.76))
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.muted.opacity(0.72))
        }
    }
}

private struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var category: FinanceCategory?
    var categories: [FinanceCategory]
    var transactions: [FinanceTransaction]
    var rules: [MerchantRule]
    var budgets: [Budget]

    @State private var name = ""
    @State private var kind: TransactionKind = .expense
    @State private var parentName = ""
    @State private var sortOrder = ""
    @State private var isArchived = false

    private var parentOptions: [FinanceCategory] {
        categories
            .filter { candidate in
                candidate.parentName == nil && candidate.id != category?.id
            }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var intSortOrder: Int {
        Int(sortOrder) ?? 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("Category", comment: "")) {
                    LabeledTextField(label: "Name", text: $name, prompt: "e.g. Travel")

                    Picker("Type", selection: $kind) {
                        ForEach(TransactionKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }

                    Picker("Parent", selection: $parentName) {
                        Text(NSLocalizedString("Top level", comment: "")).tag("")
                        ForEach(parentOptions) { parent in
                            Text(parent.name).tag(parent.name)
                        }
                    }

                    LabeledTextField(label: "Sort order", text: $sortOrder, prompt: "0", keyboard: .numberPad)

                    Toggle("Archived", isOn: $isArchived)
                }

                if category != nil {
                    Section(NSLocalizedString("Rename behavior", comment: "")) {
                        Text(NSLocalizedString("Saving a new name updates linked transactions, merchant rules, budgets, and child categories.", comment: ""))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .appFormStyle()
            .navigationTitle(category == nil ? NSLocalizedString("Add Category", comment: "") : NSLocalizedString("Edit Category", comment: ""))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Save", comment: ""), action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let category else {
            sortOrder = "\(nextSortOrder)"
            return
        }
        name = category.name
        kind = category.kind
        parentName = category.parentName ?? ""
        sortOrder = "\(category.sortOrder)"
        isArchived = category.isArchived
    }

    private var nextSortOrder: Int {
        (categories.map(\.sortOrder).max() ?? 0) + 1
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanParent = parentName.isEmpty ? nil : parentName
        guard !cleanName.isEmpty else { return }

        if let category {
            let oldName = category.name
            let oldParent = category.parentName

            category.name = cleanName
            category.kind = kind
            category.parentName = cleanParent
            category.sortOrder = intSortOrder
            category.isArchived = isArchived

            updateLinkedRecords(
                oldName: oldName,
                oldParent: oldParent,
                newName: cleanName,
                newParent: cleanParent
            )
        } else {
            modelContext.insert(
                FinanceCategory(
                    name: cleanName,
                    kind: kind,
                    parentName: cleanParent,
                    sortOrder: intSortOrder,
                    isArchived: isArchived
                )
            )
        }

        try? modelContext.save()
        dismiss()
    }

    private func updateLinkedRecords(oldName: String, oldParent: String?, newName: String, newParent: String?) {
        if oldParent == nil {
            for transaction in transactions where transaction.categoryName == oldName {
                transaction.categoryName = newParent ?? newName
                if newParent != nil {
                    transaction.subcategoryName = newName
                }
                transaction.updatedAt = .now
            }
            for rule in rules where rule.categoryName == oldName {
                rule.categoryName = newParent ?? newName
                if newParent != nil {
                    rule.subcategoryName = newName
                }
            }
            for budget in budgets where budget.categoryName == oldName {
                budget.categoryName = newParent ?? newName
                if newParent != nil {
                    budget.subcategoryName = newName
                }
            }
            for child in categories where child.parentName == oldName {
                child.parentName = newName
            }
        } else {
            for transaction in transactions where transaction.categoryName == oldParent && transaction.subcategoryName == oldName {
                transaction.categoryName = newParent ?? newName
                transaction.subcategoryName = newParent == nil ? nil : newName
                transaction.updatedAt = .now
            }
            for rule in rules where rule.categoryName == oldParent && rule.subcategoryName == oldName {
                rule.categoryName = newParent ?? newName
                rule.subcategoryName = newParent == nil ? nil : newName
            }
            for budget in budgets where budget.categoryName == oldParent && budget.subcategoryName == oldName {
                budget.categoryName = newParent ?? newName
                budget.subcategoryName = newParent == nil ? nil : newName
            }
        }
    }
}

private struct RuleDetailView: View {
    @Environment(\.appCurrency) private var appCurrency
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \FinanceCategory.sortOrder) private var categories: [FinanceCategory]
    var rule: MerchantRule
    var transactions: [FinanceTransaction]
    @State private var editingTransaction: FinanceTransaction?
    @State private var showingEditor = false
    @State private var ruleMessage: String?

    private var matchingTransactions: [FinanceTransaction] {
        let normalizedPattern = MerchantNormalizer.normalize(rule.pattern)
        return transactions.filter { transaction in
            let merchant = transaction.normalizedMerchant.isEmpty ? MerchantNormalizer.normalize(transaction.merchant) : transaction.normalizedMerchant
            return merchant.contains(normalizedPattern) || normalizedPattern.contains(merchant)
        }
    }

    private var total: Decimal {
        reportingTransactions.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var reportingCurrency: String {
        CurrencyReporting.dominantCurrency(
            in: matchingTransactions,
            fallback: appCurrency,
            currency: { $0.currency },
            amount: { $0.amount }
        )
    }

    private var reportingTransactions: [FinanceTransaction] {
        matchingTransactions.filter {
            AppFormatters.resolvedCurrency($0.currency, fallback: appCurrency) == reportingCurrency
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 16) {
                    GlassSurface {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 14) {
                                Image(systemName: "wand.and.sparkles")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(AppTheme.violet)
                                    .frame(width: 50, height: 50)
                                    .background(AppTheme.lavender.opacity(0.14), in: Circle())
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(rule.pattern)
                                        .font(.system(.title3, design: .rounded).weight(.bold))
                                        .foregroundStyle(AppTheme.ink)
                                        .lineLimit(2)
                                    Text("\(rule.categoryName)\(rule.subcategoryName.map { " / \($0)" } ?? "")")
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.muted)
                                }
                                Spacer()
                            }

                            HStack(spacing: 10) {
                                MetricCapsule(title: NSLocalizedString("Confidence", comment: ""), value: "\(Int(rule.confidence * 100))%", tint: AppTheme.lavender)
                                MetricCapsule(title: NSLocalizedString("Status", comment: ""), value: rule.isEnabled ? NSLocalizedString("On", comment: "") : NSLocalizedString("Off", comment: ""), tint: rule.isEnabled ? AppTheme.mint : AppTheme.line)
                            }
                            HStack(spacing: 10) {
                                MetricCapsule(title: NSLocalizedString("Matches", comment: ""), value: "\(matchingTransactions.count)", tint: AppTheme.teal)
                                MetricCapsule(title: NSLocalizedString("Total", comment: ""), value: AppFormatters.statMoney(total, currency: reportingCurrency), tint: AppTheme.gold)
                            }
                        }
                    }

                    VStack(spacing: 10) {
                        SectionTitle(NSLocalizedString("Matched transactions", comment: ""), subtitle: String(format: NSLocalizedString("%d rows using this pattern", comment: ""), matchingTransactions.count))
                        if matchingTransactions.isEmpty {
                            EmptyStateView(
                                systemImage: "magnifyingglass",
                                title: "No matches",
                                message: "No existing transactions currently match this merchant pattern."
                            )
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(matchingTransactions.prefix(80)) { transaction in
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
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(NSLocalizedString("Rule", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(NSLocalizedString("Edit", comment: ""), systemImage: "pencil") {
                        showingEditor = true
                    }
                    Button(rule.isEnabled ? NSLocalizedString("Disable", comment: "") : NSLocalizedString("Enable", comment: ""), systemImage: rule.isEnabled ? "pause.circle" : "play.circle") {
                        rule.isEnabled.toggle()
                        try? modelContext.save()
                    }
                    Button(NSLocalizedString("Apply to uncategorized", comment: ""), systemImage: "wand.and.sparkles") {
                        applyRuleToUncategorized()
                    }
                    Button(NSLocalizedString("Delete", comment: ""), systemImage: "trash", role: .destructive) {
                        modelContext.delete(rule)
                        try? modelContext.save()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            RuleEditorView(rule: rule, categories: categories)
        }
        .sheet(item: $editingTransaction) { transaction in
            TransactionEditorView(transaction: transaction, accounts: accounts, categories: categories)
        }
        .alert("Rule updated", isPresented: Binding(
            get: { ruleMessage != nil },
            set: { if !$0 { ruleMessage = nil } }
        )) {
            Button(NSLocalizedString("OK", comment: ""), role: .cancel) {}
        } message: {
            Text(ruleMessage ?? "")
        }
    }

    private func delete(_ transaction: FinanceTransaction) {
        modelContext.delete(transaction)
        try? modelContext.save()
    }

    private func applyRuleToUncategorized() {
        var changed = 0
        for transaction in matchingTransactions where transaction.categoryName == nil || transaction.categoryName?.isEmpty == true {
            transaction.kind = rule.kind
            transaction.categoryName = rule.categoryName
            transaction.subcategoryName = rule.subcategoryName
            transaction.updatedAt = .now
            changed += 1
        }
        rule.sampleCount += changed
        try? modelContext.save()
        ruleMessage = changed == 0 ? "No uncategorized matching transactions were found." : "Updated \(changed) matching transactions."
    }
}

private struct RuleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    var rule: MerchantRule?
    var categories: [FinanceCategory]

    @State private var pattern = ""
    @State private var matchType: MatchType = .contains
    @State private var kind: TransactionKind = .expense
    @State private var categoryName = ""
    @State private var subcategoryName = ""
    @State private var confidenceText = "95"
    @State private var isEnabled = true
    @State private var accountName = ""
    @State private var notePattern = ""
    @State private var minAmountText = ""
    @State private var maxAmountText = ""
    @State private var priorityText = "0"

    private var parentCategories: [FinanceCategory] {
        categories
            .filter { $0.kind == kind && $0.parentName == nil && !$0.isArchived }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var subcategories: [FinanceCategory] {
        categories
            .filter { $0.parentName == categoryName && !$0.isArchived }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var confidence: Double {
        min(max((Double(confidenceText) ?? 95) / 100, 0.01), 1)
    }

    private var minAmount: Decimal? {
        Decimal(string: minAmountText.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX"))
    }

    private var maxAmount: Decimal? {
        Decimal(string: maxAmountText.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX"))
    }

    private var priority: Int {
        Int(priorityText) ?? 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("Pattern", comment: "")) {
                    LabeledTextField(label: "Merchant pattern", text: $pattern, prompt: "e.g. NETFLIX", autocapitalization: .characters, autocorrection: false)
                    Picker("Match", selection: $matchType) {
                        Text(NSLocalizedString("Contains", comment: "")).tag(MatchType.contains)
                        Text(NSLocalizedString("Exact", comment: "")).tag(MatchType.exact)
                    }
                    Toggle("Enabled", isOn: $isEnabled)
                }

                Section(NSLocalizedString("Classification", comment: "")) {
                    Picker("Type", selection: $kind) {
                        ForEach(TransactionKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    Picker("Category", selection: $categoryName) {
                        Text(NSLocalizedString("Choose", comment: "")).tag("")
                        ForEach(parentCategories) { category in
                            Text(category.name).tag(category.name)
                        }
                    }
                    Picker("Subcategory", selection: $subcategoryName) {
                        Text(NSLocalizedString("None", comment: "")).tag("")
                        ForEach(subcategories) { subcategory in
                            Text(subcategory.name).tag(subcategory.name)
                        }
                    }
                    LabeledTextField(label: "Confidence %", text: $confidenceText, prompt: "95", keyboard: .numberPad)
                }

                Section(NSLocalizedString("Conditions (optional)", comment: "")) {
                    Picker("Account", selection: $accountName) {
                        Text(NSLocalizedString("Any account", comment: "")).tag("")
                        ForEach(accounts) { account in
                            Text(account.name).tag(account.name)
                        }
                    }
                    LabeledTextField(label: "Note keyword", text: $notePattern, prompt: "Optional keyword")
                    HStack {
                        LabeledNumberField(label: "Min amount", text: $minAmountText, prompt: "0.00")
                        Text(NSLocalizedString("to", comment: ""))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                        LabeledNumberField(label: "Max amount", text: $maxAmountText, prompt: "0.00")
                    }
                    LabeledTextField(label: "Priority", text: $priorityText, prompt: "0", keyboard: .numberPad)
                }
            }
            .appFormStyle()
            .navigationTitle(rule == nil ? NSLocalizedString("Add Rule", comment: "") : NSLocalizedString("Edit Rule", comment: ""))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Save", comment: ""), action: save)
                        .disabled(pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || categoryName.isEmpty)
                }
            }
            .onAppear(perform: load)
            .onChange(of: kind) { _, _ in
                if !parentCategories.contains(where: { $0.name == categoryName }) {
                    categoryName = ""
                    subcategoryName = ""
                }
            }
            .onChange(of: categoryName) { _, _ in
                if !subcategories.contains(where: { $0.name == subcategoryName }) {
                    subcategoryName = ""
                }
            }
        }
    }

    private func load() {
        guard let rule else { return }
        pattern = rule.pattern
        matchType = rule.matchType
        kind = rule.kind
        categoryName = rule.categoryName
        subcategoryName = rule.subcategoryName ?? ""
        confidenceText = "\(Int(rule.confidence * 100))"
        isEnabled = rule.isEnabled
        accountName = rule.accountName ?? ""
        notePattern = rule.notePattern ?? ""
        minAmountText = rule.minAmount.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
        maxAmountText = rule.maxAmount.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
        priorityText = "\(rule.priority)"
    }

    private func save() {
        let cleanPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPattern.isEmpty, !categoryName.isEmpty else { return }
        let cleanAccount = accountName.isEmpty ? nil : accountName
        let cleanNote = notePattern.isEmpty ? nil : notePattern
        let cleanMin = minAmountText.isEmpty ? nil : minAmount
        let cleanMax = maxAmountText.isEmpty ? nil : maxAmount
        if let rule {
            rule.pattern = cleanPattern
            rule.matchType = matchType
            rule.kind = kind
            rule.categoryName = categoryName
            rule.subcategoryName = subcategoryName.isEmpty ? nil : subcategoryName
            rule.confidence = confidence
            rule.isEnabled = isEnabled
            rule.accountName = cleanAccount
            rule.notePattern = cleanNote
            rule.minAmount = cleanMin
            rule.maxAmount = cleanMax
            rule.priority = priority
        } else {
            modelContext.insert(
                MerchantRule(
                    pattern: cleanPattern,
                    matchType: matchType,
                    categoryName: categoryName,
                    subcategoryName: subcategoryName.isEmpty ? nil : subcategoryName,
                    kind: kind,
                    confidence: confidence,
                    sampleCount: 0,
                    isEnabled: isEnabled,
                    accountName: cleanAccount,
                    notePattern: cleanNote,
                    minAmount: cleanMin,
                    maxAmount: cleanMax,
                    priority: priority
                )
            )
        }
        try? modelContext.save()
        dismiss()
    }
}
