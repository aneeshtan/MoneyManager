import AuthenticationServices
import SwiftUI

struct AuthView: View {
    @AppStorage("isAuthenticated") private var isAuthenticated = false
    @AppStorage("authProvider") private var authProvider = ""
    @AppStorage("authDisplayName") private var authDisplayName = ""
    @AppStorage("authEmail") private var authEmail = ""
    @State private var authError: String?
    @State private var showingGoogleConfiguration = false

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
                        .background(.white.opacity(0.64), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.9), lineWidth: 1))

                    VStack(spacing: 8) {
                        Text("AI Money Manager")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                            .multilineTextAlignment(.center)
                        Text("Sign in to protect your local finance workspace.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                            .multilineTextAlignment(.center)
                    }
                }

                GlassSurface {
                    VStack(spacing: 14) {
                        #if DEBUG
                        Button {
                            authDisplayName = "Local Tester"
                            authEmail = ""
                            authProvider = "Local"
                            isAuthenticated = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "iphone.and.arrow.forward")
                                    .font(.title3.weight(.semibold))
                                Text("Continue on this device")
                                    .font(.headline.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(PrimaryPressStyle())

                        Text("Debug builds use local sign-in so the app can run on a personal device without paid Apple capabilities.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        #else
                        SignInWithAppleButton(.continue) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        #endif

                        Button {
                            showingGoogleConfiguration = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "g.circle.fill")
                                    .font(.title3.weight(.semibold))
                                Text("Continue with Google")
                                    .font(.headline.weight(.semibold))
                            }
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
                        }
                        .buttonStyle(PrimaryPressStyle())

                        Text("Your app data remains on this device. Login is used only to unlock this local workspace.")
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
        }
        .alert("Sign in failed", isPresented: Binding(
            get: { authError != nil },
            set: { if !$0 { authError = nil } }
        )) {
            Button("OK", role: .cancel) { authError = nil }
        } message: {
            Text(authError ?? "")
        }
        .alert("Google sign-in setup required", isPresented: $showingGoogleConfiguration) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Add the GoogleSignIn SDK, an iOS OAuth client ID, and the reversed client ID URL scheme before enabling Google sign-in for App Store builds.")
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
            authDisplayName = displayName.isEmpty ? "Apple User" : displayName
            authEmail = credential.email ?? authEmail
            authProvider = "Apple"
            isAuthenticated = true
        case .failure(let error):
            authError = error.localizedDescription
        }
    }
}
