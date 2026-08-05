import SwiftUI
import SwiftData

struct ScheduledTransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appCurrency) private var currency
    @Query(sort: \ScheduledTransaction.nextDate) private var scheduled: [ScheduledTransaction]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \FinanceCategory.sortOrder) private var categories: [FinanceCategory]
    @State private var showingEditor = false
    @State private var editingScheduled: ScheduledTransaction?
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false

    private var activeScheduled: [ScheduledTransaction] {
        scheduled.filter { $0.isEnabled }
    }

    private var disabledScheduled: [ScheduledTransaction] {
        scheduled.filter { !$0.isEnabled }
    }

    private var upcomingThisMonth: [ScheduledTransaction] {
        let calendar = Calendar.current
        return activeScheduled.filter { calendar.isDate($0.nextDate, equalTo: .now, toGranularity: .month) }
    }

    private var totalUpcoming: Decimal {
        upcomingThisMonth.filter { $0.kind == .expense }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var totalIncome: Decimal {
        upcomingThisMonth.filter { $0.kind == .income }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        heroCard

                        if activeScheduled.isEmpty {
                            EmptyStateView(
                                systemImage: "clock.arrow.circlepath",
                                title: "No scheduled transactions",
                                message: "Schedule recurring bills, income, or subscriptions to automatically create transactions on their due dates."
                            )
                        } else {
                            VStack(spacing: 12) {
                                SectionTitle(NSLocalizedString("Upcoming", comment: ""), subtitle: NSLocalizedString("Next occurrences for active schedules", comment: ""))
                                LazyVStack(spacing: 12) {
                                    ForEach(activeScheduled) { item in
                                        ScheduledTransactionRow(
                                            item: item,
                                            currency: currency,
                                            editAction: { editingScheduled = item },
                                            postNowAction: { postNow(item) },
                                            toggleAction: { toggle(item) }
                                        )
                                    }
                                }
                            }
                        }

                        if !disabledScheduled.isEmpty {
                            VStack(spacing: 12) {
                                SectionTitle(NSLocalizedString("Paused", comment: ""), subtitle: String(format: NSLocalizedString("%d disabled schedules", comment: ""), disabledScheduled.count))
                                LazyVStack(spacing: 12) {
                                    ForEach(disabledScheduled) { item in
                                        ScheduledTransactionRow(
                                            item: item,
                                            currency: currency,
                                            editAction: { editingScheduled = item },
                                            postNowAction: { postNow(item) },
                                            toggleAction: { toggle(item) }
                                        )
                                        .opacity(0.72)
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
            .navigationTitle(NSLocalizedString("Scheduled", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(NSLocalizedString("Add scheduled transaction", comment: ""))
                }
            }
            .sheet(isPresented: $showingEditor) {
                ScheduledTransactionEditorView(item: nil, accounts: accounts, categories: categories)
            }
            .sheet(item: $editingScheduled) { item in
                ScheduledTransactionEditorView(item: item, accounts: accounts, categories: categories)
            }
        }
        .task {
            refreshNotifications()
        }
        .onChange(of: scheduled) { _, _ in
            refreshNotifications()
        }
    }

    private func refreshNotifications() {
        guard notificationsEnabled else { return }
        NotificationService.updateScheduledTransactionReminders(scheduled: scheduled)
    }

    private var heroCard: some View {
        GlassSurface(padding: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("Scheduled", comment: ""))
                            .font(.caption.weight(.semibold))
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.violet)
                        Text(NSLocalizedString("Recurring transactions", comment: ""))
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                    }
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.violet)
                        .frame(width: 50, height: 50)
                        .background(AppTheme.lavender.opacity(0.14), in: Circle())
                }

                HStack(spacing: 10) {
                    MetricCapsule(title: NSLocalizedString("Upcoming bills", comment: ""), value: AppFormatters.statMoney(totalUpcoming, currency: currency), tint: AppTheme.coral)
                    MetricCapsule(title: NSLocalizedString("Expected income", comment: ""), value: AppFormatters.statMoney(totalIncome, currency: currency), tint: AppTheme.teal)
                }
            }
            .padding(20)
            .appHeroBackground()
        }
    }

    private func postNow(_ item: ScheduledTransaction) {
        let transaction = FinanceTransaction(
            date: item.nextDate,
            kind: item.kind,
            amount: item.amount,
            currency: item.currency,
            merchant: item.merchant,
            normalizedMerchant: item.normalizedMerchant,
            note: item.note,
            rawDescription: item.merchant,
            accountName: item.accountName,
            categoryName: item.categoryName,
            subcategoryName: item.subcategoryName
        )
        modelContext.insert(transaction)

        if let nextDate = item.frequency.nextDate(after: item.nextDate) {
            item.lastRunDate = item.nextDate
            item.nextDate = nextDate
        }
        try? modelContext.save()
    }

    private func toggle(_ item: ScheduledTransaction) {
        item.isEnabled.toggle()
        try? modelContext.save()
    }
}

private struct ScheduledTransactionRow: View {
    var item: ScheduledTransaction
    var currency: String
    var editAction: () -> Void
    var postNowAction: () -> Void
    var toggleAction: () -> Void

    private var daysUntil: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: item.nextDate)).day ?? 0
    }

    var body: some View {
        GlassSurface {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: item.kind == .income ? "arrow.down.left" : "arrow.up.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(item.kind == .income ? AppTheme.teal : AppTheme.coral)
                        .frame(width: 44, height: 44)
                        .background((item.kind == .income ? AppTheme.teal : AppTheme.coral).opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.merchant)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Text(item.frequency.displayName)
                            Text("•")
                            if daysUntil == 0 {
                                Text(NSLocalizedString("Today", comment: ""))
                                    .foregroundStyle(AppTheme.coral)
                            } else if daysUntil > 0 {
                                Text(String(format: NSLocalizedString("In %d days", comment: ""), daysUntil))
                                    .foregroundStyle(AppTheme.muted)
                            } else {
                                Text(NSLocalizedString("Overdue", comment: ""))
                                    .foregroundStyle(AppTheme.coral)
                            }
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.muted)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(AppFormatters.statMoney(item.amount, currency: currency))
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(item.kind == .income ? AppTheme.teal : AppTheme.ink)
                        Text(AppFormatters.dayString(from: item.nextDate))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                    }
                }

                HStack(spacing: 10) {
                    Button(action: postNowAction) {
                        Label(NSLocalizedString("Post now", comment: ""), systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.violet, in: Capsule())
                    }
                    .buttonStyle(PrimaryPressStyle())

                    Button(action: toggleAction) {
                        Label(item.isEnabled ? NSLocalizedString("Pause", comment: "") : NSLocalizedString("Enable", comment: ""), systemImage: item.isEnabled ? "pause.circle" : "play.circle")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.violet)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.lavender.opacity(0.15), in: Capsule())
                    }
                    .buttonStyle(PrimaryPressStyle())

                    Spacer()

                    Button(action: editAction) {
                        Image(systemName: "pencil")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.muted)
                    }
                }
            }
        }
    }
}

private struct ScheduledTransactionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appCurrency) private var appCurrency

    var item: ScheduledTransaction?
    var accounts: [Account]
    var categories: [FinanceCategory]

    @State private var merchant = ""
    @State private var amountText = ""
    @State private var currency = "USD"
    @State private var kind: TransactionKind = .expense
    @State private var accountName = ""
    @State private var categoryName = ""
    @State private var subcategoryName = ""
    @State private var note = ""
    @State private var frequency: ScheduleFrequency = .monthly
    @State private var nextDate = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
    @State private var isEnabled = true
    @State private var showingDeleteConfirmation = false

    private var activeAccounts: [Account] {
        accounts.filter { !$0.isArchived }
    }

    private var parentCategories: [FinanceCategory] {
        categories.filter { $0.kind == kind && $0.parentName == nil && !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var subcategories: [FinanceCategory] {
        categories.filter { $0.parentName == categoryName && !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var amount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX"))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("Transaction", comment: "")) {
                    LabeledTextField(label: "Merchant", text: $merchant, prompt: "e.g. Netflix")
                    Picker("Type", selection: $kind) {
                        ForEach(TransactionKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    LabeledNumberField(label: "Amount", text: $amountText, prompt: "0.00")
                    LabeledCurrencyButton(currency: $currency)
                    LabeledTextField(label: "Note", text: $note, prompt: "Optional details", autocorrection: true)
                }

                Section(NSLocalizedString("Classification", comment: "")) {
                    Picker("Account", selection: $accountName) {
                        ForEach(activeAccounts) { account in
                            Text(account.name).tag(account.name)
                        }
                    }

                    Picker("Category", selection: $categoryName) {
                        Text(NSLocalizedString("Uncategorized", comment: "")).tag("")
                        ForEach(parentCategories) { category in
                            Text(category.name).tag(category.name)
                        }
                    }

                    Picker("Subcategory", selection: $subcategoryName) {
                        Text(NSLocalizedString("None", comment: "")).tag("")
                        ForEach(subcategories) { category in
                            Text(category.name).tag(category.name)
                        }
                    }
                }

                Section(NSLocalizedString("Schedule", comment: "")) {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(ScheduleFrequency.allCases) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                    DatePicker("Next date", selection: $nextDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    Toggle("Enabled", isOn: $isEnabled)
                }

                if item != nil {
                    Section {
                        Button(NSLocalizedString("Delete schedule", comment: ""), role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
            .appFormStyle()
            .navigationTitle(item == nil ? NSLocalizedString("Add Scheduled Transaction", comment: "") : NSLocalizedString("Edit Scheduled Transaction", comment: ""))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Save", comment: ""), action: save)
                        .disabled(merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || amount == nil || accountName.isEmpty)
                }
            }
            .alert("Delete Schedule?", isPresented: $showingDeleteConfirmation) {
                Button(NSLocalizedString("Delete", comment: ""), role: .destructive) { deleteItem() }
                Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("Are you sure you want to delete this scheduled transaction? This action cannot be undone.", comment: ""))
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
        guard let item else {
            accountName = activeAccounts.first?.name ?? ""
            currency = appCurrency
            return
        }
        merchant = item.merchant
        amountText = NSDecimalNumber(decimal: item.amount).stringValue
        currency = item.currency
        kind = item.kind
        accountName = item.accountName
        categoryName = item.categoryName ?? ""
        subcategoryName = item.subcategoryName ?? ""
        note = item.note
        frequency = item.frequency
        nextDate = item.nextDate
        isEnabled = item.isEnabled
    }

    private func save() {
        guard let amount else { return }
        let cleanMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCurrency = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanMerchant.isEmpty, !accountName.isEmpty else { return }

        if let item {
            item.merchant = cleanMerchant
            item.normalizedMerchant = MerchantNormalizer.normalize(cleanMerchant)
            item.amount = amount
            item.currency = cleanCurrency.isEmpty ? "USD" : cleanCurrency
            item.kind = kind
            item.accountName = accountName
            item.categoryName = categoryName.isEmpty ? nil : categoryName
            item.subcategoryName = subcategoryName.isEmpty ? nil : subcategoryName
            item.note = note
            item.frequency = frequency
            item.nextDate = nextDate
            item.isEnabled = isEnabled
        } else {
            modelContext.insert(
                ScheduledTransaction(
                    merchant: cleanMerchant,
                    amount: amount,
                    currency: cleanCurrency.isEmpty ? "USD" : cleanCurrency,
                    kind: kind,
                    accountName: accountName,
                    categoryName: categoryName.isEmpty ? nil : categoryName,
                    subcategoryName: subcategoryName.isEmpty ? nil : subcategoryName,
                    note: note,
                    frequency: frequency,
                    nextDate: nextDate,
                    isEnabled: isEnabled
                )
            )
        }
        try? modelContext.save()
        dismiss()
    }

    private func deleteItem() {
        guard let item else { return }
        modelContext.delete(item)
        try? modelContext.save()
        dismiss()
    }
}
