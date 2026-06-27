import SwiftUI
import SwiftData

@main
struct MMangerApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            UserProfile.self,
            Account.self,
            FinanceCategory.self,
            FinanceTransaction.self,
            MerchantRule.self,
            TransactionAttachment.self,
            ImportBatch.self,
            Budget.self
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
        }
        .modelContainer(container)
    }
}
