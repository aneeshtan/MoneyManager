package com.farshadghanzanfari.promoneymanager

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.farshadghanzanfari.promoneymanager.core.designsystem.BrandCoral
import com.farshadghanzanfari.promoneymanager.core.designsystem.BrandTeal
import com.farshadghanzanfari.promoneymanager.core.designsystem.ProMoneySurface
import com.farshadghanzanfari.promoneymanager.core.domain.SearchAndCalendar
import com.farshadghanzanfari.promoneymanager.core.domain.SearchQuery
import com.farshadghanzanfari.promoneymanager.core.domain.SearchResultType
import com.farshadghanzanfari.promoneymanager.core.domain.SmartCategorizationService
import com.farshadghanzanfari.promoneymanager.core.domain.TrendRange
import com.farshadghanzanfari.promoneymanager.core.model.Account
import com.farshadghanzanfari.promoneymanager.core.model.Category
import com.farshadghanzanfari.promoneymanager.core.model.MatchType
import com.farshadghanzanfari.promoneymanager.core.model.MerchantRule
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun SearchPanel(
    transactions: List<Transaction>,
    accounts: List<Account>,
    categories: List<Category>,
    usePersianCalendar: Boolean,
) {
    var query by rememberSaveable { mutableStateOf("") }
    var onlyUncategorized by rememberSaveable { mutableStateOf(false) }
    val transactionsById = remember(transactions) { transactions.associateBy { it.id.value } }
    val categoryNames = remember(categories) { categories.associate { it.id to it.name } }

    ProMoneySurface(Modifier.fillMaxWidth()) {
        Text(stringResource(R.string.search_tools_title), style = MaterialTheme.typography.titleMedium)
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.search_everything_hint)) },
            singleLine = true,
        )
        FilterChip(
            selected = onlyUncategorized,
            onClick = { onlyUncategorized = !onlyUncategorized },
            label = { Text(stringResource(R.string.uncategorized_only)) },
        )
        val results = remember(query, onlyUncategorized, transactions, accounts, categories) {
            if (query.isBlank() && !onlyUncategorized) {
                emptyList()
            } else {
                SearchAndCalendar.search(
                    query = SearchQuery(text = query, onlyUncategorized = onlyUncategorized),
                    transactions = transactions,
                    accounts = accounts,
                    categories = categories,
                )
            }
        }
        if (query.isBlank() && !onlyUncategorized) {
            Text(
                stringResource(R.string.search_tools_body),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        } else if (results.isEmpty()) {
            Text(
                stringResource(R.string.no_search_results),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        } else {
            Text(
                stringResource(R.string.search_results_count, results.size),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            results.take(25).forEach { result ->
                val transaction = transactionsById[result.id]
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(result.label, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                        val detail = when (result.type) {
                            SearchResultType.TRANSACTION -> transaction?.let {
                                listOfNotNull(
                                    AppFormatters.date(it.localDate, usePersianCalendar),
                                    categoryNames[it.categoryId]
                                        ?: stringResource(R.string.uncategorized),
                                ).joinToString(" · ")
                            } ?: stringResource(R.string.result_type_transaction)
                            SearchResultType.ACCOUNT -> stringResource(R.string.result_type_account)
                            SearchResultType.CATEGORY -> stringResource(R.string.result_type_category)
                        }
                        Text(
                            detail,
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    transaction?.let {
                        Text(
                            AppFormatters.money(it.amount),
                            style = MaterialTheme.typography.labelLarge,
                            fontWeight = FontWeight.SemiBold,
                            color = if (it.kind == TransactionKind.EXPENSE) BrandCoral else BrandTeal,
                        )
                    }
                }
            }
        }
    }
}

@Composable
internal fun CalendarPanel(
    transactions: List<Transaction>,
    categories: List<Category>,
    usePersianCalendar: Boolean,
) {
    var monthValue by rememberSaveable { mutableStateOf(YearMonth.now().toString()) }
    var selectedDayValue by rememberSaveable { mutableStateOf<String?>(null) }
    val month = YearMonth.parse(monthValue)
    val selectedDay = selectedDayValue?.let(LocalDate::parse)
    val categoryNames = remember(categories) { categories.associate { it.id to it.name } }

    val summariesByDay = remember(month, transactions) {
        SearchAndCalendar.calendarSummaries(month, transactions).groupBy { it.date }
    }

    ProMoneySurface(Modifier.fillMaxWidth()) {
        Text(stringResource(R.string.calendar_summaries_title), style = MaterialTheme.typography.titleMedium)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TextButton(onClick = {
                monthValue = month.minusMonths(1).toString()
                selectedDayValue = null
            }) { Text(stringResource(R.string.previous_month_cd)) }
            Text(
                AppFormatters.monthYear(month, usePersianCalendar),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            TextButton(onClick = {
                monthValue = month.plusMonths(1).toString()
                selectedDayValue = null
            }) { Text(stringResource(R.string.next_month_cd)) }
        }

        val firstDay = month.atDay(1)
        val leadingBlanks = (firstDay.dayOfWeek.value + 6) % 7
        val totalCells = leadingBlanks + month.lengthOfMonth()
        val weeks = (totalCells + 6) / 7
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            repeat(weeks) { week ->
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    repeat(7) { dayOfWeek ->
                        val cellIndex = week * 7 + dayOfWeek
                        val dayNumber = cellIndex - leadingBlanks + 1
                        if (dayNumber in 1..month.lengthOfMonth()) {
                            val day = month.atDay(dayNumber)
                            val daySummaries = summariesByDay[day]
                            val isSelected = day == selectedDay
                            Column(
                                modifier = Modifier
                                    .weight(1f)
                                    .aspectRatio(0.9f)
                                    .clip(MaterialTheme.shapes.small)
                                    .background(
                                        when {
                                            isSelected -> MaterialTheme.colorScheme.primaryContainer
                                            day == LocalDate.now() -> MaterialTheme.colorScheme.surfaceVariant
                                            else -> MaterialTheme.colorScheme.surface
                                        },
                                    )
                                    .clickable {
                                        selectedDayValue = if (isSelected) null else day.toString()
                                    },
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.Center,
                            ) {
                                Text(
                                    dayNumber.toString(),
                                    style = MaterialTheme.typography.labelLarge,
                                    textAlign = TextAlign.Center,
                                )
                                if (daySummaries != null) {
                                    Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                                        if (daySummaries.any { it.income.minorUnits > 0 }) {
                                            CalendarDot(BrandTeal)
                                        }
                                        if (daySummaries.any { it.expense.minorUnits > 0 }) {
                                            CalendarDot(BrandCoral)
                                        }
                                    }
                                }
                            }
                        } else {
                            Spacer(
                                Modifier
                                    .weight(1f)
                                    .aspectRatio(0.9f),
                            )
                        }
                    }
                }
            }
        }

        if (selectedDay != null) {
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            val dayTransactions = remember(transactions, selectedDay) {
                transactions
                    .filter { it.localDate == selectedDay }
                    .sortedByDescending { it.amount.minorUnits }
            }
            Text(
                AppFormatters.dayWithWeekday(selectedDay, usePersianCalendar),
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
            )
            if (dayTransactions.isEmpty()) {
                Text(
                    stringResource(R.string.no_transactions_on_day),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            dayTransactions.forEach { transaction ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(transaction.merchant, style = MaterialTheme.typography.bodyMedium)
                        Text(
                            categoryNames[transaction.categoryId] ?: stringResource(R.string.uncategorized),
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    val (sign, color) = when (transaction.kind) {
                        TransactionKind.EXPENSE -> "−" to BrandCoral
                        TransactionKind.INCOME -> "+" to BrandTeal
                        TransactionKind.TRANSFER -> "" to MaterialTheme.colorScheme.onSurfaceVariant
                    }
                    Text(
                        "$sign${AppFormatters.money(transaction.amount)}",
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.SemiBold,
                        color = color,
                    )
                }
            }
        } else {
            Text(
                stringResource(
                    R.string.calendar_summaries_body,
                    summariesByDay.size,
                ),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun CalendarDot(color: androidx.compose.ui.graphics.Color) {
    Box(
        Modifier
            .size(5.dp)
            .clip(CircleShape)
            .background(color),
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun TrendsPanel(
    transactions: List<Transaction>,
    usePersianCalendar: Boolean,
) {
    var rangeName by rememberSaveable { mutableStateOf(TrendRange.SIX_MONTHS.name) }
    val range = TrendRange.valueOf(rangeName)
    val buckets = remember(range, transactions) {
        SearchAndCalendar.trends(YearMonth.now(), range, transactions)
    }
    val maxMinorUnits = remember(buckets) {
        buckets
            .maxOfOrNull { maxOf(it.income.minorUnits, it.expense.minorUnits) }
            ?.coerceAtLeast(1L) ?: 1L
    }

    ProMoneySurface(Modifier.fillMaxWidth()) {
        Text(stringResource(R.string.trend_ranges_title), style = MaterialTheme.typography.titleMedium)
        SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
            TrendRange.entries.forEachIndexed { index, option ->
                SegmentedButton(
                    selected = range == option,
                    onClick = { rangeName = option.name },
                    shape = SegmentedButtonDefaults.itemShape(index = index, count = TrendRange.entries.size),
                ) {
                    Text(stringResource(R.string.months_count, option.monthCount))
                }
            }
        }
        if (buckets.all { it.income.minorUnits == 0L && it.expense.minorUnits == 0L }) {
            Text(
                stringResource(R.string.no_trend_data),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        buckets.forEach { bucket ->
            if (bucket.income.minorUnits == 0L && bucket.expense.minorUnits == 0L) return@forEach
            Column(Modifier.padding(vertical = 4.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(
                        AppFormatters.monthYear(bucket.month, usePersianCalendar),
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        stringResource(R.string.net_value, AppFormatters.money(bucket.net)),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                TrendBar(fraction = bucket.income.minorUnits.toFloat() / maxMinorUnits, color = BrandTeal)
                TrendBar(fraction = bucket.expense.minorUnits.toFloat() / maxMinorUnits, color = BrandCoral)
            }
        }
    }
}

@Composable
private fun TrendBar(fraction: Float, color: androidx.compose.ui.graphics.Color) {
    Box(
        Modifier
            .padding(top = 3.dp)
            .fillMaxWidth(fraction.coerceIn(0.02f, 1f))
            .height(7.dp)
            .clip(CircleShape)
            .background(color),
    )
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun SmartRulesPanel(
    transactions: List<Transaction>,
    categories: List<Category>,
    merchantRules: List<MerchantRule>,
    onSaveRule: (MerchantRule) -> Unit,
    onToggleRule: (String, Boolean) -> Unit,
    onApplyPlan: (com.farshadghanzanfari.promoneymanager.core.domain.CategorizationBulkApplyPlan) -> Unit,
) {
    val categoryNames = remember(categories) { categories.associate { it.id to it.name } }
    val candidates = remember(transactions, merchantRules) {
        SmartCategorizationService.learnRuleCandidates(transactions, merchantRules)
    }
    val previews = remember(transactions, merchantRules) {
        SmartCategorizationService.previewCategorization(transactions, merchantRules)
    }

    ProMoneySurface(Modifier.fillMaxWidth()) {
        Text(stringResource(R.string.smart_rules_title), style = MaterialTheme.typography.titleMedium)
        Text(
            stringResource(R.string.smart_rules_body),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        if (candidates.isNotEmpty()) {
            Text(
                stringResource(R.string.rule_candidates_count, candidates.size),
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
            )
            candidates.take(5).forEach { candidate ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(candidate.pattern, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                        Text(
                            stringResource(
                                R.string.rule_candidate_detail,
                                categoryNames[candidate.categoryId] ?: candidate.categoryId.value,
                                candidate.sampleCount,
                            ),
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    TextButton(onClick = {
                        onSaveRule(
                            MerchantRule(
                                id = "rule-${UUID.randomUUID()}",
                                pattern = candidate.pattern,
                                matchType = MatchType.CONTAINS,
                                categoryId = candidate.categoryId,
                                subcategoryId = candidate.subcategoryId,
                                kind = candidate.kind,
                                confidence = candidate.confidence,
                                sampleCount = candidate.sampleCount,
                                isAutoGenerated = true,
                            ),
                        )
                    }) {
                        Text(stringResource(R.string.save_rule))
                    }
                }
            }
        }

        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
        if (previews.isEmpty()) {
            Text(
                stringResource(R.string.no_uncategorized_matches),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        } else {
            Text(
                stringResource(R.string.categorization_previews_count, previews.size),
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
            )
            previews.take(5).forEach { preview ->
                Text(
                    stringResource(
                        R.string.categorization_preview_row,
                        preview.normalizedMerchant,
                        categoryNames[preview.suggestedCategoryId] ?: preview.suggestedCategoryId.value,
                    ),
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
            Button(
                onClick = {
                    onApplyPlan(
                        SmartCategorizationService.createBulkApplyPlan(
                            previews = previews,
                            selectedTransactionIds = previews.map { it.transactionId }.toSet(),
                        ),
                    )
                },
                shape = MaterialTheme.shapes.small,
            ) {
                Text(stringResource(R.string.apply_suggestions, previews.size))
            }
        }

        if (merchantRules.isNotEmpty()) {
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            Text(
                stringResource(R.string.saved_rules_count, merchantRules.size),
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
            )
            merchantRules.take(10).forEach { rule ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(rule.pattern, style = MaterialTheme.typography.bodyMedium)
                        Text(
                            categoryNames[rule.categoryId] ?: rule.categoryId.value,
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Switch(
                        checked = rule.isEnabled,
                        onCheckedChange = { onToggleRule(rule.id, it) },
                    )
                }
            }
        }
    }
}
