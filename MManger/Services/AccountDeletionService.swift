import Foundation
import SwiftData

enum AccountDeletionService {
    static let didDeleteLocalAccountKey = "didDeleteLocalAccount"

    @MainActor
    static func deleteLocalWorkspaceData(in modelContext: ModelContext, defaults: UserDefaults = .standard) throws {
        try delete(TransactionAttachment.self, in: modelContext)
        try delete(FinanceTransaction.self, in: modelContext)
        try delete(ImportBatch.self, in: modelContext)
        try delete(Budget.self, in: modelContext)
        try delete(MerchantRule.self, in: modelContext)
        try delete(FinanceCategory.self, in: modelContext)
        try delete(Account.self, in: modelContext)
        try delete(UserProfile.self, in: modelContext)
        try modelContext.save()
        defaults.set(true, forKey: didDeleteLocalAccountKey)
    }

    @MainActor
    private static func delete<Model: PersistentModel>(_ modelType: Model.Type, in modelContext: ModelContext) throws {
        let descriptor = FetchDescriptor<Model>()
        for model in try modelContext.fetch(descriptor) {
            modelContext.delete(model)
        }
    }
}
