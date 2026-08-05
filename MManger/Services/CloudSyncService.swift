import CloudKit
import Foundation

enum CloudSyncService {
    static func accountStatus() async -> CKAccountStatus {
        await withCheckedContinuation { continuation in
            CKContainer.default().accountStatus { status, _ in
                continuation.resume(returning: status)
            }
        }
    }

    static func statusDescription(_ status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "Signed in to iCloud"
        case .noAccount:
            return "Not signed in to iCloud on this device"
        case .restricted:
            return "iCloud access is restricted"
        case .couldNotDetermine:
            return "Could not check iCloud status"
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable"
        @unknown default:
            return "iCloud status unknown"
        }
    }
}
