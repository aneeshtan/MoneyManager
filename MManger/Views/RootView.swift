import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("isAuthenticated") private var isAuthenticated = false
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @Query private var transactions: [FinanceTransaction]
    @State private var isPreloading = true

    private var shouldShowIntroExperience: Bool {
        transactions.isEmpty && !didCompleteOnboarding
    }

    var body: some View {
        if !isAuthenticated {
            AuthView()
        } else {
            authenticatedBody
        }
    }

    private var authenticatedBody: some View {
        ZStack {
            TabView {
                DashboardView()
                    .tabItem { Label("Stats", systemImage: "chart.bar") }

                TransactionsView()
                    .tabItem { Label("Transactions", systemImage: "list.bullet.rectangle") }

                GlobalSearchView()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }

                ImportPDFView()
                    .tabItem { Label("Import", systemImage: "doc.badge.plus") }

                AccountsView()
                    .tabItem { Label("Accounts", systemImage: "creditcard") }

                CategoriesView()
                    .tabItem { Label("Categories", systemImage: "tag") }

                ExportView()
                    .tabItem { Label("Backup", systemImage: "square.and.arrow.up") }

                ProfileView()
                    .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            }
            .tint(AppTheme.violet)

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
                    Text("AI Money Manager")
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
                    Text("AI Money Manager")
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
                    .padding(.horizontal, 18)
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
            URLQueryItem(name: "subject", value: "AI Money Manager Feedback"),
            URLQueryItem(name: "body", value: "\n\nApp: AI Money Manager\nVersion: 1.0")
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
