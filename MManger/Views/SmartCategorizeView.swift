import SwiftUI
import SwiftData

struct SmartCategorizeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appCurrency) private var currency

    var transactions: [FinanceTransaction]
    var rules: [MerchantRule]
    var onComplete: (String) -> Void

    @State private var learnedRules: [MerchantRule] = []
    @State private var preview: [CategorizationPreview] = []
    @State private var isLearning = false
    @State private var isApplying = false

    private var uncategorized: [FinanceTransaction] {
        transactions.filter { $0.categoryName?.isEmpty != false }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        heroCard

                        if learnedRules.isEmpty && !isLearning {
                            EmptyStateView(
                                systemImage: "sparkles",
                                title: NSLocalizedString("No new rules to learn", comment: ""),
                                message: NSLocalizedString("Categorize a few more transactions with the same merchant and Smart Categorize will pick up the pattern.", comment: "")
                            )
                        } else {
                            learnedRulesSection
                        }

                        if !preview.isEmpty {
                            previewSection
                        }
                    }
                    .adaptiveScreenContent()
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(NSLocalizedString("Smart Categorize", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "")) { dismiss() }
                }
            }
            .task {
                await learn()
            }
        }
    }

    private var heroCard: some View {
        GlassSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(AppTheme.violet, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("AI auto-categorization", comment: ""))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                        Text(String(
                            format: NSLocalizedString("%d uncategorized • %d new rules", comment: ""),
                            uncategorized.count, learnedRules.count
                        ))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                }

                if !preview.isEmpty {
                    Button {
                        apply()
                    } label: {
                        Label(
                            isApplying
                                ? NSLocalizedString("Applying…", comment: "")
                                : String(
                                    format: NSLocalizedString("Apply %d suggestions", comment: ""),
                                    preview.count
                                ),
                            systemImage: "wand.and.sparkles"
                        )
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(PrimaryPressStyle())
                    .disabled(isApplying)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var learnedRulesSection: some View {
        VStack(spacing: 12) {
            SectionTitle(
                NSLocalizedString("Learned rules", comment: ""),
                subtitle: NSLocalizedString("Patterns discovered from your categorized transactions", comment: "")
            )

            ForEach(learnedRules) { rule in
                GlassSurface(padding: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "wand.and.sparkles")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.violet)
                            .frame(width: 38, height: 38)
                            .background(AppTheme.lavender.opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rule.pattern)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                            Text("→ \(rule.categoryName)\(rule.subcategoryName.map { " / \($0)" } ?? "") • \(rule.sampleCount) \(NSLocalizedString("samples", comment: ""))")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppTheme.muted)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private var previewSection: some View {
        VStack(spacing: 12) {
            SectionTitle(
                NSLocalizedString("Preview", comment: ""),
                subtitle: NSLocalizedString("Transactions that will be categorized", comment: "")
            )

            ForEach(preview.prefix(50)) { item in
                GlassSurface(padding: 14) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.transaction.merchant)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                                .lineLimit(1)
                            Text("→ \(item.suggestedCategory)\(item.suggestedSubcategory.map { " / \($0)" } ?? "") • \(Int(item.confidence * 100))%")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppTheme.violet)
                        }
                        Spacer()
                        Text(AppFormatters.statMoney(item.transaction.amount, currency: item.transaction.currency))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.ink.opacity(0.76))
                    }
                }
            }
        }
    }

    private func learn() async {
        isLearning = true
        await Task.yield()
        let newRules = SmartCategorizationService.learnRules(
            from: transactions,
            existingRules: rules,
            minSamples: 2
        )
        await MainActor.run {
            learnedRules = newRules
            preview = SmartCategorizationService.preview(for: transactions, rules: rules + newRules)
            isLearning = false
        }
    }

    private func apply() {
        isApplying = true
        for rule in learnedRules {
            modelContext.insert(rule)
        }
        let count = SmartCategorizationService.applyRules(to: transactions, rules: rules + learnedRules)
        try? modelContext.save()
        isApplying = false
        onComplete(
            count == 0
                ? NSLocalizedString("No transactions were categorized.", comment: "")
                : String(
                    format: NSLocalizedString("Categorized %d transactions and saved %d new rules.", comment: ""),
                    count, learnedRules.count
                )
        )
        dismiss()
    }
}
