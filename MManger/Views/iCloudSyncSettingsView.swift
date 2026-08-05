import CloudKit
import SwiftUI

struct iCloudSyncSettingsView: View {
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = false
    @AppStorage("authProvider") private var authProvider = ""
    @State private var accountStatus: CKAccountStatus = .couldNotDetermine
    @State private var isCheckingStatus = true
    @State private var restartNotice: String?

    private var isAppleUser: Bool { authProvider == "Apple" }
    private var isAccountAvailable: Bool { accountStatus == .available }

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
                                    Image(systemName: isAccountAvailable ? "icloud.fill" : "icloud.slash.fill")
                                        .font(.title2.weight(.semibold))
                                        .foregroundStyle(isAccountAvailable ? AppTheme.violet : AppTheme.muted)
                                        .frame(width: 50, height: 50)
                                        .background(AppTheme.lavender.opacity(0.14), in: Circle())

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(isAppleUser ? statusTitle : "Requires Sign in with Apple")
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(AppTheme.ink)
                                        Text(isAppleUser ? statusDetail : "Switch to Sign in with Apple from Profile to unlock iCloud Sync.")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.muted)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                }

                                Toggle("Sync data with iCloud", isOn: $iCloudSyncEnabled)
                                    .disabled(!isAppleUser || !isAccountAvailable || isCheckingStatus)
                                    .onChange(of: iCloudSyncEnabled) { _, newValue in
                                        restartNotice = newValue
                                            ? "Restart Pro Money Manager to finish enabling iCloud Sync."
                                            : "Restart Pro Money Manager to finish turning off iCloud Sync."
                                    }
                            }
                        }

                        if let restartNotice {
                            GlassSurface {
                                HStack(spacing: 10) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundStyle(AppTheme.gold)
                                    Text(restartNotice)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.gold)
                                    Spacer()
                                }
                            }
                        }

                        EmptyStateView(
                            systemImage: "icloud",
                            title: "How it works",
                            message: "When enabled, your accounts, transactions, and budgets sync privately through your own iCloud account. Nothing is sent to Pro Money Manager's servers — there aren't any."
                        )
                    }
                    .adaptiveScreenContent()
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(NSLocalizedString("iCloud Sync", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .task {
                accountStatus = await CloudSyncService.accountStatus()
                isCheckingStatus = false
            }
        }
    }

    private var statusTitle: String {
        isCheckingStatus ? "Checking iCloud status…" : CloudSyncService.statusDescription(accountStatus)
    }

    private var statusDetail: String {
        isAccountAvailable
            ? "Your data can sync to your private iCloud account."
            : "Sign in to iCloud in Settings on this device to enable sync."
    }

    private var heroCard: some View {
        GlassSurface(padding: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("Sync", comment: ""))
                            .font(.caption.weight(.semibold))
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.violet)
                        Text(NSLocalizedString("iCloud Sync", comment: ""))
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                    }
                    Spacer()
                    Image(systemName: "icloud")
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
