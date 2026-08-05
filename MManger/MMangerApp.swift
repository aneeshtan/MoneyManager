import SwiftUI
import SwiftData
import UserNotifications

@main
struct MMangerApp: App {
    let container: ModelContainer
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        AppLanguage.applyStoredLanguage()
        let schema = Schema([
            UserProfile.self,
            Account.self,
            FinanceCategory.self,
            FinanceTransaction.self,
            MerchantRule.self,
            TransactionAttachment.self,
            ImportBatch.self,
            Budget.self,
            SavingsGoal.self,
            ScheduledTransaction.self,
            Tag.self,
            DebtPayoffPlan.self,
            ReceiptOCRData.self,
            ReceiptLineItem.self
        ])
        do {
            container = try ModelContainer(for: schema)
            try SeedStore.seedIfNeeded(modelContext: ModelContext(container))
        } catch {
            fatalError("Unable to initialize local finance database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .withAppCurrency()
                .environment(\.locale, AppLanguage.stored.locale)
                .environment(\.calendar, AppLanguage.stored.calendar)
                .environment(\.appCalendar, AppLanguage.stored.calendar)
        }
        .modelContainer(container)
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    case arabic = "ar"
    case hindi = "hi"
    case persian = "fa"
    case german = "de"
    case french = "fr"
    case portuguese = "pt"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: "English"
        case .spanish: "Español"
        case .arabic: "العربية"
        case .hindi: "हिन्दी"
        case .persian: "فارسی"
        case .german: "Deutsch"
        case .french: "Français"
        case .portuguese: "Português"
        }
    }

    static var stored: AppLanguage {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "appLanguage"),
                  let language = AppLanguage(rawValue: raw) else {
                return .english
            }
            return language
        }
        set {
            UserDefaults.standard.setValue(newValue.rawValue, forKey: "appLanguage")
        }
    }

    static func applyStoredLanguage() {
        let language = stored
        UserDefaults.standard.setValue([language.rawValue], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }

    var suggestedCurrency: String {
        switch self {
        case .english: "USD"
        case .spanish: "EUR"
        case .arabic: "AED"
        case .hindi: "INR"
        case .persian: "IRR"
        case .german: "EUR"
        case .french: "EUR"
        case .portuguese: "BRL"
        }
    }

    var locale: Locale {
        switch self {
        case .persian:
            Locale(identifier: "fa_IR@calendar=persian")
        default:
            Locale(identifier: rawValue)
        }
    }

    var calendar: Calendar {
        switch self {
        case .persian:
            Calendar(identifier: .persian)
        default:
            Calendar(identifier: .gregorian)
        }
    }

    var suggestedRegion: String {
        switch self {
        case .english: "US"
        case .spanish: "ES"
        case .arabic: "AE"
        case .hindi: "IN"
        case .persian: "IR"
        case .german: "DE"
        case .french: "FR"
        case .portuguese: "BR"
        }
    }

    var suggestedTimeZone: String {
        switch self {
        case .english: "America/New_York"
        case .spanish: "Europe/Madrid"
        case .arabic: "Asia/Dubai"
        case .hindi: "Asia/Kolkata"
        case .persian: "Asia/Tehran"
        case .german: "Europe/Berlin"
        case .french: "Europe/Paris"
        case .portuguese: "America/Sao_Paulo"
        }
    }

    var isRightToLeft: Bool {
        switch self {
        case .arabic, .persian:
            true
        default:
            false
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationService.requestAuthorizationIfNeeded()
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
