import SwiftUI

struct AppLockSettingsView: View {
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @State private var isAuthenticating = false
    @State private var authResult: String?

    private var biometricName: String {
        AppLockService.biometricType()
    }

    private var isAvailable: Bool {
        AppLockService.isBiometricAvailable()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        heroCard

                        GlassSurface {
                            VStack(spacing: 14) {
                                HStack(spacing: 12) {
                                    Image(systemName: isAvailable ? "lock.shield.fill" : "lock.slash.fill")
                                        .font(.title2.weight(.semibold))
                                        .foregroundStyle(isAvailable ? AppTheme.violet : AppTheme.muted)
                                        .frame(width: 50, height: 50)
                                        .background(AppTheme.lavender.opacity(0.14), in: Circle())

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(isAvailable ? "Biometrics available" : "Biometrics unavailable")
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(AppTheme.ink)
                                        Text(isAvailable ? biometricName : "Set up Face ID, Touch ID, or a passcode in Settings to use app lock.")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.muted)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                }

                                Toggle("Lock app on launch", isOn: $appLockEnabled)
                                    .disabled(!isAvailable)
                                    .onChange(of: appLockEnabled) { _, newValue in
                                        if newValue {
                                            Task {
                                                let success = await AppLockService.authenticate()
                                                await MainActor.run {
                                                    if !success {
                                                        appLockEnabled = false
                                                        authResult = "Authentication failed. App lock was not enabled."
                                                    } else {
                                                        authResult = nil
                                                    }
                                                    isAuthenticating = false
                                                }
                                            }
                                        }
                                    }
                            }
                        }

                        if let authResult {
                            GlassSurface {
                                HStack(spacing: 10) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(AppTheme.coral)
                                    Text(authResult)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.coral)
                                    Spacer()
                                }
                            }
                        }

                        EmptyStateView(
                            systemImage: "lock.shield",
                            title: "How it works",
                            message: "When enabled, Pro Money Manager will require your biometrics each time you open the app. Your data stays local and secure."
                        )
                    }
                    .adaptiveScreenContent()
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(NSLocalizedString("App Lock", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var heroCard: some View {
        GlassSurface(padding: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("Security", comment: ""))
                            .font(.caption.weight(.semibold))
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.violet)
                        Text(NSLocalizedString("App Lock", comment: ""))
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                    }
                    Spacer()
                    Image(systemName: "lock.shield")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.violet)
                        .frame(width: 50, height: 50)
                        .background(AppTheme.lavender.opacity(0.14), in: Circle())
                }
            }
            .padding(20)
            .appHeroBackground()
        }
    }
}
