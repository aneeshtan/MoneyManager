import SwiftUI

struct ReceiptOCRReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(\.appCurrency) private var appCurrency
    @State private var parsedReceipt: ParsedReceipt?
    @State private var image: UIImage
    @State private var isProcessing = false
    @State private var error: String?
    @State private var merchantName: String
    @State private var totalAmount: String
    @State private var currency: String
    @State private var receiptDate: Date?
    @State private var selectedTab: OCRReviewTab = .overview
    @State private var lineItems: [ReceiptLineItem]
    var onSave: (ReceiptOCRData) -> Void

    init(image: UIImage, onSave: @escaping (ReceiptOCRData) -> Void) {
        _image = State(initialValue: image)
        _merchantName = State(initialValue: "")
        _totalAmount = State(initialValue: "")
        _currency = State(initialValue: "")
        _receiptDate = State(initialValue: nil)
        _lineItems = State(initialValue: [])
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if isProcessing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(AppTheme.violet)
                        Text(NSLocalizedString("Reading receipt…", comment: ""))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.ink)
                    }
                    .frame(maxWidth: 220)
                    .padding(20)
                    .background(AppTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Tabs
                            Picker("Tab", selection: $selectedTab) {
                                ForEach(OCRReviewTab.allCases) { tab in
                                    Text(tab.label).tag(tab)
                                }
                            }
                            .pickerStyle(.segmented)

                            // Content based on selected tab
                            switch selectedTab {
                            case .overview:
                                overviewContent

                            case .image:
                                imagePreview

                            case .lineItems:
                                lineItemsContent
                            }

                            // Error message
                            if let error = error {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(AppTheme.coral)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.coral)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(AppTheme.coral.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }

                            // Save button
                            Button {
                                saveReceipt()
                            } label: {
                                Text(NSLocalizedString("Save Receipt", comment: ""))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .disabled(merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || totalAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(20)
                        .adaptiveScreenContent(maxWidth: 600)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("Review Receipt", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.violet)
                }
            }
            .onAppear {
                if currency.isEmpty { currency = appCurrency }
                extractAndParse()
            }
        }
    }

    // MARK: - Content Views

    @ViewBuilder
    private var overviewContent: some View {
        VStack(spacing: 16) {
            // Merchant Name
            VStack(alignment: .leading, spacing: 6) {
                Label(NSLocalizedString("Merchant Name", comment: ""), systemImage: "building.2")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
                TextField(NSLocalizedString("Enter merchant name", comment: ""), text: $merchantName)
                    .textFieldStyle(.roundedBorder)
            }

            // Amount
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(NSLocalizedString("Total Amount", comment: ""), systemImage: "dollarsign.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                    TextField(NSLocalizedString("Amount", comment: ""), text: $totalAmount)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label(NSLocalizedString("Currency", comment: ""), systemImage: "globe")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                    Menu {
                        ForEach(commonCurrencies, id: \.self) { code in
                            Button(code) { currency = code }
                        }
                    } label: {
                        Text(currency)
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(AppTheme.controlSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
                    }
                }
            }

            // Date
            VStack(alignment: .leading, spacing: 6) {
                Label(NSLocalizedString("Receipt Date", comment: ""), systemImage: "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
                if receiptDate != nil {
                    DatePicker("", selection: Binding(
                        get: { receiptDate ?? Date() },
                        set: { receiptDate = $0 }
                    ), displayedComponents: .date)
                        .datePickerStyle(.compact)
                } else {
                    Button {
                        receiptDate = Date()
                    } label: {
                        Text(NSLocalizedString("Set date", comment: ""))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(AppTheme.controlSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
                    }
                    .foregroundStyle(AppTheme.muted)
                }
            }

            // Confidence indicator
            if let parsed = parsedReceipt {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(AppTheme.lavender)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("Extraction Confidence", comment: ""))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                        ProgressView(value: parsed.confidence)
                            .tint(parsed.confidence > 0.8 ? AppTheme.teal : (parsed.confidence > 0.6 ? AppTheme.gold : AppTheme.coral))
                    }
                }
                .padding(12)
                .background(AppTheme.lavender.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        VStack(spacing: 12) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 400)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.line, lineWidth: 1)
                )

            Text(NSLocalizedString("Original receipt image", comment: ""))
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
        }
    }

    @ViewBuilder
    private var lineItemsContent: some View {
        VStack(spacing: 12) {
            ForEach($lineItems, id: \.id) { $item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField(NSLocalizedString("Item", comment: ""), text: $item.itemName)
                            .font(.caption)
                        Spacer()
                        HStack(spacing: 4) {
                            Text(AppFormatters.money(item.totalPrice, currency: currency))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                        }
                    }
                    .padding(10)
                    .background(AppTheme.controlSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            Button {
                let newItem = ReceiptLineItem(description: "", unitPrice: 0, quantity: 1, totalPrice: 0)
                lineItems.append(newItem)
            } label: {
                Label(NSLocalizedString("Add line item", comment: ""), systemImage: "plus.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.violet)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Helper Functions

    private func extractAndParse() {
        isProcessing = true
        error = nil

        Task {
            do {
                let ocrText = try ReceiptOCRService.extractText(from: image)
                let parser = ReceiptParser()
                let receipt = try parser.parse(ocrText, fallbackCurrency: appCurrency)

                await MainActor.run {
                    parsedReceipt = receipt
                    merchantName = receipt.merchantName
                    totalAmount = NSDecimalNumber(decimal: receipt.totalAmount).stringValue
                    currency = receipt.currency
                    receiptDate = receipt.receiptDate
                    lineItems = receipt.lineItems
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }

    private func saveReceipt() {
        guard let totalAmount = Decimal(string: totalAmount.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            error = NSLocalizedString("Invalid amount", comment: "")
            return
        }

        let ocrData = ReceiptOCRData(
            rawText: parsedReceipt?.rawText ?? "",
            merchantName: merchantName,
            totalAmount: totalAmount,
            currency: currency,
            lineItems: lineItems,
            receiptDate: receiptDate,
            extractionConfidence: parsedReceipt?.confidence ?? 0.5
        )

        modelContext.insert(ocrData)
        try? modelContext.save()

        onSave(ocrData)
        dismiss()
    }

    private var commonCurrencies: [String] {
        ["USD", "EUR", "GBP", "AED", "INR", "JPY", "CAD", "AUD", "CHF", "CNY", "BRL", "INR", "IRR"]
    }
}

enum OCRReviewTab: String, CaseIterable, Identifiable {
    case overview
    case image
    case lineItems

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview:
            NSLocalizedString("Overview", comment: "")
        case .image:
            NSLocalizedString("Image", comment: "")
        case .lineItems:
            NSLocalizedString("Items", comment: "")
        }
    }
}

#Preview {
    ReceiptOCRReviewView(image: UIImage(systemName: "receipt.fill")!) { _ in }
}
