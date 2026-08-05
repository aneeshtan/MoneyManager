package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.Account
import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.AccountType
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyMismatchException
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import com.farshadghanzanfari.promoneymanager.core.model.TransferDirection
import com.farshadghanzanfari.promoneymanager.core.model.TransferId
import com.google.common.truth.Truth.assertThat
import org.junit.Assert.assertThrows
import org.junit.Test

class AccountBalanceCalculatorTest {
    private val aed = CurrencyCode.of("AED")
    private val accountId = AccountId("account")

    @Test
    fun appliesIncomeExpenseAndTransferLegs() {
        val account = Account(
            accountId,
            "Bank",
            aed,
            Money(10_000, aed),
            AccountType.BANK,
        )
        val postings = listOf(
            Transaction.posting(
                "income",
                accountId,
                Money(2_000, aed),
                TransactionKind.INCOME,
            ),
            Transaction.posting(
                "expense",
                accountId,
                Money(500, aed),
                TransactionKind.EXPENSE,
            ),
            Transaction.transferLeg(
                "out",
                accountId,
                Money(1_000, aed),
                TransferId("t"),
                TransferDirection.OUT,
            ),
            Transaction.transferLeg(
                "in",
                accountId,
                Money(300, aed),
                TransferId("t2"),
                TransferDirection.IN,
            ),
        )

        assertThat(AccountBalanceCalculator.currentBalance(account, postings))
            .isEqualTo(Money(10_800, aed))
    }

    @Test
    fun rejectsPostingInAnotherCurrency() {
        val account = Account(accountId, "Bank", aed, Money.zero(aed), AccountType.BANK)
        val usdPosting = Transaction.posting(
            "bad",
            accountId,
            Money(100, CurrencyCode.of("USD")),
            TransactionKind.INCOME,
        )

        assertThrows(CurrencyMismatchException::class.java) {
            AccountBalanceCalculator.currentBalance(account, listOf(usdPosting))
        }
    }
}
