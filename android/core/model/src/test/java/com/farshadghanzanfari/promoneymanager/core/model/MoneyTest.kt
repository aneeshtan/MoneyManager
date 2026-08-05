package com.farshadghanzanfari.promoneymanager.core.model

import com.google.common.truth.Truth.assertThat
import org.junit.Assert.assertThrows
import org.junit.Test

class MoneyTest {
    @Test
    fun parsesTwoDecimalCurrencyExactly() {
        assertThat(Money.parseStrict("1,234.50", CurrencyCode.of("AED")).minorUnits)
            .isEqualTo(123_450L)
    }

    @Test
    fun parsesThreeDecimalCurrencyExactly() {
        assertThat(Money.parseStrict("1.234", CurrencyCode.of("KWD")).minorUnits)
            .isEqualTo(1_234L)
    }

    @Test
    fun rejectsExcessPrecision() {
        assertThrows(MoneyFormatException::class.java) {
            Money.parseStrict("1.001", CurrencyCode.of("AED"))
        }
    }

    @Test
    fun rejectsCurrencyMismatchDuringAddition() {
        assertThrows(CurrencyMismatchException::class.java) {
            Money(100, CurrencyCode.of("AED")) + Money(100, CurrencyCode.of("USD"))
        }
    }

    @Test
    fun rejectsOverflow() {
        assertThrows(ArithmeticException::class.java) {
            Money(Long.MAX_VALUE, CurrencyCode.of("AED")) + Money(1, CurrencyCode.of("AED"))
        }
    }
}
