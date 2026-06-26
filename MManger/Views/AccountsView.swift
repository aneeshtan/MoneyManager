import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]
    @State private var editingAccount: Account?
    @State private var showingNewAccount = false
    @State private var accountDeleteError: String?

    private var activeAccounts: [Account] {
        accounts.filter { !$0.isArchived }
    }

    private var archivedAccounts: [Account] {
        accounts.filter(\.isArchived)
    }

    private var totalBalance: Decimal {
        activeAccounts.reduce(Decimal(0)) { partial, account in
            partial + balance(for: account)
        }
    }

    private var liquidBalance: Decimal {
        activeAccounts.filter { $0.type != .liability }.reduce(Decimal(0)) { $0 + max(balance(for: $1), 0) }
    }

    private var debtBalance: Decimal {
        activeAccounts.filter { $0.type == .liability || balance(for: $0) < 0 }.reduce(Decimal(0)) { $0 + abs(min(balance(for: $1), 0)) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        GlassSurface {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Accounts")
                                    .font(.system(.title2, design: .rounded).weight(.bold))
                                    .foregroundStyle(AppTheme.ink)
                                Text("Your balances across cash, cards, and bank accounts.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.muted)
                                Text(AppFormatters.statMoney(totalBalance))
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppTheme.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.65)
                                    .padding(.top, 4)
                                HStack(spacing: 10) {
                                    MetricCapsule(title: "Liquid", value: AppFormatters.statMoney(liquidBalance), tint: AppTheme.teal)
                                    MetricCapsule(title: "Debt", value: AppFormatters.statMoney(debtBalance), tint: debtBalance > 0 ? AppTheme.coral : AppTheme.mint)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if activeAccounts.isEmpty {
                            EmptyStateView(
                                systemImage: "creditcard",
                                title: "No accounts",
                                message: archivedAccounts.isEmpty ? "Seeded accounts or newly created accounts will appear here." : "Restore an archived account or add a new one."
                            )
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(Array(activeAccounts.enumerated()), id: \.element.id) { index, account in
                                    NavigationLink {
                                        AccountDetailView(
                                            account: account,
                                            transactions: transactions,
                                            balance: balance(for: account),
                                            type: account.type,
                                            edit: { editingAccount = account },
                                            remove: { remove(account) },
                                            restore: { restore(account) }
                                        )
                                    } label: {
                                        AccountCard(
                                        account: account,
                                        balance: balance(for: account),
                                        transactionCount: transactionCount(for: account),
                                        type: account.type,
                                        tint: AppTheme.categoryPalette[index % AppTheme.categoryPalette.count]
                                    )
                                    }
                                    .buttonStyle(PrimaryPressStyle())
                                }
                            }
                        }

                        if !archivedAccounts.isEmpty {
                            VStack(spacing: 10) {
                                SectionTitle("Archived", subtitle: "\(archivedAccounts.count) removed accounts kept for history")
                                LazyVStack(spacing: 12) {
                                    ForEach(Array(archivedAccounts.enumerated()), id: \.element.id) { index, account in
                                        NavigationLink {
                                            AccountDetailView(
                                                account: account,
                                                transactions: transactions,
                                                balance: balance(for: account),
                                                type: account.type,
                                                edit: { editingAccount = account },
                                                remove: { remove(account) },
                                                restore: { restore(account) }
                                            )
                                        } label: {
                                            AccountCard(
                                                account: account,
                                                balance: balance(for: account),
                                                transactionCount: transactionCount(for: account),
                                                type: account.type,
                                                tint: AppTheme.categoryPalette[(index + activeAccounts.count) % AppTheme.categoryPalette.count]
                                            )
                                            .opacity(0.72)
                                        }
                                        .buttonStyle(PrimaryPressStyle())
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
            .navigationTitle("Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewAccount = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add account")
                }
            }
            .sheet(isPresented: $showingNewAccount) {
                AccountEditorView(account: nil, transactions: transactions)
            }
            .sheet(item: $editingAccount) { account in
                AccountEditorView(account: account, transactions: transactions)
            }
            .alert("Account cannot be deleted", isPresented: Binding(
                get: { accountDeleteError != nil },
                set: { if !$0 { accountDeleteError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(accountDeleteError ?? "")
            }
        }
    }

    private func transactionCount(for account: Account) -> Int {
        transactions.filter { $0.accountName == account.name }.count
    }

    private func balance(for account: Account) -> Decimal {
        AccountBalance.value(for: account.name, openingBalance: account.openingBalance, transactions: transactions)
    }

    private func remove(_ account: Account) {
        let count = transactionCount(for: account)
        if account.isArchived {
            guard count == 0 else {
                accountDeleteError = "This archived account has \(count) transactions. Restore it, or move/delete its transactions before permanently deleting it."
                return
            }
            modelContext.delete(account)
            try? modelContext.save()
            return
        }

        guard count == 0 else {
            account.isArchived = true
            try? modelContext.save()
            return
        }
        modelContext.delete(account)
        try? modelContext.save()
    }

    private func restore(_ account: Account) {
        account.isArchived = false
        try? modelContext.save()
    }
}

private struct AccountCard: View {
    var account: Account
    var balance: Decimal
    var transactionCount: Int
    var type: AccountType
    var tint: Color

    var body: some View {
        GlassSurface {
            HStack(spacing: 14) {
                Image(systemName: iconName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(account.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                    Text("\(type.displayName) • \(transactionCount) transactions • \(account.currency)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer(minLength: 10)

                Text(AppFormatters.money(balance, currency: account.currency))
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(balance >= 0 ? AppTheme.ink : AppTheme.coral)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.62)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.muted.opacity(0.68))
            }
        }
    }

    private var iconName: String {
        let name = account.name.lowercased()
        if name.contains("cash") { return "banknote" }
        if name.contains("saving") { return "building.columns" }
        if name.contains("tabby") { return "shippingbox" }
        return "creditcard"
    }
}

private struct AccountDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FinanceCategory.sortOrder) private var categories: [FinanceCategory]
    var account: Account
    var transactions: [FinanceTransaction]
    var balance: Decimal
    var type: AccountType
    var edit: () -> Void
    var remove: () -> Void
    var restore: () -> Void
    @State private var editingTransaction: FinanceTransaction?

    private var accountTransactions: [FinanceTransaction] {
        transactions.filter { $0.accountName == account.name }.sorted { $0.date > $1.date }
    }

    private var income: Decimal {
        accountTransactions.filter { $0.kind == .income }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var expense: Decimal {
        accountTransactions.filter { $0.kind == .expense }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 16) {
                    GlassSurface {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 14) {
                                Image(systemName: iconName)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(AppTheme.violet)
                                    .frame(width: 50, height: 50)
                                    .background(AppTheme.lavender.opacity(0.14), in: Circle())
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(account.name)
                                        .font(.system(.title2, design: .rounded).weight(.bold))
                                        .foregroundStyle(AppTheme.ink)
                                    Text(account.currency)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.muted)
                                }
                                Spacer()
                            }

                            HStack(spacing: 10) {
                                MetricCapsule(title: "Balance", value: AppFormatters.money(balance, currency: account.currency), tint: AppTheme.lavender)
                                MetricCapsule(title: "Txns", value: "\(accountTransactions.count)", tint: AppTheme.mint)
                            }
                            HStack(spacing: 10) {
                                MetricCapsule(title: "Income", value: AppFormatters.money(income, currency: account.currency), tint: AppTheme.teal)
                                MetricCapsule(title: "Expense", value: AppFormatters.money(expense, currency: account.currency), tint: AppTheme.coral)
                            }
                            AccountHealthBanner(type: type, balance: balance, currency: account.currency, isArchived: account.isArchived)
                        }
                    }

                    VStack(spacing: 10) {
                        SectionTitle("Transactions", subtitle: "\(accountTransactions.count) rows linked to this account")
                        if accountTransactions.isEmpty {
                            EmptyStateView(
                                systemImage: "tray",
                                title: "No transactions",
                                message: "Transactions assigned to this account will appear here."
                            )
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(accountTransactions.prefix(120)) { transaction in
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
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingTransaction) { transaction in
            TransactionEditorView(transaction: transaction, accounts: [account], categories: categories)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if account.isArchived {
                        Button("Restore", systemImage: "arrow.uturn.backward", action: restore)
                        Button("Delete Permanently", systemImage: "trash", role: .destructive, action: remove)
                    } else {
                        Button("Edit", systemImage: "pencil", action: edit)
                        Button("Remove", systemImage: "archivebox", role: .destructive, action: remove)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private func delete(_ transaction: FinanceTransaction) {
        modelContext.delete(transaction)
        try? modelContext.save()
    }

    private var iconName: String {
        let name = account.name.lowercased()
        if name.contains("cash") { return "banknote" }
        if name.contains("saving") { return "building.columns" }
        if name.contains("tabby") { return "shippingbox" }
        return "creditcard"
    }
}

private struct AccountHealthBanner: View {
    var type: AccountType
    var balance: Decimal
    var currency: String
    var isArchived: Bool

    private var message: String {
        if isArchived {
            return "Archived account. Transactions are preserved, but this account is hidden from active totals and pickers."
        }
        switch type {
        case .creditCard:
            return balance < 0 ? "Card exposure is \(AppFormatters.money(abs(balance), currency: currency)). Track payments against statements." : "Card is currently not carrying a negative app balance."
        case .liability:
            return "Liability account. Keep this separated from cash and bank balances for clearer net worth."
        case .investment:
            return "Investment account. Include periodic valuation updates to keep net worth accurate."
        case .cash, .bank:
            return "Liquid account. This contributes to cash available for spending."
        case .other:
            return "Review this account type if you want more precise net worth grouping."
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "heart.text.square")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.violet)
            Text(message)
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .background(AppTheme.lavender.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct AccountEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var account: Account?
    var transactions: [FinanceTransaction]

    @State private var name = ""
    @State private var currency = "AED"
    @State private var currentValue = ""
    @State private var type: AccountType = .other
    @State private var sortOrder = ""

    private var decimalCurrentValue: Decimal? {
        Decimal(string: currentValue.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX"))
    }

    private var intSortOrder: Int {
        Int(sortOrder) ?? 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Name", text: $name)
                    TextField("Currency", text: $currency)
                        .textInputAutocapitalization(.characters)
                    Picker("Type", selection: $type) {
                        ForEach(AccountType.allCases) { accountType in
                            Text(accountType.displayName).tag(accountType)
                        }
                    }
                    TextField("Current value", text: $currentValue)
                        .keyboardType(.decimalPad)
                    TextField("Sort order", text: $sortOrder)
                        .keyboardType(.numberPad)
                }

                if account != nil {
                    Section("Rename behavior") {
                        Text("Saving a new name updates existing transactions linked to this account. Current value adjusts the opening balance behind the scenes.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(account == nil ? "Add Account" : "Edit Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || decimalCurrentValue == nil)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let account else {
            currentValue = "0"
            sortOrder = "0"
            return
        }
        name = account.name
        currency = account.currency
        type = account.type
        currentValue = NSDecimalNumber(decimal: AccountBalance.value(for: account.name, openingBalance: account.openingBalance, transactions: transactions)).stringValue
        sortOrder = "\(account.sortOrder)"
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCurrency = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanName.isEmpty, let targetCurrentValue = decimalCurrentValue else { return }

        if let account {
            let oldName = account.name
            let openingBalance = AccountBalance.adjustedOpeningBalance(
                targetCurrentValue: targetCurrentValue,
                accountName: oldName,
                transactions: transactions
            )
            account.name = cleanName
            account.currency = cleanCurrency.isEmpty ? "AED" : cleanCurrency
            account.type = type
            account.openingBalance = openingBalance
            account.sortOrder = intSortOrder

            if oldName != cleanName {
                for transaction in transactions where transaction.accountName == oldName {
                    transaction.accountName = cleanName
                    transaction.updatedAt = .now
                }
            }
        } else {
            modelContext.insert(
                Account(
                    name: cleanName,
                    currency: cleanCurrency.isEmpty ? "AED" : cleanCurrency,
                    openingBalance: targetCurrentValue,
                    type: type,
                    sortOrder: intSortOrder
                )
            )
        }

        try? modelContext.save()
        dismiss()
    }
}
