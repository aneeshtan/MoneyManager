package com.farshadghanzanfari.promoneymanager

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.farshadghanzanfari.promoneymanager.core.model.Account
import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.AccountType
import com.farshadghanzanfari.promoneymanager.core.model.Budget
import com.farshadghanzanfari.promoneymanager.core.model.BudgetId
import com.farshadghanzanfari.promoneymanager.core.model.Category
import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.DebtPayoffPlan
import com.farshadghanzanfari.promoneymanager.core.model.DebtPayoffStrategy
import com.farshadghanzanfari.promoneymanager.core.model.DebtPlanId
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoal
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalContributionDirection
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalId
import com.farshadghanzanfari.promoneymanager.core.model.ScheduleFrequency
import com.farshadghanzanfari.promoneymanager.core.model.ScheduleId
import com.farshadghanzanfari.promoneymanager.core.model.ScheduledTransaction
import com.farshadghanzanfari.promoneymanager.core.model.Tag
import com.farshadghanzanfari.promoneymanager.core.model.TagId
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import java.math.BigDecimal
import java.math.RoundingMode
import java.time.Instant
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.UUID

private val sheetDateFormatter = DateTimeFormatter.ofPattern("MMM d, yyyy", Locale.ENGLISH)
private val sheetMonthFormatter = DateTimeFormatter.ofPattern("MMMM yyyy", Locale.ENGLISH)

internal val tagColorPalette = listOf(
    "8151D1", "168A7D", "E65F70", "E4AE32", "2F6FDB", "6B7280",
)

internal val commonCurrencies = listOf("AED", "USD", "EUR", "GBP", "SAR", "INR", "PKR")

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ManageSheet(
    title: String,
    onDismiss: () -> Unit,
    content: @Composable () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
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
                text = title,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )
            content()
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun ManageDropdown(
    label: String,
    selectedText: String,
    options: List<Pair<String, String>>,
    onSelected: (String) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    ExposedDropdownMenuBox(
        expanded = expanded,
        onExpandedChange = { expanded = it },
    ) {
        OutlinedTextField(
            value = selectedText,
            onValueChange = {},
            modifier = Modifier
                .fillMaxWidth()
                .menuAnchor(MenuAnchorType.PrimaryNotEditable),
            label = { Text(label) },
            readOnly = true,
            singleLine = true,
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
        )
        ExposedDropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
        ) {
            options.forEach { (value, text) ->
                DropdownMenuItem(
                    text = { Text(text) },
                    onClick = {
                        onSelected(value)
                        expanded = false
                    },
                )
            }
        }
    }
}

@Composable
private fun SaveButton(label: String, enabled: Boolean, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp),
        enabled = enabled,
        shape = MaterialTheme.shapes.small,
    ) {
        Text(label)
    }
}

internal fun parseMoneyMinor(text: String, allowZero: Boolean = false): Long? = runCatching {
    val cleaned = text.trim().replace(",", "")
    if (cleaned.isEmpty()) return null
    BigDecimal(cleaned).movePointRight(2).setScale(0, RoundingMode.HALF_UP).longValueExact()
}.getOrNull()?.takeIf { it > 0 || (allowZero && it == 0L) }

private fun accountTypeLabel(type: AccountType): String = type.name
    .replace('_', ' ')
    .lowercase()
    .replaceFirstChar { it.uppercase() }

@Composable
internal fun AccountEditorSheet(
    existing: Account?,
    knownCurrencies: List<String>,
    onDismiss: () -> Unit,
    onSave: (Account) -> Unit,
) {
    var name by remember { mutableStateOf(existing?.name ?: "") }
    var type by remember { mutableStateOf(existing?.type ?: AccountType.BANK) }
    var currencyCode by remember { mutableStateOf(existing?.currency?.value ?: knownCurrencies.firstOrNull() ?: "AED") }
    var openingText by remember {
        mutableStateOf(
            existing?.openingBalance
                ?.takeIf { it.minorUnits != 0L }
                ?.let { BigDecimal(it.minorUnits).movePointLeft(2).toPlainString() }
                ?: "",
        )
    }
    val openingMinor = if (openingText.isBlank()) 0L else parseMoneyMinor(openingText, allowZero = true)
    val canSave = name.isNotBlank() && openingMinor != null

    ManageSheet(
        title = if (existing == null) stringResource(R.string.add_account) else stringResource(R.string.edit_account_title),
        onDismiss = onDismiss,
    ) {
        OutlinedTextField(
            value = name,
            onValueChange = { name = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.account_name_label)) },
            singleLine = true,
        )
        ManageDropdown(
            label = stringResource(R.string.type_label),
            selectedText = accountTypeLabel(type),
            options = AccountType.entries.map { it.name to accountTypeLabel(it) },
            onSelected = { type = AccountType.valueOf(it) },
        )
        ManageDropdown(
            label = stringResource(R.string.currency_label),
            selectedText = currencyCode,
            options = (knownCurrencies + commonCurrencies).distinct().map { it to it },
            onSelected = { currencyCode = it },
        )
        OutlinedTextField(
            value = openingText,
            onValueChange = { openingText = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.opening_balance_label)) },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            singleLine = true,
        )
        SaveButton(label = stringResource(R.string.save_account), enabled = canSave) {
            val currency = runCatching { CurrencyCode.of(currencyCode) }.getOrNull() ?: return@SaveButton
            val built = runCatching {
                Account(
                    id = existing?.id ?: AccountId("acct-${UUID.randomUUID()}"),
                    name = name.trim(),
                    currency = currency,
                    openingBalance = Money(openingMinor ?: 0L, currency),
                    type = type,
                    isArchived = existing?.isArchived ?: false,
                )
            }.getOrNull() ?: return@SaveButton
            onSave(built)
        }
    }
}

@Composable
internal fun CategoryEditorSheet(
    existing: Category?,
    onDismiss: () -> Unit,
    onSave: (Category) -> Unit,
) {
    var name by remember { mutableStateOf(existing?.name ?: "") }
    var kind by remember { mutableStateOf(existing?.kind ?: TransactionKind.EXPENSE) }

    ManageSheet(
        title = if (existing == null) stringResource(R.string.add_category) else stringResource(R.string.edit_category_title),
        onDismiss = onDismiss,
    ) {
        val expenseLabel = stringResource(R.string.expense_label)
        val incomeLabel = stringResource(R.string.income_label)
        SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
            listOf(TransactionKind.EXPENSE to expenseLabel, TransactionKind.INCOME to incomeLabel)
                .forEachIndexed { index, (option, label) ->
                    SegmentedButton(
                        selected = kind == option,
                        onClick = { kind = option },
                        shape = SegmentedButtonDefaults.itemShape(index = index, count = 2),
                    ) {
                        Text(label)
                    }
                }
        }
        OutlinedTextField(
            value = name,
            onValueChange = { name = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.category_name_label)) },
            singleLine = true,
        )
        SaveButton(label = stringResource(R.string.save_category), enabled = name.isNotBlank()) {
            val built = runCatching {
                Category(
                    id = existing?.id ?: CategoryId("cat-${UUID.randomUUID()}"),
                    name = name.trim(),
                    kind = kind,
                    parentId = existing?.parentId,
                    sortOrder = existing?.sortOrder ?: 0,
                    isArchived = existing?.isArchived ?: false,
                )
            }.getOrNull() ?: return@SaveButton
            onSave(built)
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun TagEditorSheet(
    existing: Tag?,
    onDismiss: () -> Unit,
    onSave: (Tag) -> Unit,
) {
    var name by remember { mutableStateOf(existing?.name ?: "") }
    var colorHex by remember { mutableStateOf(existing?.colorHex ?: tagColorPalette.first()) }

    ManageSheet(
        title = if (existing == null) stringResource(R.string.add_tag) else stringResource(R.string.edit_tag_title),
        onDismiss = onDismiss,
    ) {
        OutlinedTextField(
            value = name,
            onValueChange = { name = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.tag_name_label)) },
            singleLine = true,
        )
        Text(
            text = stringResource(R.string.color_label),
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            tagColorPalette.forEach { hex ->
                FilterChip(
                    selected = colorHex == hex,
                    onClick = { colorHex = hex },
                    label = {
                        Box(
                            modifier = Modifier
                                .size(20.dp)
                                .clip(CircleShape)
                                .background(Color(("FF$hex").toLong(16))),
                        )
                    },
                )
            }
        }
        SaveButton(label = stringResource(R.string.save_tag), enabled = name.isNotBlank()) {
            val built = runCatching {
                Tag(
                    id = existing?.id ?: TagId("tag-${UUID.randomUUID()}"),
                    name = name.trim(),
                    colorHex = colorHex,
                )
            }.getOrNull() ?: return@SaveButton
            onSave(built)
        }
    }
}

@Composable
internal fun BudgetEditorSheet(
    expenseCategories: List<Category>,
    currency: CurrencyCode,
    onDismiss: () -> Unit,
    onSave: (Budget) -> Unit,
    existing: Budget? = null,
) {
    var categoryId by remember { mutableStateOf(existing?.categoryId ?: expenseCategories.firstOrNull()?.id) }
    var amountText by remember {
        mutableStateOf(
            existing?.amount?.let { BigDecimal(it.minorUnits).movePointLeft(2).toPlainString() } ?: "",
        )
    }
    var month by remember { mutableStateOf(existing?.month ?: YearMonth.now()) }
    val amountMinor = parseMoneyMinor(amountText)
    val canSave = categoryId != null && amountMinor != null

    ManageSheet(
        title = if (existing == null) {
            stringResource(R.string.add_budget_title)
        } else {
            stringResource(R.string.edit_budget_title)
        },
        onDismiss = onDismiss,
    ) {
        ManageDropdown(
            label = stringResource(R.string.category_label),
            selectedText = expenseCategories.firstOrNull { it.id == categoryId }?.name ?: "",
            options = expenseCategories.map { it.id.value to it.name },
            onSelected = { value -> categoryId = CategoryId(value) },
        )
        ManageDropdown(
            label = stringResource(R.string.month_label),
            selectedText = month.atDay(1).format(sheetMonthFormatter),
            options = (-1..11).map { offset ->
                val candidate = YearMonth.now().plusMonths(offset.toLong())
                candidate.toString() to candidate.atDay(1).format(sheetMonthFormatter)
            },
            onSelected = { month = YearMonth.parse(it) },
        )
        OutlinedTextField(
            value = amountText,
            onValueChange = { amountText = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.monthly_amount_label)) },
            prefix = { Text(currency.value) },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            singleLine = true,
        )
        SaveButton(label = stringResource(R.string.save_budget), enabled = canSave) {
            val selectedCategory = categoryId ?: return@SaveButton
            val built = runCatching {
                Budget(
                    id = existing?.id ?: BudgetId("budget-${UUID.randomUUID()}"),
                    categoryId = selectedCategory,
                    month = month,
                    amount = Money(amountMinor ?: return@SaveButton, currency),
                    subcategoryId = existing?.subcategoryId
                        ?.takeIf { selectedCategory == existing.categoryId },
                    rolloverEnabled = existing?.rolloverEnabled ?: false,
                    isArchived = existing?.isArchived ?: false,
                )
            }.getOrNull() ?: return@SaveButton
            onSave(built)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun ScheduleEditorSheet(
    accounts: List<Account>,
    onDismiss: () -> Unit,
    onSave: (ScheduledTransaction) -> Unit,
    existing: ScheduledTransaction? = null,
) {
    var merchant by remember { mutableStateOf(existing?.merchant ?: "") }
    var amountText by remember {
        mutableStateOf(
            existing?.amount?.let { BigDecimal(it.minorUnits).movePointLeft(2).toPlainString() } ?: "",
        )
    }
    var accountId by remember { mutableStateOf(existing?.accountId ?: accounts.firstOrNull()?.id) }
    var frequency by remember { mutableStateOf(existing?.frequency ?: ScheduleFrequency.MONTHLY) }
    var nextDate by remember { mutableStateOf(existing?.nextDate ?: LocalDate.now().plusMonths(1)) }
    var reminderEnabled by remember { mutableStateOf(existing?.reminderEnabled ?: false) }
    var showDatePicker by remember { mutableStateOf(false) }
    val amountMinor = parseMoneyMinor(amountText)
    val canSave = merchant.isNotBlank() && amountMinor != null && accountId != null

    ManageSheet(
        title = if (existing == null) {
            stringResource(R.string.add_schedule_title)
        } else {
            stringResource(R.string.edit_schedule_title)
        },
        onDismiss = onDismiss,
    ) {
        OutlinedTextField(
            value = merchant,
            onValueChange = { merchant = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.payee_label)) },
            singleLine = true,
        )
        OutlinedTextField(
            value = amountText,
            onValueChange = { amountText = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.amount_label)) },
            prefix = {
                Text(accounts.firstOrNull { it.id == accountId }?.currency?.value ?: "")
            },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            singleLine = true,
        )
        ManageDropdown(
            label = stringResource(R.string.account_label),
            selectedText = accounts.firstOrNull { it.id == accountId }?.name ?: "",
            options = accounts.map { it.id.value to it.name },
            onSelected = { accountId = AccountId(it) },
        )
        ManageDropdown(
            label = stringResource(R.string.repeats_label),
            selectedText = frequency.name.lowercase().replaceFirstChar { it.uppercase() },
            options = ScheduleFrequency.entries.map {
                it.name to it.name.lowercase().replaceFirstChar { c -> c.uppercase() }
            },
            onSelected = { frequency = ScheduleFrequency.valueOf(it) },
        )
        TextButton(onClick = { showDatePicker = true }) {
            Text(stringResource(R.string.next_charge_label, nextDate.format(sheetDateFormatter)))
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                stringResource(R.string.reminder_day_before),
                style = MaterialTheme.typography.bodyMedium,
            )
            Switch(checked = reminderEnabled, onCheckedChange = { reminderEnabled = it })
        }
        SaveButton(label = stringResource(R.string.save_schedule), enabled = canSave) {
            val selectedAccountId = accountId ?: return@SaveButton
            val currency = accounts.firstOrNull { it.id == selectedAccountId }?.currency
                ?: return@SaveButton
            val built = runCatching {
                ScheduledTransaction(
                    id = existing?.id ?: ScheduleId("sched-${UUID.randomUUID()}"),
                    accountId = selectedAccountId,
                    amount = Money(amountMinor ?: return@SaveButton, currency),
                    kind = existing?.kind ?: TransactionKind.EXPENSE,
                    merchant = merchant.trim(),
                    categoryId = existing?.categoryId,
                    subcategoryId = existing?.subcategoryId,
                    note = existing?.note ?: "",
                    frequency = frequency,
                    nextDate = nextDate,
                    lastRunDate = existing?.lastRunDate,
                    status = existing?.status ?: com.farshadghanzanfari.promoneymanager.core.model.ScheduleStatus.ACTIVE,
                    reminderEnabled = reminderEnabled,
                )
            }.getOrNull() ?: return@SaveButton
            onSave(built)
        }
    }

    if (showDatePicker) {
        val datePickerState = rememberDatePickerState(
            initialSelectedDateMillis = nextDate.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
        )
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        datePickerState.selectedDateMillis?.let { millis ->
                            nextDate = Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate()
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

@Composable
internal fun GoalEditorSheet(
    currency: CurrencyCode,
    onDismiss: () -> Unit,
    onSave: (SavingsGoal) -> Unit,
    existing: SavingsGoal? = null,
) {
    var name by remember { mutableStateOf(existing?.name ?: "") }
    var targetText by remember {
        mutableStateOf(
            existing?.targetAmount?.let { BigDecimal(it.minorUnits).movePointLeft(2).toPlainString() } ?: "",
        )
    }
    var currentText by remember {
        mutableStateOf(
            existing?.currentAmount
                ?.takeIf { it.minorUnits != 0L }
                ?.let { BigDecimal(it.minorUnits).movePointLeft(2).toPlainString() }
                ?: "",
        )
    }
    val targetMinor = parseMoneyMinor(targetText)
    val currentMinor = if (currentText.isBlank()) 0L else parseMoneyMinor(currentText, allowZero = true)
    val canSave = name.isNotBlank() && targetMinor != null && currentMinor != null

    ManageSheet(
        title = if (existing == null) {
            stringResource(R.string.add_goal_title)
        } else {
            stringResource(R.string.edit_goal_title)
        },
        onDismiss = onDismiss,
    ) {
        OutlinedTextField(
            value = name,
            onValueChange = { name = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.goal_name_label)) },
            singleLine = true,
        )
        OutlinedTextField(
            value = targetText,
            onValueChange = { targetText = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.target_amount_label)) },
            prefix = { Text(currency.value) },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            singleLine = true,
        )
        OutlinedTextField(
            value = currentText,
            onValueChange = { currentText = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.saved_so_far_label)) },
            prefix = { Text(currency.value) },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            singleLine = true,
        )
        SaveButton(label = stringResource(R.string.save_goal), enabled = canSave) {
            val built = runCatching {
                SavingsGoal(
                    id = existing?.id ?: SavingsGoalId("goal-${UUID.randomUUID()}"),
                    name = name.trim(),
                    targetAmount = Money(targetMinor ?: return@SaveButton, currency),
                    currentAmount = Money(currentMinor ?: 0L, currency),
                    targetDate = existing?.targetDate,
                    isArchived = existing?.isArchived ?: false,
                )
            }.getOrNull() ?: return@SaveButton
            onSave(built)
        }
    }
}

@Composable
internal fun GoalContributionSheet(
    goal: SavingsGoal,
    onDismiss: () -> Unit,
    onSave: (Money, SavingsGoalContributionDirection, String) -> Unit,
) {
    var amountText by remember { mutableStateOf("") }
    var direction by remember { mutableStateOf(SavingsGoalContributionDirection.CONTRIBUTION) }
    var note by remember { mutableStateOf("") }
    val amountMinor = parseMoneyMinor(amountText)

    ManageSheet(
        title = stringResource(R.string.contribute_to_goal, goal.name),
        onDismiss = onDismiss,
    ) {
        val contributeLabel = stringResource(R.string.contribution_label)
        val withdrawLabel = stringResource(R.string.withdrawal_label)
        SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
            listOf(
                SavingsGoalContributionDirection.CONTRIBUTION to contributeLabel,
                SavingsGoalContributionDirection.WITHDRAWAL to withdrawLabel,
            ).forEachIndexed { index, (option, label) ->
                SegmentedButton(
                    selected = direction == option,
                    onClick = { direction = option },
                    shape = SegmentedButtonDefaults.itemShape(index = index, count = 2),
                ) {
                    Text(label)
                }
            }
        }
        OutlinedTextField(
            value = amountText,
            onValueChange = { amountText = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.amount_label)) },
            prefix = { Text(goal.targetAmount.currency.value) },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            singleLine = true,
        )
        OutlinedTextField(
            value = note,
            onValueChange = { note = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.note_optional_label)) },
            singleLine = true,
        )
        SaveButton(label = stringResource(R.string.save_contribution), enabled = amountMinor != null) {
            onSave(
                Money(amountMinor ?: return@SaveButton, goal.targetAmount.currency),
                direction,
                note.trim(),
            )
        }
    }
}

@Composable
internal fun DebtEditorSheet(
    currency: CurrencyCode,
    onDismiss: () -> Unit,
    onSave: (DebtPayoffPlan) -> Unit,
    existing: DebtPayoffPlan? = null,
) {
    var name by remember { mutableStateOf(existing?.name ?: "") }
    var balanceText by remember {
        mutableStateOf(
            existing?.currentBalance?.let { BigDecimal(it.minorUnits).movePointLeft(2).toPlainString() } ?: "",
        )
    }
    var minimumText by remember {
        mutableStateOf(
            existing?.minimumPayment?.let { BigDecimal(it.minorUnits).movePointLeft(2).toPlainString() } ?: "",
        )
    }
    var extraText by remember {
        mutableStateOf(
            existing?.extraPayment
                ?.takeIf { it.minorUnits != 0L }
                ?.let { BigDecimal(it.minorUnits).movePointLeft(2).toPlainString() }
                ?: "",
        )
    }
    var strategy by remember { mutableStateOf(existing?.strategy ?: DebtPayoffStrategy.SNOWBALL) }
    val balanceMinor = parseMoneyMinor(balanceText)
    val minimumMinor = parseMoneyMinor(minimumText)
    val extraMinor = if (extraText.isBlank()) 0L else parseMoneyMinor(extraText, allowZero = true)
    val canSave = name.isNotBlank() && balanceMinor != null && minimumMinor != null &&
        extraMinor != null

    ManageSheet(
        title = if (existing == null) {
            stringResource(R.string.add_debt_title)
        } else {
            stringResource(R.string.edit_debt_title)
        },
        onDismiss = onDismiss,
    ) {
        OutlinedTextField(
            value = name,
            onValueChange = { name = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.debt_name_label)) },
            singleLine = true,
        )
        OutlinedTextField(
            value = balanceText,
            onValueChange = { balanceText = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.current_balance_label)) },
            prefix = { Text(currency.value) },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            singleLine = true,
        )
        OutlinedTextField(
            value = minimumText,
            onValueChange = { minimumText = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.minimum_payment_label)) },
            prefix = { Text(currency.value) },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            singleLine = true,
        )
        OutlinedTextField(
            value = extraText,
            onValueChange = { extraText = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.extra_payment_label)) },
            prefix = { Text(currency.value) },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            singleLine = true,
        )
        val snowballLabel = stringResource(R.string.snowball_label)
        val avalancheLabel = stringResource(R.string.avalanche_label)
        SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
            listOf(DebtPayoffStrategy.SNOWBALL to snowballLabel, DebtPayoffStrategy.AVALANCHE to avalancheLabel)
                .forEachIndexed { index, (option, label) ->
                    SegmentedButton(
                        selected = strategy == option,
                        onClick = { strategy = option },
                        shape = SegmentedButtonDefaults.itemShape(index = index, count = 2),
                    ) {
                        Text(label)
                    }
                }
        }
        SaveButton(label = stringResource(R.string.save_debt_plan), enabled = canSave) {
            val balance = balanceMinor ?: return@SaveButton
            val built = runCatching {
                DebtPayoffPlan(
                    id = existing?.id ?: DebtPlanId("debt-${UUID.randomUUID()}"),
                    name = name.trim(),
                    originalBalance = existing?.originalBalance ?: Money(balance, currency),
                    currentBalance = Money(balance, currency),
                    annualInterestRateBasisPoints = existing?.annualInterestRateBasisPoints ?: 0,
                    minimumPayment = Money(minimumMinor ?: return@SaveButton, currency),
                    extraPayment = Money(extraMinor ?: 0L, currency),
                    strategy = strategy,
                    isArchived = existing?.isArchived ?: false,
                )
            }.getOrNull() ?: return@SaveButton
            onSave(built)
        }
    }
}
