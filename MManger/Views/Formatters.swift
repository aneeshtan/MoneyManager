import Foundation
import SwiftUI
import SwiftData

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
    static func money(_ amount: Decimal, currency: String = "USD") -> String {
        let formatter = CurrencyFormatterCache.shared.formatter(for: currency)
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

    static let day: DateFormatter = dayFormatter
}

// MARK: - App Currency Environment

private struct AppCurrencyKey: EnvironmentKey {
    static let defaultValue = "USD"
}

extension EnvironmentValues {
    var appCurrency: String {
        get { self[AppCurrencyKey.self] }
        set { self[AppCurrencyKey.self] = newValue }
    }
}

enum AppTheme {
    static let canvas = Color(red: 0.978, green: 0.982, blue: 0.988)
    static let ink = Color(red: 0.105, green: 0.115, blue: 0.135)
    static let muted = Color(red: 0.455, green: 0.475, blue: 0.525)
    static let line = Color(red: 0.882, green: 0.894, blue: 0.918)
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
}

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
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

struct GlassSurface<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.94))
                    .shadow(color: AppTheme.violet.opacity(0.045), radius: 14, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.line.opacity(0.68), lineWidth: 1)
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
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            if let subtitle {
                Text(subtitle)
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
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(message)
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
            Text(title)
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
        users.first?.baseCurrency ?? "USD"
    }

    func body(content: Content) -> some View {
        content.environment(\.appCurrency, currency)
    }
}

extension View {
    func withAppCurrency() -> some View {
        modifier(AppCurrencyModifier())
    }
}
