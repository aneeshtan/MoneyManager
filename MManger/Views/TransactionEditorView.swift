import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct TransactionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appCurrency) private var appCurrency
    @Query(sort: \MerchantRule.sampleCount, order: .reverse) private var merchantRules: [MerchantRule]
    @Query(sort: \TransactionAttachment.createdAt, order: .reverse) private var attachments: [TransactionAttachment]
    @Query(sort: \Tag.name) private var tags: [Tag]
    var transaction: FinanceTransaction?
    var accounts: [Account]
    var categories: [FinanceCategory]

    @State private var date = Date()
    @State private var kind: TransactionKind = .expense
    @State private var amountText = ""
    @State private var currency = ""
    @State private var accountName = ""
    @State private var categoryName = ""
    @State private var subcategoryName = ""
    @State private var merchant = ""
    @State private var note = ""
    @State private var selectedReceiptPhoto: PhotosPickerItem?
    @State private var showingReceiptFileImporter = false
    @State private var attachmentError: String?
    @State private var showingDeleteConfirmation = false
    @State private var showingSplitEditor = false
    @State private var selectedTagNames: [String] = []
    @State private var showingReceiptCapture = false
    @State private var capturedReceiptImage: UIImage?
    @State private var showingReceiptReview = false
    @State private var receiptOCRData: ReceiptOCRData?

    init(transaction: FinanceTransaction? = nil, accounts: [Account], categories: [FinanceCategory]) {
        self.transaction = transaction
        self.accounts = accounts
        self.categories = categories
    }

    private var activeAccounts: [Account] {
        accounts.filter { !$0.isArchived }
    }

    var body: some View {
        NavigationStack {
            Form {
                transactionSection
                classificationSection
                tagsSection
                sourceSection
                receiptsSection
                deleteSection
            }
            .appFormStyle()
            .navigationTitle(transaction == nil ? "Add Transaction" : "Edit Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Save", comment: ""), action: save)
                        .disabled(decimalAmount == nil || accountName.isEmpty)
                }
            }
            .onAppear {
                load()
                sanitizeClassification()
            }
            .onChange(of: kind) { _, _ in
                sanitizeCategoryForKind()
            }
            .onChange(of: categoryName) { _, _ in
                sanitizeSubcategoryForCategory()
            }
            .onChange(of: selectedReceiptPhoto) { _, item in
                guard let item, let transaction else { return }
                Task { await attachPhoto(item, to: transaction) }
            }
            .fileImporter(
                isPresented: $showingReceiptFileImporter,
                allowedContentTypes: [.image, .pdf, .data],
                allowsMultipleSelection: false
            ) { result in
                guard let transaction else { return }
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        attachFile(url, to: transaction)
                    }
                case .failure(let error):
                    attachmentError = error.localizedDescription
                }
            }
            .sheet(isPresented: $showingSplitEditor) {
                if let transaction {
                    SplitTransactionEditorView(transaction: transaction, accounts: accounts, categories: categories)
                }
            }
            .sheet(isPresented: $showingReceiptCapture) {
                ReceiptCaptureView { image in
                    capturedReceiptImage = image
                    showingReceiptCapture = false
                    showingReceiptReview = true
                }
            }
            .sheet(isPresented: $showingReceiptReview) {
                if let image = capturedReceiptImage {
                    ReceiptOCRReviewView(image: image) { ocrData in
                        receiptOCRData = ocrData
                        if let transaction {
                            prefillTransactionFromReceipt(ocrData, transaction: transaction)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var transactionSection: some View {
        Section(NSLocalizedString("Transaction", comment: "")) {
            Picker("Type", selection: $kind) {
                ForEach(TransactionKind.allCases) { k in
                    Text(k.displayName).tag(k)
                }
            }
            .pickerStyle(.segmented)

            DatePicker("Date", selection: $date, displayedComponents: .date)
            LabeledNumberField(label: "Amount", text: $amountText, prompt: "0.00")
            LabeledCurrencyButton(currency: $currency)
            LabeledTextField(label: "Merchant", text: $merchant, prompt: "e.g. Carrefour")
            LabeledTextField(label: "Note", text: $note, prompt: "Optional details", autocorrection: true)

            if transaction != nil {
                Button {
                    showingSplitEditor = true
                } label: {
                    Label(NSLocalizedString("Split into categories", comment: ""), systemImage: "rectangle.split.2x1")
                }
            }
        }
    }

    @ViewBuilder
    private var tagsSection: some View {
        if !tags.isEmpty {
            Section(NSLocalizedString("Tags", comment: "")) {
                FlowLayout(spacing: 8) {
                    ForEach(tags) { tag in
                        let isSelected = selectedTagNames.contains(tag.name)
                        Button {
                            if isSelected {
                                selectedTagNames.removeAll { $0 == tag.name }
                            } else {
                                selectedTagNames.append(tag.name)
                            }
                        } label: {
                            Text(tag.name)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isSelected ? Color(hex: tag.colorHex) : Color(hex: tag.colorHex).opacity(0.15), in: Capsule())
                                .foregroundStyle(isSelected ? .white : Color(hex: tag.colorHex))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var classificationSection: some View {
        Section(NSLocalizedString("Classification", comment: "")) {
            Picker("Account", selection: $accountName) {
                if !accountName.isEmpty && !activeAccounts.contains(where: { $0.name == accountName }) {
                    Text(accountName).tag(accountName)
                }
                ForEach(activeAccounts) { account in
                    Text(account.name).tag(account.name)
                }
            }

            Picker("Category", selection: $categoryName) {
                Text(NSLocalizedString("Uncategorized", comment: "")).tag("")
                if !categoryName.isEmpty && !parentCategories.contains(where: { $0.name == categoryName }) {
                    Text(categoryName).tag(categoryName)
                }
                ForEach(parentCategories) { category in
                    Text(category.name).tag(category.name)
                }
            }

            Picker("Subcategory", selection: $subcategoryName) {
                Text(NSLocalizedString("None", comment: "")).tag("")
                if !subcategoryName.isEmpty && !subcategories.contains(where: { $0.name == subcategoryName }) {
                    Text(subcategoryName).tag(subcategoryName)
                }
                ForEach(subcategories) { category in
                    Text(category.name).tag(category.name)
                }
            }
        }
    }

    @ViewBuilder
    private var sourceSection: some View {
        if let transaction, transaction.sourceName != nil {
            Section(NSLocalizedString("Money Manager Source", comment: "")) {
                sourceRow("Source", transaction.sourceName)
                sourceRow("Row", transaction.sourceRow.map(String.init))
                sourceRow("Period", transaction.sourcePeriodSerial)
                sourceRow("Accounts", transaction.sourceAccountColumn)
                sourceRow("Category", transaction.sourceCategoryColumn)
                sourceRow("Subcategory", transaction.sourceSubcategoryColumn)
                sourceRow("Note", transaction.sourceNoteColumn)
                sourceRow("Source amount column", transaction.sourceAEDColumn)
                sourceRow("Income/Expense", transaction.sourceIncomeExpenseColumn)
                sourceRow("Description", transaction.sourceDescriptionColumn)
                sourceRow("Amount", transaction.sourceAmountColumn)
                sourceRow("Currency", transaction.sourceCurrencyColumn)
                sourceRow("Accounts trailing", transaction.sourceTrailingAccountsColumn)
            }
        }
    }

    @ViewBuilder
    private var receiptsSection: some View {
        if transaction != nil {
            Section(NSLocalizedString("Receipts", comment: "")) {
                if transactionAttachments.isEmpty {
                    Text(NSLocalizedString("No receipts attached.", comment: ""))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(transactionAttachments) { attachment in
                        HStack {
                            Image(systemName: attachment.contentType.hasPrefix("image/") ? "photo" : "doc")
                                .foregroundStyle(AppTheme.violet)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(attachment.originalFileName)
                                    .lineLimit(1)
                                Text(attachment.createdAt, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                removeAttachment(attachment)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Button {
                    showingReceiptCapture = true
                } label: {
                    Label(NSLocalizedString("Scan receipt (OCR)", comment: ""), systemImage: "doc.viewfinder")
                }

                PhotosPicker(selection: $selectedReceiptPhoto, matching: .images) {
                    Label(NSLocalizedString("Attach receipt photo", comment: ""), systemImage: "camera")
                }

                Button {
                    showingReceiptFileImporter = true
                } label: {
                    Label(NSLocalizedString("Attach file", comment: ""), systemImage: "paperclip")
                }

                if let attachmentError {
                    Text(attachmentError)
                        .font(.caption)
                        .foregroundStyle(AppTheme.coral)
                }
            }
        }
    }

    @ViewBuilder
    private var deleteSection: some View {
        if transaction != nil {
            Section {
                Button(NSLocalizedString("Delete Transaction", comment: ""), role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .frame(maxWidth: .infinity)
                .alert("Delete Transaction?", isPresented: $showingDeleteConfirmation) {
                    Button(NSLocalizedString("Delete Transaction", comment: ""), role: .destructive) {
                        deleteTransaction()
                    }
                } message: {
                    Text(NSLocalizedString("Are you sure you want to delete this transaction? This action cannot be undone.", comment: ""))
                }
            }
        }
    }

    private var parentCategories: [FinanceCategory] {
        categories
            .filter { $0.kind == kind && $0.parentName == nil }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var subcategories: [FinanceCategory] {
        categories
            .filter { $0.parentName == categoryName }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var decimalAmount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX"))
    }

    private var transactionAttachments: [TransactionAttachment] {
        guard let transaction else { return [] }
        return attachments.filter { $0.transactionId == transaction.id }
    }

    private func load() {
        guard let transaction else {
            accountName = activeAccounts.first?.name ?? SeedStore.defaultImportAccountName
            currency = appCurrency
            sanitizeClassification()
            return
        }
        date = transaction.date
        kind = transaction.kind
        amountText = NSDecimalNumber(decimal: transaction.amount).stringValue
        currency = AppFormatters.resolvedCurrency(transaction.currency, fallback: appCurrency)
        accountName = transaction.accountName
        categoryName = transaction.categoryName ?? ""
        subcategoryName = transaction.subcategoryName ?? ""
        merchant = transaction.merchant
        note = transaction.note
        selectedTagNames = transaction.tagNames
    }

    private func sanitizeClassification() {
        sanitizeCategoryForKind()
        sanitizeSubcategoryForCategory()
    }

    private func sanitizeCategoryForKind() {
        guard !categoryName.isEmpty else {
            subcategoryName = ""
            return
        }
        if !parentCategories.contains(where: { $0.name == categoryName }) {
            subcategoryName = ""
        }
    }

    private func sanitizeSubcategoryForCategory() {
        guard !subcategoryName.isEmpty else { return }
        if !subcategories.contains(where: { $0.name == subcategoryName }) {
            subcategoryName = ""
        }
    }

    private func save() {
        guard let amount = decimalAmount else { return }
        let resolvedCurrency = AppFormatters.resolvedCurrency(currency, fallback: appCurrency)
        let normalized = MerchantNormalizer.normalize(merchant)
        if let transaction {
            let oldCategory = transaction.categoryName
            let oldSubcategory = transaction.subcategoryName
            let oldNormalized = transaction.normalizedMerchant
            transaction.date = date
            transaction.kind = kind
            transaction.amount = amount
            transaction.currency = resolvedCurrency
            transaction.accountName = accountName
            transaction.categoryName = categoryName.isEmpty ? nil : categoryName
            transaction.subcategoryName = subcategoryName.isEmpty ? nil : subcategoryName
            transaction.merchant = merchant
            transaction.normalizedMerchant = normalized
            transaction.note = note
            transaction.tagNames = selectedTagNames
            transaction.updatedAt = .now
            if oldCategory != transaction.categoryName || oldSubcategory != transaction.subcategoryName || oldNormalized != normalized {
                learnRule(normalized: normalized)
            }
        } else {
            let newTransaction = FinanceTransaction(
                date: date,
                kind: kind,
                amount: amount,
                currency: resolvedCurrency,
                merchant: merchant,
                normalizedMerchant: normalized,
                note: note,
                rawDescription: merchant,
                accountName: accountName,
                categoryName: categoryName.isEmpty ? nil : categoryName,
                subcategoryName: subcategoryName.isEmpty ? nil : subcategoryName
            )
            newTransaction.tagNames = selectedTagNames
            modelContext.insert(newTransaction)
            learnRule(normalized: normalized)
        }
        try? modelContext.save()
        dismiss()
    }

    private func learnRule(normalized: String) {
        guard !normalized.isEmpty, !categoryName.isEmpty else { return }
        if let rule = merchantRules.first(where: { MerchantNormalizer.normalize($0.pattern) == normalized }) {
            rule.categoryName = categoryName
            rule.subcategoryName = subcategoryName.isEmpty ? nil : subcategoryName
            rule.kind = kind
            rule.confidence = max(rule.confidence, 0.95)
            rule.sampleCount += 1
        } else {
            modelContext.insert(
                MerchantRule(
                    pattern: normalized,
                    matchType: .exact,
                    categoryName: categoryName,
                    subcategoryName: subcategoryName.isEmpty ? nil : subcategoryName,
                    kind: kind,
                    confidence: 0.95,
                    sampleCount: 1
                )
            )
        }
    }

    @ViewBuilder
    private func sourceRow(_ title: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .top) {
                Text(title)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    @MainActor
    private func attachPhoto(_ item: PhotosPickerItem, to transaction: FinanceTransaction) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let originalName = "Receipt \(AppFormatters.dayString(from: .now)).jpg"
            try saveAttachment(data: data, originalName: originalName, contentType: "image/jpeg", to: transaction)
            selectedReceiptPhoto = nil
        } catch {
            attachmentError = error.localizedDescription
        }
    }

    private func attachFile(_ url: URL, to transaction: FinanceTransaction) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let contentType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            try saveAttachment(data: data, originalName: url.lastPathComponent, contentType: contentType, to: transaction)
        } catch {
            attachmentError = error.localizedDescription
        }
    }

    private func saveAttachment(data: Data, originalName: String, contentType: String, to transaction: FinanceTransaction) throws {
        let folder = try receiptsFolder()
        let ext = (originalName as NSString).pathExtension.isEmpty ? "dat" : (originalName as NSString).pathExtension
        let fileName = "\(UUID().uuidString).\(ext)"
        try data.write(to: folder.appendingPathComponent(fileName), options: [.atomic])
        modelContext.insert(
            TransactionAttachment(
                transactionId: transaction.id,
                fileName: fileName,
                originalFileName: originalName,
                contentType: contentType
            )
        )
        transaction.updatedAt = .now
        attachmentError = nil
        try modelContext.save()
    }

    private func removeAttachment(_ attachment: TransactionAttachment) {
        try? FileManager.default.removeItem(at: receiptsURL(for: attachment))
        modelContext.delete(attachment)
        try? modelContext.save()
    }

    private func receiptsURL(for attachment: TransactionAttachment) -> URL {
        (try? receiptsFolder())?.appendingPathComponent(attachment.fileName) ?? URL(fileURLWithPath: attachment.fileName)
    }

    private func receiptsFolder() throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = documents.appendingPathComponent("Receipts", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    private func deleteTransaction() {
        guard let transaction else { return }

        for attachment in transactionAttachments {
            try? FileManager.default.removeItem(at: receiptsURL(for: attachment))
            modelContext.delete(attachment)
        }

        modelContext.delete(transaction)

        try? modelContext.save()
        dismiss()
    }

    private func prefillTransactionFromReceipt(_ ocrData: ReceiptOCRData, transaction: FinanceTransaction) {
        // Update merchant if extracted
        if !ocrData.merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            merchant = ocrData.merchantName
        }

        // Update amount if extracted
        let amount = NSDecimalNumber(decimal: ocrData.totalAmount).stringValue
        amountText = amount

        // Update currency if extracted
        if !ocrData.currency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            currency = ocrData.currency
        }

        // Update date if extracted
        if let receiptDate = ocrData.receiptDate {
            date = receiptDate
        }

        // Try to auto-categorize based on merchant
        let normalized = MerchantNormalizer.normalize(ocrData.merchantName)
        if let suggestion = CategoryMatcher.match(
            merchant: normalized,
            ruleSnapshots: merchantRules.map(MerchantRuleSnapshot.init),
            fallbackKind: kind
        ) {
            categoryName = suggestion.category
            if let subcategory = suggestion.subcategory {
                subcategoryName = subcategory
            }
        }
    }
}
