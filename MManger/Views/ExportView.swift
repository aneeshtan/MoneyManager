import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \FinanceCategory.sortOrder) private var categories: [FinanceCategory]
    @Query(sort: \MerchantRule.sampleCount, order: .reverse) private var rules: [MerchantRule]
    @Query(sort: \ImportBatch.importedAt, order: .reverse) private var batches: [ImportBatch]
    @State private var exportURL: URL?
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showingRestorePicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        GlassSurface {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Backup")
                                    .font(.system(.title2, design: .rounded).weight(.bold))
                                    .foregroundStyle(AppTheme.ink)
                                Text("Export a portable copy of your transactions or the full local database.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.muted)
                                Label("Your data is stored locally on this device. Exports are created only when you choose them.", systemImage: "lock.shield")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppTheme.teal)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        VStack(spacing: 12) {
                            ExportActionCard(
                                title: "Transactions CSV",
                                subtitle: "\(transactions.count) rows for spreadsheets",
                                systemImage: "tablecells",
                                tint: AppTheme.teal,
                                action: writeCSV
                            )

                            ExportActionCard(
                                title: "Full Backup JSON",
                                subtitle: "\(accounts.count) accounts, \(categories.count) categories, \(rules.count) rules",
                                systemImage: "archivebox",
                                tint: AppTheme.violet,
                                action: writeJSON
                            )

                            ExportActionCard(
                                title: "Restore Backup JSON",
                                subtitle: "Import a previous Pro Money Manager backup",
                                systemImage: "arrow.clockwise.icloud",
                                tint: AppTheme.gold,
                                action: { showingRestorePicker = true }
                            )
                        }

                        ImportHistorySection(batches: Array(batches.prefix(12)))

                        if let exportURL {
                            GlassSurface {
                                ShareLink(item: exportURL) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(AppTheme.violet)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Latest export")
                                                .font(.headline.weight(.semibold))
                                                .foregroundStyle(AppTheme.ink)
                                            Text(exportURL.lastPathComponent)
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.muted)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(AppTheme.muted)
                                    }
                                }
                            }
                            .buttonStyle(PrimaryPressStyle())
                        }

                        if let errorMessage {
                            GlassSurface {
                                Label(errorMessage, systemImage: "exclamationmark.triangle")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.coral)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if let successMessage {
                            GlassSurface {
                                Label(successMessage, systemImage: "checkmark.seal")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.teal)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .adaptiveScreenContent()
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Backup")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingRestorePicker) {
                DocumentPicker(contentTypes: [.json]) { url in
                    showingRestorePicker = false
                    restoreJSON(from: url)
                }
            }
        }
    }

    private func writeCSV() {
        do {
            let url = FileManager.default.temporaryDirectory.appending(path: "ai-money-manager-transactions.csv")
            try ExportService.transactionsCSV(transactions).write(to: url, atomically: true, encoding: .utf8)
            exportURL = url
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func writeJSON() {
        do {
            let url = FileManager.default.temporaryDirectory.appending(path: "ai-money-manager-backup.json")
            try ExportService.backupJSON(transactions: transactions, accounts: accounts, categories: categories, rules: rules).write(to: url)
            exportURL = url
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restoreJSON(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backup = try decoder.decode(RestorableBackupPayload.self, from: data)

            var insertedAccounts = 0
            var insertedCategories = 0
            var insertedRules = 0
            var insertedTransactions = 0

            for backupAccount in backup.accounts where !accounts.contains(where: { $0.name == backupAccount.name }) {
                modelContext.insert(
                    Account(
                        name: backupAccount.name,
                        currency: backupAccount.currency,
                        openingBalance: Decimal(string: backupAccount.openingBalance, locale: Locale(identifier: "en_US_POSIX")) ?? 0,
                        type: AccountType(rawValue: backupAccount.type) ?? .other,
                        isArchived: backupAccount.isArchived
                    )
                )
                insertedAccounts += 1
            }

            for backupCategory in backup.categories where !categories.contains(where: { $0.name == backupCategory.name && $0.parentName == backupCategory.parentName }) {
                modelContext.insert(
                    FinanceCategory(
                        name: backupCategory.name,
                        kind: TransactionKind(rawValue: backupCategory.kind) ?? .expense,
                        parentName: backupCategory.parentName
                    )
                )
                insertedCategories += 1
            }

            for backupRule in backup.rules where !rules.contains(where: { $0.pattern == backupRule.pattern }) {
                modelContext.insert(
                    MerchantRule(
                        pattern: backupRule.pattern,
                        categoryName: backupRule.category,
                        subcategoryName: backupRule.subcategory,
                        confidence: backupRule.confidence,
                        sampleCount: 1
                    )
                )
                insertedRules += 1
            }

            for backupTransaction in backup.transactions {
                let amount = Decimal(string: backupTransaction.amount, locale: Locale(identifier: "en_US_POSIX")) ?? 0
                let normalized = MerchantNormalizer.normalize(backupTransaction.merchant)
                let duplicate = transactions.contains { existing in
                    Calendar.current.isDate(existing.date, inSameDayAs: backupTransaction.date)
                        && existing.accountName == backupTransaction.accountName
                        && existing.amount == amount
                        && existing.normalizedMerchant == normalized
                }
                guard !duplicate else { continue }
                modelContext.insert(
                    FinanceTransaction(
                        date: backupTransaction.date,
                        kind: TransactionKind(rawValue: backupTransaction.kind) ?? .expense,
                        amount: amount,
                        currency: backupTransaction.currency,
                        merchant: backupTransaction.merchant,
                        normalizedMerchant: normalized,
                        note: backupTransaction.note,
                        rawDescription: backupTransaction.merchant,
                        accountName: backupTransaction.accountName,
                        categoryName: backupTransaction.categoryName,
                        subcategoryName: backupTransaction.subcategoryName,
                        sourceName: backupTransaction.source.name,
                        sourceRow: backupTransaction.source.row,
                        sourcePeriodSerial: backupTransaction.source.periodSerial,
                        sourceAccountColumn: backupTransaction.source.account,
                        sourceCategoryColumn: backupTransaction.source.category,
                        sourceSubcategoryColumn: backupTransaction.source.subcategory,
                        sourceNoteColumn: backupTransaction.source.note,
                        sourceAEDColumn: backupTransaction.source.aed,
                        sourceIncomeExpenseColumn: backupTransaction.source.incomeExpense,
                        sourceDescriptionColumn: backupTransaction.source.description,
                        sourceAmountColumn: backupTransaction.source.amount,
                        sourceCurrencyColumn: backupTransaction.source.currency,
                        sourceTrailingAccountsColumn: backupTransaction.source.trailingAccounts
                    )
                )
                insertedTransactions += 1
            }

            try modelContext.save()
            errorMessage = nil
            successMessage = "Restored \(insertedTransactions) transactions, \(insertedAccounts) accounts, \(insertedCategories) categories, and \(insertedRules) rules."
        } catch {
            successMessage = nil
            errorMessage = error.localizedDescription
        }
    }
}

private struct ExportActionCard: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassSurface {
                HStack(spacing: 14) {
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(width: 48, height: 48)
                        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                        Text(subtitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                    }

                    Spacer()

                    Image(systemName: "arrow.down.doc")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.muted)
                }
            }
        }
        .buttonStyle(PrimaryPressStyle())
    }
}

private struct ImportHistorySection: View {
    var batches: [ImportBatch]

    var body: some View {
        VStack(spacing: 12) {
            SectionTitle("Import history", subtitle: "Recent saved import batches")
            if batches.isEmpty {
                EmptyStateView(
                    systemImage: "clock.arrow.circlepath",
                    title: "No import history",
                    message: "Saved imports will appear here for audit and recovery."
                )
            } else {
                GlassSurface(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(batches) { batch in
                            HStack(spacing: 12) {
                                Image(systemName: "tray.and.arrow.down")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppTheme.violet)
                                    .frame(width: 38, height: 38)
                                    .background(AppTheme.lavender.opacity(0.13), in: Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(batch.sourceFileName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.ink)
                                        .lineLimit(1)
                                    Text("\(batch.savedCount) saved • \(batch.ignoredCount) ignored • \(AppFormatters.day.string(from: batch.importedAt))")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.muted)
                                }
                                Spacer()
                            }
                            .padding(14)
                            Divider().overlay(AppTheme.line.opacity(0.45))
                        }
                    }
                }
            }
        }
    }
}

private struct RestorableBackupPayload: Codable {
    var exportedAt: Date
    var accounts: [AccountBackupRecord]
    var categories: [RestorableCategory]
    var rules: [RestorableRule]
    var transactions: [RestorableTransaction]
}

private struct RestorableCategory: Codable {
    var name: String
    var kind: String
    var parentName: String?
}

private struct RestorableRule: Codable {
    var pattern: String
    var category: String
    var subcategory: String?
    var confidence: Double
}

private struct RestorableTransaction: Codable {
    var date: Date
    var accountName: String
    var kind: String
    var amount: String
    var currency: String
    var merchant: String
    var categoryName: String?
    var subcategoryName: String?
    var note: String
    var source: RestorableTransactionSource
}

private struct RestorableTransactionSource: Codable {
    var name: String?
    var row: Int?
    var periodSerial: String?
    var account: String?
    var category: String?
    var subcategory: String?
    var note: String?
    var aed: String?
    var incomeExpense: String?
    var description: String?
    var amount: String?
    var currency: String?
    var trailingAccounts: String?
}
