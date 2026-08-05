import Foundation
import SwiftUI
import SwiftData
import UIKit

// MARK: - Number Caching
private final class CurrencyFormatterCache: @unchecked Sendable {
    static let shared = CurrencyFormatterCache()
    private var cache: [String: NumberFormatter] = [:]
    private let lock = NSLock()

    func formatter(for currencyCode: String) -> NumberFormatter {
        lock.lock()
        defer { lock.unlock() }
        if let existing = cache[currencyCode] {
            return existing
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        cache[currencyCode] = formatter
        return formatter
    }
}

private let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()

enum AppFormatters {
    static func defaultCurrency(
        for language: AppLanguage = AppLanguage.stored,
        localeCurrency: String? = Locale.current.currency?.identifier
    ) -> String {
        if language == .persian {
            return "IRR"
        }
        return (localeCurrency?.isEmpty == false ? localeCurrency : nil) ?? language.suggestedCurrency
    }

    static func money(_ amount: Decimal, currency: String = "USD") -> String {
        let effectiveCurrency = currency.uppercased()
        if effectiveCurrency == "IRR" {
            let toman = (amount as NSDecimalNumber).dividing(by: 10)
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            formatter.groupingSeparator = Locale.current.groupingSeparator
            let numberString = formatter.string(from: toman) ?? "\(toman)"
            return "\(numberString) تومان"
        }
        let formatter = CurrencyFormatterCache.shared.formatter(for: effectiveCurrency)
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }

    static func statMoney(_ amount: Decimal, currency: String = "USD") -> String {
        money(amount, currency: currency)
    }

    static func resolvedCurrency(_ currency: String?, fallback: String = "USD") -> String {
        let trimmed = (currency ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed.isEmpty ? fallback : trimmed
    }

    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    static func dayString(from date: Date, language: AppLanguage = AppLanguage.stored) -> String {
        if language == .persian {
            return JalaliDateFormatter.shared.string(from: date)
        }
        dayFormatter.calendar = language.calendar
        return dayFormatter.string(from: date)
    }
}

enum CurrencyReporting {
    static func dominantCurrency<T>(
        in values: [T],
        fallback: String,
        currency: (T) -> String,
        amount: (T) -> Decimal
    ) -> String {
        let grouped = Dictionary(grouping: values) {
            AppFormatters.resolvedCurrency(currency($0), fallback: fallback)
        }
        return grouped
            .map { code, rows in
                let total = rows.reduce(Decimal(0)) { $0 + abs(amount($1)) }
                return (code: code, total: total, count: rows.count)
            }
            .sorted {
                if $0.total == $1.total { return $0.count > $1.count }
                return $0.total > $1.total
            }
            .first?.code ?? fallback
    }
}

// MARK: - Jalali Date Conversion

private final class JalaliDateFormatter: @unchecked Sendable {
    static let shared = JalaliDateFormatter()

    private let persianCalendar = Calendar(identifier: .persian)
    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .persian)
        formatter.locale = Locale(identifier: "fa_IR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}

// MARK: - App Currency Environment

private struct AppCurrencyKey: EnvironmentKey {
    static let defaultValue = AppFormatters.defaultCurrency()
}

extension EnvironmentValues {
    var appCurrency: String {
        get { self[AppCurrencyKey.self] }
        set { self[AppCurrencyKey.self] = newValue }
    }
}

// MARK: - App Calendar Environment

private struct AppCalendarKey: EnvironmentKey {
    static let defaultValue = AppLanguage.stored.calendar
}

extension EnvironmentValues {
    var appCalendar: Calendar {
        get { self[AppCalendarKey.self] }
        set { self[AppCalendarKey.self] = newValue }
    }
}

struct AppThemePalette {
    var canvas: UIColor
    var ink: UIColor
    var muted: UIColor
    var line: UIColor
    var surface: UIColor
    var elevatedSurface: UIColor
    var controlSurface: UIColor
}

enum AppTheme {
    static var canvas: Color { adaptiveColor(\.canvas) }
    static var ink: Color { adaptiveColor(\.ink) }
    static var muted: Color { adaptiveColor(\.muted) }
    static var line: Color { adaptiveColor(\.line) }
    static var surface: Color { adaptiveColor(\.surface) }
    static var elevatedSurface: Color { adaptiveColor(\.elevatedSurface) }
    static var controlSurface: Color { adaptiveColor(\.controlSurface) }

    static let mint = Color(red: 0.165, green: 0.735, blue: 0.625)
    static let teal = Color(red: 0.045, green: 0.600, blue: 0.555)
    static let coral = Color(red: 0.965, green: 0.410, blue: 0.485)
    static let rose = Color(red: 0.900, green: 0.320, blue: 0.520)
    static let lavender = Color(red: 0.650, green: 0.485, blue: 0.930)
    static let violet = Color(red: 0.475, green: 0.335, blue: 0.815)
    static let gold = Color(red: 0.905, green: 0.675, blue: 0.315)

    static let categoryPalette: [Color] = [
        coral, gold, mint, lavender, teal,
        Color(red: 0.365, green: 0.655, blue: 0.955),
        Color(red: 0.955, green: 0.615, blue: 0.380),
        violet
    ]

    static func palette(for style: UIUserInterfaceStyle) -> AppThemePalette {
        if style == .dark {
            return AppThemePalette(
                canvas: UIColor(red: 0.055, green: 0.060, blue: 0.075, alpha: 1),
                ink: UIColor(red: 0.890, green: 0.910, blue: 0.945, alpha: 1),
                muted: UIColor(red: 0.610, green: 0.640, blue: 0.700, alpha: 1),
                line: UIColor(red: 0.205, green: 0.225, blue: 0.270, alpha: 1),
                surface: UIColor(red: 0.105, green: 0.112, blue: 0.135, alpha: 1),
                elevatedSurface: UIColor(red: 0.130, green: 0.140, blue: 0.170, alpha: 1),
                controlSurface: UIColor(red: 0.165, green: 0.175, blue: 0.215, alpha: 1)
            )
        }

        return AppThemePalette(
            canvas: UIColor(red: 0.978, green: 0.982, blue: 0.988, alpha: 1),
            ink: UIColor(red: 0.105, green: 0.115, blue: 0.135, alpha: 1),
            muted: UIColor(red: 0.455, green: 0.475, blue: 0.525, alpha: 1),
            line: UIColor(red: 0.882, green: 0.894, blue: 0.918, alpha: 1),
            surface: UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1),
            elevatedSurface: UIColor(red: 0.990, green: 0.992, blue: 0.997, alpha: 1),
            controlSurface: UIColor(red: 0.955, green: 0.960, blue: 0.975, alpha: 1)
        )
    }

    private static func adaptiveColor(_ keyPath: KeyPath<AppThemePalette, UIColor>) -> Color {
        Color(uiColor: UIColor { traitCollection in
            palette(for: traitCollection.userInterfaceStyle)[keyPath: keyPath]
        })
    }
}

struct AppFormColors {
    var background: UIColor
    var row: UIColor
    var header: UIColor
    var separator: UIColor
}

enum AppFormPalette {
    static func colors(for style: UIUserInterfaceStyle) -> AppFormColors {
        if style == .dark {
            return AppFormColors(
                background: UIColor(red: 0.035, green: 0.040, blue: 0.052, alpha: 1),
                row: UIColor(red: 0.068, green: 0.075, blue: 0.095, alpha: 1),
                header: UIColor(red: 0.610, green: 0.640, blue: 0.700, alpha: 1),
                separator: UIColor(red: 0.205, green: 0.225, blue: 0.270, alpha: 1)
            )
        }

        return AppFormColors(
            background: UIColor(red: 0.978, green: 0.982, blue: 0.988, alpha: 1),
            row: UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1),
            header: UIColor(red: 0.455, green: 0.475, blue: 0.525, alpha: 1),
            separator: UIColor(red: 0.882, green: 0.894, blue: 0.918, alpha: 1)
        )
    }
}

enum AppHeroPalette {
    static func backgroundColors(for style: UIUserInterfaceStyle) -> [UIColor] {
        if style == .dark {
            return [
                UIColor(red: 0.155, green: 0.170, blue: 0.210, alpha: 1),
                UIColor(red: 0.100, green: 0.105, blue: 0.150, alpha: 1),
                UIColor(red: 0.065, green: 0.145, blue: 0.145, alpha: 1)
            ]
        }

        return [
            UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 0.88),
            UIColor(red: 0.650, green: 0.485, blue: 0.930, alpha: 0.13),
            UIColor(red: 0.165, green: 0.735, blue: 0.625, alpha: 0.12)
        ]
    }
}

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    AppTheme.elevatedSurface,
                    Color(red: 0.075, green: 0.085, blue: 0.100),
                    AppTheme.canvas
                ]
                : [
                    Color(red: 0.992, green: 0.955, blue: 0.970),
                    Color(red: 0.955, green: 0.985, blue: 0.975),
                    AppTheme.canvas
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct AppFormStyleModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let style: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        let colors = AppFormPalette.colors(for: style)

        content
            .scrollContentBackground(.hidden)
            .listRowBackground(Color(uiColor: colors.row))
            .listSectionSeparatorTint(Color(uiColor: colors.separator))
            .background(Color(uiColor: colors.background).ignoresSafeArea())
            .foregroundStyle(AppTheme.ink)
            .tint(AppTheme.violet)
            .toolbarBackground(Color(uiColor: colors.background), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

private struct AppListStyleModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let style: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        let colors = AppFormPalette.colors(for: style)

        content
            .scrollContentBackground(.hidden)
            .listRowBackground(Color(uiColor: colors.row))
            .listSectionSeparatorTint(Color(uiColor: colors.separator))
            .background(Color(uiColor: colors.background).ignoresSafeArea())
            .foregroundStyle(AppTheme.ink)
            .tint(AppTheme.violet)
            .toolbarBackground(Color(uiColor: colors.background), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

private struct AppHeroBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let style: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        let colors = AppHeroPalette.backgroundColors(for: style).map(Color.init(uiColor:))

        content.background(
            LinearGradient(
                colors: colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }
}

private struct AdaptiveScreenContentModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var maxWidth: CGFloat
    var compactHorizontalPadding: CGFloat
    var regularHorizontalPadding: CGFloat

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: isRegularWidth ? maxWidth : .infinity, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.horizontal, isRegularWidth ? regularHorizontalPadding : compactHorizontalPadding)
    }
}

struct GlassSurface<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(colorScheme == .dark ? AppTheme.elevatedSurface : AppTheme.surface.opacity(0.94))
                    .shadow(color: colorScheme == .dark ? Color(red: 0.020, green: 0.024, blue: 0.032).opacity(0.28) : AppTheme.violet.opacity(0.045), radius: 14, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(colorScheme == .dark ? AppTheme.line.opacity(0.92) : AppTheme.line.opacity(0.68), lineWidth: 1)
            )
    }
}

struct PrimaryPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

struct SectionTitle: View {
    var title: String
    var subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(NSLocalizedString(title, comment: ""))
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            if let subtitle {
                Text(NSLocalizedString(subtitle, comment: ""))
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyStateView: View {
    var systemImage: String
    var title: String
    var message: String

    var body: some View {
        GlassSurface(padding: 24) {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(AppTheme.violet)
                    .frame(width: 68, height: 68)
                    .background(AppTheme.lavender.opacity(0.14), in: Circle())
                Text(NSLocalizedString(title, comment: ""))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(NSLocalizedString(message, comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct MetricCapsule: View {
    var title: String
    var value: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString(title, comment: ""))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - App Currency Injector

private struct AppCurrencyModifier: ViewModifier {
    @Query private var users: [UserProfile]

    private var currency: String {
        users.first?.baseCurrency ?? AppFormatters.defaultCurrency()
    }

    func body(content: Content) -> some View {
        content.environment(\.appCurrency, currency)
    }
}

// MARK: - Reusable Labeled Field

struct LabeledTextField: View {
    var label: String
    @Binding var text: String
    var prompt: String?
    var keyboard: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var autocorrection: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString(label, comment: ""))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
            TextField(prompt.map { NSLocalizedString($0, comment: "") } ?? "", text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(!autocorrection)
        }
    }
}

struct LabeledNumberField: View {
    var label: String
    @Binding var text: String
    var prompt: String?

    var body: some View {
        LabeledTextField(label: label, text: $text, prompt: prompt, keyboard: .decimalPad)
    }
}

struct LabeledCurrencyButton: View {
    var label: String = "Currency"
    @Binding var currency: String
    @State private var showingPicker = false

    var body: some View {
        Button {
            showingPicker = true
        } label: {
            HStack {
                Text(NSLocalizedString(label, comment: ""))
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text(currency)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppTheme.violet)
            }
        }
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                CurrencyRegionSelector(
                    baseCurrency: $currency,
                    countryCode: .constant(nil),
                    timeZoneIdentifier: .constant(nil)
                )
                .navigationTitle(NSLocalizedString("Select Currency", comment: ""))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(NSLocalizedString("Done", comment: "")) { showingPicker = false }
                    }
                }
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        var totalWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width + spacing > proposal.width ?? .infinity {
                totalWidth = max(totalWidth, rowWidth)
                totalHeight += rowHeight + spacing
                rowWidth = size.width + spacing
                rowHeight = size.height
            } else {
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalWidth = max(totalWidth, rowWidth)
        totalHeight += rowHeight
        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension View {
    func withAppCurrency() -> some View {
        modifier(AppCurrencyModifier())
    }

    func appHeroBackground() -> some View {
        modifier(AppHeroBackgroundModifier())
    }

    func appFormStyle() -> some View {
        modifier(AppFormStyleModifier())
    }

    func appListStyle() -> some View {
        modifier(AppListStyleModifier())
    }

    func adaptiveScreenContent(
        maxWidth: CGFloat = 1040,
        compactHorizontalPadding: CGFloat = 18,
        regularHorizontalPadding: CGFloat = 28
    ) -> some View {
        modifier(
            AdaptiveScreenContentModifier(
                maxWidth: maxWidth,
                compactHorizontalPadding: compactHorizontalPadding,
                regularHorizontalPadding: regularHorizontalPadding
            )
        )
    }
}
