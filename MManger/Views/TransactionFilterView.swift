import SwiftUI

// MARK: - Filter Model

struct TransactionFilter: Equatable {
    var startDate: Date?
    var endDate: Date?
    var accountName: String = ""
    var categoryName: String = ""
    var kind: TransactionKind? = nil
    var minAmount: Decimal? = nil
    var maxAmount: Decimal? = nil

    var isActive: Bool {
        startDate != nil || endDate != nil || !accountName.isEmpty
        || !categoryName.isEmpty || kind != nil || minAmount != nil || maxAmount != nil
    }

    func matches(_ t: FinanceTransaction) -> Bool {
        if let start = startDate, t.date < start { return false }
        if let end = endDate, t.date > end { return false }
        if !accountName.isEmpty, t.accountName != accountName { return false }
        if !categoryName.isEmpty, (t.categoryName ?? "") != categoryName { return false }
        if let k = kind, t.kind != k { return false }
        if let min = minAmount, t.amount < min { return false }
        if let max = maxAmount, t.amount > max { return false }
        return true
    }
}

// MARK: - Filter Sheet

struct TransactionFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var filter: TransactionFilter
    var accounts: [Account]
    var categories: [FinanceCategory]

    @State private var draft: TransactionFilter
    @State private var minAmountText = ""
    @State private var maxAmountText = ""
    @State private var useStartDate = false
    @State private var useEndDate = false

    init(filter: Binding<TransactionFilter>, accounts: [Account], categories: [FinanceCategory]) {
        self._filter = filter
        self.accounts = accounts
        self.categories = categories
        self._draft = State(initialValue: filter.wrappedValue)
    }

    private var parentCategories: [FinanceCategory] {
        categories.filter { $0.parentName == nil && !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Date range") {
                    Toggle("From", isOn: $useStartDate.animation())
                    if useStartDate {
                        DatePicker("Start", selection: Binding(
                            get: { draft.startDate ?? Calendar.current.date(byAdding: .month, value: -1, to: .now)! },
                            set: { draft.startDate = $0 }
                        ), displayedComponents: .date)
                        .datePickerStyle(.compact)
                    }
                    Toggle("To", isOn: $useEndDate.animation())
                    if useEndDate {
                        DatePicker("End", selection: Binding(
                            get: { draft.endDate ?? .now },
                            set: { draft.endDate = $0 }
                        ), displayedComponents: .date)
                        .datePickerStyle(.compact)
                    }
                }

                Section("Transaction type") {
                    Picker("Type", selection: $draft.kind) {
                        Text("Any").tag(Optional<TransactionKind>.none)
                        ForEach(TransactionKind.allCases) { k in
                            Text(k.displayName).tag(Optional(k))
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Account") {
                    Picker("Account", selection: $draft.accountName) {
                        Text("Any").tag("")
                        ForEach(accounts.filter { !$0.isArchived }) { account in
                            Text(account.name).tag(account.name)
                        }
                    }
                }

                Section("Category") {
                    Picker("Category", selection: $draft.categoryName) {
                        Text("Any").tag("")
                        Text("Uncategorized").tag("__uncategorized__")
                        ForEach(parentCategories) { cat in
                            Text(cat.name).tag(cat.name)
                        }
                    }
                }

                Section("Amount range") {
                    HStack {
                        Text("Min")
                            .foregroundStyle(AppTheme.muted)
                            .frame(width: 36, alignment: .leading)
                        TextField("0.00", text: $minAmountText)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("Max")
                            .foregroundStyle(AppTheme.muted)
                            .frame(width: 36, alignment: .leading)
                        TextField("Any", text: $maxAmountText)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    Button("Clear all filters", role: .destructive) {
                        draft = TransactionFilter()
                        minAmountText = ""
                        maxAmountText = ""
                        useStartDate = false
                        useEndDate = false
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyAndDismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear(perform: loadDraft)
        }
    }

    private func loadDraft() {
        useStartDate = draft.startDate != nil
        useEndDate = draft.endDate != nil
        minAmountText = draft.minAmount.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
        maxAmountText = draft.maxAmount.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
    }

    private func applyAndDismiss() {
        if !useStartDate { draft.startDate = nil }
        if !useEndDate { draft.endDate = nil }
        draft.minAmount = Decimal(string: minAmountText.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX"))
        draft.maxAmount = Decimal(string: maxAmountText.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX"))

        // Map __uncategorized__ sentinel to empty string handled in filter.matches
        filter = draft
        dismiss()
    }
}
