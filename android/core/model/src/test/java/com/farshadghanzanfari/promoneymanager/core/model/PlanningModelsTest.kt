package com.farshadghanzanfari.promoneymanager.core.model

import com.google.common.truth.Truth.assertThat
import java.time.LocalDate
import org.junit.Assert.assertThrows
import org.junit.Test

class PlanningModelsTest {
    private val aed = CurrencyCode.of("AED")

    @Test
    fun scheduledTransactionRequiresPositiveAmountAndMerchant() {
        assertThrows(MoneyFormatException::class.java) {
            schedule(amount = Money.zero(aed))
        }

        val blankMerchant = assertThrows(IllegalArgumentException::class.java) {
            schedule(merchant = " ")
        }

        assertThat(blankMerchant).hasMessageThat().contains("merchant")
    }

    @Test
    fun scheduledTransactionStoresCadenceAndPauseState() {
        val scheduled = schedule(
            frequency = ScheduleFrequency.BIWEEKLY,
            status = ScheduleStatus.PAUSED,
        )

        assertThat(scheduled.frequency).isEqualTo(ScheduleFrequency.BIWEEKLY)
        assertThat(scheduled.status).isEqualTo(ScheduleStatus.PAUSED)
        assertThat(scheduled.isActive).isFalse()
    }

    private fun schedule(
        amount: Money = Money(5_800, aed),
        merchant: String = "Careem Hala",
        frequency: ScheduleFrequency = ScheduleFrequency.MONTHLY,
        status: ScheduleStatus = ScheduleStatus.ACTIVE,
    ) = ScheduledTransaction(
        id = ScheduleId("schedule-careem"),
        accountId = AccountId("credit-card"),
        amount = amount,
        kind = TransactionKind.EXPENSE,
        merchant = merchant,
        normalizedMerchant = merchant.uppercase(),
        categoryId = CategoryId("transportation"),
        note = "airport ride",
        frequency = frequency,
        nextDate = LocalDate.parse("2026-07-15"),
        lastRunDate = null,
        status = status,
        reminderEnabled = true,
    )
}
