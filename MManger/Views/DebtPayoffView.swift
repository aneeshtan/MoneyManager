import SwiftUI
import SwiftData

struct DebtPayoffView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appCurrency) private var currency
    @Query(sort: \DebtPayoffPlan.createdAt, order: .reverse) private var plans: [DebtPayoffPlan]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]
    @State private var showingEditor = false
    @State private var editingPlan: DebtPayoffPlan?

    private var activePlans: [DebtPayoffPlan] {
        plans.filter { !$0.isArchived }
    }

    private var totalDebt: Decimal {
        activePlans.reduce(Decimal(0)) { $0 + $1.totalDebt }
    }

    private var totalMonthly: Decimal {
        activePlans.reduce(Decimal(0)) { $0 + $1.monthlyPayment }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        heroCard

                        if activePlans.isEmpty {
                            EmptyStateView(
                                systemImage: "chart.line.downtrend.xyaxis",
                                title: "No debt payoff plans",
                                message: "Create a plan to track your debt payoff progress using snowball or avalanche strategy."
                            )
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(activePlans) { plan in
                                    Button {
                                        editingPlan = plan
                                    } label: {
                                        DebtPayoffCard(plan: plan, currency: currency, balance: currentBalance(for: plan))
                                    }
                                    .buttonStyle(PrimaryPressStyle())
                                }
                            }
                        }
                    }
                    .adaptiveScreenContent()
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(NSLocalizedString("Debt Payoff", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(NSLocalizedString("Add debt payoff plan", comment: ""))
                }
            }
            .sheet(isPresented: $showingEditor) {
                DebtPayoffEditorView(plan: nil, accounts: accounts)
            }
            .sheet(item: $editingPlan) { plan in
                DebtPayoffEditorView(plan: plan, accounts: accounts)
            }
        }
    }

    private func currentBalance(for plan: DebtPayoffPlan) -> Decimal {
        AccountBalance.value(for: plan.accountName, openingBalance: plan.totalDebt, transactions: transactions.filter { $0.accountName == plan.accountName })
    }

    private var heroCard: some View {
        GlassSurface(padding: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("Debt Payoff", comment: ""))
                            .font(.caption.weight(.semibold))
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.violet)
                        Text(NSLocalizedString("Track your payoff progress", comment: ""))
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                    }
                    Spacer()
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.violet)
                        .frame(width: 50, height: 50)
                        .background(AppTheme.lavender.opacity(0.14), in: Circle())
                }

                HStack(spacing: 10) {
                    MetricCapsule(title: "Total debt", value: AppFormatters.statMoney(totalDebt, currency: currency), tint: AppTheme.coral)
                    MetricCapsule(title: "Monthly payment", value: AppFormatters.statMoney(totalMonthly, currency: currency), tint: AppTheme.teal)
                }
            }
            .padding(20)
            .appHeroBackground()
        }
    }
}

private struct DebtPayoffCard: View {
    var plan: DebtPayoffPlan
    var currency: String
    var balance: Decimal

    private var progress: Double {
        guard plan.totalDebt > 0 else { return 0 }
        let paid = NSDecimalNumber(decimal: max(plan.totalDebt - abs(balance), 0)).doubleValue
        return min(max(paid / NSDecimalNumber(decimal: plan.totalDebt).doubleValue, 0), 1)
    }

    var body: some View {
        GlassSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "creditcard.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.coral)
                        .frame(width: 48, height: 48)
                        .background(AppTheme.coral.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(plan.name)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)
                        Text(plan.strategy.displayName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(AppFormatters.statMoney(abs(balance), currency: currency))
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.coral)
                        Text(NSLocalizedString("remaining", comment: ""))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progress)
                        .tint(progress >= 1 ? AppTheme.teal : AppTheme.violet)
                    HStack {
                        Text("\(AppFormatters.percent(progress)) paid off")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.muted)
                        Spacer()
                        if plan.estimatedMonths > 0 {
                            Text("~\(plan.estimatedMonths) months left")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppTheme.muted)
                        }
                    }
                }

                HStack(spacing: 10) {
                    MetricCapsule(title: "Monthly", value: AppFormatters.statMoney(plan.monthlyPayment, currency: currency), tint: AppTheme.teal)
                    MetricCapsule(title: "Interest", value: String(format: "%.1f%%", plan.interestRate), tint: AppTheme.gold)
                }
            }
        }
    }
}

private struct DebtPayoffEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appCurrency) private var appCurrency

    var plan: DebtPayoffPlan?
    var accounts: [Account]

    @State private var name = ""
    @State private var accountName = ""
    @State private var totalDebtText = ""
    @State private var minimumPaymentText = ""
    @State private var extraPaymentText = ""
    @State private var interestRateText = ""
    @State private var strategy: DebtPayoffStrategy = .avalanche
    @State private var showingDeleteConfirmation = false

    private var liabilityAccounts: [Account] {
        accounts.filter { $0.type == .liability || $0.name.lowercased().contains("loan") || $0.name.lowercased().contains("tabby") }
    }

    private var allAccounts: [Account] {
        accounts.filter { !$0.isArchived }
    }

    private var totalDebt: Decimal? {
        Decimal(string: totalDebtText.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX"))
    }

    private var minimumPayment: Decimal? {
        Decimal(string: minimumPaymentText.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX"))
    }

    private var extraPayment: Decimal? {
        Decimal(string: extraPaymentText.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX"))
    }

    private var interestRate: Double {
        Double(interestRateText) ?? 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("Plan", comment: "")) {
                    LabeledTextField(label: "Name", text: $name, prompt: "e.g. Car loan")
                    Picker("Account", selection: $accountName) {
                        Text(NSLocalizedString("Choose account", comment: "")).tag("")
                        ForEach(allAccounts) { account in
                            Text(account.name).tag(account.name)
                        }
                    }
                    LabeledNumberField(label: "Total debt", text: $totalDebtText, prompt: "0.00")
                }

                Section(NSLocalizedString("Payment", comment: "")) {
                    LabeledNumberField(label: "Minimum payment", text: $minimumPaymentText, prompt: "0.00")
                    LabeledNumberField(label: "Extra payment", text: $extraPaymentText, prompt: "0.00")
                    LabeledNumberField(label: "Interest rate %", text: $interestRateText, prompt: "0.0")
                }

                Section(NSLocalizedString("Strategy", comment: "")) {
                    Picker("Strategy", selection: $strategy) {
                        ForEach(DebtPayoffStrategy.allCases) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                }

                if plan != nil {
                    Section {
                        Button(NSLocalizedString("Delete plan", comment: ""), role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
            .appFormStyle()
            .navigationTitle(plan == nil ? "Add Debt Payoff Plan" : "Edit Debt Payoff Plan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Save", comment: ""), action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || totalDebt == nil || accountName.isEmpty)
                }
            }
            .alert("Delete Plan?", isPresented: $showingDeleteConfirmation) {
                Button(NSLocalizedString("Delete", comment: ""), role: .destructive) { deletePlan() }
                Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("Are you sure you want to delete this debt payoff plan?", comment: ""))
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let plan else {
            accountName = allAccounts.first?.name ?? ""
            return
        }
        name = plan.name
        accountName = plan.accountName
        totalDebtText = NSDecimalNumber(decimal: plan.totalDebt).stringValue
        minimumPaymentText = NSDecimalNumber(decimal: plan.minimumPayment).stringValue
        extraPaymentText = NSDecimalNumber(decimal: plan.extraPayment).stringValue
        interestRateText = String(plan.interestRate)
        strategy = plan.strategy
    }

    private func save() {
        guard let totalDebt else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, !accountName.isEmpty else { return }

        if let plan {
            plan.name = cleanName
            plan.accountName = accountName
            plan.totalDebt = totalDebt
            plan.minimumPayment = minimumPayment ?? 0
            plan.extraPayment = extraPayment ?? 0
            plan.interestRate = interestRate
            plan.strategy = strategy
        } else {
            modelContext.insert(
                DebtPayoffPlan(
                    name: cleanName,
                    accountName: accountName,
                    totalDebt: totalDebt,
                    minimumPayment: minimumPayment ?? 0,
                    extraPayment: extraPayment ?? 0,
                    interestRate: interestRate,
                    strategy: strategy
                )
            )
        }
        try? modelContext.save()
        dismiss()
    }

    private func deletePlan() {
        guard let plan else { return }
        modelContext.delete(plan)
        try? modelContext.save()
        dismiss()
    }
}
