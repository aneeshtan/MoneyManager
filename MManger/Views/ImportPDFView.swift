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
    @State private var importSummary: ImportSummary?
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
    private var selectedAccountCurrency: String {
        AppFormatters.resolvedCurrency(
            activeAccounts.first(where: { $0.name == selectedAccountName })?.currency,
            fallback: currency
        )
    }
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

                        if let importSummary {
                            GlassSurface {
                                Label(importSummary.message, systemImage: "checkmark.seal")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.teal)
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
                                SectionTitle(NSLocalizedString("Review import", comment: ""), subtitle: sourceFileName.isEmpty ? selectedSource.reviewSubtitle : sourceFileName)
                                Spacer()
                                Button(NSLocalizedString("Select clean", comment: "")) {
                                    for index in parsedRows.indices {
                                        parsedRows[index].isSelected = !parsedRows[index].isDuplicate && !parsedRows[index].isReviewOnly
                                    }
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.violet)
                                .buttonStyle(PrimaryPressStyle())
                            }

                            LazyVStack(spacing: 12) {
                                // Index-based bindings are O(1); scanning parsedRows for the id
                                // on every binding access made large imports glitchy. Indices
                                // stay valid because rows are only appended or cleared wholesale.
                                ForEach(Array(parsedRows.prefix(maxDisplayedRows).enumerated()), id: \.element.id) { index, _ in
                                    ImportReviewRow(
                                        row: $parsedRows[index],
                                        fallbackCurrency: selectedAccountCurrency,
                                        categories: categories,
                                        createRuleAction: { createRule(from: parsedRows[index], existingRules: rules) },
                                        mergeDuplicateAction: { mergeDuplicate(parsedRows[index]) }
                                    )
                                }
                            }

                            if parsedRows.count > maxDisplayedRows {
                                GlassSurface {
                                    HStack(spacing: 10) {
                                        Image(systemName: "info.circle")
                                            .foregroundStyle(AppTheme.violet)
                                        Text(String(format: NSLocalizedString("Showing the first %d of %d rows. Save will include all selected rows.", comment: ""), maxDisplayedRows, parsedRows.count))
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(AppTheme.muted)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                    .adaptiveScreenContent(maxWidth: 1120)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }

                if isParsing || isSaving {
                    ImportProgressOverlay(label: parsingLabel)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isParsing)
            .animation(.easeInOut(duration: 0.2), value: isSaving)
            .navigationTitle(NSLocalizedString("Import", comment: ""))
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
        importSummary = nil
        sourceFileName = url.lastPathComponent
        parsingLabel = "Reading \(url.lastPathComponent)…"
        isParsing = true
        parsedRows = []

        let ext = url.pathExtension.lowercased()

        importTask?.cancel()
        importTask = Task { @MainActor in
            let accountName = selectedAccountName
            let fallbackCurrency = selectedAccountCurrency
            let ruleSnapshots = rules.map(MerchantRuleSnapshot.init)
            // Spreadsheet exports can name an account per row, so duplicate detection has
            // to consider every account rather than only the one picked above.
            let existingSnapshots = transactions.map(TransactionSnapshot.init)
            let format: ImportFormat = ext == "pdf" ? .pdf : (ext == "csv" ? .csv : .plainText)
            let isWorkbook = ["xlsx", "xls"].contains(ext)

            // Extract and parse off the main actor in a detached task, streaming results back
            // in chunks. The PDFDocument stays confined to that single task, which is the
            // confinement PDFKit needs; doing this on the main thread froze the UI on big files.
            let stream = AsyncStream<[ParsedBankTransaction]> { continuation in
                Task.detached(priority: .userInitiated) {
                    defer { continuation.finish() }
                    do {
                        let all: [ParsedBankTransaction]
                        if isWorkbook {
                            await MainActor.run { parsingLabel = "Reading worksheet…" }
                            let table = try SpreadsheetImportParser.table(fromXLSX: url)
                            guard SpreadsheetImportParser.isSupported(table) else {
                                throw UniversalImportParserError.noTransactionsFound
                            }
                            await MainActor.run { parsingLabel = "Parsing transactions…" }
                            all = SpreadsheetImportParser.parse(
                                table,
                                ruleSnapshots: ruleSnapshots,
                                existingSnapshots: existingSnapshots,
                                defaultAccountName: accountName,
                                fallbackCurrency: fallbackCurrency
                            )
                            guard !all.isEmpty else { throw UniversalImportParserError.noTransactionsFound }
                        } else {
                            let rawText: String
                            if ext == "pdf" {
                                rawText = try BankStatementPDFParser.extractText(from: url)
                            } else if let text = try? String(contentsOf: url, encoding: .utf8) {
                                rawText = text
                            } else {
                                throw UniversalImportParserError.unreadableFile
                            }

                            await MainActor.run { parsingLabel = "Parsing transactions…" }

                            // A CSV carrying its own Category/Account columns is a full
                            // export, not a bank statement, so keep those columns instead
                            // of re-deriving them.
                            let table = format == .csv ? SpreadsheetImportParser.table(fromCSV: rawText) : SpreadsheetTable(headers: [], rows: [])
                            if SpreadsheetImportParser.isSupported(table) {
                                all = SpreadsheetImportParser.parse(
                                    table,
                                    ruleSnapshots: ruleSnapshots,
                                    existingSnapshots: existingSnapshots,
                                    defaultAccountName: accountName,
                                    fallbackCurrency: fallbackCurrency
                                )
                            } else {
                                all = try UniversalImportParser().parseText(
                                    rawText,
                                    format: format,
                                    ruleSnapshots: ruleSnapshots,
                                    existingSnapshots: existingSnapshots,
                                    accountName: accountName,
                                    fallbackCurrency: fallbackCurrency
                                )
                            }
                        }
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
                        await MainActor.run { errorMessage = error.localizedDescription }
                    }
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
        importSummary = nil
        sourceFileName = "Pasted messages"
        parsingLabel = "Parsing messages…"
        isParsing = true
        parsedRows = []

        let accountName = selectedAccountName
        let fallbackCurrency = selectedAccountCurrency
        let ruleSnapshots = rules.map(MerchantRuleSnapshot.init)
        let existingSnapshots = selectedAccountTransactions.map(TransactionSnapshot.init)
        let text = pastedText

        importTask?.cancel()
        importTask = Task {
            do {
                let rows = try await Task.detached(priority: .userInitiated) { [text, ruleSnapshots, existingSnapshots, accountName, fallbackCurrency] in
                    try UniversalImportParser().parsePastedMessages(
                        text,
                        ruleSnapshots: ruleSnapshots,
                        existingSnapshots: existingSnapshots,
                        accountName: accountName,
                        fallbackCurrency: fallbackCurrency
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
        parsingLabel = "Saving transactions…"
        let accountName = selectedAccountName
        let fallbackCurrency = selectedAccountCurrency
        let rowsToSave = parsedRows.filter(\.isSelected)
        let draftsToSave = rowsToSave.map {
            ImportSaveDraft(row: $0, accountName: accountName, fallbackCurrency: fallbackCurrency)
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
                backfillImportMetadata(for: draftsToSave)

                var existingByIdentity = existingIdentity
                var ruleLookup = makeRuleLookup(allRules)
                var saved = 0
                var trainingRows: [FinanceTransaction] = []
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
                    let transaction = draft.transaction(importBatchId: batch.id)
                    modelContext.insert(transaction)
                    // Rows the file already categorized are learned in one voting pass
                    // below. Writing a rule per row here would emit thousands of
                    // single-sample exact rules and let a merchant's rarest category win.
                    if row.isPreCategorized {
                        trainingRows.append(transaction)
                    } else {
                        createRule(from: row, rulesByPattern: &ruleLookup)
                    }
                    saved += 1

                    if saved % batchSize == 0 {
                        try modelContext.save()
                        parsingLabel = "Saved \(saved) of \(savedCount)…"
                        await Task.yield()  // hand control back to the main run loop
                    }
                }

                try modelContext.save()

                let learnedCount = learnRules(from: trainingRows, existingRules: allRules)
                if learnedCount > 0 {
                    try modelContext.save()
                }

                parsedRows.removeAll()
                pastedText = ""
                parsingLabel = ""
                importSummary = ImportSummary(savedCount: savedCount, learnedRuleCount: learnedCount)
            } catch {
                errorMessage = "Could not save imported transactions: \(error.localizedDescription)"
            }
        }
    }

    private func backfillImportMetadata(for drafts: [ImportSaveDraft]) {
        guard !drafts.isEmpty else { return }

        // A spreadsheet export can reference several accounts in one file, so create every
        // account the rows name rather than only the one selected in the picker.
        var existingAccountNames = Set(accounts.map(\.name))
        var nextAccountSortOrder = (accounts.map(\.sortOrder).max() ?? 0) + 1
        for draft in drafts where !existingAccountNames.contains(draft.accountName) {
            modelContext.insert(
                Account(
                    name: draft.accountName,
                    currency: draft.currency,
                    sortOrder: nextAccountSortOrder
                )
            )
            existingAccountNames.insert(draft.accountName)
            nextAccountSortOrder += 1
        }

        var existingCategoryKeys = Set(categories.map { categoryKey(name: $0.name, parentName: $0.parentName) })
        var nextSortOrder = (categories.map(\.sortOrder).max() ?? 0) + 1

        for draft in drafts {
            guard let categoryName = draft.categoryName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !categoryName.isEmpty else {
                continue
            }

            let parentKey = categoryKey(name: categoryName, parentName: nil)
            if !existingCategoryKeys.contains(parentKey) {
                modelContext.insert(
                    FinanceCategory(
                        name: categoryName,
                        kind: draft.kind,
                        sortOrder: nextSortOrder
                    )
                )
                existingCategoryKeys.insert(parentKey)
                nextSortOrder += 1
            }

            guard let subcategoryName = draft.subcategoryName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !subcategoryName.isEmpty else {
                continue
            }

            let childKey = categoryKey(name: subcategoryName, parentName: categoryName)
            if !existingCategoryKeys.contains(childKey) {
                modelContext.insert(
                    FinanceCategory(
                        name: subcategoryName,
                        kind: draft.kind,
                        parentName: categoryName,
                        sortOrder: nextSortOrder
                    )
                )
                existingCategoryKeys.insert(childKey)
                nextSortOrder += 1
            }
        }
    }

    private func categoryKey(name: String, parentName: String?) -> String {
        "\(parentName ?? "")|\(name)".lowercased()
    }

    /// Normalized pattern → rule, so the save loop can match rules in O(1) instead of
    /// re-normalizing every rule's pattern for every saved row.
    private func makeRuleLookup(_ rules: [MerchantRule]) -> [String: MerchantRule] {
        var lookup: [String: MerchantRule] = [:]
        lookup.reserveCapacity(rules.count)
        for rule in rules {
            let pattern = MerchantNormalizer.normalize(rule.pattern)
            if !pattern.isEmpty, lookup[pattern] == nil {
                lookup[pattern] = rule
            }
        }
        return lookup
    }

    /// Turns the categories a file already carried into reusable merchant rules, so the
    /// next statement or SMS import categorizes itself. Returns how many rules were added.
    private func learnRules(from trainingRows: [FinanceTransaction], existingRules: [MerchantRule]) -> Int {
        guard !trainingRows.isEmpty else { return 0 }
        parsingLabel = "Learning categories…"
        // One sample is enough here, unlike the in-app sweep: a category that came from
        // the file is a decision the user already made, not a guess worth corroborating.
        // On a 5k-row export this traded ~1pp of precision for ~4pp more coverage.
        let learned = SmartCategorizationService.learnRules(
            from: trainingRows,
            existingRules: existingRules,
            minSamples: 1
        )
        for rule in learned {
            modelContext.insert(rule)
        }
        return learned.count
    }

    private func createRule(from row: ParsedBankTransaction, existingRules: [MerchantRule]) {
        var lookup = makeRuleLookup(existingRules)
        createRule(from: row, rulesByPattern: &lookup)
        try? modelContext.save()
    }

    private func createRule(from row: ParsedBankTransaction, rulesByPattern: inout [String: MerchantRule]) {
        guard let category = row.suggestedCategory, !category.isEmpty else { return }
        let pattern = row.normalizedMerchant.isEmpty ? MerchantNormalizer.normalize(row.description) : row.normalizedMerchant
        guard !pattern.isEmpty else { return }
        if let existing = rulesByPattern[pattern] {
            existing.categoryName = category
            existing.subcategoryName = row.suggestedSubcategory
            existing.kind = row.kind
            existing.confidence = max(existing.confidence, max(row.confidence, 0.85))
            existing.sampleCount += 1
        } else {
            let rule = MerchantRule(
                pattern: pattern,
                matchType: .exact,
                categoryName: category,
                subcategoryName: row.suggestedSubcategory,
                kind: row.kind,
                confidence: max(row.confidence, 0.85),
                sampleCount: 1
            )
            modelContext.insert(rule)
            // Track the new rule so repeated merchants in this import update it
            // instead of inserting duplicate rules.
            rulesByPattern[pattern] = rule
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
        Dictionary(grouping: transactions) { transaction in
            TransactionIdentityKey.make(
                accountName: transaction.accountName,
                date: transaction.date,
                amount: transaction.amount,
                normalizedMerchant: MerchantNormalizer.normalize(transaction.normalizedMerchant)
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

private struct ImportSummary {
    var savedCount: Int
    var learnedRuleCount: Int

    var message: String {
        guard learnedRuleCount > 0 else {
            return String(format: NSLocalizedString("Saved %d transactions.", comment: ""), savedCount)
        }
        return String(
            format: NSLocalizedString("Saved %d transactions and learned %d categorization rules from this file.", comment: ""),
            savedCount,
            learnedRuleCount
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
        case .csv: "Excel / CSV export"
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
            [.commaSeparatedText, .spreadsheet, .plainText, .text]
                + [UTType(filenameExtension: "xlsx"), UTType(filenameExtension: "xls")].compactMap { $0 }
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
            "Import an .xlsx or .csv export from Excel, Google Sheets, another money app, or your bank. Headers like Date, Description, Amount, Debit, Credit, and Currency are supported. If the file has Category, Subcategory, or Account columns those are kept as-is and used to teach categorization."
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

    private var ctaState: ImportCTAState {
        ImportCTAState(parsedCount: parsedCount, selectedCount: selectedCount, isBusy: isBusy)
    }

    var body: some View {
        GlassSurface {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("Data Sources", comment: ""))
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                        Text(NSLocalizedString("Collect transactions from files, exports, and bank messages.", comment: ""))
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
                        Label(source == .paste ? NSLocalizedString("Parse Paste", comment: "") : NSLocalizedString("Choose File", comment: ""), systemImage: source == .paste ? "sparkle.magnifyingglass" : "folder")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(ctaState.isImportPrimary ? Color.white : AppTheme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(ctaState.isImportPrimary ? AppTheme.violet : AppTheme.controlSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(ctaState.isImportPrimary ? Color.clear : AppTheme.line, lineWidth: 1)
                            )
                    }
                    .disabled(isBusy)
                    .buttonStyle(PrimaryPressStyle())

                    Button {
                        saveAction()
                    } label: {
                        Label(NSLocalizedString("Save", comment: ""), systemImage: "checkmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(ctaState.isSaveDisabled ? AppTheme.muted : (ctaState.isSavePrimary ? Color.white : AppTheme.ink))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(ctaState.isSavePrimary && !ctaState.isSaveDisabled ? AppTheme.violet : AppTheme.controlSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(ctaState.isSavePrimary && !ctaState.isSaveDisabled ? Color.clear : AppTheme.line, lineWidth: 1)
                            )
                    }
                    .disabled(ctaState.isSaveDisabled)
                    .buttonStyle(PrimaryPressStyle())
                }
            }
        }
    }
}

enum ImportCTAAction: Equatable {
    case importRows
    case saveRows
}

struct ImportCTAState: Equatable {
    var parsedCount: Int
    var selectedCount: Int
    var isBusy: Bool

    var primaryAction: ImportCTAAction {
        parsedCount > 0 ? .saveRows : .importRows
    }

    var isImportPrimary: Bool {
        primaryAction == .importRows
    }

    var isSavePrimary: Bool {
        primaryAction == .saveRows
    }

    var isSaveDisabled: Bool {
        selectedCount == 0 || isBusy
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
                SectionTitle(NSLocalizedString("Paste bank messages", comment: ""), subtitle: NSLocalizedString("One message per line works best", comment: ""))
                TextEditor(text: $text)
                    .frame(minHeight: 150)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(AppTheme.elevatedSurface.opacity(0.82), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.line.opacity(0.75), lineWidth: 1)
                    )

                Button {
                    parseAction()
                } label: {
                    Label(NSLocalizedString("Parse pasted text", comment: ""), systemImage: "sparkle.magnifyingglass")
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
    @Binding var row: ParsedBankTransaction
    var fallbackCurrency: String
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
                        Text("\(AppFormatters.dayString(from: row.date)) • \(row.suggestedCategory ?? NSLocalizedString("Uncategorized", comment: ""))\(subcategorySuffix)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                    }

                    Spacer(minLength: 8)

                    Text(AppFormatters.money(row.amount, currency: AppFormatters.resolvedCurrency(row.currency, fallback: fallbackCurrency)))
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
                        Text(NSLocalizedString("Uncategorized", comment: "")).tag("")
                        ForEach(parentCategories) { category in
                            Text(category.name).tag(category.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Picker("Subcategory", selection: Binding($row.suggestedSubcategory, replacingNilWith: "")) {
                        Text(NSLocalizedString("None", comment: "")).tag("")
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
                        Label(NSLocalizedString("Learn rule", comment: ""), systemImage: "wand.and.sparkles")
                    }
                    .disabled(row.suggestedCategory?.isEmpty != false)

                    if row.isDuplicate {
                        Button {
                            mergeDuplicateAction()
                        } label: {
                            Label(NSLocalizedString("Merge duplicate", comment: ""), systemImage: "arrow.triangle.merge")
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
            Color(red: 0.020, green: 0.024, blue: 0.032).opacity(0.24)
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
