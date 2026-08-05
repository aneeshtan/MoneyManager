package com.farshadghanzanfari.promoneymanager.core.model

import java.math.BigDecimal
import java.math.RoundingMode

data class Money(val minorUnits: Long, val currency: CurrencyCode) {
    operator fun plus(other: Money): Money {
        requireCurrency(other)
        return copy(minorUnits = Math.addExact(minorUnits, other.minorUnits))
    }

    operator fun minus(other: Money): Money {
        requireCurrency(other)
        return copy(minorUnits = Math.subtractExact(minorUnits, other.minorUnits))
    }

    fun requirePositiveMagnitude(): Money {
        if (minorUnits <= 0) throw MoneyFormatException("Amount must be greater than zero")
        return this
    }

    private fun requireCurrency(other: Money) {
        if (currency != other.currency) {
            throw CurrencyMismatchException(currency, other.currency)
        }
    }

    companion object {
        fun zero(currency: CurrencyCode) = Money(0, currency)

        fun parseStrict(raw: String, currency: CurrencyCode): Money {
            try {
                val normalized = raw.trim().replace(",", "")
                val scaled = BigDecimal(normalized)
                    .setScale(currency.fractionDigits, RoundingMode.UNNECESSARY)
                return Money(
                    scaled.movePointRight(currency.fractionDigits).longValueExact(),
                    currency,
                )
            } catch (error: ArithmeticException) {
                throw MoneyFormatException(
                    "Amount has invalid precision or exceeds the supported range",
                    error,
                )
            } catch (error: NumberFormatException) {
                throw MoneyFormatException("Amount is not a valid number", error)
            }
        }
    }
}

class MoneyFormatException(message: String, cause: Throwable? = null) :
    IllegalArgumentException(message, cause)

class CurrencyMismatchException(left: CurrencyCode, right: CurrencyCode) :
    IllegalArgumentException("Cannot combine ${left.value} and ${right.value}")
