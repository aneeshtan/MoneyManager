import AuthenticationServices
import SwiftData
import SwiftUI

struct AuthView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("isAuthenticated") private var isAuthenticated = false
    @AppStorage("authProvider") private var authProvider = ""
    @AppStorage("authDisplayName") private var authDisplayName = ""
    @AppStorage("authEmail") private var authEmail = ""
    @State private var authError: String?

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.violet, AppTheme.teal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 104, height: 104)
                        .background(AppTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(AppTheme.line.opacity(0.72), lineWidth: 1))

                    VStack(spacing: 8) {
                        Text(NSLocalizedString("Pro Money Manager", comment: ""))
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                            .multilineTextAlignment(.center)
                        Text(NSLocalizedString("Private finance tracking, stored on this device.", comment: ""))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                            .multilineTextAlignment(.center)
                    }
                }

                GlassSurface {
                    VStack(spacing: 14) {
                        Button {
                            completeSignIn(displayName: "Local User", email: "", provider: "Local")
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "iphone.and.arrow.forward")
                                    .font(.title3.weight(.semibold))
                                Text(NSLocalizedString("Continue on this device", comment: ""))
                                    .font(.headline.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(PrimaryPressStyle())

                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        Text(NSLocalizedString("Your data stays on this device. Apple sign-in is optional and only unlocks this local workspace.", comment: ""))
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .adaptiveScreenContent(maxWidth: 520, compactHorizontalPadding: 0, regularHorizontalPadding: 32)
        }
        .alert("Sign in failed", isPresented: Binding(
            get: { authError != nil },
            set: { if !$0 { authError = nil } }
        )) {
            Button(NSLocalizedString("OK", comment: ""), role: .cancel) { authError = nil }
        } message: {
            Text(authError ?? "")
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authError = "Apple did not return a valid credential."
                return
            }
            let displayName = PersonNameComponentsFormatter().string(from: credential.fullName ?? PersonNameComponents())
            let resolvedDisplayName = displayName.isEmpty ? "Apple User" : displayName
            completeSignIn(
                displayName: resolvedDisplayName,
                email: credential.email ?? authEmail,
                provider: "Apple"
            )
        case .failure(let error):
            authError = error.localizedDescription
        }
    }

    private func completeSignIn(displayName: String, email: String, provider: String) {
        do {
            try ensureLocalProfile(displayName: displayName)
            authDisplayName = displayName
            authEmail = email
            authProvider = provider
            isAuthenticated = true
        } catch {
            authError = "Unable to create your local account. \(error.localizedDescription)"
        }
    }

    private func ensureLocalProfile(displayName: String) throws {
        let descriptor = FetchDescriptor<UserProfile>()
        if let profile = try modelContext.fetch(descriptor).first {
            profile.displayName = displayName
        } else {
            modelContext.insert(
                UserProfile(
                    id: SeedStore.defaultUserId,
                    displayName: displayName,
                    baseCurrency: AppFormatters.defaultCurrency()
                )
            )
        }
        try modelContext.save()
    }
}
