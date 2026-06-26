import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FinanceCategory.sortOrder) private var categories: [FinanceCategory]
    @Query(sort: \MerchantRule.sampleCount, order: .reverse) private var rules: [MerchantRule]
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]
    @Query(sort: \Budget.monthStart, order: .reverse) private var budgets: [Budget]
    @State private var selectedTab = 0
    @State private var showingNewCategory = false
    @State private var showingRuleEditor = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        GlassSurface {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionTitle("Categories", subtitle: "Tap any category to see spending, rules, and transactions")
                                Picker("View", selection: $selectedTab) {
                                    Text("Categories").tag(0)
                                    Text("Rules").tag(1)
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        if selectedTab == 0 {
                            categoryList
                        } else {
                            ruleList
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Categories")
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
                    .accessibilityLabel(selectedTab == 0 ? "Add category" : "Add merchant rule")
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
        }
    }

    private var categoryList: some View {
        VStack(spacing: 12) {
            ForEach(parentCategories) { category in
                let children = categories.filter { $0.parentName == category.name }
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
                                total: totalAmount(for: category),
                                budgetProgress: budgetProgress(for: category)
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(PrimaryPressStyle())

                        if !children.isEmpty {
                            Divider().overlay(AppTheme.line.opacity(0.55))
                            ForEach(children) { child in
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
                                        total: totalAmount(for: child),
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

    private func totalAmount(for category: FinanceCategory) -> Decimal {
        matchingTransactions(for: category).reduce(Decimal(0)) { $0 + $1.amount }
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
                Text(AppFormatters.statMoney(total))
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
        var parts = [category.kind.displayName, "\(transactionCount) txns"]
        if let parentName = category.parentName {
            parts.insert(parentName, at: 0)
        }
        if category.isArchived {
            parts.append("Archived")
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
                Text("\(AppFormatters.statMoney(progress.spent)) of \(AppFormatters.statMoney(progress.budget.amount))")
                Spacer()
                Text(progress.isOverspent ? "Over \(AppFormatters.statMoney(abs(progress.remaining)))" : "\(AppFormatters.statMoney(progress.remaining)) left")
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
                    Text("\(rule.isEnabled ? "Enabled" : "Disabled") • \(rule.categoryName)\(rule.subcategoryName.map { " / \($0)" } ?? "") • \(Int(rule.confidence * 100))% • \(rule.sampleCount) samples")
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

    private var total: Decimal {
        categoryTransactions.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var income: Decimal {
        categoryTransactions.filter { $0.kind == .income }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var expense: Decimal {
        categoryTransactions.filter { $0.kind == .expense }.reduce(Decimal(0)) { $0 + $1.amount }
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
                                MetricCapsule(title: "Total", value: AppFormatters.statMoney(total), tint: AppTheme.lavender)
                                MetricCapsule(title: "Txns", value: "\(categoryTransactions.count)", tint: AppTheme.mint)
                            }
                            HStack(spacing: 10) {
                                MetricCapsule(title: "Income", value: AppFormatters.statMoney(income), tint: AppTheme.teal)
                                MetricCapsule(title: "Expense", value: AppFormatters.statMoney(expense), tint: AppTheme.coral)
                            }
                            if let currentBudgetProgress {
                                VStack(alignment: .leading, spacing: 8) {
                                    SectionTitle("This month budget", subtitle: currentBudgetProgress.isOverspent ? "Over budget" : "On track")
                                    BudgetProgressBar(progress: currentBudgetProgress)
                                }
                            }
                        }
                    }

                    if !children.isEmpty {
                        VStack(spacing: 10) {
                            SectionTitle("Subcategories", subtitle: "\(children.count) linked under \(category.name)")
                            GlassSurface(padding: 0) {
                                VStack(spacing: 0) {
                                    ForEach(children) { child in
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
                                                transactionCount: transactions.filter { $0.categoryName == category.name && $0.subcategoryName == child.name }.count,
                                                amount: transactions.filter { $0.categoryName == category.name && $0.subcategoryName == child.name }.reduce(Decimal(0)) { $0 + $1.amount }
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
                            SectionTitle("Matching rules", subtitle: "\(categoryRules.count) merchant patterns")
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
                        SectionTitle("Transactions", subtitle: "\(categoryTransactions.count) matching rows")
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
                    Button("Edit", systemImage: "pencil") {
                        showingEditor = true
                    }
                    Button(category.isArchived ? "Restore" : "Archive", systemImage: category.isArchived ? "arrow.uturn.backward" : "archivebox") {
                        category.isArchived.toggle()
                        try? modelContext.save()
                    }
                    Button("Delete", systemImage: "trash", role: .destructive, action: deleteCategory)
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
            Button("OK", role: .cancel) {}
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

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill((category.kind == .income ? AppTheme.teal : AppTheme.coral).opacity(0.18))
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Text("\(transactionCount) transactions")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
            Text(AppFormatters.statMoney(amount))
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
                Section("Category") {
                    TextField("Name", text: $name)

                    Picker("Type", selection: $kind) {
                        ForEach(TransactionKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }

                    Picker("Parent", selection: $parentName) {
                        Text("Top level").tag("")
                        ForEach(parentOptions) { parent in
                            Text(parent.name).tag(parent.name)
                        }
                    }

                    TextField("Sort order", text: $sortOrder)
                        .keyboardType(.numberPad)

                    Toggle("Archived", isOn: $isArchived)
                }

                if category != nil {
                    Section("Rename behavior") {
                        Text("Saving a new name updates linked transactions, merchant rules, budgets, and child categories.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(category == nil ? "Add Category" : "Edit Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
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
        matchingTransactions.reduce(Decimal(0)) { $0 + $1.amount }
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
                                MetricCapsule(title: "Confidence", value: "\(Int(rule.confidence * 100))%", tint: AppTheme.lavender)
                                MetricCapsule(title: "Status", value: rule.isEnabled ? "On" : "Off", tint: rule.isEnabled ? AppTheme.mint : AppTheme.line)
                            }
                            HStack(spacing: 10) {
                                MetricCapsule(title: "Matches", value: "\(matchingTransactions.count)", tint: AppTheme.teal)
                                MetricCapsule(title: "Total", value: AppFormatters.statMoney(total), tint: AppTheme.gold)
                            }
                        }
                    }

                    VStack(spacing: 10) {
                        SectionTitle("Matched transactions", subtitle: "\(matchingTransactions.count) rows using this pattern")
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
        .navigationTitle("Rule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit", systemImage: "pencil") {
                        showingEditor = true
                    }
                    Button(rule.isEnabled ? "Disable" : "Enable", systemImage: rule.isEnabled ? "pause.circle" : "play.circle") {
                        rule.isEnabled.toggle()
                        try? modelContext.save()
                    }
                    Button("Apply to uncategorized", systemImage: "wand.and.sparkles") {
                        applyRuleToUncategorized()
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
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
            Button("OK", role: .cancel) {}
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

    var rule: MerchantRule?
    var categories: [FinanceCategory]

    @State private var pattern = ""
    @State private var matchType: MatchType = .contains
    @State private var kind: TransactionKind = .expense
    @State private var categoryName = ""
    @State private var subcategoryName = ""
    @State private var confidenceText = "95"
    @State private var isEnabled = true

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

    var body: some View {
        NavigationStack {
            Form {
                Section("Pattern") {
                    TextField("Merchant pattern", text: $pattern)
                        .textInputAutocapitalization(.characters)
                    Picker("Match", selection: $matchType) {
                        Text("Contains").tag(MatchType.contains)
                        Text("Exact").tag(MatchType.exact)
                    }
                    Toggle("Enabled", isOn: $isEnabled)
                }

                Section("Classification") {
                    Picker("Type", selection: $kind) {
                        ForEach(TransactionKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    Picker("Category", selection: $categoryName) {
                        Text("Choose").tag("")
                        ForEach(parentCategories) { category in
                            Text(category.name).tag(category.name)
                        }
                    }
                    Picker("Subcategory", selection: $subcategoryName) {
                        Text("None").tag("")
                        ForEach(subcategories) { subcategory in
                            Text(subcategory.name).tag(subcategory.name)
                        }
                    }
                    TextField("Confidence %", text: $confidenceText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle(rule == nil ? "Add Rule" : "Edit Rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
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
    }

    private func save() {
        let cleanPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPattern.isEmpty, !categoryName.isEmpty else { return }
        if let rule {
            rule.pattern = cleanPattern
            rule.matchType = matchType
            rule.kind = kind
            rule.categoryName = categoryName
            rule.subcategoryName = subcategoryName.isEmpty ? nil : subcategoryName
            rule.confidence = confidence
            rule.isEnabled = isEnabled
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
                    isEnabled: isEnabled
                )
            )
        }
        try? modelContext.save()
        dismiss()
    }
}
