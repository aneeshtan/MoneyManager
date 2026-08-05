package com.farshadghanzanfari.promoneymanager

import android.content.Context
import android.content.res.Configuration
import android.os.LocaleList
import android.view.View
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import java.util.Locale
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class LocalizationResourcesTest {
    private val context = ApplicationProvider.getApplicationContext<Context>()

    @Test
    fun SpanishResourcesTranslatePrimaryNavigation() {
        val spanish = localizedContext("es")

        assertThat(spanish.getString(R.string.destination_stats)).isEqualTo("Estadísticas")
        assertThat(spanish.getString(R.string.destination_transactions)).isEqualTo("Transacciones")
        assertThat(spanish.getString(R.string.destination_import)).isEqualTo("Importar")
        assertThat(spanish.getString(R.string.destination_more)).isEqualTo("Más")
    }

    @Test
    fun ArabicAndPersianResourcesUseRtlLayout() {
        assertThat(localizedContext("ar").resources.configuration.layoutDirection)
            .isEqualTo(View.LAYOUT_DIRECTION_RTL)
        assertThat(localizedContext("fa").resources.configuration.layoutDirection)
            .isEqualTo(View.LAYOUT_DIRECTION_RTL)
    }

    @Test
    fun everySupportedLocaleHasTranslatedImportAction() {
        val translations = mapOf(
            "en" to "Import",
            "es" to "Importar",
            "ar" to "استيراد",
            "hi" to "आयात",
            "fa" to "وارد کردن",
            "de" to "Importieren",
            "fr" to "Importer",
            "pt" to "Importar",
        )

        translations.forEach { (tag, expected) ->
            assertThat(localizedContext(tag).getString(R.string.destination_import)).isEqualTo(expected)
        }
    }

    private fun localizedContext(languageTag: String): Context {
        val configuration = Configuration(context.resources.configuration)
        configuration.setLocales(LocaleList.forLanguageTags(languageTag))
        configuration.setLayoutDirection(Locale.forLanguageTag(languageTag))
        return context.createConfigurationContext(configuration)
    }
}
