import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("isAuthenticated") private var isAuthenticated = false
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @Query private var transactions: [FinanceTransaction]
    @State private var isPreloading = true
    @State private var selectedSidebarDestination: AppDestination? = .dashboard

    private var shouldShowIntroExperience: Bool {
        transactions.isEmpty && !didCompleteOnboarding
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
                CompactTabRoot(showingMore: $showingMore)
            }

            if shouldShowIntroExperience && isPreloading {
                PastelPreloader()
                    .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .scale(scale: 1.015))))
            }
        }
        .task {
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
            OnboardingView {
                didCompleteOnboarding = true
            }
        }
    }
}

private struct ProMoneySidebar: View {
    @Binding var selection: AppDestination?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
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
                    Text("Workspace")
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
                Text("Pro Money")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                Text("Manager")
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
                        .fill(isSelected ? .white.opacity(0.18) : .white.opacity(0.76))
                )

            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isSelected ? .white : AppTheme.ink)

            Spacer(minLength: 0)

            if isSelected {
                Circle()
                    .fill(.white)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? AppTheme.violet : .white.opacity(0.62))
                .shadow(color: isSelected ? AppTheme.violet.opacity(0.22) : .clear, radius: 12, x: 0, y: 7)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? .white.opacity(0.28) : AppTheme.line.opacity(0.58), lineWidth: 1)
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
                .background(.white.opacity(0.78), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Local data")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                Text("Private on device")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.ink.opacity(0.58))
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.72), lineWidth: 1)
        )
    }
}

private enum AppDestination: String, CaseIterable, Identifiable {
    case dashboard
    case transactions
    case importPDF
    case search
    case trends
    case accounts
    case categories
    case backup
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Stats"
        case .transactions: "Transactions"
        case .importPDF: "Import"
        case .search: "Search"
        case .trends: "Trends"
        case .accounts: "Accounts"
        case .categories: "Categories"
        case .backup: "Backup"
        case .profile: "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "chart.bar"
        case .transactions: "list.bullet.rectangle"
        case .importPDF: "doc.badge.plus"
        case .search: "magnifyingglass"
        case .trends: "chart.line.uptrend.xyaxis"
        case .accounts: "creditcard"
        case .categories: "tag"
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
        case .search:
            GlobalSearchView()
        case .trends:
            TrendsView()
        case .accounts:
            AccountsView()
        case .categories:
            CategoriesView()
        case .backup:
            ExportView()
        case .profile:
            ProfileView()
        }
    }
}

private struct CompactTabRoot: View {
    @Binding var showingMore: Bool

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }

            TransactionsView()
                .tabItem { Label("Transactions", systemImage: "list.bullet.rectangle") }

            ImportPDFView()
                .tabItem { Label("Import", systemImage: "doc.badge.plus") }

            Color.clear
                .tabItem { Label("More", systemImage: "ellipsis") }
                .onAppear { showingMore = true }
        }
        .tint(AppTheme.violet)
        .sheet(isPresented: $showingMore) {
            MoreMenuView()
        }
    }
}

private struct OnboardingView: View {
    var complete: () -> Void

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 22) {
                Spacer()

                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.violet, AppTheme.teal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 110, height: 110)
                    .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(.white.opacity(0.9), lineWidth: 1))

                VStack(spacing: 8) {
                    Text("Pro Money Manager")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                        .multilineTextAlignment(.center)
                    Text("Private, local-first money tracking with smart imports, budgets, recurring bills, and AI-style insights.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    OnboardingStep(systemImage: "creditcard", title: "Review accounts", subtitle: "Seeded accounts and balances are ready to edit.")
                    OnboardingStep(systemImage: "tray.and.arrow.down", title: "Import transactions", subtitle: "Use PDF, CSV, or pasted bank messages.")
                    OnboardingStep(systemImage: "target", title: "Plan budgets", subtitle: "Set monthly limits and track safe-to-spend.")
                    OnboardingStep(systemImage: "lock.shield", title: "Keep control", subtitle: "Data stays local unless you export or restore a backup.")
                }

                Spacer()

                Button(action: complete) {
                    Text("Start managing money")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(PrimaryPressStyle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .adaptiveScreenContent(maxWidth: 560, compactHorizontalPadding: 0, regularHorizontalPadding: 32)
        }
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
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                    Text(subtitle)
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
                        .fill(.white.opacity(0.42))
                        .frame(width: 132, height: 132)
                        .overlay(
                            RoundedRectangle(cornerRadius: 34, style: .continuous)
                                .stroke(.white.opacity(0.72), lineWidth: 1)
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
                    Text("Pro Money Manager")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                    Text("Preparing your money view")
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
        .background(.white.opacity(0.54), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.72), lineWidth: 1))
    }
}

struct ProfileView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage("isAuthenticated") private var isAuthenticated = false
    @AppStorage("authProvider") private var authProvider = ""
    @AppStorage("authDisplayName") private var authDisplayName = ""
    @AppStorage("authEmail") private var authEmail = ""
    @Query private var users: [UserProfile]
    @Query private var accounts: [Account]
    @Query private var categories: [FinanceCategory]
    @Query private var transactions: [FinanceTransaction]
    @Query private var rules: [MerchantRule]

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
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
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
                                        Text(authDisplayName.isEmpty ? "Signed in" : authDisplayName)
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
                                        Text("Sign out")
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
                                            Text("Email support")
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(AppTheme.ink)
                                            Text("aneeshtan@gmail.com")
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
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var loginSubtitle: String {
        if !authEmail.isEmpty {
            return authEmail
        }
        if !authProvider.isEmpty {
            return "Signed in with \(authProvider)"
        }
        return "Signed in on this device"
    }

    private func signOut() {
        isAuthenticated = false
        authProvider = ""
        authDisplayName = ""
        authEmail = ""
    }

    private func openFeedbackEmail() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "aneeshtan@gmail.com"
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
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                Text(detail)
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
            Text(title)
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

// MARK: - More Menu

private struct MoreMenuView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 12) {
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
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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
                        Text(title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                        Text(subtitle)
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
