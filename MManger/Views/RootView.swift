import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("isAuthenticated") private var isAuthenticated = false
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    /// Persisted (not plain @State) because completing onboarding with a new
    /// language forces an `exit(0)` restart before the redirect can happen.
    @AppStorage("pendingImportRedirectAfterOnboarding") private var pendingImportRedirect = false
    @State private var hasAnyTransactions = true
    @State private var isPreloading = true
    @State private var selectedSidebarDestination: AppDestination? = .dashboard
    @State private var compactRequestedTab: CompactRootTab?

    private var shouldShowIntroExperience: Bool {
        !hasAnyTransactions && !didCompleteOnboarding
    }

    private var usesSidebarNavigation: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        if !isAuthenticated {
            AuthView()
        } else {
            authenticatedBody
        }
    }

    @State private var showingMore = false
    @State private var onboardingBaseCurrency = AppFormatters.defaultCurrency()
    @State private var onboardingCountryCode: String? = Locale.current.region?.identifier
    @State private var onboardingTimeZoneIdentifier: String? = TimeZone.current.identifier
    @State private var onboardingLanguage = AppLanguage.stored
    @Environment(\.modelContext) private var modelContext

    private var authenticatedBody: some View {
        ZStack {
            if usesSidebarNavigation {
                NavigationSplitView {
                    ProMoneySidebar(selection: $selectedSidebarDestination)
                } detail: {
                    if let selectedSidebarDestination {
                        selectedSidebarDestination.content
                    } else {
                        DashboardView()
                    }
                }
                .tint(AppTheme.violet)
            } else {
                CompactTabRoot(showingMore: $showingMore, requestedTab: $compactRequestedTab)
            }

            if shouldShowIntroExperience && isPreloading {
                PastelPreloader()
                    .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .scale(scale: 1.015))))
            }
        }
        .task {
            if pendingImportRedirect {
                pendingImportRedirect = false
                navigateToImportAfterOnboarding()
            }
            if !didCompleteOnboarding {
                let count = (try? modelContext.fetchCount(FetchDescriptor<FinanceTransaction>())) ?? 0
                hasAnyTransactions = count > 0
            }
            guard shouldShowIntroExperience else {
                isPreloading = false
                return
            }
            isPreloading = true
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.spring(response: 0.72, dampingFraction: 0.86)) {
                isPreloading = false
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { shouldShowIntroExperience && !isPreloading },
            set: { if !$0 { didCompleteOnboarding = true } }
        )) {
            OnboardingView(
                baseCurrency: $onboardingBaseCurrency,
                countryCode: $onboardingCountryCode,
                timeZoneIdentifier: $onboardingTimeZoneIdentifier,
                language: $onboardingLanguage,
                complete: {
                    completeOnboarding()
                }
            )
        }
    }

    private func completeOnboarding() {
        let requiresRestart = onboardingLanguage != AppLanguage.stored
        applyOnboardingCurrencySelection()
        applyOnboardingLanguageSelection()
        didCompleteOnboarding = true

        guard requiresRestart else {
            navigateToImportAfterOnboarding()
            return
        }
        // The language switch needs a fresh process; the redirect survives via
        // `pendingImportRedirect` and is applied on the next launch's `.task`.
        pendingImportRedirect = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exit(0)
        }
    }

    /// Sends a brand-new user straight to Import so they can bring their data in
    /// right after finishing setup, instead of landing on an empty dashboard.
    private func navigateToImportAfterOnboarding() {
        selectedSidebarDestination = .importPDF
        compactRequestedTab = .importPDF
    }

    private func applyOnboardingCurrencySelection() {
        let descriptor = FetchDescriptor<UserProfile>()
        do {
            if let user = try modelContext.fetch(descriptor).first {
                user.applyRegionalDefaults(
                    currency: onboardingBaseCurrency,
                    countryCode: onboardingCountryCode,
                    timeZoneIdentifier: onboardingTimeZoneIdentifier
                )
                try modelContext.save()
            }
        } catch {
            // Silent failure; currency can be changed later in Profile.
        }
    }

    private func applyOnboardingLanguageSelection() {
        AppLanguage.stored = onboardingLanguage
        AppLanguage.applyStoredLanguage()
    }
}

private struct ProMoneySidebar: View {
    @Binding var selection: AppDestination?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [
                        AppTheme.elevatedSurface,
                        Color(red: 0.080, green: 0.088, blue: 0.112),
                        AppTheme.canvas
                    ]
                    : [
                        Color(red: 0.995, green: 0.970, blue: 0.985),
                        Color(red: 0.965, green: 0.955, blue: 0.995),
                        Color(red: 0.950, green: 0.985, blue: 0.980)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                SidebarHeader()

                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("Workspace", comment: ""))
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(AppTheme.ink.opacity(0.58))
                        .padding(.horizontal, 12)

                    VStack(spacing: 6) {
                        ForEach(AppDestination.allCases) { destination in
                            Button {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                                    selection = destination
                                }
                            } label: {
                                SidebarDestinationRow(
                                    title: destination.title,
                                    systemImage: destination.systemImage,
                                    isSelected: selection == destination
                                )
                            }
                            .buttonStyle(PrimaryPressStyle())
                        }
                    }
                }

                Spacer(minLength: 0)

                SidebarFooter()
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 320)
    }
}

private struct SidebarHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.pie.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(
                    LinearGradient(
                        colors: [AppTheme.violet, AppTheme.rose],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .shadow(color: AppTheme.violet.opacity(0.18), radius: 12, x: 0, y: 7)

            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("Pro Money", comment: ""))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                Text(NSLocalizedString("Manager", comment: ""))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.ink.opacity(0.64))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

private struct SidebarDestinationRow: View {
    var title: String
    var systemImage: String
    var isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isSelected ? .white : AppTheme.violet)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(isSelected ? AppTheme.surface.opacity(0.20) : AppTheme.controlSurface)
                )

            Text(NSLocalizedString(title, comment: ""))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isSelected ? .white : AppTheme.ink)

            Spacer(minLength: 0)

            if isSelected {
                Circle()
                    .fill(AppTheme.surface)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? AppTheme.violet : AppTheme.elevatedSurface.opacity(0.82))
                .shadow(color: isSelected ? AppTheme.violet.opacity(0.22) : .clear, radius: 12, x: 0, y: 7)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? AppTheme.surface.opacity(0.30) : AppTheme.line.opacity(0.72), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

private struct SidebarFooter: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.teal)
                .frame(width: 32, height: 32)
                .background(AppTheme.controlSurface, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("Local data", comment: ""))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                Text(NSLocalizedString("Private on device", comment: ""))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.ink.opacity(0.58))
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(AppTheme.elevatedSurface.opacity(0.76), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.line.opacity(0.72), lineWidth: 1)
        )
    }
}

private enum AppDestination: String, CaseIterable, Identifiable {
    case dashboard
    case transactions
    case importPDF
    case calendar
    case search
    case trends
    case accounts
    case categories
    case savingsGoals
    case scheduled
    case backup
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Stats"
        case .transactions: "Transactions"
        case .importPDF: "Import"
        case .calendar: "Calendar"
        case .search: "Search"
        case .trends: "Trends"
        case .accounts: "Accounts"
        case .categories: "Categories"
        case .savingsGoals: "Goals"
        case .scheduled: "Scheduled"
        case .backup: "Backup"
        case .profile: "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "chart.bar"
        case .transactions: "list.bullet.rectangle"
        case .importPDF: "doc.badge.plus"
        case .calendar: "calendar"
        case .search: "magnifyingglass"
        case .trends: "chart.line.uptrend.xyaxis"
        case .accounts: "creditcard"
        case .categories: "tag"
        case .savingsGoals: "target"
        case .scheduled: "clock.arrow.circlepath"
        case .backup: "square.and.arrow.up"
        case .profile: "person.crop.circle"
        }
    }

    @MainActor
    @ViewBuilder var content: some View {
        switch self {
        case .dashboard:
            DashboardView()
        case .transactions:
            TransactionsView()
        case .importPDF:
            ImportPDFView()
        case .calendar:
            CalendarView()
        case .search:
            GlobalSearchView()
        case .trends:
            TrendsView()
        case .accounts:
            AccountsView()
        case .categories:
            CategoriesView()
        case .savingsGoals:
            SavingsGoalsView()
        case .scheduled:
            ScheduledTransactionsView()
        case .backup:
            ExportView()
        case .profile:
            ProfileView()
        }
    }
}

enum CompactRootTab: Hashable {
    case stats
    case transactions
    case importPDF
    case more

    var isContentTab: Bool {
        self != .more
    }
}

struct CompactTabSelectionState: Equatable {
    private(set) var selected: CompactRootTab = .stats
    private var previousContentTab: CompactRootTab = .stats

    mutating func select(_ tab: CompactRootTab) -> Bool {
        selected = tab
        if tab.isContentTab {
            previousContentTab = tab
            return false
        }
        return true
    }

    mutating func dismissMore() {
        guard selected == .more else { return }
        selected = previousContentTab
    }
}

private struct CompactTabRoot: View {
    @Binding var showingMore: Bool
    @Binding var requestedTab: CompactRootTab?
    @State private var tabState = CompactTabSelectionState()

    private var selectedTab: Binding<CompactRootTab> {
        Binding(
            get: { tabState.selected },
            set: { newTab in
                if tabState.select(newTab) {
                    showingMore = true
                }
            }
        )
    }

    var body: some View {
        TabView(selection: selectedTab) {
            DashboardView()
                .tabItem { Label(NSLocalizedString("Stats", comment: ""), systemImage: "chart.bar") }
                .tag(CompactRootTab.stats)

            TransactionsView()
                .tabItem { Label(NSLocalizedString("Transactions", comment: ""), systemImage: "list.bullet.rectangle") }
                .tag(CompactRootTab.transactions)

            ImportPDFView()
                .tabItem { Label(NSLocalizedString("Import", comment: ""), systemImage: "doc.badge.plus") }
                .tag(CompactRootTab.importPDF)

            Color.clear
                .tabItem { Label(NSLocalizedString("More", comment: ""), systemImage: "ellipsis") }
                .tag(CompactRootTab.more)
        }
        .tint(AppTheme.violet)
        .sheet(isPresented: $showingMore, onDismiss: restorePreviousTab) {
            MoreMenuView()
        }
        .onChange(of: requestedTab) { _, newValue in
            guard let newValue else { return }
            _ = tabState.select(newValue)
            requestedTab = nil
        }
    }

    private func restorePreviousTab() {
        tabState.dismissMore()
    }
}

private struct OnboardingView: View {
    @Binding var baseCurrency: String
    @Binding var countryCode: String?
    @Binding var timeZoneIdentifier: String?
    @Binding var language: AppLanguage
    var complete: () -> Void

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                OnboardingHeader()

                VStack(spacing: 12) {
                    LanguagePicker(
                        language: $language,
                        baseCurrency: $baseCurrency,
                        countryCode: $countryCode,
                        timeZoneIdentifier: $timeZoneIdentifier
                    )

                    CurrencyRegionSelector(
                        baseCurrency: $baseCurrency,
                        countryCode: $countryCode,
                        timeZoneIdentifier: $timeZoneIdentifier
                    )
                }

                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        InfoPill(systemImage: "globe", title: "Region", value: countryCode ?? NSLocalizedString("Auto", comment: ""))
                        InfoPill(systemImage: "clock", title: "Timezone", value: timeZoneIdentifier ?? NSLocalizedString("Auto", comment: ""))
                    }

                    Button(action: complete) {
                        Text(NSLocalizedString("Start managing money", comment: ""))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PrimaryPressStyle())
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(AppTheme.canvas)
            }
        }
    }
}

private struct LanguagePicker: View {
    @Binding var language: AppLanguage
    @Binding var baseCurrency: String
    @Binding var countryCode: String?
    @Binding var timeZoneIdentifier: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("Language", comment: ""))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .padding(.horizontal, 24)

            Menu {
                Picker(NSLocalizedString("Language", comment: ""), selection: $language) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "globe")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.violet)
                    Text(language.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.muted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppTheme.controlSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.line.opacity(0.72), lineWidth: 1)
                )
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 8)
        .onChange(of: language) { _, newValue in
            baseCurrency = AppFormatters.defaultCurrency(for: newValue, localeCurrency: nil)
            countryCode = newValue.suggestedRegion
            timeZoneIdentifier = newValue.suggestedTimeZone
        }
    }
}

private struct OnboardingHeader: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.violet, AppTheme.teal],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 96, height: 96)
                .background(AppTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(AppTheme.line.opacity(0.72), lineWidth: 1))

            VStack(spacing: 6) {
                Text(NSLocalizedString("Pro Money Manager", comment: ""))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                    .multilineTextAlignment(.center)
                Text(NSLocalizedString("Choose your language, home currency, region, and timezone.", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 16)
    }
}

private struct InfoPill: View {
    var systemImage: String
    var title: String
    var value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.violet)
            Text(NSLocalizedString(title, comment: ""))
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.muted)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.controlSurface, in: Capsule())
    }
}

private struct OnboardingStep: View {
    var systemImage: String
    var title: String
    var subtitle: String

    var body: some View {
        GlassSurface(padding: 14) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.violet)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.lavender.opacity(0.13), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString(title, comment: ""))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                    Text(NSLocalizedString(subtitle, comment: ""))
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
            }
        }
    }
}

private struct PastelPreloader: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 26) {
                ZStack {
                    PastelOrb(color: AppTheme.mint, size: 96, x: isAnimating ? -42 : -18, y: isAnimating ? -26 : -48, delay: 0)
                    PastelOrb(color: AppTheme.coral, size: 86, x: isAnimating ? 40 : 20, y: isAnimating ? -34 : -12, delay: 0.14)
                    PastelOrb(color: AppTheme.lavender, size: 104, x: isAnimating ? 18 : 42, y: isAnimating ? 42 : 24, delay: 0.28)
                    PastelOrb(color: AppTheme.gold, size: 70, x: isAnimating ? -28 : -44, y: isAnimating ? 40 : 24, delay: 0.42)

                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(AppTheme.elevatedSurface.opacity(0.84))
                        .frame(width: 132, height: 132)
                        .overlay(
                            RoundedRectangle(cornerRadius: 34, style: .continuous)
                                .stroke(AppTheme.line.opacity(0.72), lineWidth: 1)
                        )
                        .shadow(color: AppTheme.violet.opacity(0.16), radius: 30, x: 0, y: 18)

                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.violet, AppTheme.teal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(isAnimating ? 1.04 : 0.94)
                        .animation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true), value: isAnimating)
                }
                .frame(width: 190, height: 190)

                VStack(spacing: 9) {
                    Text(NSLocalizedString("Pro Money Manager", comment: ""))
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                    Text(NSLocalizedString("Preparing your money view", comment: ""))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.muted)
                }

                LoadingDots(isAnimating: isAnimating)
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

private struct PastelOrb: View {
    @State private var floated = false

    var color: Color
    var size: CGFloat
    var x: CGFloat
    var y: CGFloat
    var delay: Double

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(0.82), color.opacity(0.18)],
                    center: .topLeading,
                    startRadius: 8,
                    endRadius: size
                )
            )
            .frame(width: size, height: size)
            .blur(radius: 1.5)
            .offset(x: floated ? x : x * 0.58, y: floated ? y : y * 0.58)
            .scaleEffect(floated ? 1 : 0.92)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.45).delay(delay).repeatForever(autoreverses: true)) {
                    floated = true
                }
            }
    }
}

private struct LoadingDots: View {
    var isAnimating: Bool

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill([AppTheme.mint, AppTheme.coral, AppTheme.lavender][index])
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.0 : 0.58)
                    .opacity(isAnimating ? 1 : 0.45)
                    .animation(
                        .easeInOut(duration: 0.58)
                            .delay(Double(index) * 0.16)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.elevatedSurface.opacity(0.84), in: Capsule())
        .overlay(Capsule().stroke(AppTheme.line.opacity(0.72), lineWidth: 1))
    }
}

struct ProfileView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @AppStorage("isAuthenticated") private var isAuthenticated = false
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @AppStorage("authProvider") private var authProvider = ""
    @AppStorage("authDisplayName") private var authDisplayName = ""
    @AppStorage("authEmail") private var authEmail = ""
    @Query private var users: [UserProfile]
    @Query private var accounts: [Account]
    @Query private var categories: [FinanceCategory]
    @Query private var transactions: [FinanceTransaction]
    @Query private var rules: [MerchantRule]
    @State private var showingDeleteAccountConfirmation = false
    @State private var showingAccountDeletedConfirmation = false
    @State private var deletionError: String?
    @State private var showingCurrencySelector = false
    @State private var showingLanguagePicker = false
    @State private var selectedLanguage = AppLanguage.stored

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        if let user = users.first {
                            GlassSurface {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack(spacing: 14) {
                                        Image(systemName: "person.crop.circle.fill")
                                            .font(.system(size: 42))
                                            .foregroundStyle(AppTheme.violet)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(user.displayName)
                                                .font(.system(.title2, design: .rounded).weight(.bold))
                                                .foregroundStyle(AppTheme.ink)
                                            Text(user.baseCurrency)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(AppTheme.muted)
                                        }
                                    }
                                    ProfileLine(title: "User ID", value: user.id)

                                    Button {
                                        showingCurrencySelector = true
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "globe")
                                                .font(.headline.weight(.bold))
                                                .foregroundStyle(AppTheme.violet)
                                                .frame(width: 32, height: 32)
                                                .background(AppTheme.lavender.opacity(0.14), in: Circle())
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(NSLocalizedString("Currency & Region", comment: ""))
                                                    .font(.subheadline.weight(.bold))
                                                    .foregroundStyle(AppTheme.ink)
                                                Text("\(user.baseCurrency) • \(user.countryCode ?? NSLocalizedString("Auto", comment: "")) • \(user.timeZoneIdentifier ?? NSLocalizedString("Auto", comment: ""))")
                                                    .font(.caption.weight(.medium))
                                                    .foregroundStyle(AppTheme.muted)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(AppTheme.muted.opacity(0.6))
                                        }
                                    }
                                    .buttonStyle(PrimaryPressStyle())
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .sheet(isPresented: $showingCurrencySelector) {
                                NavigationStack {
                                    CurrencyRegionSelector(
                                        baseCurrency: Binding(
                                            get: { user.baseCurrency },
                                            set: { newValue in
                                                user.baseCurrency = newValue.uppercased()
                                                try? modelContext.save()
                                            }
                                        ),
                                        countryCode: Binding(
                                            get: { user.countryCode },
                                            set: { newValue in
                                                user.countryCode = newValue
                                                try? modelContext.save()
                                            }
                                        ),
                                        timeZoneIdentifier: Binding(
                                            get: { user.timeZoneIdentifier },
                                            set: { newValue in
                                                user.timeZoneIdentifier = newValue
                                                try? modelContext.save()
                                            }
                                        )
                                    )
                                    .navigationTitle(NSLocalizedString("Currency & Region", comment: ""))
                                    .navigationBarTitleDisplayMode(.inline)
                                    .toolbar {
                                        ToolbarItem(placement: .confirmationAction) {
                                            Button(NSLocalizedString("Done", comment: "")) { showingCurrencySelector = false }
                                        }
                                    }
                                }
                            }
                        }

                        GlassSurface {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionTitle("Language", subtitle: "Restart required to apply")
                                Button {
                                    showingLanguagePicker = true
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "globe")
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(AppTheme.violet)
                                            .frame(width: 32, height: 32)
                                            .background(AppTheme.lavender.opacity(0.14), in: Circle())
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(NSLocalizedString("App Language", comment: ""))
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(AppTheme.ink)
                                            Text(selectedLanguage.displayName)
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(AppTheme.muted)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(AppTheme.muted.opacity(0.6))
                                    }
                                }
                                .buttonStyle(PrimaryPressStyle())
                            }
                        }
                        .confirmationDialog(NSLocalizedString("Select Language", comment: ""), isPresented: $showingLanguagePicker, titleVisibility: .visible) {
                            ForEach(AppLanguage.allCases) { option in
                                Button(option.displayName) {
                                    selectedLanguage = option
                                    AppLanguage.stored = option
                                    AppLanguage.applyStoredLanguage()
                                    // Restart the app to apply language change
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        exit(0)
                                    }
                                }
                            }
                            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
                        } message: {
                            Text(NSLocalizedString("Changing the language will restart the app.", comment: ""))
                        }

                        GlassSurface {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionTitle("Login", subtitle: "Access to this local workspace")
                                HStack(spacing: 12) {
                                    Image(systemName: authProvider == "Apple" ? "apple.logo" : "person.badge.key.fill")
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 42, height: 42)
                                        .background(AppTheme.ink, in: Circle())
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(authDisplayName.isEmpty ? NSLocalizedString("Signed in", comment: "") : authDisplayName)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(AppTheme.ink)
                                        Text(loginSubtitle)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(AppTheme.muted)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }

                                Button(role: .destructive) {
                                    signOut()
                                } label: {
                                    HStack {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                        Text(NSLocalizedString("Sign out", comment: ""))
                                    }
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(AppTheme.coral.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(PrimaryPressStyle())
                            }
                        }

                        GlassSurface {
                            VStack(spacing: 14) {
                                SectionTitle("Allocated Data", subtitle: "Local records assigned to this user")
                                ProfileLine(title: "Accounts", value: "\(accounts.count)")
                                ProfileLine(title: "Categories", value: "\(categories.count)")
                                ProfileLine(title: "Transactions", value: "\(transactions.count)")
                                ProfileLine(title: "Merchant Rules", value: "\(rules.count)")
                            }
                        }

                        NotificationSettingsSection()

                        if authProvider == "Apple" {
                            NavigationLink {
                                iCloudSyncSettingsView()
                            } label: {
                                GlassSurface {
                                    HStack(spacing: 12) {
                                        Image(systemName: "icloud")
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 42, height: 42)
                                            .background(AppTheme.violet, in: Circle())
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(NSLocalizedString("iCloud Sync", comment: ""))
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(AppTheme.ink)
                                            Text(NSLocalizedString("Sync data with your private iCloud account", comment: ""))
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
                            .buttonStyle(.plain)
                        }

                        GlassSurface {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionTitle("Account Deletion", subtitle: "Permanently remove this local account and its data")
                                Text(NSLocalizedString("This deletes your profile, accounts, transactions, categories, budgets, rules, imports, and attachments from this device. This action cannot be undone.", comment: ""))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.muted)
                                    .fixedSize(horizontal: false, vertical: true)

                                Button(role: .destructive) {
                                    showingDeleteAccountConfirmation = true
                                } label: {
                                    HStack {
                                        Image(systemName: "trash")
                                        Text(NSLocalizedString("Delete account and local data", comment: ""))
                                    }
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(AppTheme.coral.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(PrimaryPressStyle())
                            }
                        }

                        GlassSurface {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionTitle("Privacy & Safety", subtitle: "Private by design")
                                PrivacyPoint(systemImage: "wifi.slash", title: "No data collection", detail: "The app does not send your transactions, accounts, files, or budgets to any server.")
                                PrivacyPoint(systemImage: "iphone", title: "Local storage", detail: "Your finance data is stored on this device unless you export a backup yourself.")
                                PrivacyPoint(systemImage: "eye.slash", title: "No ads or tracking", detail: "There are no analytics SDKs, advertising SDKs, or third-party trackers.")
                                PrivacyPoint(systemImage: "square.and.arrow.up", title: "User-controlled export", detail: "CSV and JSON backups are created only when you choose to export them.")
                            }
                        }

                        GlassSurface {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionTitle("Feedback", subtitle: "Send ideas, issues, or App Store support requests")
                                Button {
                                    openFeedbackEmail()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "envelope.fill")
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 42, height: 42)
                                            .background(AppTheme.violet, in: Circle())
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(NSLocalizedString("Email support", comment: ""))
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(AppTheme.ink)
                                            Text(AppConfig.supportEmail)
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(AppTheme.muted)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(AppTheme.muted)
                                    }
                                }
                                .buttonStyle(PrimaryPressStyle())
                            }
                        }
                    }
                    .adaptiveScreenContent(maxWidth: 760)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(NSLocalizedString("Profile", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .alert(NSLocalizedString("Delete Account?", comment: ""), isPresented: $showingDeleteAccountConfirmation) {
                Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("Delete Account", comment: ""), role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text(NSLocalizedString("This permanently deletes your local account and all finance data stored by Pro Money Manager on this device.", comment: ""))
            }
            .alert(NSLocalizedString("Account Deleted", comment: ""), isPresented: $showingAccountDeletedConfirmation) {
                Button(NSLocalizedString("OK", comment: "")) {
                    finishAccountDeletion()
                }
            } message: {
                Text(NSLocalizedString("Your local account and finance data have been deleted from this device.", comment: ""))
            }
            .alert(NSLocalizedString("Account deletion failed", comment: ""), isPresented: Binding(
                get: { deletionError != nil },
                set: { if !$0 { deletionError = nil } }
            )) {
                Button(NSLocalizedString("OK", comment: ""), role: .cancel) { deletionError = nil }
            } message: {
                Text(deletionError ?? "")
            }
        }
    }

    private var loginSubtitle: String {
        if !authEmail.isEmpty {
            return authEmail
        }
        if !authProvider.isEmpty {
            return String(format: NSLocalizedString("Signed in with %@", comment: ""), authProvider)
        }
        return NSLocalizedString("Signed in on this device", comment: "")
    }

    private func signOut() {
        isAuthenticated = false
        authProvider = ""
        authDisplayName = ""
        authEmail = ""
    }

    private func deleteAccount() {
        do {
            try AccountDeletionService.deleteLocalWorkspaceData(in: modelContext)
            showingAccountDeletedConfirmation = true
        } catch {
            deletionError = String(format: NSLocalizedString("Unable to delete your local account. %@", comment: ""), error.localizedDescription)
        }
    }

    private func finishAccountDeletion() {
        didCompleteOnboarding = false
        signOut()
    }

    private func openFeedbackEmail() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppConfig.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Pro Money Manager Feedback"),
            URLQueryItem(name: "body", value: "\n\nApp: Pro Money Manager\nVersion: 1.0")
        ]
        if let url = components.url {
            openURL(url)
        }
    }
}

private struct PrivacyPoint: View {
    var systemImage: String
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.violet)
                .frame(width: 32, height: 32)
                .background(AppTheme.lavender.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(NSLocalizedString(title, comment: ""))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                Text(NSLocalizedString(detail, comment: ""))
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct ProfileLine: View {
    var title: String
    var value: String

    var body: some View {
        HStack {
            Text(NSLocalizedString(title, comment: ""))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.muted)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
    }
}

private struct NotificationSettingsSection: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingDeniedAlert = false

    var body: some View {
        GlassSurface {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle("Notifications", subtitle: "Get reminded about upcoming bills")

                HStack(spacing: 12) {
                    Image(systemName: statusIcon)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(statusColor)
                        .frame(width: 42, height: 42)
                        .background(statusColor.opacity(0.13), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("Bill reminders", comment: ""))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                        Text(statusDescription)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Toggle("", isOn: $notificationsEnabled)
                        .labelsHidden()
                        .tint(AppTheme.violet)
                        .onChange(of: notificationsEnabled) { _, newValue in
                            handleToggleChange(newValue)
                        }
                }
            }
        }
        .task {
            await refreshAuthorizationStatus()
        }
        .alert(NSLocalizedString("Notifications Disabled", comment: ""), isPresented: $showingDeniedAlert) {
            Button(NSLocalizedString("Open Settings", comment: "")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("Please enable notifications in Settings to receive bill reminders.", comment: ""))
        }
    }

    private var statusIcon: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "bell.badge.fill"
        case .denied:
            return "bell.slash.fill"
        default:
            return "bell.fill"
        }
    }

    private var statusColor: Color {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return AppTheme.violet
        case .denied:
            return AppTheme.coral
        default:
            return AppTheme.muted
        }
    }

    private var statusDescription: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return NSLocalizedString("You will receive a reminder the day before each scheduled bill.", comment: "")
        case .denied:
            return NSLocalizedString("Notifications are disabled in Settings.", comment: "")
        default:
            return NSLocalizedString("Enable to be reminded before bills are due.", comment: "")
        }
    }

    private func handleToggleChange(_ newValue: Bool) {
        if newValue {
            Task {
                let granted = await NotificationService.requestPermission()
                await MainActor.run {
                    if !granted {
                        showingDeniedAlert = true
                    }
                    Task { await refreshAuthorizationStatus() }
                }
            }
        } else {
            NotificationService.cancelAllNotifications()
            Task { await refreshAuthorizationStatus() }
        }
    }

    private func refreshAuthorizationStatus() async {
        let status = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            authorizationStatus = status.authorizationStatus
            if status.authorizationStatus == .denied {
                notificationsEnabled = false
            }
        }
    }
}

// MARK: - More Menu

private struct MoreMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("authProvider") private var authProvider = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 12) {
                        MoreMenuRow(title: "Calendar", subtitle: "Transactions on a monthly calendar", systemImage: "calendar", tint: AppTheme.violet) {
                            CalendarView()
                        }
                        MoreMenuRow(title: "Search", subtitle: "Find any transaction", systemImage: "magnifyingglass", tint: AppTheme.violet) {
                            GlobalSearchView()
                        }
                        MoreMenuRow(title: "Trends", subtitle: "Spending charts over time", systemImage: "chart.line.uptrend.xyaxis", tint: AppTheme.teal) {
                            TrendsView()
                        }
                        MoreMenuRow(title: "Accounts", subtitle: "Balances and account details", systemImage: "creditcard", tint: AppTheme.mint) {
                            AccountsView()
                        }
                        MoreMenuRow(title: "Categories", subtitle: "Rules and spending groups", systemImage: "tag", tint: AppTheme.gold) {
                            CategoriesView()
                        }
                        MoreMenuRow(title: "Savings Goals", subtitle: "Track progress toward targets", systemImage: "target", tint: AppTheme.mint) {
                            SavingsGoalsView()
                        }
                        MoreMenuRow(title: "Scheduled", subtitle: "Recurring transactions and bills", systemImage: "clock.arrow.circlepath", tint: AppTheme.gold) {
                            ScheduledTransactionsView()
                        }
                        MoreMenuRow(title: "Subscriptions", subtitle: "Track recurring charges", systemImage: "creditcard.and.123", tint: AppTheme.coral) {
                            SubscriptionsView()
                        }
                        MoreMenuRow(title: "Debt Payoff", subtitle: "Plan to eliminate debt", systemImage: "chart.line.downtrend.xyaxis", tint: AppTheme.teal) {
                            DebtPayoffView()
                        }
                        MoreMenuRow(title: "Tags", subtitle: "Label transactions", systemImage: "tag", tint: AppTheme.lavender) {
                            TagsView()
                        }
                        MoreMenuRow(title: "App Lock", subtitle: "Secure with Face ID or passcode", systemImage: "lock.shield", tint: AppTheme.gold) {
                            AppLockSettingsView()
                        }
                        if authProvider == "Apple" {
                            MoreMenuRow(title: "iCloud Sync", subtitle: "Sync data with your private iCloud account", systemImage: "icloud", tint: AppTheme.violet) {
                                iCloudSyncSettingsView()
                            }
                        }
                        MoreMenuRow(title: "Backup", subtitle: "Export and restore data", systemImage: "square.and.arrow.up", tint: AppTheme.coral) {
                            ExportView()
                        }
                        MoreMenuRow(title: "Profile", subtitle: "Settings and privacy", systemImage: "person.crop.circle", tint: AppTheme.lavender) {
                            ProfileView()
                        }
                    }
                    .adaptiveScreenContent(maxWidth: 760)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(NSLocalizedString("More", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Done", comment: "")) { dismiss() }
                }
            }
        }
    }
}

private struct MoreMenuRow<Destination: View>: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var tint: Color
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination()) {
            GlassSurface {
                HStack(spacing: 14) {
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(width: 44, height: 44)
                        .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(NSLocalizedString(title, comment: ""))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                        Text(NSLocalizedString(subtitle, comment: ""))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.muted.opacity(0.6))
                }
            }
        }
        .buttonStyle(PrimaryPressStyle())
    }
}
