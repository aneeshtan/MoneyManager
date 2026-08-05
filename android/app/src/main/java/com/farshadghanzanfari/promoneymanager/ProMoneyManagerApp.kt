package com.farshadghanzanfari.promoneymanager

import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.adaptive.navigationsuite.NavigationSuiteScaffold
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.farshadghanzanfari.promoneymanager.core.designsystem.BrandLavender
import com.farshadghanzanfari.promoneymanager.core.designsystem.BrandTeal
import com.farshadghanzanfari.promoneymanager.core.designsystem.BrandViolet
import com.farshadghanzanfari.promoneymanager.core.designsystem.ProMoneySurface
import com.farshadghanzanfari.promoneymanager.core.domain.BackupEngine
import com.farshadghanzanfari.promoneymanager.core.domain.CategorizationBulkApplyPlan
import com.farshadghanzanfari.promoneymanager.core.domain.DebtPayoffCalculator
import com.farshadghanzanfari.promoneymanager.core.domain.SavingsGoalCalculator
import com.farshadghanzanfari.promoneymanager.core.domain.SubscriptionDetector
import com.farshadghanzanfari.promoneymanager.core.model.Account
import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.AppShortcutSpec
import com.farshadghanzanfari.promoneymanager.core.model.Budget
import com.farshadghanzanfari.promoneymanager.core.model.BudgetId
import com.farshadghanzanfari.promoneymanager.core.model.Category
import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.DebtPayoffPlan
import com.farshadghanzanfari.promoneymanager.core.model.DebtPlanId
import com.farshadghanzanfari.promoneymanager.core.model.MerchantRule
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.RestorePreview
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalContribution
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalContributionDirection
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalId
import com.farshadghanzanfari.promoneymanager.core.model.ScheduleId
import com.farshadghanzanfari.promoneymanager.core.model.NotificationPermissionState
import com.farshadghanzanfari.promoneymanager.core.model.NotificationSettings
import com.farshadghanzanfari.promoneymanager.core.model.OcrConfidence
import com.farshadghanzanfari.promoneymanager.core.model.OcrReviewDraft
import com.farshadghanzanfari.promoneymanager.core.model.ParsedImportTransaction
import com.farshadghanzanfari.promoneymanager.core.model.PrivacySettings
import com.farshadghanzanfari.promoneymanager.core.model.RegionalSettings
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoal
import com.farshadghanzanfari.promoneymanager.core.model.ScheduleFrequency
import com.farshadghanzanfari.promoneymanager.core.model.ScheduledTransaction
import com.farshadghanzanfari.promoneymanager.core.model.ScheduledNotificationAction
import com.farshadghanzanfari.promoneymanager.core.model.SmsIngestionPolicy
import com.farshadghanzanfari.promoneymanager.core.model.Tag
import com.farshadghanzanfari.promoneymanager.core.model.TagId
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionId
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import com.farshadghanzanfari.promoneymanager.core.model.WidgetPrivacyMode
import com.farshadghanzanfari.promoneymanager.core.model.WidgetSnapshot
import java.math.BigDecimal
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

private enum class AppDestination(val labelRes: Int) {
    STATS(R.string.destination_stats),
    TRANSACTIONS(R.string.destination_transactions),
    IMPORT(R.string.destination_import),
    MORE(R.string.destination_more),
}

private enum class MorePanel(val labelRes: Int) {
    HOME(R.string.panel_home),
    ACCOUNTS(R.string.panel_accounts),
    CATEGORIES(R.string.panel_categories),
    TAGS(R.string.panel_tags),
    SEARCH(R.string.panel_search),
    CALENDAR(R.string.panel_calendar),
    TRENDS(R.string.panel_trends),
    RULES(R.string.panel_smart_rules),
    BUDGETS(R.string.panel_budgets),
    BACKUP(R.string.panel_backup),
    PRIVACY(R.string.panel_privacy),
    NOTIFICATIONS(R.string.panel_notifications),
    LANGUAGE(R.string.language),
    ANDROID(R.string.panel_android),
    SCHEDULE(R.string.panel_schedule),
    GOALS(R.string.panel_goals),
    DEBT_PAYOFF(R.string.panel_debt_payoff),
    SUBSCRIPTIONS(R.string.panel_subscriptions),
}

@Composable
private fun AppDestination.label(): String = stringResource(labelRes)

@Composable
private fun MorePanel.label(): String = stringResource(labelRes)

@Composable
fun ProMoneyManagerApp(
    sharedImportText: String? = null,
    shortcutDestination: String? = null,
    onSecureScreenChanged: (Boolean) -> Unit = {},
    viewModel: AppViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val authenticator = rememberAndroidAppAuthenticator()
    val lockSessionState = rememberAppLockSessionState()
    LaunchedEffect(state.regionalSettings.language) {
        val target = LocaleListCompat.forLanguageTags(state.regionalSettings.language.languageTag)
        if (AppCompatDelegate.getApplicationLocales() != target) {
            AppCompatDelegate.setApplicationLocales(target)
        }
    }
    LaunchedEffect(sharedImportText) {
        if (!sharedImportText.isNullOrBlank()) {
            viewModel.acceptSharedImportText(sharedImportText)
        }
    }
    LaunchedEffect(state.privacySettings.secureScreenEnabled) {
        onSecureScreenChanged(state.privacySettings.secureScreenEnabled)
    }
    AppLockGate(
        settings = state.privacySettings,
        authenticator = authenticator,
        sessionState = lockSessionState,
    ) {
        ProMoneyManagerContent(
            state = state,
            shortcutDestination = shortcutDestination,
            onContinueOnDevice = {},
            onCompleteOnboarding = viewModel::continueOnDevice,
            onSaveRegionalSettings = viewModel::saveRegionalSettings,
            onSaveAccount = viewModel::saveAccount,
            onArchiveAccount = viewModel::setAccountArchived,
            onSaveCategory = viewModel::saveCategory,
            onSaveTag = viewModel::saveTag,
            onSaveBudget = viewModel::saveBudget,
            onSaveTransaction = viewModel::saveTransaction,
            onDeleteTransaction = viewModel::deleteTransaction,
            onImportTextChanged = viewModel::updateImportText,
            onParseImportText = viewModel::parseImportText,
            onImportDocumentSelected = viewModel::importDocument,
            onSelectCleanImportRows = viewModel::selectCleanImportRows,
            onToggleImportRow = viewModel::toggleImportRow,
            onEditImportRow = viewModel::editImportRow,
            onSaveReviewedImport = viewModel::saveReviewedImport,
            onSaveSchedule = viewModel::saveScheduledTransaction,
            onSaveSavingsGoal = viewModel::saveSavingsGoal,
            onSaveDebtPlan = viewModel::saveDebtPlan,
            onSaveTransfer = viewModel::saveTransfer,
            onPostSchedule = viewModel::postScheduleNow,
            onPauseSchedule = viewModel::setSchedulePaused,
            onArchiveSchedule = viewModel::archiveSchedule,
            onArchiveCategory = viewModel::setCategoryArchived,
            onDeleteTag = viewModel::deleteTag,
            onArchiveBudget = viewModel::setBudgetArchived,
            onArchiveGoal = viewModel::setSavingsGoalArchived,
            onArchiveDebtPlan = viewModel::setDebtPlanArchived,
            onSaveContribution = viewModel::saveGoalContribution,
            onSaveRule = viewModel::saveMerchantRule,
            onToggleRule = viewModel::setMerchantRuleEnabled,
            onApplyCategorizationPlan = viewModel::applyCategorizationPlan,
            onSetRemindersEnabled = viewModel::setRemindersEnabled,
            onExportBackup = viewModel::exportCompleteBackup,
            onExportCsv = viewModel::exportTransactionsCsv,
            onPreviewRestore = viewModel::previewRestore,
            onConfirmRestore = viewModel::confirmRestore,
            onCancelRestore = viewModel::cancelRestore,
            onToggleAppLock = {
                if (state.privacySettings.appLockEnabled) {
                    viewModel.toggleAppLock()
                } else if (authenticator.canAuthenticate()) {
                    authenticator.authenticate { success ->
                        if (success) {
                            lockSessionState.authenticated = true
                            viewModel.toggleAppLock()
                        }
                    }
                }
            },
            onDeleteWorkspace = viewModel::clearWorkspace,
        )
    }
}

@Composable
fun ProMoneyManagerContent(
    state: AppUiState,
    shortcutDestination: String? = null,
    onContinueOnDevice: () -> Unit,
    onCompleteOnboarding: (RegionalSettings) -> Unit = { onContinueOnDevice() },
    onSaveRegionalSettings: (RegionalSettings) -> Unit = {},
    onSaveAccount: (Account) -> Unit = {},
    onArchiveAccount: (AccountId, Boolean) -> Unit = { _, _ -> },
    onSaveCategory: (Category) -> Unit = {},
    onSaveTag: (Tag) -> Unit = {},
    onSaveBudget: (Budget) -> Unit = {},
    onSaveTransaction: (Transaction) -> Unit = {},
    onDeleteTransaction: (TransactionId) -> Unit = {},
    onImportTextChanged: (String) -> Unit = {},
    onParseImportText: () -> Unit = {},
    onImportDocumentSelected: (Uri, String?, String?) -> Unit = { _, _, _ -> },
    onSelectCleanImportRows: () -> Unit = {},
    onToggleImportRow: (Int?) -> Unit = {},
    onEditImportRow: (Int?, String, Long, CategoryId?, LocalDate?) -> Unit = { _, _, _, _, _ -> },
    onSaveReviewedImport: () -> Unit = {},
    onSaveSchedule: (ScheduledTransaction) -> Unit = {},
    onSaveSavingsGoal: (SavingsGoal) -> Unit = {},
    onSaveDebtPlan: (DebtPayoffPlan) -> Unit = {},
    onSaveTransfer: (AccountId, AccountId, Money, LocalDate, String) -> Unit = { _, _, _, _, _ -> },
    onPostSchedule: (ScheduleId) -> Unit = {},
    onPauseSchedule: (ScheduledTransaction, Boolean) -> Unit = { _, _ -> },
    onArchiveSchedule: (ScheduleId) -> Unit = {},
    onArchiveCategory: (CategoryId, Boolean) -> Unit = { _, _ -> },
    onDeleteTag: (TagId) -> Unit = {},
    onArchiveBudget: (BudgetId, Boolean) -> Unit = { _, _ -> },
    onArchiveGoal: (SavingsGoalId, Boolean) -> Unit = { _, _ -> },
    onArchiveDebtPlan: (DebtPlanId, Boolean) -> Unit = { _, _ -> },
    onSaveContribution: (SavingsGoal, Money, SavingsGoalContributionDirection, String) -> Unit = { _, _, _, _ -> },
    onSaveRule: (MerchantRule) -> Unit = {},
    onToggleRule: (String, Boolean) -> Unit = { _, _ -> },
    onApplyCategorizationPlan: (CategorizationBulkApplyPlan) -> Unit = {},
    onSetRemindersEnabled: (Boolean, NotificationPermissionState) -> Unit = { _, _ -> },
    onExportBackup: (Uri) -> Unit = {},
    onExportCsv: (Uri) -> Unit = {},
    onPreviewRestore: (Uri) -> Unit = {},
    onConfirmRestore: () -> Unit = {},
    onCancelRestore: () -> Unit = {},
    onToggleAppLock: () -> Unit = {},
    onDeleteWorkspace: () -> Unit = {},
) {
    when {
        state.isLoading -> LoadingWorkspace()
        state.hasWorkspace -> WorkspaceShell(
            accounts = state.accounts,
            categories = state.categories,
            tags = state.tags,
            transactions = state.transactions,
            merchantRules = state.merchantRules,
            budgets = state.budgets,
            scheduledTransactions = state.scheduledTransactions,
            savingsGoals = state.savingsGoals,
            savingsGoalContributions = state.savingsGoalContributions,
            debtPayoffPlans = state.debtPayoffPlans,
            privacySettings = state.privacySettings,
            notificationSettings = state.notificationSettings,
            regionalSettings = state.regionalSettings,
            backupStatus = state.backupStatus,
            restorePreview = state.restorePreview,
            onSaveAccount = onSaveAccount,
            onArchiveAccount = onArchiveAccount,
            onSaveCategory = onSaveCategory,
            onSaveTag = onSaveTag,
            onSaveBudget = onSaveBudget,
            onSaveTransaction = onSaveTransaction,
            onDeleteTransaction = onDeleteTransaction,
            onSaveSchedule = onSaveSchedule,
            onSaveSavingsGoal = onSaveSavingsGoal,
            onSaveDebtPlan = onSaveDebtPlan,
            onSaveTransfer = onSaveTransfer,
            onPostSchedule = onPostSchedule,
            onPauseSchedule = onPauseSchedule,
            onArchiveSchedule = onArchiveSchedule,
            onArchiveCategory = onArchiveCategory,
            onDeleteTag = onDeleteTag,
            onArchiveBudget = onArchiveBudget,
            onArchiveGoal = onArchiveGoal,
            onArchiveDebtPlan = onArchiveDebtPlan,
            onSaveContribution = onSaveContribution,
            onSaveRule = onSaveRule,
            onToggleRule = onToggleRule,
            onApplyCategorizationPlan = onApplyCategorizationPlan,
            onSetRemindersEnabled = onSetRemindersEnabled,
            onExportBackup = onExportBackup,
            onExportCsv = onExportCsv,
            onPreviewRestore = onPreviewRestore,
            onConfirmRestore = onConfirmRestore,
            onCancelRestore = onCancelRestore,
            onToggleAppLock = onToggleAppLock,
            onSaveRegionalSettings = onSaveRegionalSettings,
            onDeleteWorkspace = onDeleteWorkspace,
            shortcutDestination = shortcutDestination,
            importText = state.importText,
            importRows = state.importRows,
            importStatus = state.importStatus,
            isImporting = state.isImporting,
            errorMessage = state.errorMessage,
            onImportTextChanged = onImportTextChanged,
            onParseImportText = onParseImportText,
            onImportDocumentSelected = onImportDocumentSelected,
            onSelectCleanImportRows = onSelectCleanImportRows,
            onToggleImportRow = onToggleImportRow,
            onEditImportRow = onEditImportRow,
            onSaveReviewedImport = onSaveReviewedImport,
        )
        else -> Onboarding(onCompleteOnboarding)
    }
}

@Composable
private fun Onboarding(onComplete: (RegionalSettings) -> Unit) {
    var draftSettings by remember {
        mutableStateOf(RegionalSettings())
    }
    val isDark = androidx.compose.foundation.isSystemInDarkTheme()
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.linearGradient(
                    colors = if (isDark) {
                        listOf(
                            MaterialTheme.colorScheme.surface,
                            Color(0xFF13161A),
                            MaterialTheme.colorScheme.background,
                        )
                    } else {
                        listOf(
                            Color(0xFFFDF4F7),
                            Color(0xFFF4FBF9),
                            MaterialTheme.colorScheme.background,
                        )
                    },
                    start = Offset.Zero,
                    end = Offset(900f, 1_400f),
                ),
            )
            .safeDrawingPadding(),
    ) {
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.Center)
                .padding(horizontal = 24.dp),
            contentPadding = PaddingValues(vertical = 28.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            item {
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                    Box(
                        modifier = Modifier
                            .size(104.dp)
                            .clip(RoundedCornerShape(28.dp))
                            .background(MaterialTheme.colorScheme.surface)
                            .border(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.72f), RoundedCornerShape(28.dp)),
                        contentAlignment = Alignment.Center,
                    ) {
                        PieChartGlyph(
                            modifier = Modifier.size(48.dp),
                            brush = Brush.linearGradient(listOf(BrandViolet, BrandTeal)),
                        )
                    }
                    Text(
                        text = stringResource(R.string.app_name),
                        modifier = Modifier.padding(top = 16.dp),
                        style = MaterialTheme.typography.displaySmall,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onBackground,
                        textAlign = TextAlign.Center,
                    )
                    Text(
                        text = stringResource(R.string.onboarding_tagline),
                        modifier = Modifier.padding(top = 8.dp),
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                    )
                }
            }
            item {
                ProMoneySurface(
                    modifier = Modifier.fillMaxWidth(),
                    shape = MaterialTheme.shapes.medium,
                ) {
                    Text(
                        text = stringResource(R.string.onboarding_subtitle),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    RegionalSettingsEditor(
                        settings = draftSettings,
                        actionLabel = stringResource(R.string.start_managing_money),
                        onSave = { settings ->
                            draftSettings = settings
                            onComplete(settings)
                        },
                    )
                    Text(
                        text = stringResource(R.string.onboarding_footer),
                        modifier = Modifier.fillMaxWidth(),
                        textAlign = TextAlign.Center,
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

@Composable
private fun PieChartGlyph(modifier: Modifier = Modifier, brush: Brush) {
    Canvas(modifier) {
        val diameter = size.minDimension
        val topLeft = Offset((size.width - diameter) / 2f, (size.height - diameter) / 2f)
        drawArc(
            brush = brush,
            startAngle = -90f,
            sweepAngle = 360f,
            useCenter = true,
            topLeft = topLeft,
            size = androidx.compose.ui.geometry.Size(diameter, diameter),
        )
        val dividerColor = Color.White.copy(alpha = 0.85f)
        val center = Offset(size.width / 2f, size.height / 2f)
        val radius = diameter / 2f
        listOf(-90f, 30f, 165f).forEach { angleDegrees ->
            val angle = Math.toRadians(angleDegrees.toDouble())
            drawLine(
                color = dividerColor,
                start = center,
                end = Offset(
                    center.x + (radius * kotlin.math.cos(angle)).toFloat(),
                    center.y + (radius * kotlin.math.sin(angle)).toFloat(),
                ),
                strokeWidth = diameter * 0.045f,
            )
        }
    }
}

@Composable
private fun LoadingWorkspace() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        repeat(3) { index ->
            Box(
                Modifier
                    .fillMaxWidth(if (index == 0) 0.58f else 1f)
                    .height(if (index == 0) 34.dp else 72.dp)
                    .clip(RoundedCornerShape(20.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant),
            )
            Spacer(Modifier.height(14.dp))
        }
    }
}

@Composable
private fun WorkspaceShell(
    accounts: List<Account>,
    categories: List<Category>,
    tags: List<Tag>,
    transactions: List<Transaction>,
    merchantRules: List<MerchantRule>,
    budgets: List<Budget>,
    scheduledTransactions: List<ScheduledTransaction>,
    savingsGoals: List<SavingsGoal>,
    savingsGoalContributions: List<SavingsGoalContribution>,
    debtPayoffPlans: List<DebtPayoffPlan>,
    privacySettings: PrivacySettings,
    notificationSettings: NotificationSettings,
    regionalSettings: RegionalSettings,
    backupStatus: String?,
    restorePreview: RestorePreview?,
    onSaveAccount: (Account) -> Unit,
    onArchiveAccount: (AccountId, Boolean) -> Unit,
    onSaveCategory: (Category) -> Unit,
    onSaveTag: (Tag) -> Unit,
    onSaveBudget: (Budget) -> Unit,
    onSaveTransaction: (Transaction) -> Unit,
    onDeleteTransaction: (TransactionId) -> Unit,
    onSaveSchedule: (ScheduledTransaction) -> Unit,
    onSaveSavingsGoal: (SavingsGoal) -> Unit,
    onSaveDebtPlan: (DebtPayoffPlan) -> Unit,
    onSaveTransfer: (AccountId, AccountId, Money, LocalDate, String) -> Unit,
    onPostSchedule: (ScheduleId) -> Unit,
    onPauseSchedule: (ScheduledTransaction, Boolean) -> Unit,
    onArchiveSchedule: (ScheduleId) -> Unit,
    onArchiveCategory: (CategoryId, Boolean) -> Unit,
    onDeleteTag: (TagId) -> Unit,
    onArchiveBudget: (BudgetId, Boolean) -> Unit,
    onArchiveGoal: (SavingsGoalId, Boolean) -> Unit,
    onArchiveDebtPlan: (DebtPlanId, Boolean) -> Unit,
    onSaveContribution: (SavingsGoal, Money, SavingsGoalContributionDirection, String) -> Unit,
    onSaveRule: (MerchantRule) -> Unit,
    onToggleRule: (String, Boolean) -> Unit,
    onApplyCategorizationPlan: (CategorizationBulkApplyPlan) -> Unit,
    onSetRemindersEnabled: (Boolean, NotificationPermissionState) -> Unit,
    onExportBackup: (Uri) -> Unit,
    onExportCsv: (Uri) -> Unit,
    onPreviewRestore: (Uri) -> Unit,
    onConfirmRestore: () -> Unit,
    onCancelRestore: () -> Unit,
    onToggleAppLock: () -> Unit,
    onSaveRegionalSettings: (RegionalSettings) -> Unit,
    onDeleteWorkspace: () -> Unit,
    shortcutDestination: String?,
    importText: String,
    importRows: List<ParsedImportTransaction>,
    importStatus: String?,
    isImporting: Boolean,
    errorMessage: String?,
    onImportTextChanged: (String) -> Unit,
    onParseImportText: () -> Unit,
    onImportDocumentSelected: (Uri, String?, String?) -> Unit,
    onSelectCleanImportRows: () -> Unit,
    onToggleImportRow: (Int?) -> Unit,
    onEditImportRow: (Int?, String, Long, CategoryId?, LocalDate?) -> Unit,
    onSaveReviewedImport: () -> Unit,
) {
    var selected by rememberSaveable {
        mutableStateOf(shortcutDestination.toAppDestination(importText))
    }
    var lastImportLaunchText by rememberSaveable { mutableStateOf(importText) }

    LaunchedEffect(shortcutDestination) {
        val shortcutLaunchDestination = shortcutDestination.toAppDestination(importText)
        if (shortcutDestination != null && selected != shortcutLaunchDestination) {
            selected = shortcutLaunchDestination
        }
    }

    LaunchedEffect(importText) {
        if (importText.isNotBlank() && importText != lastImportLaunchText) {
            selected = AppDestination.IMPORT
            lastImportLaunchText = importText
        }
    }

    NavigationSuiteScaffold(
        navigationSuiteItems = {
            AppDestination.entries.forEach { destination ->
                item(
                    selected = selected == destination,
                    onClick = { selected = destination },
                    icon = {
                        DestinationGlyph(
                            destination = destination,
                            selected = selected == destination,
                        )
                    },
                    label = { Text(destination.label()) },
                )
            }
        },
    ) {
        when (selected) {
            AppDestination.STATS -> StatsScreen(
                accounts = accounts,
                categories = categories,
                transactions = transactions,
                budgets = budgets,
                scheduledTransactions = scheduledTransactions,
                usePersianCalendar = regionalSettings.usesPersianCalendar,
            )
            AppDestination.TRANSACTIONS -> TransactionsScreen(
                transactions = transactions,
                accounts = accounts,
                categories = categories,
                tags = tags,
                regionalSettings = regionalSettings,
                onSaveTransaction = onSaveTransaction,
                onDeleteTransaction = onDeleteTransaction,
                onSaveTransfer = onSaveTransfer,
            )
            AppDestination.IMPORT -> ImportScreen(
                importText = importText,
                accounts = accounts,
                categories = categories,
                importRows = importRows,
                importStatus = importStatus,
                isImporting = isImporting,
                errorMessage = errorMessage,
                onImportTextChanged = onImportTextChanged,
                onParseImportText = onParseImportText,
                onImportDocumentSelected = onImportDocumentSelected,
                onSelectCleanImportRows = onSelectCleanImportRows,
                onToggleImportRow = onToggleImportRow,
                onEditImportRow = onEditImportRow,
                onSaveReviewedImport = onSaveReviewedImport,
            )
            AppDestination.MORE -> MoreScreen(
                accounts = accounts,
                categories = categories,
                tags = tags,
                transactions = transactions,
                merchantRules = merchantRules,
                budgets = budgets,
                scheduledTransactions = scheduledTransactions,
                savingsGoals = savingsGoals,
                savingsGoalContributions = savingsGoalContributions,
                debtPayoffPlans = debtPayoffPlans,
                privacySettings = privacySettings,
                notificationSettings = notificationSettings,
                regionalSettings = regionalSettings,
                backupStatus = backupStatus,
                restorePreview = restorePreview,
                onSaveAccount = onSaveAccount,
                onArchiveAccount = onArchiveAccount,
                onSaveCategory = onSaveCategory,
                onSaveTag = onSaveTag,
                onSaveBudget = onSaveBudget,
                onSaveSchedule = onSaveSchedule,
                onSaveSavingsGoal = onSaveSavingsGoal,
                onSaveDebtPlan = onSaveDebtPlan,
                onPostSchedule = onPostSchedule,
                onPauseSchedule = onPauseSchedule,
                onArchiveSchedule = onArchiveSchedule,
                onArchiveCategory = onArchiveCategory,
                onDeleteTag = onDeleteTag,
                onArchiveBudget = onArchiveBudget,
                onArchiveGoal = onArchiveGoal,
                onArchiveDebtPlan = onArchiveDebtPlan,
                onSaveContribution = onSaveContribution,
                onSaveRule = onSaveRule,
                onToggleRule = onToggleRule,
                onApplyCategorizationPlan = onApplyCategorizationPlan,
                onSetRemindersEnabled = onSetRemindersEnabled,
                onExportBackup = onExportBackup,
                onExportCsv = onExportCsv,
                onPreviewRestore = onPreviewRestore,
                onConfirmRestore = onConfirmRestore,
                onCancelRestore = onCancelRestore,
                onToggleAppLock = onToggleAppLock,
                onSaveRegionalSettings = onSaveRegionalSettings,
                onDeleteWorkspace = onDeleteWorkspace,
                initialPanel = shortcutDestination.toMorePanel() ?: MorePanel.HOME,
            )
        }
    }
}

private fun String?.toAppDestination(importText: String): AppDestination = when (this) {
    "add_expense" -> AppDestination.TRANSACTIONS
    "import_statement" -> AppDestination.IMPORT
    "search", "upcoming_bills" -> AppDestination.MORE
    else -> if (importText.isNotBlank()) AppDestination.IMPORT else AppDestination.STATS
}

private fun String?.toMorePanel(): MorePanel? = when (this) {
    "search" -> MorePanel.SEARCH
    "upcoming_bills" -> MorePanel.SCHEDULE
    else -> null
}

@Composable
private fun DestinationGlyph(destination: AppDestination, selected: Boolean) {
    val color = if (selected) {
        MaterialTheme.colorScheme.primary
    } else {
        MaterialTheme.colorScheme.onSurfaceVariant
    }
    val destinationLabel = destination.label()
    Box(
        modifier = Modifier
            .size(30.dp)
            .semantics { contentDescription = destinationLabel },
        contentAlignment = Alignment.Center,
    ) {
        Canvas(Modifier.size(22.dp)) {
            val stroke = Stroke(width = 2.dp.toPx())
            when (destination) {
                AppDestination.STATS -> {
                    drawLine(
                        color,
                        Offset(2.dp.toPx(), 18.dp.toPx()),
                        Offset(2.dp.toPx(), 11.dp.toPx()),
                        2.dp.toPx(),
                    )
                    drawLine(
                        color,
                        Offset(10.dp.toPx(), 18.dp.toPx()),
                        Offset(10.dp.toPx(), 5.dp.toPx()),
                        2.dp.toPx(),
                    )
                    drawLine(
                        color,
                        Offset(18.dp.toPx(), 18.dp.toPx()),
                        Offset(18.dp.toPx(), 2.dp.toPx()),
                        2.dp.toPx(),
                    )
                }
                AppDestination.TRANSACTIONS -> {
                    drawCircle(color, 8.dp.toPx(), center, style = stroke)
                    drawLine(
                        color,
                        center,
                        Offset(center.x + 4.dp.toPx(), center.y - 3.dp.toPx()),
                        2.dp.toPx(),
                    )
                }
                AppDestination.IMPORT -> {
                    drawCircle(color, 9.dp.toPx(), center, style = stroke)
                    drawLine(
                        color,
                        Offset(center.x, 4.dp.toPx()),
                        Offset(center.x, 15.dp.toPx()),
                        2.dp.toPx(),
                    )
                    drawLine(
                        color,
                        Offset(center.x, 15.dp.toPx()),
                        Offset(center.x - 4.dp.toPx(), 11.dp.toPx()),
                        2.dp.toPx(),
                    )
                    drawLine(
                        color,
                        Offset(center.x, 15.dp.toPx()),
                        Offset(center.x + 4.dp.toPx(), 11.dp.toPx()),
                        2.dp.toPx(),
                    )
                }
                AppDestination.MORE -> {
                    listOf(5f, 11f, 17f).forEach { x ->
                        drawCircle(color, 1.5.dp.toPx(), Offset(x.dp.toPx(), center.y))
                    }
                }
            }
        }
    }
}

@Composable
private fun ImportScreen(
    importText: String,
    accounts: List<Account>,
    categories: List<Category>,
    importRows: List<ParsedImportTransaction>,
    importStatus: String?,
    isImporting: Boolean,
    errorMessage: String?,
    onImportTextChanged: (String) -> Unit,
    onParseImportText: () -> Unit,
    onImportDocumentSelected: (Uri, String?, String?) -> Unit,
    onSelectCleanImportRows: () -> Unit,
    onToggleImportRow: (Int?) -> Unit,
    onEditImportRow: (Int?, String, Long, CategoryId?, LocalDate?) -> Unit,
    onSaveReviewedImport: () -> Unit,
) {
    val context = LocalContext.current
    val categoryNames = remember(categories) { categories.associate { it.id to it.name } }
    var editingRow by rememberSaveable { mutableStateOf<Int?>(null) }
    val activeAccount = accounts.firstOrNull { !it.isArchived && it.type == com.farshadghanzanfari.promoneymanager.core.model.AccountType.CREDIT_CARD }
        ?: accounts.firstOrNull { !it.isArchived }
    val documentLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            onImportDocumentSelected(
                uri,
                context.contentResolver.getType(uri),
                context.contentResolver.queryDisplayName(uri),
            )
        }
    }
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .statusBarsPadding(),
        contentPadding = PaddingValues(horizontal = 22.dp, vertical = 26.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        item {
            Text(
                text = stringResource(R.string.destination_import),
                modifier = Modifier.semantics { heading() },
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = stringResource(R.string.import_subtitle),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        item {
            ProMoneySurface(Modifier.fillMaxWidth()) {
                Text(
                    text = stringResource(
                        R.string.import_account,
                        activeAccount?.name ?: stringResource(R.string.create_account_first),
                    ),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Button(
                    onClick = {
                        documentLauncher.launch(arrayOf("application/pdf", "text/csv", "text/plain"))
                    },
                    enabled = activeAccount != null && !isImporting,
                    shape = MaterialTheme.shapes.small,
                ) {
                    Text(stringResource(R.string.choose_pdf_or_file))
                }
                OutlinedTextField(
                    value = importText,
                    onValueChange = onImportTextChanged,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(150.dp),
                    label = { Text(stringResource(R.string.paste_statement_text)) },
                    minLines = 5,
                )
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Button(
                        onClick = onParseImportText,
                        enabled = importText.isNotBlank() && !isImporting,
                        shape = MaterialTheme.shapes.small,
                    ) {
                        Text(stringResource(R.string.parse_import))
                    }
                    Button(
                        onClick = onSaveReviewedImport,
                        enabled = importRows.any { it.isSelected && !it.isDuplicate },
                        shape = MaterialTheme.shapes.small,
                    ) {
                        Text(stringResource(R.string.save_selected))
                    }
                }
                importStatus?.let {
                    Text(
                        text = it,
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
                if (isImporting) {
                    Text(
                        text = stringResource(R.string.reading_document),
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
                errorMessage?.let {
                    Text(
                        text = it,
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }
        }
        if (importRows.isEmpty()) {
            item {
                ProMoneySurface(Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.no_rows_parsed), style = MaterialTheme.typography.titleMedium)
                    Text(
                        stringResource(R.string.local_parse_notice),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        } else {
            item {
                ProMoneySurface(Modifier.fillMaxWidth()) {
                    val selectedCount = importRows.count { it.isSelected }
                    val duplicateCount = importRows.count { it.isDuplicate }
                    val reviewCount = importRows.count { it.isReviewOnly }
                    Text(
                        text = stringResource(
                            R.string.import_counts,
                            importRows.size,
                            selectedCount,
                            duplicateCount,
                            reviewCount,
                        ),
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    TextButton(onClick = onSelectCleanImportRows) {
                        Text(stringResource(R.string.select_clean))
                    }
                }
            }
            items(importRows.size, key = { importRows[it].sourceRow ?: it }) { index ->
                val row = importRows[index]
                ProMoneySurface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(enabled = !row.isDuplicate) { editingRow = row.sourceRow },
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(
                            checked = row.isSelected,
                            onCheckedChange = { onToggleImportRow(row.sourceRow) },
                            enabled = !row.isDuplicate,
                        )
                        Spacer(Modifier.width(8.dp))
                        Column(Modifier.weight(1f)) {
                            Text(
                                text = row.merchant,
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.SemiBold,
                            )
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text(
                                    text = AppFormatters.money(row.amount),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.primary,
                                )
                                Text(
                                    text = row.localDate?.toString()
                                        ?: stringResource(R.string.no_date_detected),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = if (row.localDate == null) {
                                        MaterialTheme.colorScheme.error
                                    } else {
                                        MaterialTheme.colorScheme.onSurfaceVariant
                                    },
                                )
                            }
                            val categoryText = row.suggestedCategoryId?.let { categoryNames[it] }
                                ?: stringResource(R.string.uncategorized)
                            Text(
                                text = stringResource(
                                    R.string.suggestion_confidence,
                                    categoryText,
                                    (row.confidence * 100).toInt(),
                                ),
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                    if (row.isDuplicate) {
                        Text(
                            text = stringResource(R.string.duplicate),
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.error,
                        )
                    }
                    if (row.isReviewOnly) {
                        Text(
                            text = stringResource(R.string.review_only),
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.tertiary,
                        )
                    }
                    if (!row.isDuplicate) {
                        Text(
                            text = stringResource(R.string.tap_to_edit_row),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }
    }

    val editingSourceRow = editingRow
    if (editingSourceRow != null) {
        val row = importRows.firstOrNull { it.sourceRow == editingSourceRow }
        if (row != null) {
            ImportRowEditorSheet(
                row = row,
                categories = categories,
                onDismiss = { editingRow = null },
                onSave = { merchant, amountMinorUnits, categoryId, localDate ->
                    onEditImportRow(editingSourceRow, merchant, amountMinorUnits, categoryId, localDate)
                    editingRow = null
                },
            )
        } else {
            editingRow = null
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ImportRowEditorSheet(
    row: ParsedImportTransaction,
    categories: List<Category>,
    onDismiss: () -> Unit,
    onSave: (merchant: String, amountMinorUnits: Long, categoryId: CategoryId?, localDate: LocalDate?) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var merchant by remember { mutableStateOf(row.merchant) }
    var amountText by remember {
        mutableStateOf(BigDecimal(row.amount.minorUnits).movePointLeft(2).toPlainString())
    }
    var categoryId by remember { mutableStateOf(row.suggestedCategoryId) }
    var date by remember { mutableStateOf(row.localDate ?: LocalDate.now()) }
    var showDatePicker by remember { mutableStateOf(false) }

    val kindCategories = categories.filter { it.kind == row.kind && it.parentId == null }
    val amountMinorUnits = parseMoneyMinor(amountText)
    val canSave = merchant.isNotBlank() && amountMinorUnits != null

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp)
                .navigationBarsPadding()
                .imePadding()
                .padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                text = stringResource(R.string.edit_import_row_title),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )
            OutlinedTextField(
                value = merchant,
                onValueChange = { merchant = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text(stringResource(R.string.merchant_label)) },
                singleLine = true,
            )
            OutlinedTextField(
                value = amountText,
                onValueChange = { amountText = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text(stringResource(R.string.amount_label)) },
                prefix = { Text(row.amount.currency.value) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                singleLine = true,
            )
            TextButton(onClick = { showDatePicker = true }) {
                Text(stringResource(R.string.next_charge_label, date.toString()))
            }
            val uncategorizedLabel = stringResource(R.string.uncategorized)
            ManageDropdown(
                label = stringResource(R.string.category_label),
                selectedText = kindCategories.firstOrNull { it.id == categoryId }?.name
                    ?: uncategorizedLabel,
                options = listOf("" to uncategorizedLabel) +
                    kindCategories.map { it.id.value to it.name },
                onSelected = { value ->
                    categoryId = value.takeIf { it.isNotEmpty() }?.let(::CategoryId)
                },
            )
            Button(
                onClick = {
                    onSave(merchant.trim(), amountMinorUnits ?: return@Button, categoryId, date)
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                enabled = canSave,
                shape = MaterialTheme.shapes.small,
            ) {
                Text(stringResource(R.string.save_changes))
            }
        }
    }

    if (showDatePicker) {
        val datePickerState = rememberDatePickerState(
            initialSelectedDateMillis = date.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
        )
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        datePickerState.selectedDateMillis?.let { millis ->
                            date = Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate()
                        }
                        showDatePicker = false
                    },
                ) {
                    Text(stringResource(R.string.ok_action))
                }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) {
                    Text(stringResource(R.string.cancel_action))
                }
            },
        ) {
            DatePicker(state = datePickerState)
        }
    }
}

private fun android.content.ContentResolver.queryDisplayName(uri: Uri): String? =
    runCatching {
        query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) cursor.getString(index) else null
        }
    }.getOrNull()

@Composable
private fun PanelButton(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    if (selected) {
        Button(onClick = onClick, shape = MaterialTheme.shapes.small) {
            Text(label)
        }
    } else {
        FilledTonalButton(onClick = onClick, shape = MaterialTheme.shapes.small) {
            Text(label)
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun MoreScreen(
    accounts: List<Account>,
    categories: List<Category>,
    tags: List<Tag>,
    transactions: List<Transaction>,
    merchantRules: List<MerchantRule>,
    budgets: List<Budget>,
    scheduledTransactions: List<ScheduledTransaction>,
    savingsGoals: List<SavingsGoal>,
    savingsGoalContributions: List<SavingsGoalContribution>,
    debtPayoffPlans: List<DebtPayoffPlan>,
    privacySettings: PrivacySettings,
    notificationSettings: NotificationSettings,
    regionalSettings: RegionalSettings,
    backupStatus: String?,
    restorePreview: RestorePreview?,
    onSaveAccount: (Account) -> Unit,
    onArchiveAccount: (AccountId, Boolean) -> Unit,
    onSaveCategory: (Category) -> Unit,
    onSaveTag: (Tag) -> Unit,
    onSaveBudget: (Budget) -> Unit,
    onSaveSchedule: (ScheduledTransaction) -> Unit,
    onSaveSavingsGoal: (SavingsGoal) -> Unit,
    onSaveDebtPlan: (DebtPayoffPlan) -> Unit,
    onPostSchedule: (ScheduleId) -> Unit,
    onPauseSchedule: (ScheduledTransaction, Boolean) -> Unit,
    onArchiveSchedule: (ScheduleId) -> Unit,
    onArchiveCategory: (CategoryId, Boolean) -> Unit,
    onDeleteTag: (TagId) -> Unit,
    onArchiveBudget: (BudgetId, Boolean) -> Unit,
    onArchiveGoal: (SavingsGoalId, Boolean) -> Unit,
    onArchiveDebtPlan: (DebtPlanId, Boolean) -> Unit,
    onSaveContribution: (SavingsGoal, Money, SavingsGoalContributionDirection, String) -> Unit,
    onSaveRule: (MerchantRule) -> Unit,
    onToggleRule: (String, Boolean) -> Unit,
    onApplyCategorizationPlan: (CategorizationBulkApplyPlan) -> Unit,
    onSetRemindersEnabled: (Boolean, NotificationPermissionState) -> Unit,
    onExportBackup: (Uri) -> Unit,
    onExportCsv: (Uri) -> Unit,
    onPreviewRestore: (Uri) -> Unit,
    onConfirmRestore: () -> Unit,
    onCancelRestore: () -> Unit,
    onToggleAppLock: () -> Unit,
    onSaveRegionalSettings: (RegionalSettings) -> Unit,
    onDeleteWorkspace: () -> Unit,
    initialPanel: MorePanel = MorePanel.HOME,
) {
    var panel by rememberSaveable { mutableStateOf(initialPanel) }
    var activeEditor by rememberSaveable { mutableStateOf<String?>(null) }
    val primaryCurrency = accounts.firstOrNull()?.currency ?: CurrencyCode.of("AED")
    val usePersianCalendar = regionalSettings.usesPersianCalendar
    LaunchedEffect(initialPanel) {
        if (initialPanel != MorePanel.HOME) {
            panel = initialPanel
        }
    }
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .statusBarsPadding(),
        contentPadding = PaddingValues(horizontal = 22.dp, vertical = 26.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        item {
            Text(
                text = stringResource(R.string.destination_more),
                modifier = Modifier.semantics { heading() },
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = stringResource(R.string.more_subtitle),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        item {
            ProMoneySurface(Modifier.fillMaxWidth()) {
                when (panel) {
                MorePanel.HOME -> {
                    Text(stringResource(R.string.recently_added), style = MaterialTheme.typography.titleMedium)
                    accounts.takeLast(2).forEach { Text(it.name, style = MaterialTheme.typography.bodyMedium) }
                    if (accounts.isEmpty()) {
                        Text(stringResource(R.string.no_accounts_saved), style = MaterialTheme.typography.bodyMedium)
                    }
                    categories.takeLast(2).forEach { Text(it.name, style = MaterialTheme.typography.bodyMedium) }
                    tags.takeLast(2).forEach { Text(it.name, style = MaterialTheme.typography.bodyMedium) }
                }
                MorePanel.SCHEDULE -> {
                    scheduledTransactions.take(1).forEach { schedule ->
                        Text(schedule.merchant, style = MaterialTheme.typography.bodyMedium)
                        Text(
                            text = if (schedule.isActive) {
                                stringResource(
                                    R.string.schedule_upcoming,
                                    AppFormatters.date(schedule.nextDate, usePersianCalendar),
                                )
                            } else {
                                stringResource(R.string.schedule_paused)
                            },
                            style = MaterialTheme.typography.bodyMedium,
                        )
                        Text(
                            text = if (schedule.reminderEnabled) {
                                stringResource(R.string.reminder_enabled)
                            } else {
                                stringResource(R.string.reminder_disabled)
                            },
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
                }
                MorePanel.GOALS -> {
                    savingsGoals.take(1).forEach { goal ->
                        val progress = SavingsGoalCalculator.progress(goal)
                        Text(goal.name, style = MaterialTheme.typography.bodyMedium)
                        Text(
                            stringResource(R.string.goal_remaining, formatMoney(progress.remainingAmount)),
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
                }
                MorePanel.DEBT_PAYOFF -> {
                    debtPayoffPlans.take(1).forEach { plan ->
                        val summary = DebtPayoffCalculator.summary(plan)
                        val monthsText = summary.estimatedMonthsRemaining?.let {
                            stringResource(R.string.months_count, it)
                        } ?: stringResource(R.string.debt_needs_higher_payment)
                        Text(plan.name, style = MaterialTheme.typography.bodyMedium)
                        Text("${summary.strategyLabel} · $monthsText", style = MaterialTheme.typography.bodyMedium)
                    }
                }
                MorePanel.SUBSCRIPTIONS -> {
                    SubscriptionDetector.detect(transactions, LocalDate.now()).take(1).forEach {
                        Text(it.merchant, style = MaterialTheme.typography.bodyMedium)
                        Text(
                            stringResource(
                                R.string.subscription_next_expected,
                                AppFormatters.date(it.nextExpectedDate, usePersianCalendar),
                            ),
                            style = MaterialTheme.typography.bodyMedium,
                        )
                        if (it.hasPriceIncrease) {
                            Text(stringResource(R.string.subscription_price_increased), style = MaterialTheme.typography.bodyMedium)
                        }
                    }
                }
                else -> Unit
                }
            }
        }
        item {
            Text(
                text = stringResource(R.string.section_insights_planning),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )
        }
        item {
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                listOf(
                    MorePanel.SEARCH,
                    MorePanel.CALENDAR,
                    MorePanel.TRENDS,
                    MorePanel.RULES,
                    MorePanel.BUDGETS,
                    MorePanel.SCHEDULE,
                    MorePanel.GOALS,
                    MorePanel.DEBT_PAYOFF,
                    MorePanel.SUBSCRIPTIONS,
                ).forEach { target ->
                    PanelButton(
                        label = target.label(),
                        selected = panel == target,
                        onClick = { panel = target },
                    )
                }
            }
        }
        item {
            if (panel in listOf(
                    MorePanel.SEARCH,
                    MorePanel.CALENDAR,
                    MorePanel.TRENDS,
                    MorePanel.RULES,
                    MorePanel.BUDGETS,
                    MorePanel.SCHEDULE,
                    MorePanel.GOALS,
                    MorePanel.DEBT_PAYOFF,
                    MorePanel.SUBSCRIPTIONS,
                )
            ) {
                when (panel) {
                    MorePanel.SEARCH -> SearchPanel(
                        transactions = transactions,
                        accounts = accounts,
                        categories = categories,
                        usePersianCalendar = usePersianCalendar,
                    )
                    MorePanel.CALENDAR -> CalendarPanel(
                        transactions = transactions,
                        categories = categories,
                        usePersianCalendar = usePersianCalendar,
                    )
                    MorePanel.TRENDS -> TrendsPanel(
                        transactions = transactions,
                        usePersianCalendar = usePersianCalendar,
                    )
                    MorePanel.RULES -> SmartRulesPanel(
                        transactions = transactions,
                        categories = categories,
                        merchantRules = merchantRules,
                        onSaveRule = onSaveRule,
                        onToggleRule = onToggleRule,
                        onApplyPlan = onApplyCategorizationPlan,
                    )
                    MorePanel.BUDGETS -> BudgetsPanel(
                        budgets = budgets,
                        categories = categories,
                        onAddBudget = { activeEditor = "budget" },
                        onEditBudget = { activeEditor = "budget|${it.value}" },
                        onArchiveBudget = onArchiveBudget,
                    )
                    MorePanel.SCHEDULE -> SchedulePanel(
                        schedules = scheduledTransactions,
                        usePersianCalendar = usePersianCalendar,
                        onAddSchedule = { activeEditor = "schedule" },
                        onEditSchedule = { activeEditor = "schedule|${it.value}" },
                        onPostSchedule = onPostSchedule,
                        onPauseSchedule = onPauseSchedule,
                        onArchiveSchedule = onArchiveSchedule,
                    )
                    MorePanel.GOALS -> GoalsPanel(
                        goals = savingsGoals,
                        onAddGoal = { activeEditor = "goal" },
                        onEditGoal = { activeEditor = "goal|${it.value}" },
                        onContribute = { activeEditor = "contribute|${it.value}" },
                        onArchiveGoal = onArchiveGoal,
                    )
                    MorePanel.DEBT_PAYOFF -> DebtPayoffPanel(
                        plans = debtPayoffPlans,
                        onAddDebtPlan = { activeEditor = "debt" },
                        onEditDebtPlan = { activeEditor = "debt|${it.value}" },
                        onArchiveDebtPlan = onArchiveDebtPlan,
                    )
                    MorePanel.SUBSCRIPTIONS -> SubscriptionsPanel(
                        transactions = transactions,
                        usePersianCalendar = usePersianCalendar,
                    )
                    else -> Unit
                }
            }
        }
        item {
            Text(
                text = stringResource(R.string.section_manage),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )
        }
        item {
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                listOf(MorePanel.ACCOUNTS, MorePanel.CATEGORIES, MorePanel.TAGS).forEach { target ->
                    PanelButton(
                        label = target.label(),
                        selected = panel == target,
                        onClick = { panel = target },
                    )
                }
            }
        }
        item {
            when (panel) {
                MorePanel.ACCOUNTS -> ManageListPanel(
                    title = stringResource(R.string.panel_accounts),
                    addLabel = stringResource(R.string.add_account),
                    onAdd = { activeEditor = "account" },
                ) {
                    accounts.forEach { account ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column(
                                Modifier
                                    .weight(1f)
                                    .clickable { activeEditor = "account|${account.id.value}" },
                            ) {
                                Text(account.name, style = MaterialTheme.typography.bodyMedium)
                                Text(
                                    text = account.type.name.replace('_', ' ').lowercase()
                                        .replaceFirstChar { it.uppercase() } +
                                        " · ${account.currency.value}",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                            TextButton(
                                onClick = { onArchiveAccount(account.id, !account.isArchived) },
                            ) {
                                Text(
                                    if (account.isArchived) {
                                        stringResource(R.string.restore_action)
                                    } else {
                                        stringResource(R.string.archive_action)
                                    },
                                )
                            }
                        }
                    }
                }
                MorePanel.CATEGORIES -> ManageListPanel(
                    title = stringResource(R.string.panel_categories),
                    addLabel = stringResource(R.string.add_category),
                    onAdd = { activeEditor = "category" },
                ) {
                    categories.filter { !it.isArchived && it.parentId == null }.forEach { category ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                text = "${category.name} · " +
                                    category.kind.name.lowercase().replaceFirstChar { it.uppercase() },
                                modifier = Modifier
                                    .weight(1f)
                                    .clickable { activeEditor = "category|${category.id.value}" },
                                style = MaterialTheme.typography.bodyMedium,
                            )
                            TextButton(onClick = { onArchiveCategory(category.id, true) }) {
                                Text(stringResource(R.string.archive_action))
                            }
                        }
                    }
                }
                MorePanel.TAGS -> ManageListPanel(
                    title = stringResource(R.string.panel_tags),
                    addLabel = stringResource(R.string.add_tag),
                    onAdd = { activeEditor = "tag" },
                ) {
                    tags.forEach { tag ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                tag.name,
                                modifier = Modifier
                                    .weight(1f)
                                    .clickable { activeEditor = "tag|${tag.id.value}" },
                                style = MaterialTheme.typography.bodyMedium,
                            )
                            TextButton(onClick = { onDeleteTag(tag.id) }) {
                                Text(stringResource(R.string.delete_action))
                            }
                        }
                    }
                }
                else -> Unit
            }
        }
        item {
            Text(
                text = stringResource(R.string.section_settings),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )
        }
        item {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    listOf(
                        MorePanel.BACKUP,
                        MorePanel.PRIVACY,
                        MorePanel.NOTIFICATIONS,
                        MorePanel.LANGUAGE,
                        MorePanel.ANDROID,
                    ).forEach { target ->
                        PanelButton(
                            label = target.label(),
                            selected = panel == target,
                            onClick = { panel = target },
                        )
                    }
                }
                when (panel) {
                    MorePanel.BACKUP -> {
                        Text(stringResource(R.string.backup_package_title), style = MaterialTheme.typography.titleMedium)
                        Text(stringResource(R.string.restore_preview), style = MaterialTheme.typography.bodyMedium)
                        Text(stringResource(R.string.legacy_export_report), style = MaterialTheme.typography.bodyMedium)
                        Text(stringResource(R.string.backup_local_notice), style = MaterialTheme.typography.bodyMedium)
                    }
                    MorePanel.PRIVACY -> {
                        Text(stringResource(R.string.privacy_lock_title), style = MaterialTheme.typography.titleMedium)
                        Text(
                            if (privacySettings.appLockEnabled) {
                                stringResource(R.string.app_lock_enabled)
                            } else {
                                stringResource(R.string.app_lock_disabled)
                            },
                            style = MaterialTheme.typography.bodyMedium,
                        )
                        Text(
                            if (privacySettings.secureScreenEnabled) {
                                stringResource(R.string.secure_screen_enabled)
                            } else {
                                stringResource(R.string.secure_screen_disabled)
                            },
                            style = MaterialTheme.typography.bodyMedium,
                        )
                        Text(
                            stringResource(R.string.delete_workspace_description),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Button(
                            onClick = onDeleteWorkspace,
                            shape = MaterialTheme.shapes.small,
                            colors = ButtonDefaults.buttonColors(
                                containerColor = MaterialTheme.colorScheme.error,
                                contentColor = MaterialTheme.colorScheme.onError,
                            ),
                        ) {
                            Text(stringResource(R.string.delete_workspace_button))
                        }
                    }
                    MorePanel.NOTIFICATIONS -> {
                        Text(stringResource(R.string.reminder_permission_not_requested), style = MaterialTheme.typography.bodyMedium)
                        Text(
                            stringResource(R.string.reminder_permission_note),
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
                    MorePanel.LANGUAGE -> {
                        Text(stringResource(R.string.language_region), style = MaterialTheme.typography.titleMedium)
                        Text(regionalSettings.language.displayName, style = MaterialTheme.typography.bodyMedium)
                        Text(stringResource(R.string.rtl_notice), style = MaterialTheme.typography.bodyMedium)
                        Text(stringResource(R.string.persian_calendar_supported), style = MaterialTheme.typography.bodyMedium)
                    }
                    MorePanel.ANDROID -> {
                        AndroidEnhancementsPanel()
                    }
                    else -> Unit
                }
            }
        }
        item {
            if (panel in listOf(MorePanel.BACKUP, MorePanel.PRIVACY, MorePanel.NOTIFICATIONS, MorePanel.LANGUAGE)) {
                when (panel) {
                    MorePanel.BACKUP -> BackupSettingsPanel(
                        snapshotForReport = BackupEngine.completeSnapshot(
                            createdAt = Instant.now(),
                            accounts = accounts,
                            categories = categories,
                            tags = tags,
                            transactions = transactions,
                            merchantRules = merchantRules,
                            budgets = budgets,
                            scheduledTransactions = scheduledTransactions,
                            savingsGoals = savingsGoals,
                            savingsGoalContributions = savingsGoalContributions,
                            debtPayoffPlans = debtPayoffPlans,
                        ),
                        backupStatus = backupStatus,
                        restorePreview = restorePreview,
                        onExportBackup = onExportBackup,
                        onExportCsv = onExportCsv,
                        onPreviewRestore = onPreviewRestore,
                        onConfirmRestore = onConfirmRestore,
                        onCancelRestore = onCancelRestore,
                    )
                    MorePanel.PRIVACY -> PrivacyPanel(
                        onToggleAppLock = onToggleAppLock,
                    )
                    MorePanel.NOTIFICATIONS -> NotificationsSettingsPanel(
                        settings = notificationSettings,
                        onSetRemindersEnabled = onSetRemindersEnabled,
                    )
                    MorePanel.LANGUAGE -> LanguagePanel(
                        settings = regionalSettings,
                        onSave = onSaveRegionalSettings,
                    )
                    else -> Unit
                }
            }
        }
    }

    val editorKind = activeEditor?.substringBefore('|')
    val editorId = activeEditor?.substringAfter('|', missingDelimiterValue = "")?.takeIf { it.isNotEmpty() }
    when (editorKind) {
        "account" -> AccountEditorSheet(
            existing = accounts.firstOrNull { it.id.value == editorId },
            knownCurrencies = accounts.map { it.currency.value }.distinct(),
            onDismiss = { activeEditor = null },
            onSave = { account ->
                onSaveAccount(account)
                activeEditor = null
            },
        )
        "category" -> CategoryEditorSheet(
            existing = categories.firstOrNull { it.id.value == editorId },
            onDismiss = { activeEditor = null },
            onSave = { category ->
                onSaveCategory(category)
                activeEditor = null
            },
        )
        "tag" -> TagEditorSheet(
            existing = tags.firstOrNull { it.id.value == editorId },
            onDismiss = { activeEditor = null },
            onSave = { tag ->
                onSaveTag(tag)
                activeEditor = null
            },
        )
        "budget" -> BudgetEditorSheet(
            existing = budgets.firstOrNull { it.id.value == editorId },
            expenseCategories = categories.filter {
                it.kind == TransactionKind.EXPENSE && it.parentId == null && !it.isArchived
            },
            currency = primaryCurrency,
            onDismiss = { activeEditor = null },
            onSave = { budget ->
                onSaveBudget(budget)
                activeEditor = null
            },
        )
        "schedule" -> ScheduleEditorSheet(
            existing = scheduledTransactions.firstOrNull { it.id.value == editorId },
            accounts = accounts.filter { !it.isArchived },
            onDismiss = { activeEditor = null },
            onSave = { schedule ->
                onSaveSchedule(schedule)
                activeEditor = null
            },
        )
        "goal" -> GoalEditorSheet(
            existing = savingsGoals.firstOrNull { it.id.value == editorId },
            currency = primaryCurrency,
            onDismiss = { activeEditor = null },
            onSave = { goal ->
                onSaveSavingsGoal(goal)
                activeEditor = null
            },
        )
        "contribute" -> savingsGoals.firstOrNull { it.id.value == editorId }?.let { goal ->
            GoalContributionSheet(
                goal = goal,
                onDismiss = { activeEditor = null },
                onSave = { amount, direction, note ->
                    onSaveContribution(goal, amount, direction, note)
                    activeEditor = null
                },
            )
        }
        "debt" -> DebtEditorSheet(
            existing = debtPayoffPlans.firstOrNull { it.id.value == editorId },
            currency = primaryCurrency,
            onDismiss = { activeEditor = null },
            onSave = { plan ->
                onSaveDebtPlan(plan)
                activeEditor = null
            },
        )
    }
}

@Composable
private fun PrivacyPanel(
    onToggleAppLock: () -> Unit,
) {
    ProMoneySurface(Modifier.fillMaxWidth()) {
        Text(stringResource(R.string.lock_details_title), style = MaterialTheme.typography.titleMedium)
        Text(
            stringResource(R.string.lock_details_description),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Button(onClick = onToggleAppLock, shape = MaterialTheme.shapes.small) {
                Text(stringResource(R.string.toggle_app_lock))
            }
        }
    }
}

@Composable
private fun LanguagePanel(
    settings: RegionalSettings,
    onSave: (RegionalSettings) -> Unit,
) {
    ProMoneySurface(Modifier.fillMaxWidth()) {
        Text(stringResource(R.string.region_details), style = MaterialTheme.typography.titleMedium)
        Text(settings.language.languageTag, style = MaterialTheme.typography.bodyMedium)
        Text(
            "${settings.baseCurrency.value} · ${settings.countryCode} · ${settings.timeZoneId}",
            style = MaterialTheme.typography.bodyMedium,
        )
        RegionalSettingsEditor(
            settings = settings,
            actionLabel = stringResource(R.string.save_regional_settings),
            onSave = onSave,
        )
    }
}

@Composable
private fun AndroidEnhancementsPanel() {
    val shortcuts = AppShortcutSpec.defaults()
    val actions = ScheduledNotificationAction.defaults()
    val widgetDisplay = WidgetSnapshot(
        safeToSpend = "AED 0.00",
        monthIncome = "AED 0.00",
        monthExpense = "AED 0.00",
        upcomingBill = "No upcoming bills",
        privacyMode = WidgetPrivacyMode.REDACTED,
    ).display()
    val ocrDraft = OcrReviewDraft(
        sourceLabel = "Receipt camera",
        recognizedText = "",
        confidence = OcrConfidence.LOW,
    )
    val smsPolicy = SmsIngestionPolicy()

    ProMoneySurface(Modifier.fillMaxWidth()) {
        Text(stringResource(R.string.android_gates_title), style = MaterialTheme.typography.titleMedium)
        Text(stringResource(R.string.share_target_imports), style = MaterialTheme.typography.bodyMedium)
        Text(
            stringResource(R.string.shortcut_suffix, shortcuts.first { it.id == "add_expense" }.shortLabel),
            style = MaterialTheme.typography.bodyMedium,
        )
        Text(
            stringResource(R.string.shortcut_suffix, shortcuts.first { it.id == "import_statement" }.shortLabel),
            style = MaterialTheme.typography.bodyMedium,
        )
        Text(
            stringResource(R.string.widget_hidden_notice),
            style = MaterialTheme.typography.bodyMedium,
        )
        Text(
            stringResource(R.string.widget_safe_to_spend, widgetDisplay.safeToSpend),
            style = MaterialTheme.typography.bodyMedium,
        )
        Text(
            stringResource(R.string.notification_actions_list, actions.joinToString { it.label }),
            style = MaterialTheme.typography.bodyMedium,
        )
        Text(
            text = if (!ocrDraft.canAutoSave) {
                stringResource(R.string.ocr_requires_review)
            } else {
                stringResource(R.string.ocr_can_save)
            },
            style = MaterialTheme.typography.bodyMedium,
        )
        Text(
            text = if (!smsPolicy.isEnabled) {
                stringResource(R.string.sms_disabled)
            } else {
                stringResource(R.string.sms_enabled)
            },
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}

@Composable
private fun ManageListPanel(
    title: String,
    addLabel: String,
    onAdd: () -> Unit,
    content: @Composable ColumnScope.() -> Unit,
) {
    ProMoneySurface(Modifier.fillMaxWidth()) {
        Text(title, style = MaterialTheme.typography.titleMedium)
        content()
        Button(onClick = onAdd, shape = MaterialTheme.shapes.small) {
            Text(addLabel)
        }
    }
}

@Composable
private fun BudgetsPanel(
    budgets: List<Budget>,
    categories: List<Category>,
    onAddBudget: () -> Unit,
    onEditBudget: (BudgetId) -> Unit,
    onArchiveBudget: (BudgetId, Boolean) -> Unit,
) {
    val categoryNames = categories.associate { it.id to it.name }
    ProMoneySurface(Modifier.fillMaxWidth()) {
        Text(stringResource(R.string.budget_center_title), style = MaterialTheme.typography.titleMedium)
        Text(
            stringResource(R.string.budgets_saved_count, budgets.count { !it.isArchived }),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        budgets.filter { !it.isArchived }.forEach { budget ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "${categoryNames[budget.categoryId] ?: budget.categoryId.value} · " +
                        "${budget.month} · ${formatMoney(budget.amount)}",
                    modifier = Modifier
                        .weight(1f)
                        .clickable { onEditBudget(budget.id) },
                    style = MaterialTheme.typography.bodyMedium,
                )
                TextButton(onClick = { onArchiveBudget(budget.id, true) }) {
                    Text(stringResource(R.string.archive_action))
                }
            }
        }
        Button(onClick = onAddBudget, shape = MaterialTheme.shapes.small) {
            Text(stringResource(R.string.add_budget))
        }
    }
}

@Composable
private fun SchedulePanel(
    schedules: List<ScheduledTransaction>,
    usePersianCalendar: Boolean,
    onAddSchedule: () -> Unit,
    onEditSchedule: (ScheduleId) -> Unit,
    onPostSchedule: (ScheduleId) -> Unit,
    onPauseSchedule: (ScheduledTransaction, Boolean) -> Unit,
    onArchiveSchedule: (ScheduleId) -> Unit,
) {
    ProMoneySurface(Modifier.fillMaxWidth()) {
        Text(stringResource(R.string.panel_schedule), style = MaterialTheme.typography.titleMedium)
        if (schedules.isEmpty()) {
            Text(
                stringResource(R.string.no_scheduled_transactions),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        schedules.forEach { schedule ->
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(MaterialTheme.shapes.small)
                    .clickable { onEditSchedule(schedule.id) }
                    .padding(vertical = 6.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        schedule.merchant,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        formatMoney(schedule.amount),
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
                Text(
                    text = if (schedule.isActive) {
                        stringResource(
                            R.string.schedule_upcoming,
                            AppFormatters.date(schedule.nextDate, usePersianCalendar),
                        )
                    } else {
                        stringResource(R.string.schedule_paused)
                    },
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    TextButton(onClick = { onPostSchedule(schedule.id) }) {
                        Text(stringResource(R.string.post_now))
                    }
                    TextButton(onClick = { onPauseSchedule(schedule, schedule.isActive) }) {
                        Text(
                            if (schedule.isActive) {
                                stringResource(R.string.pause_action)
                            } else {
                                stringResource(R.string.resume_action)
                            },
                        )
                    }
                    TextButton(onClick = { onArchiveSchedule(schedule.id) }) {
                        Text(stringResource(R.string.delete_action))
                    }
                }
            }
        }
        Button(onClick = onAddSchedule, shape = MaterialTheme.shapes.small) {
            Text(stringResource(R.string.add_schedule))
        }
    }
}

@Composable
private fun GoalsPanel(
    goals: List<SavingsGoal>,
    onAddGoal: () -> Unit,
    onEditGoal: (SavingsGoalId) -> Unit,
    onContribute: (SavingsGoalId) -> Unit,
    onArchiveGoal: (SavingsGoalId, Boolean) -> Unit,
) {
    ProMoneySurface(Modifier.fillMaxWidth()) {
        Text(stringResource(R.string.panel_goals), style = MaterialTheme.typography.titleMedium)
        val activeGoals = goals.filter { !it.isArchived }
        if (activeGoals.isEmpty()) {
            Text(
                stringResource(R.string.no_savings_goals),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        activeGoals.forEach { goal ->
            val progress = SavingsGoalCalculator.progress(goal)
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(MaterialTheme.shapes.small)
                    .clickable { onEditGoal(goal.id) }
                    .padding(vertical = 6.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(goal.name, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                    Text(
                        stringResource(R.string.percent_value, progress.percentComplete),
                        style = MaterialTheme.typography.labelLarge,
                    )
                }
                Text(
                    stringResource(R.string.goal_remaining, formatMoney(progress.remainingAmount)),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    TextButton(onClick = { onContribute(goal.id) }) {
                        Text(stringResource(R.string.contribute_action))
                    }
                    TextButton(onClick = { onArchiveGoal(goal.id, true) }) {
                        Text(stringResource(R.string.archive_action))
                    }
                }
            }
        }
        Button(onClick = onAddGoal, shape = MaterialTheme.shapes.small) {
            Text(stringResource(R.string.add_goal))
        }
    }
}

@Composable
private fun DebtPayoffPanel(
    plans: List<DebtPayoffPlan>,
    onAddDebtPlan: () -> Unit,
    onEditDebtPlan: (DebtPlanId) -> Unit,
    onArchiveDebtPlan: (DebtPlanId, Boolean) -> Unit,
) {
    ProMoneySurface(Modifier.fillMaxWidth()) {
        Text(stringResource(R.string.panel_debt_payoff), style = MaterialTheme.typography.titleMedium)
        val activePlans = plans.filter { !it.isArchived }
        if (activePlans.isEmpty()) {
            Text(
                stringResource(R.string.no_debt_plans),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        activePlans.forEach { plan ->
            val summary = DebtPayoffCalculator.summary(plan)
            val monthsText = summary.estimatedMonthsRemaining?.let {
                stringResource(R.string.months_count, it)
            } ?: stringResource(R.string.debt_needs_higher_payment)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(
                    Modifier
                        .weight(1f)
                        .clickable { onEditDebtPlan(plan.id) },
                ) {
                    Text(plan.name, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                    Text(
                        "${summary.strategyLabel} · $monthsText · ${formatMoney(plan.currentBalance)}",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                TextButton(onClick = { onArchiveDebtPlan(plan.id, true) }) {
                    Text(stringResource(R.string.archive_action))
                }
            }
        }
        Button(onClick = onAddDebtPlan, shape = MaterialTheme.shapes.small) {
            Text(stringResource(R.string.add_debt_plan))
        }
    }
}

@Composable
private fun SubscriptionsPanel(
    transactions: List<Transaction>,
    usePersianCalendar: Boolean,
) {
    val candidates = SubscriptionDetector.detect(
        transactions = transactions,
        asOf = LocalDate.now(),
    )
    ProMoneySurface(Modifier.fillMaxWidth()) {
        Text(stringResource(R.string.panel_subscriptions), style = MaterialTheme.typography.titleMedium)
        if (candidates.isEmpty()) {
            Text(
                stringResource(R.string.no_subscriptions_detected),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Text(stringResource(R.string.subscriptions_candidates_count, candidates.size), style = MaterialTheme.typography.bodyMedium)
        candidates.take(10).forEach { candidate ->
            Column(Modifier.padding(vertical = 4.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(candidate.merchant, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                    Text(formatMoney(candidate.averageAmount), style = MaterialTheme.typography.labelLarge)
                }
                Text(
                    stringResource(
                        R.string.subscription_next_expected,
                        AppFormatters.date(candidate.nextExpectedDate, usePersianCalendar),
                    ),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                if (candidate.hasPriceIncrease) {
                    Text(
                        stringResource(R.string.subscription_price_increased),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }
        }
    }
}

private fun formatMoney(money: Money): String = AppFormatters.money(money)
