package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.SplitId

data class SplitAllocation(
    val id: SplitId,
    val categoryId: CategoryId,
    val amount: Money,
)

sealed interface SplitValidation {
    data object Valid : SplitValidation

    data object Empty : SplitValidation

    data object CurrencyMismatch : SplitValidation

    data class TotalMismatch(
        val expectedMinor: Long,
        val actualMinor: Long,
    ) : SplitValidation
}

object SplitValidator {
    fun validate(parent: Money, allocations: List<SplitAllocation>): SplitValidation {
        if (allocations.any {
                it.amount.currency != parent.currency || it.amount.minorUnits <= 0
            }
        ) {
            return SplitValidation.CurrencyMismatch
        }
        if (allocations.size < 2) return SplitValidation.Empty

        val total = allocations.fold(0L) { sum, allocation ->
            Math.addExact(sum, allocation.amount.minorUnits)
        }

        return if (total == parent.minorUnits) {
            SplitValidation.Valid
        } else {
            SplitValidation.TotalMismatch(parent.minorUnits, total)
        }
    }
}
