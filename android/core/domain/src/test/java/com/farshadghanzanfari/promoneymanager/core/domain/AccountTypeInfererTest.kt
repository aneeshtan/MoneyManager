package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.AccountType
import com.google.common.truth.Truth.assertThat
import org.junit.Test

class AccountTypeInfererTest {
    @Test
    fun infersCashAccounts() {
        assertThat(AccountTypeInferer.infer("Wallet Cash")).isEqualTo(AccountType.CASH)
    }

    @Test
    fun infersBankAccounts() {
        assertThat(AccountTypeInferer.infer("ADIB Current Account")).isEqualTo(AccountType.BANK)
        assertThat(AccountTypeInferer.infer("Emergency Savings")).isEqualTo(AccountType.BANK)
    }

    @Test
    fun infersCreditCards() {
        assertThat(AccountTypeInferer.infer("Visa Credit Card")).isEqualTo(AccountType.CREDIT_CARD)
    }

    @Test
    fun infersLiabilities() {
        assertThat(AccountTypeInferer.infer("Tabby Pay Later")).isEqualTo(AccountType.LIABILITY)
        assertThat(AccountTypeInferer.infer("Car Loan Debt")).isEqualTo(AccountType.LIABILITY)
    }

    @Test
    fun infersInvestments() {
        assertThat(AccountTypeInferer.infer("Crypto Stock Investing")).isEqualTo(AccountType.INVESTMENT)
    }

    @Test
    fun fallsBackToOther() {
        assertThat(AccountTypeInferer.infer("Household Jar")).isEqualTo(AccountType.OTHER)
    }
}
