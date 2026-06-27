import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportPDFView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appCurrency) private var currency
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]
    @Query(sort: \MerchantRule.sampleCount, order: .reverse) private var rules: [MerchantRule]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \FinanceCategory.sortOrder) private var categories: [FinanceCategory]

    @State private var selectedSource: ImportSource = .pdf
    @State private var selectedAccountName = SeedStore.defaultImportAccountName
    @State private var showingPicker = false
    @State private var pastedText = ""
    @State private var parsedRows: [ParsedBankTransaction] = []
    @State private var sourceFileName = ""
    @State private var errorMessage: String?
    @State private var isParsing = false
    @State private var isSaving = false
    @State private var parsingLabel = ""
    @State private var importTask: Task<Void, Never>?
    @State private var saveTask: Task<Void, Never>?

    private let maxDisplayedRows = 200

    private var selectedCount: Int { parsedRows.filter(\.isSelected).count }
    private var duplicateCount: Int { parsedRows.filter(\.isDuplicate).count }
    private var reviewCount: Int { parsedRows.filter(\.isReviewOnly).count }
    private var activeAccounts: [Account] { accounts.filter { !$0.isArchived } }
    private var selectedAccountTransactions: [FinanceTransaction] {
        transactions.filter { $0.accountName == selectedAccountName }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        ImportHero(
                            source: $selectedSource,
                            accountName: $selectedAccountName,
                            accounts: activeAccounts,
                            parsedCount: parsedRows.count,
                            selectedCount: selectedCount,
                            duplicateCount: duplicateCount,
                            reviewCount: reviewCount,
                            isBusy: isParsing || isSaving,
                            chooseAction: { showingPicker = true },
                            pasteAction: parsePastedText,
                            saveAction: saveSelected
                        )

                        if selectedSource == .paste {
                            PasteImportBox(text: $pastedText, parseAction: parsePastedText)
                        } else {
                            ImportSourceHelp(source: selectedSource)
                        }

                        if let errorMessage {
                            GlassSurface {
                                Label(errorMessage, systemImage: "exclamationmark.triangle")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.coral)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if parsedRows.isEmpty {
                            EmptyStateView(
                                systemImage: selectedSource.emptyIcon,
                                title: selectedSource.emptyTitle,
                                message: selectedSource.emptyMessage
                            )
                        } else {
                            HStack {
                                SectionTitle("Review import", subtitle: sourceFileName.isEmpty ? selectedSource.reviewSubtitle : sourceFileName)
                                Spacer()
                                Button("Select clean") {
                                    for index in parsedRows.indices {
                                        parsedRows[index].isSelected = !parsedRows[index].isDuplicate && !parsedRows[index].isReviewOnly
                                    }
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.violet)
                                .buttonStyle(PrimaryPressStyle())
                            }

                            LazyVStack(spacing: 12) {
                                ForEach(Array(parsedRows.prefix(maxDisplayedRows)), id: \.id) { row in
                                    let rowBinding = binding(for: row)
                                    ImportReviewRow(
                                        row: rowBinding,
                                        categories: categories,
                                        createRuleAction: { createRule(from: rowBinding.wrappedValue, existingRules: rules) },
                                        mergeDuplicateAction: { mergeDuplicate(rowBinding.wrappedValue) }
                                    )
                                }
                            }

                            if parsedRows.count > maxDisplayedRows {
                                GlassSurface {
                                    HStack(spacing: 10) {
                                        Image(systemName: "info.circle")
                                            .foregroundStyle(AppTheme.violet)
                                        Text("Showing the first \(maxDisplayedRows) of \(parsedRows.count) rows. Save will include all selected rows.")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(AppTheme.muted)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }

                if isParsing || isSaving {
                    ImportProgressOverlay(label: isSaving ? "Saving transactions…" : parsingLabel)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isParsing)
            .animation(.easeInOut(duration: 0.2), value: isSaving)
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingPicker) {
                DocumentPicker(contentTypes: selectedSource.contentTypes) { url in
                    showingPicker = false
                    importFile(url)
                }
            }
            .onAppear {
                if !activeAccounts.contains(where: { $0.name == selectedAccountName }) {
                    selectedAccountName = activeAccounts.first?.name ?? SeedStore.defaultImportAccountName
                }
            }
            .onDisappear {
                importTask?.cancel()
            }
        }
    }

    // MARK: - Import / parse

    private func importFile(_ url: URL) {
        errorMessage = nil
        sourceFileName = url.lastPathComponent
        parsingLabel = "Reading \(url.lastPathComponent)…"
        isParsing = true
        parsedRows = []

        let ext = url.pathExtension.lowercased()
        if ["xlsx", "xls"].contains(ext) {
            errorMessage = UniversalImportParserError.unsupportedSpreadsheet.localizedDescription
            isParsing = false
            return
        }

        importTask?.cancel()
        importTask = Task { @MainActor in
            // 1. Extract text on the main actor (PDFKit is not thread-safe)
            let rawText: String
            do {
                if ext == "pdf" {
                    rawText = try BankStatementPDFParser.extractText(from: url)
                } else {
                    guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                        errorMessage = UniversalImportParserError.unreadableFile.localizedDescription
                        isParsing = false
                        return
                    }
                    rawText = text
                }
            } catch {
                errorMessage = error.localizedDescription
                isParsing = false
                return
            }

            let accountName = selectedAccountName
            let ruleSnapshots = rules.map(MerchantRuleSnapshot.init)
            let existingSnapshots = selectedAccountTransactions.map(TransactionSnapshot.init)
            let format: ImportFormat = ext == "pdf" ? .pdf : (ext == "csv" ? .csv : .plainText)

            parsingLabel = "Parsing transactions…"

            // 2. Parse off the main actor in a detached task, streaming results back in chunks
            let stream = AsyncStream<[ParsedBankTransaction]> { continuation in
                Task.detached(priority: .userInitiated) {
                    do {
                        let all = try UniversalImportParser().parseText(
                            rawText,
                            format: format,
                            ruleSnapshots: ruleSnapshots,
                            existingSnapshots: existingSnapshots,
                            accountName: accountName
                        )
                        // Stream in chunks of 30 so the UI renders progressively
                        let chunkSize = 30
                        var index = 0
                        while index < all.count {
                            let end = min(index + chunkSize, all.count)
                            continuation.yield(Array(all[index..<end]))
                            index = end
                            // Small sleep lets the main actor breathe between chunks
                            try? await Task.sleep(nanoseconds: 8_000_000) // 8ms
                        }
                    } catch {
                        continuation.yield(with: .success([]))
                        await MainActor.run { errorMessage = error.localizedDescription }
                    }
                    continuation.finish()
                }
            }

            var totalCount = 0
            for await chunk in stream {
                guard !Task.isCancelled else { break }
                parsedRows.append(contentsOf: chunk)
                totalCount += chunk.count
                parsingLabel = "Loaded \(totalCount) transactions…"
            }

            isParsing = false
        }
    }

    private func parsePastedText() {
        errorMessage = nil
        sourceFileName = "Pasted messages"
        parsingLabel = "Parsing messages…"
        isParsing = true
        parsedRows = []

        let accountName = selectedAccountName
        let ruleSnapshots = rules.map(MerchantRuleSnapshot.init)
        let existingSnapshots = selectedAccountTransactions.map(TransactionSnapshot.init)
        let text = pastedText

        importTask?.cancel()
        importTask = Task {
            do {
                let rows = try await Task.detached(priority: .userInitiated) { [text, ruleSnapshots, existingSnapshots, accountName] in
                    try UniversalImportParser().parsePastedMessages(
                        text,
                        ruleSnapshots: ruleSnapshots,
                        existingSnapshots: existingSnapshots,
                        accountName: accountName
                    )
                }.value
                parsedRows = rows
            } catch {
                parsedRows = []
                errorMessage = error.localizedDescription
            }
            isParsing = false
        }
    }

    // MARK: - Save

    private func saveSelected() {
        guard selectedCount > 0 else { return }
        isSaving = true
        let accountName = selectedAccountName
        let rowsToSave = parsedRows.filter(\.isSelected)
        let draftsToSave = rowsToSave.map {
            ImportSaveDraft(row: $0, accountName: accountName, fallbackCurrency: currency)
        }
        let existingIdentity = existingTransactionsByIdentity()
        let allRules = rules
        let sourceName = sourceFileName.isEmpty ? selectedSource.defaultSourceName : sourceFileName
        let parsedCount = parsedRows.count
        let savedCount = draftsToSave.count

        saveTask?.cancel()
        saveTask = Task { @MainActor in
            defer {
                isSaving = false
            }

            do {
                let batch = ImportBatch(
                    sourceFileName: sourceName,
                    parsedCount: parsedCount,
                    savedCount: savedCount,
                    ignoredCount: parsedCount - savedCount
                )
                modelContext.insert(batch)

                var existingByIdentity = existingIdentity
                var saved = 0
                let batchSize = 50  // small batches keep memory low and UI responsive

                for pair in zip(rowsToSave, draftsToSave) {
                    guard !Task.isCancelled else { return }

                    let row = pair.0
                    let draft = pair.1
                    let key = draft.identityKey()
                    if draft.isDuplicate {
                        for duplicate in existingByIdentity[key] ?? [] {
                            modelContext.delete(duplicate)
                        }
                        existingByIdentity[key] = []
                    }
                    modelContext.insert(draft.transaction(importBatchId: batch.id))
                    createRule(from: row, existingRules: allRules, saveImmediately: false)
                    saved += 1

                    if saved % batchSize == 0 {
                        try modelContext.save()
                        parsingLabel = "Saved \(saved) of \(savedCount)…"
                        await Task.yield()  // hand control back to the main run loop
                    }
                }

                try modelContext.save()
                parsedRows.removeAll()
                pastedText = ""
                parsingLabel = ""
            } catch {
                errorMessage = "Could not save imported transactions: \(error.localizedDescription)"
            }
        }
    }

    private func binding(for row: ParsedBankTransaction) -> Binding<ParsedBankTransaction> {
        Binding(
            get: {
                parsedRows.first(where: { $0.id == row.id }) ?? row
            },
            set: { updatedRow in
                guard let index = parsedRows.firstIndex(where: { $0.id == updatedRow.id }) else { return }
                parsedRows[index] = updatedRow
            }
        )
    }

    private func createRule(from row: ParsedBankTransaction, existingRules: [MerchantRule], saveImmediately: Bool = true) {
        guard let category = row.suggestedCategory, !category.isEmpty else { return }
        let pattern = row.normalizedMerchant.isEmpty ? MerchantNormalizer.normalize(row.description) : row.normalizedMerchant
        guard !pattern.isEmpty else { return }
        if let existing = existingRules.first(where: { MerchantNormalizer.normalize($0.pattern) == pattern }) {
            existing.categoryName = category
            existing.subcategoryName = row.suggestedSubcategory
            existing.kind = row.kind
            existing.confidence = max(existing.confidence, max(row.confidence, 0.85))
            existing.sampleCount += 1
        } else {
            modelContext.insert(
                MerchantRule(
                    pattern: pattern,
                    matchType: .exact,
                    categoryName: category,
                    subcategoryName: row.suggestedSubcategory,
                    kind: row.kind,
                    confidence: max(row.confidence, 0.85),
                    sampleCount: 1
                )
            )
        }
        if saveImmediately {
            try? modelContext.save()
        }
    }

    private func mergeDuplicate(_ row: ParsedBankTransaction) {
        deleteDuplicates(for: row)
        if let index = parsedRows.firstIndex(where: { $0.id == row.id }) {
            parsedRows[index].isDuplicate = false
            parsedRows[index].isSelected = true
        }
        try? modelContext.save()
    }

    private func deleteDuplicates(for row: ParsedBankTransaction) {
        let key = transactionIdentityKey(for: row, accountName: selectedAccountName)
        for transaction in existingTransactionsByIdentity()[key] ?? [] {
            modelContext.delete(transaction)
        }
    }

    private func existingTransactionsByIdentity() -> [String: [FinanceTransaction]] {
        Dictionary(grouping: selectedAccountTransactions) { transaction in
            TransactionIdentityKey.make(
                accountName: transaction.accountName,
                date: transaction.date,
                amount: transaction.amount,
                normalizedMerchant: transaction.normalizedMerchant
            )
        }
    }

    private func transactionIdentityKey(for row: ParsedBankTransaction, accountName: String) -> String {
        TransactionIdentityKey.make(
            accountName: accountName,
            date: row.date,
            amount: row.amount,
            normalizedMerchant: row.normalizedMerchant
        )
    }
}

private enum ImportSource: String, CaseIterable, Identifiable {
    case pdf = "PDF"
    case csv = "CSV"
    case paste = "Paste"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pdf: "PDF statement"
        case .csv: "CSV / Excel export"
        case .paste: "SMS paste"
        }
    }

    var systemImage: String {
        switch self {
        case .pdf: "doc.text.magnifyingglass"
        case .csv: "tablecells"
        case .paste: "text.bubble"
        }
    }

    var contentTypes: [UTType] {
        switch self {
        case .pdf:
            [.pdf]
        case .csv:
            [.commaSeparatedText, .plainText, .text]
        case .paste:
            [.plainText, .text]
        }
    }

    var defaultSourceName: String {
        switch self {
        case .pdf: "PDF statement"
        case .csv: "CSV import"
        case .paste: "Pasted bank messages"
        }
    }

    var reviewSubtitle: String {
        switch self {
        case .pdf: "Parsed from statement text"
        case .csv: "Parsed from spreadsheet rows"
        case .paste: "Parsed from pasted messages"
        }
    }

    var emptyIcon: String { systemImage }

    var emptyTitle: String {
        switch self {
        case .pdf: "Ready for a statement"
        case .csv: "Ready for CSV"
        case .paste: "Ready for messages"
        }
    }

    var emptyMessage: String {
        switch self {
        case .pdf:
            "Choose a searchable bank PDF. Known statement formats get exact parsing; other PDFs use generic date, amount, and merchant detection."
        case .csv:
            "Import a CSV exported from Excel, Google Sheets, or your bank. Headers like Date, Description, Amount, Debit, Credit, and Currency are supported."
        case .paste:
            "Paste bank SMS messages or notification text. The app detects amount, date, merchant, and income or expense direction where possible."
        }
    }
}

private struct ImportHero: View {
    @Binding var source: ImportSource
    @Binding var accountName: String
    var accounts: [Account]
    var parsedCount: Int
    var selectedCount: Int
    var duplicateCount: Int
    var reviewCount: Int
    var isBusy: Bool
    var chooseAction: () -> Void
    var pasteAction: () -> Void
    var saveAction: () -> Void

    var body: some View {
        GlassSurface {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Data Sources")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                        Text("Collect transactions from files, exports, and bank messages.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                    Image(systemName: source.systemImage)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.violet)
                        .frame(width: 50, height: 50)
                        .background(AppTheme.lavender.opacity(0.14), in: Circle())
                }

                Picker("Source", selection: $source) {
                    ForEach(ImportSource.allCases) { source in
                        Text(source.rawValue).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(isBusy)

                Picker("Account", selection: $accountName) {
                    ForEach(accounts) { account in
                        Text(account.name).tag(account.name)
                    }
                }
                .pickerStyle(.menu)
                .font(.subheadline.weight(.medium))
                .tint(AppTheme.violet)
                .disabled(isBusy)

                HStack(spacing: 10) {
                    ImportMetric(title: "Parsed", value: "\(parsedCount)", tint: AppTheme.lavender)
                    ImportMetric(title: "Selected", value: "\(selectedCount)", tint: AppTheme.mint)
                    ImportMetric(title: "Review", value: "\(duplicateCount + reviewCount)", tint: AppTheme.gold)
                }

                HStack(spacing: 10) {
                    Button {
                        source == .paste ? pasteAction() : chooseAction()
                    } label: {
                        Label(source == .paste ? "Parse Paste" : "Choose File", systemImage: source == .paste ? "sparkle.magnifyingglass" : "folder")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(isBusy)
                    .buttonStyle(PrimaryPressStyle())

                    Button {
                        saveAction()
                    } label: {
                        Label("Save", systemImage: "checkmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(selectedCount == 0 ? AppTheme.muted : AppTheme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(AppTheme.line, lineWidth: 1)
                            )
                    }
                    .disabled(selectedCount == 0 || isBusy)
                    .buttonStyle(PrimaryPressStyle())
                }
            }
        }
    }
}

private struct ImportSourceHelp: View {
    var source: ImportSource

    var body: some View {
        GlassSurface {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: source.systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.violet)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.lavender.opacity(0.13), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text(source.emptyMessage)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PasteImportBox: View {
    @Binding var text: String
    var parseAction: () -> Void

    var body: some View {
        GlassSurface {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("Paste bank messages", subtitle: "One message per line works best")
                TextEditor(text: $text)
                    .frame(minHeight: 150)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.line.opacity(0.75), lineWidth: 1)
                    )

                Button {
                    parseAction()
                } label: {
                    Label("Parse pasted text", systemImage: "sparkle.magnifyingglass")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.teal, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(PrimaryPressStyle())
            }
        }
    }
}

private struct ImportMetric: View {
    var title: String
    var value: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(AppTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

private struct ImportReviewRow: View {
    @Environment(\.appCurrency) private var currency
    @Binding var row: ParsedBankTransaction
    var categories: [FinanceCategory]
    var createRuleAction: () -> Void
    var mergeDuplicateAction: () -> Void

    private var parentCategories: [FinanceCategory] {
        categories
            .filter { $0.parentName == nil && $0.kind == row.kind && !$0.isArchived }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var subcategories: [FinanceCategory] {
        guard let category = row.suggestedCategory else { return [] }
        return categories
            .filter { $0.parentName == category && !$0.isArchived }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        GlassSurface(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Toggle("", isOn: $row.isSelected)
                        .labelsHidden()
                        .tint(AppTheme.violet)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(row.description)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(2)
                        Text("\(AppFormatters.day.string(from: row.date)) • \(row.suggestedCategory ?? "Uncategorized")\(subcategorySuffix)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                    }

                    Spacer(minLength: 8)

                    Text(AppFormatters.money(row.amount, currency: AppFormatters.resolvedCurrency(row.currency, fallback: currency)))
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(row.kind == .income ? AppTheme.teal : AppTheme.ink)
                        .multilineTextAlignment(.trailing)
                }

                HStack(spacing: 10) {
                    Picker("Type", selection: $row.kind) {
                        ForEach(TransactionKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    if row.isDuplicate {
                        StatusPill(title: "Duplicate", systemImage: "exclamationmark.triangle.fill", tint: AppTheme.gold)
                    } else if row.isReviewOnly {
                        StatusPill(title: "Review", systemImage: "eye", tint: AppTheme.lavender)
                    }
                }

                HStack(spacing: 10) {
                    Picker("Category", selection: Binding($row.suggestedCategory, replacingNilWith: "")) {
                        Text("Uncategorized").tag("")
                        ForEach(parentCategories) { category in
                            Text(category.name).tag(category.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Picker("Subcategory", selection: Binding($row.suggestedSubcategory, replacingNilWith: "")) {
                        Text("None").tag("")
                        ForEach(subcategories) { category in
                            Text(category.name).tag(category.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 10) {
                    Button {
                        createRuleAction()
                    } label: {
                        Label("Learn rule", systemImage: "wand.and.sparkles")
                    }
                    .disabled(row.suggestedCategory?.isEmpty != false)

                    if row.isDuplicate {
                        Button {
                            mergeDuplicateAction()
                        } label: {
                            Label("Merge duplicate", systemImage: "arrow.triangle.merge")
                        }
                    }

                    Spacer()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.violet)
            }
        }
    }

    private var subcategorySuffix: String {
        guard let subcategory = row.suggestedSubcategory, !subcategory.isEmpty else {
            return ""
        }
        return " / \(subcategory)"
    }
}

private struct StatusPill: View {
    var title: String
    var systemImage: String
    var tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct ImportProgressOverlay: View {
    var label: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
            GlassSurface {
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(AppTheme.violet)
                    Text(label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.ink)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 220)
            }
        }
    }
}

private extension Binding where Value == String {
    init(_ source: Binding<String?>, replacingNilWith defaultValue: String) {
        self.init {
            source.wrappedValue ?? defaultValue
        } set: { newValue in
            source.wrappedValue = newValue.isEmpty ? nil : newValue
        }
    }
}
