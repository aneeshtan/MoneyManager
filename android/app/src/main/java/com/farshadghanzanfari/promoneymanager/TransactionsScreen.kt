package com.farshadghanzanfari.promoneymanager

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.farshadghanzanfari.promoneymanager.core.designsystem.BrandCoral
import com.farshadghanzanfari.promoneymanager.core.designsystem.BrandLavender
import com.farshadghanzanfari.promoneymanager.core.designsystem.BrandTeal
import com.farshadghanzanfari.promoneymanager.core.designsystem.ProMoneySurface
import com.farshadghanzanfari.promoneymanager.core.domain.MerchantNormalizer
import com.farshadghanzanfari.promoneymanager.core.model.Account
import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.Category
import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.RegionalSettings
import com.farshadghanzanfari.promoneymanager.core.model.SplitId
import com.farshadghanzanfari.promoneymanager.core.model.Tag
import com.farshadghanzanfari.promoneymanager.core.model.TagId
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionId
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import com.farshadghanzanfari.promoneymanager.core.model.TransactionSplitAllocation
import java.math.BigDecimal
import java.math.RoundingMode
import java.time.Instant
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneOffset
import java.util.UUID

internal data class TransactionFilter(
    val kind: TransactionKind? = null,
    val accountId: AccountId? = null,
    val categoryId: CategoryId? = null,
    val startDate: LocalDate? = null,
    val endDate: LocalDate? = null,
    val minAmountMinorUnits: Long? = null,
    val maxAmountMinorUnits: Long? = null,
) {
    val isActive: Boolean
        get() = kind != null || accountId != null || categoryId != null ||
            startDate != null || endDate != null ||
            minAmountMinorUnits != null || maxAmountMinorUnits != null

    fun matches(transaction: Transaction): Boolean {
        if (kind != null && transaction.kind != kind) return false
        if (accountId != null && transaction.accountId != accountId) return false
        if (categoryId != null && transaction.categoryId != categoryId &&
            transaction.subcategoryId != categoryId
        ) {
            return false
        }
        if (startDate != null && transaction.localDate.isBefore(startDate)) return false
        if (endDate != null && transaction.localDate.isAfter(endDate)) return false
        if (minAmountMinorUnits != null && transaction.amount.minorUnits < minAmountMinorUnits) return false
        if (maxAmountMinorUnits != null && transaction.amount.minorUnits > maxAmountMinorUnits) return false
        return true
    }
}

@Composable
internal fun TransactionsScreen(
    transactions: List<Transaction>,
    accounts: List<Account>,
    categories: List<Category>,
    tags: List<Tag>,
    regionalSettings: RegionalSettings,
    onSaveTransaction: (Transaction) -> Unit,
    onDeleteTransaction: (TransactionId) -> Unit,
    onSaveTransfer: (AccountId, AccountId, Money, LocalDate, String) -> Unit,
) {
    var businessOnly by rememberSaveable { mutableStateOf(false) }
    var searchQuery by rememberSaveable { mutableStateOf("") }
    var editorOpen by rememberSaveable { mutableStateOf(false) }
    var filterSheetOpen by rememberSaveable { mutableStateOf(false) }
    var editingTransactionId by rememberSaveable { mutableStateOf<String?>(null) }
    var filter by remember { mutableStateOf(TransactionFilter()) }
    val usePersianCalendar = regionalSettings.usesPersianCalendar

    val businessTag = remember(tags) { tags.firstOrNull { it.name == "Business" }?.id ?: TagId("business") }
    val categoryNames = remember(categories) { categories.associate { it.id to it.name } }
    val accountNames = remember(accounts) { accounts.associate { it.id to it.name } }

    val visibleTransactions = remember(transactions, businessOnly, businessTag, filter, searchQuery, categoryNames, accountNames) {
        transactions
            .asSequence()
            .filter { !businessOnly || businessTag in it.tagIds }
            .filter(filter::matches)
            .filter { transaction ->
                val query = searchQuery.trim()
                query.isEmpty() ||
                    transaction.merchant.contains(query, ignoreCase = true) ||
                    transaction.note.contains(query, ignoreCase = true) ||
                    (categoryNames[transaction.categoryId]?.contains(query, ignoreCase = true) == true) ||
                    (accountNames[transaction.accountId]?.contains(query, ignoreCase = true) == true)
            }
            .sortedByDescending { it.localDate }
            .toList()
    }
    val dayGroups = remember(visibleTransactions) { visibleTransactions.groupBy { it.localDate } }

    val currentMonth = remember { YearMonth.now() }
    val primaryCurrency = accounts.firstOrNull()?.currency
    val monthTransactions = remember(transactions, currentMonth) {
        transactions.filter { YearMonth.from(it.localDate) == currentMonth }
    }
    val monthIncome = remember(monthTransactions, primaryCurrency) {
        monthTransactions
            .filter { it.kind == TransactionKind.INCOME && it.amount.currency == primaryCurrency }
            .sumOf { it.amount.minorUnits }
    }
    val monthExpense = remember(monthTransactions, primaryCurrency) {
        monthTransactions
            .filter { it.kind == TransactionKind.EXPENSE && it.amount.currency == primaryCurrency }
            .sumOf { it.amount.minorUnits }
    }

    Box(Modifier.fillMaxSize()) {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
                .statusBarsPadding(),
            contentPadding = PaddingValues(start = 22.dp, end = 22.dp, top = 26.dp, bottom = 110.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            item {
                Text(
                    text = stringResource(R.string.destination_transactions),
                    modifier = Modifier.semantics { heading() },
                    style = MaterialTheme.typography.headlineLarge,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = stringResource(R.string.transactions_subtitle),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            item {
                MonthSummaryCard(
                    currencyCode = primaryCurrency?.value ?: "AED",
                    incomeMinorUnits = monthIncome,
                    expenseMinorUnits = monthExpense,
                    transactionCount = monthTransactions.size,
                )
            }
            item {
                OutlinedTextField(
                    value = searchQuery,
                    onValueChange = { searchQuery = it },
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text(stringResource(R.string.search_merchant_hint)) },
                    singleLine = true,
                    shape = MaterialTheme.shapes.medium,
                )
            }
            item {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    FilterChip(
                        selected = businessOnly,
                        onClick = { businessOnly = !businessOnly },
                        label = { Text(stringResource(R.string.business_filter)) },
                    )
                    FilterChip(
                        selected = filter.isActive,
                        onClick = { filterSheetOpen = true },
                        label = { Text(stringResource(R.string.filters_label)) },
                    )
                    if (filter.isActive) {
                        TextButton(onClick = { filter = TransactionFilter() }) {
                            Text(stringResource(R.string.clear_filters))
                        }
                    } else if (businessOnly) {
                        Text(
                            text = stringResource(R.string.filtered_by_business),
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.primary,
                        )
                    }
                }
            }
            if (visibleTransactions.isEmpty()) {
                item {
                    ProMoneySurface(Modifier.fillMaxWidth()) {
                        Text(stringResource(R.string.no_transactions_title), style = MaterialTheme.typography.titleMedium)
                        Text(
                            stringResource(R.string.no_transactions_body),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        TextButton(
                            onClick = {
                                editingTransactionId = null
                                editorOpen = true
                            },
                        ) {
                            Text(stringResource(R.string.add_first_transaction))
                        }
                    }
                }
            } else {
                dayGroups.forEach { (day, dayTransactions) ->
                    item(key = "day-$day") {
                        DayHeader(
                            day = day,
                            transactions = dayTransactions,
                            primaryCurrencyCode = primaryCurrency?.value,
                            usePersianCalendar = usePersianCalendar,
                        )
                    }
                    item(key = "card-$day") {
                        ProMoneySurface(Modifier.fillMaxWidth()) {
                            dayTransactions.forEachIndexed { index, transaction ->
                                TransactionRow(
                                    transaction = transaction,
                                    categoryName = categoryNames[transaction.categoryId],
                                    accountName = accountNames[transaction.accountId],
                                    onClick = {
                                        if (transaction.kind != TransactionKind.TRANSFER) {
                                            editingTransactionId = transaction.id.value
                                            editorOpen = true
                                        }
                                    },
                                )
                                if (index != dayTransactions.lastIndex) {
                                    HorizontalDivider(
                                        modifier = Modifier.padding(vertical = 10.dp),
                                        color = MaterialTheme.colorScheme.outlineVariant,
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        FloatingActionButton(
            onClick = {
                editingTransactionId = null
                editorOpen = true
            },
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(24.dp),
            containerColor = MaterialTheme.colorScheme.primary,
            contentColor = MaterialTheme.colorScheme.onPrimary,
        ) {
            val addTransactionCd = stringResource(R.string.add_transaction_cd)
            Text(
                text = "+",
                modifier = Modifier.semantics { contentDescription = addTransactionCd },
                style = MaterialTheme.typography.headlineMedium,
            )
        }
    }

    if (editorOpen) {
        TransactionEditorSheet(
            existing = transactions.firstOrNull { it.id.value == editingTransactionId },
            accounts = accounts.filter { !it.isArchived },
            categories = categories.filter { !it.isArchived },
            tags = tags,
            usePersianCalendar = usePersianCalendar,
            onDismiss = { editorOpen = false },
            onSave = { transaction ->
                onSaveTransaction(transaction)
                editorOpen = false
            },
            onSaveTransfer = { source, destination, amount, date, note ->
                onSaveTransfer(source, destination, amount, date, note)
                editorOpen = false
            },
            onDelete = { transactionId ->
                onDeleteTransaction(transactionId)
                editorOpen = false
            },
        )
    }

    if (filterSheetOpen) {
        TransactionFilterSheet(
            current = filter,
            accounts = accounts,
            categories = categories.filter { !it.isArchived },
            usePersianCalendar = usePersianCalendar,
            onDismiss = { filterSheetOpen = false },
            onApply = { applied ->
                filter = applied
                filterSheetOpen = false
            },
        )
    }
}

@Composable
private fun MonthSummaryCard(
    currencyCode: String,
    incomeMinorUnits: Long,
    expenseMinorUnits: Long,
    transactionCount: Int,
) {
    ProMoneySurface(Modifier.fillMaxWidth()) {
        Text(
            text = stringResource(R.string.month_summary_header, transactionCount),
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontWeight = FontWeight.Bold,
        )
        Row(Modifier.fillMaxWidth()) {
            SummaryColumn(
                label = stringResource(R.string.income_label),
                value = formatMinorUnits(currencyCode, incomeMinorUnits),
                valueColor = BrandTeal,
                modifier = Modifier.weight(1f),
            )
            SummaryColumn(
                label = stringResource(R.string.expenses_label),
                value = formatMinorUnits(currencyCode, expenseMinorUnits),
                valueColor = BrandCoral,
                modifier = Modifier.weight(1f),
            )
            SummaryColumn(
                label = stringResource(R.string.net_label),
                value = formatMinorUnits(currencyCode, incomeMinorUnits - expenseMinorUnits),
                valueColor = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun SummaryColumn(
    label: String,
    value: String,
    valueColor: androidx.compose.ui.graphics.Color,
    modifier: Modifier = Modifier,
) {
    Column(modifier) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text = value,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = valueColor,
        )
    }
}

@Composable
private fun DayHeader(
    day: LocalDate,
    transactions: List<Transaction>,
    primaryCurrencyCode: String?,
    usePersianCalendar: Boolean,
) {
    val dayExpense = transactions
        .filter { it.kind == TransactionKind.EXPENSE && it.amount.currency.value == primaryCurrencyCode }
        .sumOf { it.amount.minorUnits }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = AppFormatters.dayWithWeekday(day, usePersianCalendar),
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        if (dayExpense > 0 && primaryCurrencyCode != null) {
            Text(
                text = "−${formatMinorUnits(primaryCurrencyCode, dayExpense)}",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun TransactionRow(
    transaction: Transaction,
    categoryName: String?,
    accountName: String?,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(MaterialTheme.shapes.small)
            .clickable(onClick = onClick),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(42.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(BrandLavender),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = (categoryName ?: transaction.merchant).take(1).uppercase(),
                color = MaterialTheme.colorScheme.primary,
                fontWeight = FontWeight.Bold,
            )
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(
                text = transaction.merchant,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = listOfNotNull(categoryName ?: stringResource(R.string.uncategorized), accountName)
                    .joinToString(" · "),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            transaction.source?.let { source ->
                val sourceName = source.sourceName ?: "import"
                val importedFromText = source.sourceRow?.let {
                    stringResource(R.string.imported_from_row, sourceName, it)
                } ?: stringResource(R.string.imported_from, sourceName)
                Text(
                    text = importedFromText,
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        Spacer(Modifier.width(8.dp))
        val (sign, color) = when (transaction.kind) {
            TransactionKind.EXPENSE -> "−" to BrandCoral
            TransactionKind.INCOME -> "+" to BrandTeal
            TransactionKind.TRANSFER -> "" to MaterialTheme.colorScheme.onSurfaceVariant
        }
        Text(
            text = "$sign${formatMinorUnits(transaction.amount.currency.value, transaction.amount.minorUnits)}",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = color,
        )
    }
}

private data class SplitDraft(
    val categoryIdValue: String?,
    val amountText: String,
)

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
private fun TransactionEditorSheet(
    existing: Transaction?,
    accounts: List<Account>,
    categories: List<Category>,
    tags: List<Tag>,
    usePersianCalendar: Boolean,
    onDismiss: () -> Unit,
    onSave: (Transaction) -> Unit,
    onSaveTransfer: (AccountId, AccountId, Money, LocalDate, String) -> Unit,
    onDelete: (TransactionId) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var kind by remember { mutableStateOf(existing?.kind ?: TransactionKind.EXPENSE) }
    var amountText by remember {
        mutableStateOf(existing?.amount?.let { formatAmountForInput(it) } ?: "")
    }
    var merchant by remember { mutableStateOf(existing?.merchant ?: "") }
    var note by remember { mutableStateOf(existing?.note ?: "") }
    var date by remember { mutableStateOf(existing?.localDate ?: LocalDate.now()) }
    var accountId by remember { mutableStateOf(existing?.accountId ?: accounts.firstOrNull()?.id) }
    var destinationAccountId by remember {
        mutableStateOf(accounts.firstOrNull { it.id != accountId }?.id)
    }
    var categoryId by remember { mutableStateOf(existing?.categoryId) }
    var selectedTagIds by remember { mutableStateOf(existing?.tagIds ?: emptyList()) }
    var showDatePicker by remember { mutableStateOf(false) }
    var splitEnabled by remember { mutableStateOf(existing?.splitAllocations?.isNotEmpty() == true) }
    var splitDrafts by remember {
        mutableStateOf(
            existing?.splitAllocations
                ?.takeIf { it.isNotEmpty() }
                ?.map { SplitDraft(it.categoryId.value, formatAmountForInput(it.amount)) }
                ?: listOf(SplitDraft(null, ""), SplitDraft(null, "")),
        )
    }

    val isTransfer = kind == TransactionKind.TRANSFER
    val kindCategories = categories.filter { it.kind == kind && it.parentId == null }
    if (categoryId != null && !isTransfer && kindCategories.none { it.id == categoryId }) {
        categoryId = null
    }
    val amountMinorUnits = parseAmountToMinorUnits(amountText)
    val splitTotalMinorUnits = splitDrafts.sumOf { parseAmountToMinorUnits(it.amountText) ?: 0L }
    val splitsValid = !splitEnabled || (
        splitDrafts.size >= 2 &&
            splitDrafts.all { it.categoryIdValue != null && parseAmountToMinorUnits(it.amountText) != null } &&
            splitTotalMinorUnits == amountMinorUnits
        )
    val canSave = if (isTransfer) {
        amountMinorUnits != null && accountId != null && destinationAccountId != null &&
            accountId != destinationAccountId
    } else {
        amountMinorUnits != null && merchant.isNotBlank() && accountId != null && splitsValid
    }

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
                text = if (existing == null) {
                    stringResource(R.string.add_transaction_title)
                } else {
                    stringResource(R.string.edit_transaction_title)
                },
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )
            val expenseLabel = stringResource(R.string.expense_label)
            val incomeLabel = stringResource(R.string.income_label)
            val transferLabel = stringResource(R.string.transfer_label)
            val kindOptions = buildList {
                add(TransactionKind.EXPENSE to expenseLabel)
                add(TransactionKind.INCOME to incomeLabel)
                if (existing == null) add(TransactionKind.TRANSFER to transferLabel)
            }
            SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                kindOptions.forEachIndexed { index, (option, label) ->
                    SegmentedButton(
                        selected = kind == option,
                        onClick = { kind = option },
                        shape = SegmentedButtonDefaults.itemShape(index = index, count = kindOptions.size),
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
                prefix = {
                    Text(accounts.firstOrNull { it.id == accountId }?.currency?.value ?: "")
                },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                singleLine = true,
            )
            if (!isTransfer) {
                OutlinedTextField(
                    value = merchant,
                    onValueChange = { merchant = it },
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text(stringResource(R.string.merchant_label)) },
                    singleLine = true,
                )
            }
            OutlinedTextField(
                value = AppFormatters.date(date, usePersianCalendar),
                onValueChange = {},
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { showDatePicker = true },
                label = { Text(stringResource(R.string.date_label)) },
                readOnly = true,
                enabled = false,
                colors = androidx.compose.material3.OutlinedTextFieldDefaults.colors(
                    disabledTextColor = MaterialTheme.colorScheme.onSurface,
                    disabledBorderColor = MaterialTheme.colorScheme.outline,
                    disabledLabelColor = MaterialTheme.colorScheme.onSurfaceVariant,
                ),
            )
            val uncategorizedLabel = stringResource(R.string.uncategorized)
            EditorDropdown(
                label = if (isTransfer) {
                    stringResource(R.string.from_account_label)
                } else {
                    stringResource(R.string.account_label)
                },
                selectedText = accounts.firstOrNull { it.id == accountId }?.name ?: "",
                options = accounts.map { it.id.value to it.name },
                onSelected = { value -> accountId = AccountId(value) },
            )
            if (isTransfer) {
                EditorDropdown(
                    label = stringResource(R.string.to_account_label),
                    selectedText = accounts.firstOrNull { it.id == destinationAccountId }?.name ?: "",
                    options = accounts
                        .filter { it.id != accountId }
                        .map { it.id.value to it.name },
                    onSelected = { value -> destinationAccountId = AccountId(value) },
                )
                if (accountId != null && accountId == destinationAccountId) {
                    Text(
                        stringResource(R.string.transfer_accounts_must_differ),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }
            if (!isTransfer) {
                EditorDropdown(
                    label = stringResource(R.string.category_label),
                    selectedText = kindCategories.firstOrNull { it.id == categoryId }?.name
                        ?: uncategorizedLabel,
                    options = listOf("" to uncategorizedLabel) +
                        kindCategories.map { it.id.value to it.name },
                    onSelected = { value ->
                        categoryId = value.takeIf { it.isNotEmpty() }?.let(::CategoryId)
                    },
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        stringResource(R.string.split_across_categories),
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    androidx.compose.material3.Switch(
                        checked = splitEnabled,
                        onCheckedChange = { splitEnabled = it },
                    )
                }
                if (splitEnabled) {
                    splitDrafts.forEachIndexed { index, draft ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Box(Modifier.weight(1.2f)) {
                                EditorDropdown(
                                    label = stringResource(R.string.category_label),
                                    selectedText = kindCategories
                                        .firstOrNull { it.id.value == draft.categoryIdValue }?.name ?: "",
                                    options = kindCategories.map { it.id.value to it.name },
                                    onSelected = { value ->
                                        splitDrafts = splitDrafts.toMutableList().also {
                                            it[index] = draft.copy(categoryIdValue = value)
                                        }
                                    },
                                )
                            }
                            OutlinedTextField(
                                value = draft.amountText,
                                onValueChange = { value ->
                                    splitDrafts = splitDrafts.toMutableList().also {
                                        it[index] = draft.copy(amountText = value)
                                    }
                                },
                                modifier = Modifier.weight(0.8f),
                                label = { Text(stringResource(R.string.amount_label)) },
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                                singleLine = true,
                            )
                            if (splitDrafts.size > 2) {
                                TextButton(onClick = {
                                    splitDrafts = splitDrafts.toMutableList().also { it.removeAt(index) }
                                }) {
                                    Text(stringResource(R.string.remove_split))
                                }
                            }
                        }
                    }
                    TextButton(onClick = { splitDrafts = splitDrafts + SplitDraft(null, "") }) {
                        Text(stringResource(R.string.add_split))
                    }
                    val currencyCode = accounts.firstOrNull { it.id == accountId }?.currency?.value ?: ""
                    if (amountMinorUnits != null && splitTotalMinorUnits != amountMinorUnits) {
                        Text(
                            stringResource(
                                R.string.split_remainder,
                                formatMinorUnits(currencyCode, amountMinorUnits - splitTotalMinorUnits),
                            ),
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.error,
                        )
                    }
                }
            }
            if (!isTransfer && tags.isNotEmpty()) {
                Text(
                    text = stringResource(R.string.tags_label),
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    tags.forEach { tag ->
                        val selected = tag.id in selectedTagIds
                        FilterChip(
                            selected = selected,
                            onClick = {
                                selectedTagIds = if (selected) {
                                    selectedTagIds - tag.id
                                } else {
                                    selectedTagIds + tag.id
                                }
                            },
                            label = { Text(tag.name) },
                        )
                    }
                }
            }
            OutlinedTextField(
                value = note,
                onValueChange = { note = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text(stringResource(R.string.note_optional_label)) },
            )
            Button(
                onClick = {
                    val minorUnits = amountMinorUnits ?: return@Button
                    val selectedAccountId = accountId ?: return@Button
                    val currency = accounts.firstOrNull { it.id == selectedAccountId }?.currency
                        ?: return@Button
                    if (isTransfer) {
                        val destination = destinationAccountId ?: return@Button
                        onSaveTransfer(
                            selectedAccountId,
                            destination,
                            Money(minorUnits, currency),
                            date,
                            note.trim(),
                        )
                        return@Button
                    }
                    val splitAllocations = if (splitEnabled) {
                        splitDrafts.mapNotNull { draft ->
                            val splitCategory = draft.categoryIdValue ?: return@mapNotNull null
                            val splitMinor = parseAmountToMinorUnits(draft.amountText)
                                ?: return@mapNotNull null
                            TransactionSplitAllocation(
                                id = SplitId("split-${UUID.randomUUID()}"),
                                categoryId = CategoryId(splitCategory),
                                amount = Money(splitMinor, currency),
                            )
                        }
                    } else {
                        emptyList()
                    }
                    val built = runCatching {
                        if (existing != null) {
                            existing.copy(
                                accountId = selectedAccountId,
                                amount = Money(minorUnits, currency),
                                kind = kind,
                                localDate = date,
                                merchant = merchant.trim(),
                                normalizedMerchant = MerchantNormalizer.normalize(merchant),
                                note = note.trim(),
                                categoryId = categoryId,
                                subcategoryId = existing.subcategoryId
                                    ?.takeIf { categoryId == existing.categoryId },
                                tagIds = selectedTagIds,
                                splitAllocations = splitAllocations,
                            )
                        } else {
                            Transaction.posting(
                                id = "txn-${UUID.randomUUID()}",
                                accountId = selectedAccountId,
                                amount = Money(minorUnits, currency),
                                kind = kind,
                                localDate = date,
                                merchant = merchant.trim(),
                                normalizedMerchant = MerchantNormalizer.normalize(merchant),
                                note = note.trim(),
                                categoryId = categoryId,
                                tagIds = selectedTagIds,
                                splitAllocations = splitAllocations,
                            )
                        }
                    }.getOrNull() ?: return@Button
                    onSave(built)
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                enabled = canSave,
                shape = MaterialTheme.shapes.small,
            ) {
                Text(
                    if (existing == null) {
                        stringResource(R.string.save_transaction)
                    } else {
                        stringResource(R.string.save_changes)
                    },
                )
            }
            if (existing != null) {
                TextButton(
                    onClick = { onDelete(existing.id) },
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = MaterialTheme.colorScheme.error,
                    ),
                ) {
                    Text(stringResource(R.string.delete_transaction))
                }
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EditorDropdown(
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

private fun parseAmountToMinorUnits(text: String): Long? = runCatching {
    val cleaned = text.trim().replace(",", "")
    if (cleaned.isEmpty()) return null
    BigDecimal(cleaned).movePointRight(2).setScale(0, RoundingMode.HALF_UP).longValueExact()
}.getOrNull()?.takeIf { it > 0 }

private fun formatAmountForInput(money: Money): String =
    BigDecimal(money.minorUnits).movePointLeft(2).toPlainString()

private fun formatMinorUnits(currencyCode: String, minorUnits: Long): String {
    val currency = runCatching { CurrencyCode.of(currencyCode) }.getOrNull()
        ?: return "$currencyCode ${BigDecimal(minorUnits).movePointLeft(2).toPlainString()}"
    val sign = if (minorUnits < 0) "−" else ""
    return "$sign${AppFormatters.money(Money(kotlin.math.abs(minorUnits), currency))}"
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TransactionFilterSheet(
    current: TransactionFilter,
    accounts: List<Account>,
    categories: List<Category>,
    usePersianCalendar: Boolean,
    onDismiss: () -> Unit,
    onApply: (TransactionFilter) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var kind by remember { mutableStateOf(current.kind) }
    var accountId by remember { mutableStateOf(current.accountId) }
    var categoryId by remember { mutableStateOf(current.categoryId) }
    var startDate by remember { mutableStateOf(current.startDate) }
    var endDate by remember { mutableStateOf(current.endDate) }
    var minAmountText by remember {
        mutableStateOf(current.minAmountMinorUnits?.let { BigDecimal(it).movePointLeft(2).toPlainString() } ?: "")
    }
    var maxAmountText by remember {
        mutableStateOf(current.maxAmountMinorUnits?.let { BigDecimal(it).movePointLeft(2).toPlainString() } ?: "")
    }
    var datePickerTarget by remember { mutableStateOf<String?>(null) }

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
                text = stringResource(R.string.filters_label),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )
            val allLabel = stringResource(R.string.filter_all_types)
            EditorDropdown(
                label = stringResource(R.string.type_label),
                selectedText = when (kind) {
                    TransactionKind.EXPENSE -> stringResource(R.string.expense_label)
                    TransactionKind.INCOME -> stringResource(R.string.income_label)
                    TransactionKind.TRANSFER -> stringResource(R.string.transfer_label)
                    null -> allLabel
                },
                options = listOf("" to allLabel) + listOf(
                    TransactionKind.EXPENSE.name to stringResource(R.string.expense_label),
                    TransactionKind.INCOME.name to stringResource(R.string.income_label),
                    TransactionKind.TRANSFER.name to stringResource(R.string.transfer_label),
                ),
                onSelected = { value ->
                    kind = value.takeIf { it.isNotEmpty() }?.let(TransactionKind::valueOf)
                },
            )
            val allAccountsLabel = stringResource(R.string.filter_all_accounts)
            EditorDropdown(
                label = stringResource(R.string.account_label),
                selectedText = accounts.firstOrNull { it.id == accountId }?.name ?: allAccountsLabel,
                options = listOf("" to allAccountsLabel) + accounts.map { it.id.value to it.name },
                onSelected = { value ->
                    accountId = value.takeIf { it.isNotEmpty() }?.let(::AccountId)
                },
            )
            val allCategoriesLabel = stringResource(R.string.filter_all_categories)
            EditorDropdown(
                label = stringResource(R.string.category_label),
                selectedText = categories.firstOrNull { it.id == categoryId }?.name ?: allCategoriesLabel,
                options = listOf("" to allCategoriesLabel) + categories.map { it.id.value to it.name },
                onSelected = { value ->
                    categoryId = value.takeIf { it.isNotEmpty() }?.let(::CategoryId)
                },
            )
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                TextButton(onClick = { datePickerTarget = "start" }, modifier = Modifier.weight(1f)) {
                    Text(
                        startDate?.let {
                            stringResource(R.string.filter_from_date, AppFormatters.date(it, usePersianCalendar))
                        } ?: stringResource(R.string.filter_any_start_date),
                    )
                }
                TextButton(onClick = { datePickerTarget = "end" }, modifier = Modifier.weight(1f)) {
                    Text(
                        endDate?.let {
                            stringResource(R.string.filter_to_date, AppFormatters.date(it, usePersianCalendar))
                        } ?: stringResource(R.string.filter_any_end_date),
                    )
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(
                    value = minAmountText,
                    onValueChange = { minAmountText = it },
                    modifier = Modifier.weight(1f),
                    label = { Text(stringResource(R.string.filter_min_amount)) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    singleLine = true,
                )
                OutlinedTextField(
                    value = maxAmountText,
                    onValueChange = { maxAmountText = it },
                    modifier = Modifier.weight(1f),
                    label = { Text(stringResource(R.string.filter_max_amount)) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    singleLine = true,
                )
            }
            Button(
                onClick = {
                    onApply(
                        TransactionFilter(
                            kind = kind,
                            accountId = accountId,
                            categoryId = categoryId,
                            startDate = startDate,
                            endDate = endDate,
                            minAmountMinorUnits = parseAmountToMinorUnits(minAmountText),
                            maxAmountMinorUnits = parseAmountToMinorUnits(maxAmountText),
                        ),
                    )
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = MaterialTheme.shapes.small,
            ) {
                Text(stringResource(R.string.apply_filters))
            }
            TextButton(
                onClick = { onApply(TransactionFilter()) },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(stringResource(R.string.clear_filters))
            }
        }
    }

    if (datePickerTarget != null) {
        val initial = (if (datePickerTarget == "start") startDate else endDate) ?: LocalDate.now()
        val datePickerState = rememberDatePickerState(
            initialSelectedDateMillis = initial.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
        )
        DatePickerDialog(
            onDismissRequest = { datePickerTarget = null },
            confirmButton = {
                TextButton(
                    onClick = {
                        datePickerState.selectedDateMillis?.let { millis ->
                            val picked = Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate()
                            if (datePickerTarget == "start") startDate = picked else endDate = picked
                        }
                        datePickerTarget = null
                    },
                ) {
                    Text(stringResource(R.string.ok_action))
                }
            },
            dismissButton = {
                TextButton(onClick = { datePickerTarget = null }) {
                    Text(stringResource(R.string.cancel_action))
                }
            },
        ) {
            DatePicker(state = datePickerState)
        }
    }
}
