package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.Budget
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import java.time.YearMonth

data class BudgetProgress(
    val budget: Budget,
    val available: Money,
    val spent: Money,
    val remaining: Money,
    val fractionUsed: Double,
    val isOverspent: Boolean,
)

object BudgetProgressCalculator {
    fun progress(
        budget: Budget,
        transactions: List<Transaction>,
        rolloverFromPrevious: Money,
    ): BudgetProgress {
        if (budget.rolloverEnabled) {
            require(budget.amount.currency == rolloverFromPrevious.currency) {
                "Budget rollover currency must match the budget currency."
            }
        }

        val available = if (budget.rolloverEnabled) {
            budget.amount + rolloverFromPrevious
        } else {
            budget.amount
        }
        val spent = transactions
            .filter { transaction ->
                YearMonth.from(transaction.localDate) == budget.month &&
                    transaction.kind == TransactionKind.EXPENSE &&
                    transaction.amount.currency == budget.amount.currency &&
                    transaction.categoryId == budget.categoryId &&
                    (budget.subcategoryId == null || transaction.subcategoryId == budget.subcategoryId)
            }
            .fold(Money.zero(budget.amount.currency)) { total, transaction ->
                total + transaction.amount
            }
        val remaining = available - spent
        return BudgetProgress(
            budget = budget,
            available = available,
            spent = spent,
            remaining = remaining,
            fractionUsed = spent.minorUnits.toDouble() / available.minorUnits.toDouble(),
            isOverspent = remaining.minorUnits < 0,
        )
    }
}
