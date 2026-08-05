package com.farshadghanzanfari.promoneymanager

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.RegionalSettings
import com.farshadghanzanfari.promoneymanager.core.model.SupportedLanguage
import java.util.Currency
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun RegionalSettingsEditor(
    settings: RegionalSettings,
    actionLabel: String,
    onSave: (RegionalSettings) -> Unit,
    modifier: Modifier = Modifier,
) {
    var languageName by rememberSaveable(settings.language.name) { mutableStateOf(settings.language.name) }
    var currencyCode by rememberSaveable(settings.baseCurrency.value) {
        mutableStateOf(settings.baseCurrency.value)
    }
    var countryText by rememberSaveable(settings.countryCode) { mutableStateOf(settings.countryCode) }
    var timeZoneText by rememberSaveable(settings.timeZoneId) { mutableStateOf(settings.timeZoneId) }

    val language = SupportedLanguage.valueOf(languageName)

    androidx.compose.foundation.layout.Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(stringResource(R.string.language), style = MaterialTheme.typography.titleMedium)
        FlowRow(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            SupportedLanguage.entries.forEach { option ->
                FilterChip(
                    selected = option == language,
                    onClick = {
                        if (option != language) {
                            currencyCode = option.suggestedCurrency
                            countryText = option.suggestedRegion
                            timeZoneText = option.suggestedTimeZone
                        }
                        languageName = option.name
                    },
                    label = { Text(option.displayName) },
                )
            }
        }
        CurrencyDropdownField(
            label = stringResource(R.string.base_currency),
            helperText = stringResource(R.string.currency_helper),
            selectedCode = currencyCode,
            onSelected = { currencyCode = it },
        )
        OutlinedTextField(
            value = countryText,
            onValueChange = {},
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.country_region)) },
            readOnly = true,
            singleLine = true,
        )
        OutlinedTextField(
            value = timeZoneText,
            onValueChange = {},
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.timezone)) },
            readOnly = true,
            singleLine = true,
        )
        Button(
            onClick = {
                onSave(
                    RegionalSettings(
                        language = language,
                        countryCode = countryText,
                        timeZoneId = timeZoneText,
                        baseCurrency = CurrencyCode.of(currencyCode),
                    ),
                )
            },
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 4.dp),
        ) {
            Text(actionLabel)
        }
    }
}

private data class CurrencyOption(val code: String, val displayName: String)

private val curatedCurrencyCodes = listOf(
    "USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "SEK", "NZD",
    "MXN", "SGD", "HKD", "NOK", "KRW", "TRY", "INR", "BRL", "ZAR", "AED",
    "SAR", "QAR", "KWD", "BHD", "OMR", "EGP", "PHP", "THB", "IDR", "MYR",
    "IRR", "RUB", "PLN", "DKK", "CZK", "HUF", "ILS", "PKR", "BDT", "VND", "NGN",
    "KES", "GHS", "UGX", "TZS", "XOF", "XAF", "MAD", "TND", "JOD", "LBP",
)

private val curatedCurrencyOptions: List<CurrencyOption> = curatedCurrencyCodes
    .map { code -> CurrencyOption(code, Currency.getInstance(code).getDisplayName(Locale.US)) }
    .sortedBy { it.displayName }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CurrencyDropdownField(
    label: String,
    helperText: String,
    selectedCode: String,
    onSelected: (String) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    var query by rememberSaveable { mutableStateOf("") }
    val filteredOptions = remember(query) {
        if (query.isBlank()) {
            curatedCurrencyOptions
        } else {
            curatedCurrencyOptions.filter {
                it.code.contains(query, ignoreCase = true) || it.displayName.contains(query, ignoreCase = true)
            }
        }
    }
    val selectedOption = curatedCurrencyOptions.firstOrNull { it.code == selectedCode }

    ExposedDropdownMenuBox(
        expanded = expanded,
        onExpandedChange = { expanded = it },
    ) {
        OutlinedTextField(
            value = selectedOption?.let { "${it.code} — ${it.displayName}" } ?: selectedCode,
            onValueChange = {},
            modifier = Modifier
                .fillMaxWidth()
                .menuAnchor(MenuAnchorType.PrimaryNotEditable),
            label = { Text(label) },
            supportingText = { Text(helperText) },
            readOnly = true,
            singleLine = true,
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
        )
        ExposedDropdownMenu(
            expanded = expanded,
            onDismissRequest = {
                expanded = false
                query = ""
            },
        ) {
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 4.dp),
                placeholder = { Text(stringResource(R.string.search_currency)) },
                singleLine = true,
            )
            filteredOptions.forEach { option ->
                DropdownMenuItem(
                    text = { Text("${option.code} — ${option.displayName}") },
                    onClick = {
                        onSelected(option.code)
                        expanded = false
                        query = ""
                    },
                )
            }
        }
    }
}
