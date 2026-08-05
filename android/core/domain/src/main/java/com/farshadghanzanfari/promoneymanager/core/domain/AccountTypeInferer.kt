package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.AccountType

object AccountTypeInferer {
    fun infer(accountName: String): AccountType {
        val name = accountName.lowercase()
        return when {
            "cash" in name -> AccountType.CASH
            "saving" in name || "current" in name || "bank" in name || "adib" in name -> {
                AccountType.BANK
            }
            "credit" in name || "card" in name -> AccountType.CREDIT_CARD
            "tabby" in name || "loan" in name || "debt" in name -> AccountType.LIABILITY
            "invest" in name || "crypto" in name || "stock" in name -> AccountType.INVESTMENT
            else -> AccountType.OTHER
        }
    }
}
