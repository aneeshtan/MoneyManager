import SwiftUI
import SwiftData

struct SavingsGoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appCurrency) private var currency
    @Query(sort: \SavingsGoal.sortOrder) private var goals: [SavingsGoal]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]
    @State private var showingEditor = false
    @State private var editingGoal: SavingsGoal?
    @State private var contributingGoal: SavingsGoal?

    private var activeGoals: [SavingsGoal] {
        goals.filter { !$0.isArchived }
    }

    private var archivedGoals: [SavingsGoal] {
        goals.filter(\.isArchived)
    }

    private var totalTarget: Decimal {
        activeGoals.reduce(Decimal(0)) { $0 + $1.targetAmount }
    }

    private var totalSaved: Decimal {
        activeGoals.reduce(Decimal(0)) { $0 + $1.currentAmount }
    }

    private var overallProgress: Double {
        let target = NSDecimalNumber(decimal: totalTarget).doubleValue
        guard target > 0 else { return 0 }
        return min(max(NSDecimalNumber(decimal: totalSaved).doubleValue / target, 0), 1)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        heroCard

                        if activeGoals.isEmpty {
                            EmptyStateView(
                                systemImage: "target",
                                title: "No savings goals",
                                message: "Create a goal for an emergency fund, vacation, or any target you want to reach."
                            )
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(activeGoals) { goal in
                                    Button {
                                        editingGoal = goal
                                    } label: {
                                        SavingsGoalCard(
                                            goal: goal,
                                            currency: currency,
                                            contributeAction: { contributingGoal = goal }
                                        )
                                    }
                                    .buttonStyle(PrimaryPressStyle())
                                }
                            }
                        }

                        if !archivedGoals.isEmpty {
                            VStack(spacing: 10) {
                                SectionTitle("Archived", subtitle: "\(archivedGoals.count) completed or removed goals")
                                LazyVStack(spacing: 12) {
                                    ForEach(archivedGoals) { goal in
                                        Button {
                                            editingGoal = goal
                                        } label: {
                                            SavingsGoalCard(
                                                goal: goal,
                                                currency: currency,
                                                contributeAction: { contributingGoal = goal }
                                            )
                                            .opacity(0.72)
                                        }
                                        .buttonStyle(PrimaryPressStyle())
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
            .navigationTitle(NSLocalizedString("Savings Goals", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(NSLocalizedString("Add savings goal", comment: ""))
                }
            }
            .sheet(isPresented: $showingEditor) {
                SavingsGoalEditorView(goal: nil)
            }
            .sheet(item: $editingGoal) { goal in
                SavingsGoalEditorView(goal: goal)
            }
            .sheet(item: $contributingGoal) { goal in
                SavingsGoalContributionView(goal: goal)
            }
        }
    }

    private var heroCard: some View {
        GlassSurface(padding: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("Savings Goals", comment: ""))
                            .font(.caption.weight(.semibold))
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.violet)
                        Text(NSLocalizedString("Track progress toward your targets", comment: ""))
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                    }
                    Spacer()
                    Image(systemName: "target")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.violet)
                        .frame(width: 50, height: 50)
                        .background(AppTheme.lavender.opacity(0.14), in: Circle())
                }

                HStack(spacing: 10) {
                    MetricCapsule(title: "Saved", value: AppFormatters.statMoney(totalSaved, currency: currency), tint: AppTheme.teal)
                    MetricCapsule(title: "Target", value: AppFormatters.statMoney(totalTarget, currency: currency), tint: AppTheme.lavender)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(NSLocalizedString("Overall progress", comment: ""))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                        Spacer()
                        Text(AppFormatters.percent(overallProgress))
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                    }
                    ProgressView(value: overallProgress)
                        .tint(overallProgress >= 1 ? AppTheme.teal : AppTheme.violet)
                }
            }
            .padding(20)
            .appHeroBackground()
        }
    }
}

private struct SavingsGoalCard: View {
    var goal: SavingsGoal
    var currency: String
    var contributeAction: () -> Void

    private var daysRemaining: Int? {
        guard let targetDate = goal.targetDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: calendar.startOfDay(for: targetDate))
        return components.day
    }

    var body: some View {
        GlassSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: goal.isComplete ? "checkmark.seal.fill" : "target")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(goal.isComplete ? AppTheme.teal : AppTheme.violet)
                        .frame(width: 48, height: 48)
                        .background((goal.isComplete ? AppTheme.teal : AppTheme.violet).opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(goal.name)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)
                        if let daysRemaining {
                            Text(daysRemaining >= 0 ? "\(daysRemaining) days left" : "Past target date")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(daysRemaining >= 0 ? AppTheme.muted : AppTheme.coral)
                        } else {
                            Text(NSLocalizedString("No target date", comment: ""))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppTheme.muted)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(AppFormatters.statMoney(goal.currentAmount, currency: currency))
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                        Text("of \(AppFormatters.statMoney(goal.targetAmount, currency: currency))")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: goal.progress)
                        .tint(goal.isComplete ? AppTheme.teal : (goal.progress >= 0.75 ? AppTheme.mint : AppTheme.violet))
                    HStack {
                        Text(AppFormatters.percent(goal.progress))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.muted)
                        Spacer()
                        if !goal.isComplete {
                            Text("\(AppFormatters.statMoney(goal.remaining, currency: currency)) to go")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppTheme.muted)
                        } else {
                            Text(NSLocalizedString("Goal reached", comment: ""))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.teal)
                        }
                    }
                }

                if !goal.isComplete {
                    Button(action: contributeAction) {
                        Label(NSLocalizedString("Add contribution", comment: ""), systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(PrimaryPressStyle())
                }
            }
        }
    }
}

private struct SavingsGoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appCurrency) private var appCurrency
    @Query(sort: \SavingsGoal.sortOrder) private var goals: [SavingsGoal]

    var goal: SavingsGoal?

    @State private var name = ""
    @State private var targetAmountText = ""
    @State private var currentAmountText = "0"
    @State private var currency = "USD"
    @State private var hasTargetDate = false
    @State private var targetDate = Calendar.current.date(byAdding: .month, value: 6, to: .now) ?? .now
    @State private var showingDeleteConfirmation = false

    private var targetAmount: Decimal? {
        Decimal(string: targetAmountText.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX"))
    }

    private var currentAmount: Decimal? {
        Decimal(string: currentAmountText.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX"))
    }

    private var nextSortOrder: Int {
        (goals.map(\.sortOrder).max() ?? 0) + 1
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("Goal", comment: "")) {
                    LabeledTextField(label: "Name", text: $name, prompt: "e.g. Vacation")
                    LabeledNumberField(label: "Target amount", text: $targetAmountText, prompt: "0.00")
                    LabeledNumberField(label: "Current amount", text: $currentAmountText, prompt: "0.00")
                    LabeledCurrencyButton(currency: $currency)
                }

                Section(NSLocalizedString("Target date", comment: "")) {
                    Toggle("Set target date", isOn: $hasTargetDate.animation())
                    if hasTargetDate {
                        DatePicker("Target date", selection: $targetDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }
                }

                if goal != nil {
                    Section {
                        Button(NSLocalizedString("Delete goal", comment: ""), role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
            .appFormStyle()
            .navigationTitle(goal == nil ? "Add Savings Goal" : "Edit Savings Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Save", comment: ""), action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || targetAmount == nil)
                }
            }
            .alert("Delete Goal?", isPresented: $showingDeleteConfirmation) {
                Button(NSLocalizedString("Delete", comment: ""), role: .destructive) { deleteGoal() }
                Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("Are you sure you want to delete this savings goal? This action cannot be undone.", comment: ""))
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let goal else {
            currency = appCurrency
            return
        }
        name = goal.name
        targetAmountText = NSDecimalNumber(decimal: goal.targetAmount).stringValue
        currentAmountText = NSDecimalNumber(decimal: goal.currentAmount).stringValue
        currency = goal.currency
        if let targetDate = goal.targetDate {
            hasTargetDate = true
            self.targetDate = targetDate
        }
    }

    private func save() {
        guard let targetAmount, let currentAmount else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCurrency = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanName.isEmpty else { return }

        if let goal {
            goal.name = cleanName
            goal.targetAmount = targetAmount
            goal.currentAmount = currentAmount
            goal.currency = cleanCurrency.isEmpty ? "USD" : cleanCurrency
            goal.targetDate = hasTargetDate ? targetDate : nil
        } else {
            modelContext.insert(
                SavingsGoal(
                    name: cleanName,
                    targetAmount: targetAmount,
                    currentAmount: currentAmount,
                    currency: cleanCurrency.isEmpty ? "USD" : cleanCurrency,
                    targetDate: hasTargetDate ? targetDate : nil,
                    sortOrder: nextSortOrder
                )
            )
        }
        try? modelContext.save()
        dismiss()
    }

    private func deleteGoal() {
        guard let goal else { return }
        modelContext.delete(goal)
        try? modelContext.save()
        dismiss()
    }
}

private struct SavingsGoalContributionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appCurrency) private var currency

    var goal: SavingsGoal

    @State private var amountText = ""
    @State private var isWithdrawal = false

    private var amount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX"))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Contribution to \(goal.name)") {
                    LabeledNumberField(label: "Amount", text: $amountText, prompt: "0.00")
                    Toggle("Withdraw from goal", isOn: $isWithdrawal)
                }

                Section(NSLocalizedString("Current status", comment: "")) {
                    LabeledContent("Saved", value: AppFormatters.statMoney(goal.currentAmount, currency: currency))
                    LabeledContent("Target", value: AppFormatters.statMoney(goal.targetAmount, currency: currency))
                    LabeledContent("Remaining", value: AppFormatters.statMoney(goal.remaining, currency: currency))
                }
            }
            .appFormStyle()
            .navigationTitle(NSLocalizedString("Add Contribution", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Save", comment: ""), action: save)
                        .disabled(amount == nil || amount == 0)
                }
            }
        }
    }

    private func save() {
        guard let amount else { return }
        if isWithdrawal {
            goal.currentAmount = max(goal.currentAmount - amount, 0)
        } else {
            goal.currentAmount += amount
        }
        try? modelContext.save()
        dismiss()
    }
}
