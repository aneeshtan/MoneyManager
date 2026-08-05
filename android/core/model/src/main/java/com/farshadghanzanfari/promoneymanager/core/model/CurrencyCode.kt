package com.farshadghanzanfari.promoneymanager.core.model

import java.util.Currency
import java.util.Locale

@JvmInline
value class CurrencyCode private constructor(val value: String) {
    val fractionDigits: Int
        get() = Currency.getInstance(value).defaultFractionDigits

    companion object {
        fun of(raw: String): CurrencyCode {
            val normalized = raw.trim().uppercase(Locale.ROOT)
            require(normalized.length == 3) { "Currency code must contain three letters" }
            val currency = Currency.getInstance(normalized)
            require(currency.defaultFractionDigits >= 0) { "Currency must define minor units" }
            return CurrencyCode(normalized)
        }
    }
}
