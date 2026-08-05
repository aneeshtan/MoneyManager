package com.farshadghanzanfari.promoneymanager

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.farshadghanzanfari.promoneymanager.core.designsystem.BrandCoral
import com.farshadghanzanfari.promoneymanager.core.designsystem.BrandLavender
import com.farshadghanzanfari.promoneymanager.core.designsystem.BrandTeal
import com.farshadghanzanfari.promoneymanager.core.designsystem.ProMoneySurface
import com.farshadghanzanfari.promoneymanager.core.domain.AccountBalanceCalculator
import com.farshadghanzanfari.promoneymanager.core.domain.BudgetProgressCalculator
import com.farshadghanzanfari.promoneymanager.core.domain.DashboardAnalytics
import com.farshadghanzanfari.promoneymanager.core.domain.DashboardInsight
import com.farshadghanzanfari.promoneymanager.core.domain.DashboardInsightKind
import com.farshadghanzanfari.promoneymanager.core.model.Account
import com.farshadghanzanfari.promoneymanager.core.model.Budget
import com.farshadghanzanfari.promoneymanager.core.model.Category
import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.ScheduledTransaction
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import java.time.YearMonth

@Composable
internal fun StatsScreen(
    accounts: List<Account>,
    categories: List<Category>,
    transactions: List<Transaction>,
    budgets: List<Budget>,
    scheduledTransactions: List<ScheduledTransaction>,
    usePersianCalendar: Boolean = false,
) {
    var selectedMonthKey by rememberSaveable { mutableStateOf<String?>(null) }
    val defaultMonth = remember(transactions) {
        transactions.maxByOrNull { it.localDate }?.localDate?.let(YearMonth::from)
    } ?: YearMonth.now()
    val selectedMonth = selectedMonthKey?.let { runCatching(it, YearMonth::parse) } ?: defaultMonth

    val categoryNames = remember(categories) { categories.associate { it.id to it.name } }
    val budgetProgress = remember(budgets, selectedMonth, transactions) {
        budgets
            .filter { it.month == selectedMonth && !it.isArchived }
            .map { budget ->
                BudgetProgressCalculator.progress(
                    budget = budget,
                    transactions = transactions,
                    rolloverFromPrevious = Money.zero(budget.amount.currency),
                )
            }
    }
    val currentBalances = remember(accounts, transactions) {
        accounts.mapNotNull { account ->
            runCatching { AccountBalanceCalculator.currentBalance(account, transactions) }.getOrNull()
        }
    }
    val scheduledObligations = remember(scheduledTransactions, selectedMonth) {
        scheduledTransactions
            .filter { it.isActive && YearMonth.from(it.nextDate) == selectedMonth }
            .map { it.amount }
    }
    val summary = remember(selectedMonth, transactions, currentBalances, budgetProgress, scheduledObligations) {
        DashboardAnalytics.monthlySummary(
            month = selectedMonth,
            transactions = transactions,
            currentResources = currentBalances,
            plannedBudgetRemaining = budgetProgress.map { it.remaining },
            scheduledObligations = scheduledObligations,
        )
    }
    val primaryTotal = summary.totals.firstOrNull()
    val expenseShareBase = primaryTotal?.expense?.minorUnits?.takeIf { it > 0 }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .statusBarsPadding()
            .testTag("stats-list"),
        contentPadding = PaddingValues(horizontal = 22.dp, vertical = 26.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        item {
            Text(
                text = stringResource(R.string.destination_stats),
                modifier = Modifier.semantics { heading() },
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = stringResource(R.string.stats_subtitle),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        item {
            val monthlyTotalsCd = stringResource(R.string.monthly_totals_summary_cd)
            val previousMonthCd = stringResource(R.string.previous_month_cd)
            val nextMonthCd = stringResource(R.string.next_month_cd)
            val extraTotals = summary.totals.drop(1).map {
                stringResource(R.string.extra_currency_net, it.currency.value, formatStatsMoney(it.net))
            }
            HeroCard(
                monthTitle = AppFormatters.monthYear(selectedMonth, usePersianCalendar),
                incomeText = primaryTotal?.income?.let(::formatStatsMoney),
                expenseText = primaryTotal?.expense?.let(::formatStatsMoney),
                netText = primaryTotal?.net?.let(::formatStatsMoney),
                safeToSpendText = summary.safeToSpend.firstOrNull()?.amount?.let(::formatStatsMoney),
                extraTotals = extraTotals,
                monthlyTotalsCd = monthlyTotalsCd,
                previousMonthCd = previousMonthCd,
                nextMonthCd = nextMonthCd,
                onPreviousMonth = { selectedMonthKey = selectedMonth.minusMonths(1).toString() },
                onNextMonth = { selectedMonthKey = selectedMonth.plusMonths(1).toString() },
            )
        }
        item {
            ProMoneySurface(modifier = Modifier.fillMaxWidth()) {
                val categoryShareCd = stringResource(R.string.category_share_summary_cd)
                Text(
                    text = stringResource(R.string.spending_by_category),
                    modifier = Modifier.semantics { contentDescription = categoryShareCd },
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                if (summary.categoryTotals.isEmpty()) {
                    Text(
                        stringResource(R.string.no_category_spending),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                summary.categoryTotals.take(6).forEach { categoryTotal ->
                    val share = expenseShareBase
                        ?.let { categoryTotal.amount.minorUnits.toFloat() / it }
                        ?.coerceIn(0f, 1f)
                    ShareRow(
                        name = categoryTotal.categoryId?.let { categoryNames[it] ?: it.value }
                            ?: stringResource(R.string.uncategorized),
                        amountText = formatStatsMoney(categoryTotal.amount),
                        fraction = share ?: 0f,
                        percentText = share?.let { stringResource(R.string.percent_value, (it * 100).toInt()) } ?: "",
                        barColor = MaterialTheme.colorScheme.primary,
                    )
                }
            }
        }
        item {
            ProMoneySurface(modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = stringResource(R.string.panel_budgets),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                if (budgetProgress.isEmpty()) {
                    Text(
                        stringResource(R.string.no_budgets_for_month, selectedMonth.toString()),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                budgetProgress.forEach { progress ->
                    ShareRow(
                        name = categoryNames[progress.budget.categoryId]
                            ?: progress.budget.categoryId.value,
                        amountText = if (progress.isOverspent) {
                            stringResource(
                                R.string.over_by,
                                formatStatsMoney(progress.remaining.let { Money(-it.minorUnits, it.currency) }),
                            )
                        } else {
                            stringResource(R.string.amount_left, formatStatsMoney(progress.remaining))
                        },
                        fraction = progress.fractionUsed.toFloat().coerceIn(0f, 1f),
                        percentText = stringResource(R.string.percent_value, (progress.fractionUsed * 100).toInt()),
                        barColor = if (progress.isOverspent) BrandCoral else BrandTeal,
                    )
                }
            }
        }
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = stringResource(R.string.accounts_title),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = stringResource(R.string.accounts_active_count, accounts.count { !it.isArchived }),
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        item {
            ProMoneySurface(modifier = Modifier.fillMaxWidth()) {
                val activeAccounts = accounts.filter { !it.isArchived }
                activeAccounts.forEachIndexed { index, account ->
                    val balance = runCatching {
                        AccountBalanceCalculator.currentBalance(account, transactions)
                    }.getOrNull()
                    StatsAccountRow(account = account, balanceText = balance?.let(::formatStatsMoney))
                    if (index != activeAccounts.lastIndex) {
                        HorizontalDivider(
                            modifier = Modifier.padding(vertical = 12.dp),
                            color = MaterialTheme.colorScheme.outlineVariant,
                        )
                    }
                }
            }
        }
        item {
            ProMoneySurface(modifier = Modifier.fillMaxWidth()) {
                Text(
                    stringResource(R.string.notes_title),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                summary.notes.forEach { note ->
                    Text(stringResource(R.string.note_bullet, note), style = MaterialTheme.typography.bodyMedium)
                }
                if (summary.notes.isEmpty()) {
                    Text(
                        stringResource(R.string.no_notes_this_month),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
        item {
            ProMoneySurface(modifier = Modifier.fillMaxWidth()) {
                Text(
                    stringResource(R.string.local_insights_title),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                if (summary.insights.isEmpty()) {
                    Text(
                        stringResource(R.string.everything_steady),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                val uncategorizedLabel = stringResource(R.string.uncategorized)
                summary.insights.forEach { insight ->
                    val (title, message) = insightCopy(insight, categoryNames, uncategorizedLabel)
                    Column {
                        Text(
                            title,
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.SemiBold,
                        )
                        Text(
                            message,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }
    }
}

private fun <T> runCatching(value: String, parser: (String) -> T): T? =
    kotlin.runCatching { parser(value) }.getOrNull()

@Composable
private fun insightCopy(
    insight: DashboardInsight,
    categoryNames: Map<CategoryId, String>,
    uncategorizedLabel: String,
): Pair<String, String> = when (insight.kind) {
    DashboardInsightKind.DOMINANT_CATEGORY -> {
        val categoryLabel = insight.categoryId?.let { categoryNames[it] } ?: uncategorizedLabel
        stringResource(R.string.dominant_category_title) to
            stringResource(R.string.dominant_category_message, categoryLabel)
    }
    DashboardInsightKind.UNCATEGORIZED ->
        stringResource(R.string.uncategorized_spending_title) to
            stringResource(R.string.uncategorized_spending_message, insight.count)
    DashboardInsightKind.POSSIBLE_DUPLICATES ->
        stringResource(R.string.possible_duplicates_title) to
            stringResource(R.string.possible_duplicates_message, insight.count)
    DashboardInsightKind.SPENDING_INCREASE ->
        stringResource(R.string.spending_increased_title) to
            stringResource(R.string.spending_increased_message, insight.count)
}

@Composable
private fun HeroCard(
    monthTitle: String,
    incomeText: String?,
    expenseText: String?,
    netText: String?,
    safeToSpendText: String?,
    extraTotals: List<String>,
    monthlyTotalsCd: String,
    previousMonthCd: String,
    nextMonthCd: String,
    onPreviousMonth: () -> Unit,
    onNextMonth: () -> Unit,
) {
    ProMoneySurface(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onPreviousMonth) {
                Text(
                    text = "‹",
                    modifier = Modifier.semantics { contentDescription = previousMonthCd },
                    style = MaterialTheme.typography.headlineMedium,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
            Text(
                text = monthTitle,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            IconButton(onClick = onNextMonth) {
                Text(
                    text = "›",
                    modifier = Modifier.semantics { contentDescription = nextMonthCd },
                    style = MaterialTheme.typography.headlineMedium,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        }
        Text(
            text = stringResource(R.string.net_position_label),
            modifier = Modifier.semantics { contentDescription = monthlyTotalsCd },
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = netText ?: stringResource(R.string.no_activity),
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.SemiBold,
        )
        Row(Modifier.fillMaxWidth()) {
            Column(Modifier.weight(1f)) {
                Text(
                    text = stringResource(R.string.income_label),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = incomeText ?: "AED 0.00",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = BrandTeal,
                )
            }
            Column(Modifier.weight(1f)) {
                Text(
                    text = stringResource(R.string.expense_label),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = expenseText ?: "AED 0.00",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = BrandCoral,
                )
            }
        }
        safeToSpendText?.let {
            Text(
                text = stringResource(R.string.safe_to_spend_label, it),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.primary,
            )
        }
        extraTotals.forEach {
            Text(
                text = it,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun ShareRow(
    name: String,
    amountText: String,
    fraction: Float,
    percentText: String,
    barColor: Color,
) {
    Column(Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = name,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = listOf(amountText, percentText).filter { it.isNotEmpty() }
                    .joinToString(" · "),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Spacer(Modifier.height(6.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(8.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.surfaceVariant),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(fraction.coerceIn(0f, 1f))
                    .height(8.dp)
                    .clip(CircleShape)
                    .background(barColor),
            )
        }
    }
}

@Composable
private fun StatsAccountRow(account: Account, balanceText: String?) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(BrandLavender),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = account.name.take(1),
                color = MaterialTheme.colorScheme.primary,
                fontWeight = FontWeight.Bold,
            )
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(account.name, style = MaterialTheme.typography.titleMedium)
            Text(
                text = account.type.name
                    .replace('_', ' ')
                    .lowercase()
                    .replaceFirstChar { it.uppercase() },
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Text(
            text = balanceText ?: stringResource(R.string.account_currency_placeholder, account.currency.value),
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

private fun formatStatsMoney(money: Money): String {
    val sign = if (money.minorUnits < 0) "−" else ""
    return "$sign${AppFormatters.money(money.copy(minorUnits = kotlin.math.abs(money.minorUnits)))}"
}
