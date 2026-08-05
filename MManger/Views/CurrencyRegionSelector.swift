import SwiftUI

struct CurrencyRegionSelector: View {
    @Binding var baseCurrency: String
    @Binding var countryCode: String?
    @Binding var timeZoneIdentifier: String?

    @State private var searchText = ""
    @State private var selectedCurrency: String
    @State private var selectedCountry: Locale.Region?
    @State private var selectedTimeZone: TimeZone?

    private let allCurrencies: [CurrencyOption] = {
        let codes = [
            "USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "SEK", "NZD",
            "MXN", "SGD", "HKD", "NOK", "KRW", "TRY", "INR", "BRL", "ZAR", "AED",
            "SAR", "QAR", "KWD", "BHD", "OMR", "EGP", "PHP", "THB", "IDR", "MYR",
            "IRR", "RUB", "PLN", "DKK", "CZK", "HUF", "ILS", "PKR", "BDT", "VND", "NGN",
            "KES", "GHS", "UGX", "TZS", "XOF", "XAF", "MAD", "TND", "JOD", "LBP"
        ]
        return codes.compactMap { code in
            let currency = Locale.Currency(code)
            return CurrencyOption(code: code, currency: currency)
        }.sorted { $0.name < $1.name }
    }()

    private var filteredCurrencies: [CurrencyOption] {
        if searchText.isEmpty { return allCurrencies }
        let lower = searchText.lowercased()
        return allCurrencies.filter {
            $0.name.lowercased().contains(lower) || $0.code.lowercased().contains(lower)
        }
    }

    init(
        baseCurrency: Binding<String>,
        countryCode: Binding<String?>,
        timeZoneIdentifier: Binding<String?>
    ) {
        self._baseCurrency = baseCurrency
        self._countryCode = countryCode
        self._timeZoneIdentifier = timeZoneIdentifier
        let initialCurrency = baseCurrency.wrappedValue.uppercased()
        _selectedCurrency = State(initialValue: initialCurrency)
        _selectedCountry = State(initialValue: countryCode.wrappedValue.map { Locale.Region($0) })
        _selectedTimeZone = State(initialValue: timeZoneIdentifier.wrappedValue.flatMap(TimeZone.init(identifier:)))
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchBar(text: $searchText)

            List {
                Section(NSLocalizedString("Selected", comment: "")) {
                    if let option = allCurrencies.first(where: { $0.code == selectedCurrency }) {
                        CurrencyRow(option: option, isSelected: true)
                    }
                }

                Section(NSLocalizedString("Currencies", comment: "")) {
                    ForEach(filteredCurrencies) { option in
                        CurrencyRow(option: option, isSelected: option.code == selectedCurrency)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedCurrency = option.code
                                updateBindings()
                            }
                    }
                }
            }
            .listStyle(.plain)
        }
        .onAppear {
            if selectedCurrency.isEmpty || !allCurrencies.contains(where: { $0.code == selectedCurrency }) {
                let deviceCurrency = AppFormatters.defaultCurrency()
                selectedCurrency = deviceCurrency.uppercased()
            }
            if selectedCountry == nil {
                selectedCountry = Locale.current.region
            }
            if selectedTimeZone == nil {
                selectedTimeZone = TimeZone.current
            }
            updateBindings()
        }
        .onChange(of: baseCurrency) { _, newValue in
            let normalized = newValue.uppercased()
            guard normalized != selectedCurrency,
                  allCurrencies.contains(where: { $0.code == normalized }) else {
                return
            }
            selectedCurrency = normalized
        }
        .onChange(of: countryCode) { _, newValue in
            selectedCountry = newValue.map { Locale.Region($0) }
        }
        .onChange(of: timeZoneIdentifier) { _, newValue in
            selectedTimeZone = newValue.flatMap(TimeZone.init(identifier:))
        }
    }

    private func updateBindings() {
        baseCurrency = selectedCurrency
        countryCode = selectedCountry?.identifier
        timeZoneIdentifier = selectedTimeZone?.identifier
    }
}

private struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.muted)
            TextField(NSLocalizedString("Search currencies", comment: ""), text: $text)
                .font(.subheadline)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.muted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.controlSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct CurrencyRow: View {
    var option: CurrencyOption
    var isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(option.code)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 48, alignment: .leading)

            Text(option.name)
                .font(.subheadline)
                .foregroundStyle(AppTheme.ink)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.violet)
            }
        }
        .padding(.vertical, 4)
        .background(isSelected ? AppTheme.violet.opacity(0.08) : Color.clear)
    }
}

private struct CurrencyOption: Identifiable {
    var id: String { code }
    var code: String
    var currency: Locale.Currency

    var name: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: 0)?.replacingOccurrences(of: "0.00", with: "").trimmingCharacters(in: .whitespaces) ?? code
    }
}

#Preview {
    CurrencyRegionSelector(
        baseCurrency: .constant("USD"),
        countryCode: .constant(nil),
        timeZoneIdentifier: .constant(nil)
    )
}
