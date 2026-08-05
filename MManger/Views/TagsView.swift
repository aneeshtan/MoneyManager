import SwiftUI
import SwiftData

struct TagsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appCurrency) private var currency
    @Query(sort: \Tag.name) private var tags: [Tag]
    @Query(sort: \FinanceTransaction.date, order: .reverse) private var transactions: [FinanceTransaction]
    @State private var showingEditor = false
    @State private var editingTag: Tag?

    private let palette = [
        "8151D1", "E85D75", "F4A261", "2A9D8F", "264653",
        "E76F51", "06A77D", "118AB2", "073B4C", "8338EC"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        heroCard

                        if tags.isEmpty {
                            EmptyStateView(
                                systemImage: "tag",
                                title: "No tags yet",
                                message: "Create tags like 'reimbursable', 'tax-deductible', or 'business' to organize transactions beyond categories."
                            )
                        } else {
                            VStack(spacing: 12) {
                                SectionTitle("Your tags", subtitle: "Tap a tag to see related transactions")
                                LazyVStack(spacing: 12) {
                                    ForEach(tags) { tag in
                                        Button {
                                            editingTag = tag
                                        } label: {
                                            TagRow(tag: tag, total: totalFor(tag: tag), count: countFor(tag: tag), currency: currency)
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
            .navigationTitle(NSLocalizedString("Tags", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(NSLocalizedString("Add tag", comment: ""))
                }
            }
            .sheet(isPresented: $showingEditor) {
                TagEditorView(tag: nil, palette: palette)
            }
            .sheet(item: $editingTag) { tag in
                TagEditorView(tag: tag, palette: palette)
            }
        }
    }

    private var heroCard: some View {
        GlassSurface(padding: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("Tags", comment: ""))
                            .font(.caption.weight(.semibold))
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.violet)
                        Text(NSLocalizedString("Label your transactions", comment: ""))
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                    }
                    Spacer()
                    Image(systemName: "tag")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.violet)
                        .frame(width: 50, height: 50)
                        .background(AppTheme.lavender.opacity(0.14), in: Circle())
                }

                HStack(spacing: 10) {
                    MetricCapsule(title: "Total tags", value: "\(tags.count)", tint: AppTheme.lavender)
                    MetricCapsule(title: "Tagged transactions", value: "\(taggedCount)", tint: AppTheme.teal)
                }
            }
            .padding(20)
            .appHeroBackground()
        }
    }

    private var taggedCount: Int {
        transactions.filter { !$0.tagNames.isEmpty }.count
    }

    private func totalFor(tag: Tag) -> Decimal {
        transactions.filter { $0.tagNames.contains(tag.name) }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private func countFor(tag: Tag) -> Int {
        transactions.filter { $0.tagNames.contains(tag.name) }.count
    }
}

private struct TagRow: View {
    var tag: Tag
    var total: Decimal
    var count: Int
    var currency: String

    var body: some View {
        GlassSurface {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: tag.colorHex))
                    .frame(width: 16, height: 16)
                VStack(alignment: .leading, spacing: 4) {
                    Text(tag.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text(String(format: NSLocalizedString("%d transactions", comment: ""), count))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
                Text(AppFormatters.statMoney(total, currency: currency))
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.ink)
            }
        }
    }
}

private struct TagEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var tag: Tag?
    var palette: [String]

    @State private var name = ""
    @State private var selectedColor = "8151D1"
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("Tag", comment: "")) {
                    LabeledTextField(label: "Name", text: $name, prompt: "e.g. Business")
                }

                Section(NSLocalizedString("Color", comment: "")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(palette, id: \.self) { hex in
                            Button {
                                selectedColor = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColor == hex ? AppTheme.ink : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if tag != nil {
                    Section {
                        Button(NSLocalizedString("Delete tag", comment: ""), role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
            .appFormStyle()
            .navigationTitle(NSLocalizedString(tag == nil ? "Add Tag" : "Edit Tag", comment: ""))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Save", comment: ""), action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert(NSLocalizedString("Delete Tag?", comment: ""), isPresented: $showingDeleteConfirmation) {
                Button(NSLocalizedString("Delete", comment: ""), role: .destructive) { deleteTag() }
                Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("Are you sure you want to delete this tag?", comment: ""))
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let tag else { return }
        name = tag.name
        selectedColor = tag.colorHex
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        if let tag {
            tag.name = cleanName
            tag.colorHex = selectedColor
        } else {
            modelContext.insert(Tag(name: cleanName, colorHex: selectedColor))
        }
        try? modelContext.save()
        dismiss()
    }

    private func deleteTag() {
        guard let tag else { return }
        modelContext.delete(tag)
        try? modelContext.save()
        dismiss()
    }
}
