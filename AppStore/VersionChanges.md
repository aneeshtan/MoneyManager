# Pro Money Manager — Version 1.1 Release Notes

## New Features

### 1. Push Notifications for Bills
- Get a local notification at 9 AM the day before any scheduled bill or recurring charge is due.
- Enable or disable reminders from Profile → Notifications.
- Tapping the notification opens the app.

### 2. Customizable Dashboard
- Reorder or hide dashboard cards from Stats → customize icon.
- Cards include: Month overview, AI insights, Monthly summary, and Category/Budget/Notes content.
- Layout preference is persisted across app launches.

### 3. Smart Rules & Auto-categorization
- Rules now support extra conditions: account name, note keyword, min/max amount, and priority.
- New "Smart Categorize" card in Categories → Rules learns patterns from your categorized transactions.
- Preview learned rules and affected transactions before applying.
- One-tap bulk apply categorizes all matching uncategorized transactions and saves the new rules.

### 4. Account Deletion
- Profile → Delete account and local data permanently removes the user profile and all finance data from the device.
- Required for App Store compliance.

### 5. App Lock
- Secure the app with Face ID / Touch ID / device passcode.
- Enable from More → App Lock.

### 6. Scheduled Transactions
- Create recurring bills, income, or subscriptions with weekly, biweekly, monthly, quarterly, or yearly schedules.
- Post transactions manually or pause schedules.

### 7. Savings Goals
- Track progress toward savings targets.
- Add contributions and view remaining amount.

### 8. Debt Payoff Planner
- Plan debt elimination with snowball or avalanche strategies.
- See estimated months to payoff.

### 9. Subscriptions Tracker
- Dedicated view to track recurring subscription charges.

### 10. Tags
- Label transactions with custom tags for flexible grouping.

### 11. Calendar View
- View transactions on a monthly calendar.

### 12. Trends
- Spending charts over time.

## Improvements
- Enhanced transaction editor with split transactions support.
- Improved category/budget drill-down views.
- Better import review and duplicate detection.
- UI polish across the app with the pastel glassmorphism design.

## Files Added
- `MManger/Services/AccountDeletionService.swift`
- `MManger/Services/AppLockService.swift`
- `MManger/Services/NotificationService.swift`
- `MManger/Services/SmartCategorizationService.swift`
- `MManger/Views/AppLockSettingsView.swift`
- `MManger/Views/CalendarView.swift`
- `MManger/Views/DebtPayoffView.swift`
- `MManger/Views/SavingsGoalsView.swift`
- `MManger/Views/ScheduledTransactionsView.swift`
- `MManger/Views/SmartCategorizeView.swift`
- `MManger/Views/SplitTransactionEditorView.swift`
- `MManger/Views/SubscriptionsView.swift`
- `MManger/Views/TagsView.swift`

## Files Modified
- `MManger/MMangerApp.swift`
- `MManger/Models/FinanceModels.swift`
- `MManger/Services/MerchantNormalizer.swift`
- `MManger/Services/SeedStore.swift`
- `MManger/Views/AuthView.swift`
- `MManger/Views/CategoriesView.swift`
- `MManger/Views/DashboardView.swift`
- `MManger/Views/Formatters.swift`
- `MManger/Views/ImportPDFView.swift`
- `MManger/Views/RootView.swift`
- `MManger/Views/TransactionEditorView.swift`
- `MManger/Views/TransactionsView.swift`
- `MManger/Views/TrendsView.swift`
- `MMangerTests/AccountManagementTests.swift`
- `MMangerTests/BudgetProgressTests.swift`
- `ProMoneyManager.xcodeproj/project.pbxproj`
