package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.Account
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyMismatchException
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import com.farshadghanzanfari.promoneymanager.core.model.TransferDirection

object AccountBalanceCalculator {
    fun currentBalance(account: Account, transactions: List<Transaction>): Money =
        transactions
            .filter { it.accountId == account.id }
            .fold(account.openingBalance) { balance, transaction ->
                if (transaction.amount.currency != account.currency) {
                    throw CurrencyMismatchException(
                        account.currency,
                        transaction.amount.currency,
                    )
                }

                when (transaction.kind) {
                    TransactionKind.INCOME -> balance + transaction.amount
                    TransactionKind.EXPENSE -> balance - transaction.amount
                    TransactionKind.TRANSFER -> when (transaction.transferDirection) {
                        TransferDirection.IN -> balance + transaction.amount
                        TransferDirection.OUT -> balance - transaction.amount
                        null -> error("Transfer direction is required")
                    }
                }
            }
}
