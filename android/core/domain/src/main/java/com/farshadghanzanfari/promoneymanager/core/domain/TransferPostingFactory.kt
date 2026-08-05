package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransferDirection
import com.farshadghanzanfari.promoneymanager.core.model.TransferId

data class TransferPostings(
    val source: Transaction,
    val destination: Transaction,
)

object TransferPostingFactory {
    fun create(
        transferId: TransferId,
        sourceAccountId: AccountId,
        destinationAccountId: AccountId,
        sourceAmount: Money,
        destinationAmount: Money,
    ): TransferPostings {
        require(sourceAccountId != destinationAccountId) {
            "Transfer accounts must be different"
        }
        sourceAmount.requirePositiveMagnitude()
        destinationAmount.requirePositiveMagnitude()
        if (sourceAmount.currency == destinationAmount.currency) {
            require(sourceAmount.minorUnits == destinationAmount.minorUnits) {
                "Same-currency transfer must balance"
            }
        }

        return TransferPostings(
            source = Transaction.transferLeg(
                "${transferId.value}-out",
                sourceAccountId,
                sourceAmount,
                transferId,
                TransferDirection.OUT,
            ),
            destination = Transaction.transferLeg(
                "${transferId.value}-in",
                destinationAccountId,
                destinationAmount,
                transferId,
                TransferDirection.IN,
            ),
        )
    }
}
