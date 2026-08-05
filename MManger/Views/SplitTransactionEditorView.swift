import SwiftUI
import SwiftData

struct SplitTransactionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appCurrency) private var appCurrency

    var transaction: FinanceTransaction
    var accounts: [Account]
    var categories: [FinanceCategory]

    @State private var splits: [TransactionSplit] = []

    private var totalSplit: Decimal {
        splits.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var parentCategories: [FinanceCategory] {
        categories.filter { $0.kind == transaction.kind && $0.parentName == nil && !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func subcategories(for categoryName: String) -> [FinanceCategory] {
        categories.filter { $0.parentName == categoryName && !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("Transaction", comment: "")) {
                    LabeledContent("Merchant", value: transaction.merchant)
                    LabeledContent("Total amount", value: AppFormatters.statMoney(transaction.amount, currency: transaction.currency))
                    LabeledContent("Allocated", value: AppFormatters.statMoney(totalSplit, currency: transaction.currency))
                    LabeledContent("Remaining", value: AppFormatters.statMoney(max(transaction.amount - totalSplit, 0), currency: transaction.currency))
                }

                Section(NSLocalizedString("Splits", comment: "")) {
                    ForEach(splits) { split in
                        SplitRowView(
                            split: binding(for: split),
                            categories: parentCategories,
                            subcategories: subcategories(for: split.categoryName),
                            currency: transaction.currency
                        )
                    }
                    .onDelete(perform: deleteSplit)

                    Button {
                        addSplit()
                    } label: {
                        Label(NSLocalizedString("Add split", comment: ""), systemImage: "plus.circle.fill")
                    }
                }

                if !splits.isEmpty {
                    Section {
                        Button(NSLocalizedString("Apply splits", comment: ""), action: applySplits)
                            .disabled(totalSplit != transaction.amount)
                    }
                }
            }
            .appFormStyle()
            .navigationTitle(NSLocalizedString("Split Transaction", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "")) { dismiss() }
                }
            }
            .onAppear(perform: load)
        }
    }

    private func binding(for split: TransactionSplit) -> Binding<TransactionSplit> {
        Binding(
            get: {
                splits.first(where: { $0.id == split.id }) ?? split
            },
            set: { updated in
                if let index = splits.firstIndex(where: { $0.id == split.id }) {
                    splits[index] = updated
                }
            }
        )
    }

    private func load() {
        if splits.isEmpty {
            splits = [TransactionSplit(
                amount: transaction.amount,
                categoryName: transaction.categoryName ?? "",
                subcategoryName: transaction.subcategoryName
            )]
        }
    }

    private func addSplit() {
        let remaining = transaction.amount - totalSplit
        splits.append(TransactionSplit(
            amount: max(remaining, 0),
            categoryName: "",
            subcategoryName: nil
        ))
    }

    private func deleteSplit(at offsets: IndexSet) {
        splits.remove(atOffsets: offsets)
    }

    private func applySplits() {
        guard totalSplit == transaction.amount, splits.count >= 2 else { return }

        if let first = splits.first {
            transaction.categoryName = first.categoryName.isEmpty ? nil : first.categoryName
            transaction.subcategoryName = first.subcategoryName
            transaction.updatedAt = .now
        }

        for split in splits.dropFirst() {
            let newTransaction = FinanceTransaction(
                date: transaction.date,
                kind: transaction.kind,
                amount: split.amount,
                currency: transaction.currency,
                merchant: transaction.merchant,
                normalizedMerchant: transaction.normalizedMerchant,
                note: transaction.note,
                rawDescription: transaction.rawDescription,
                accountName: transaction.accountName,
                categoryName: split.categoryName.isEmpty ? nil : split.categoryName,
                subcategoryName: split.subcategoryName
            )
            modelContext.insert(newTransaction)
        }

        try? modelContext.save()
        dismiss()
    }
}

private struct SplitRowView: View {
    @Binding var split: TransactionSplit
    var categories: [FinanceCategory]
    var subcategories: [FinanceCategory]
    var currency: String

    @State private var amountText = ""

    private var amount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX"))
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                LabeledNumberField(label: "Amount", text: $amountText, prompt: "0.00")
                    .onChange(of: amountText) { _, _ in
                        if let amount {
                            split.amount = amount
                        }
                    }
                Text(currency)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("Category", selection: $split.categoryName) {
                Text(NSLocalizedString("Uncategorized", comment: "")).tag("")
                ForEach(categories) { category in
                    Text(category.name).tag(category.name)
                }
            }

            if !subcategories.isEmpty {
                Picker("Subcategory", selection: Binding(
                    get: { split.subcategoryName ?? "" },
                    set: { split.subcategoryName = $0.isEmpty ? nil : $0 }
                )) {
                    Text(NSLocalizedString("None", comment: "")).tag("")
                    ForEach(subcategories) { subcategory in
                        Text(subcategory.name).tag(subcategory.name)
                    }
                }
            }
        }
        .onAppear {
            amountText = NSDecimalNumber(decimal: split.amount).stringValue
        }
    }
}
