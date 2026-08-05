package com.farshadghanzanfari.promoneymanager.core.domain

object MerchantNormalizer {
    private val locationSuffixes = listOf(
        "DUBAI ARE",
        "DUBAI AE",
        "DUBAI",
        "ABU DHABI ARE",
        "ABU DHABI AE",
        "ABU DHABI",
        "RAS AL KHAIMA",
        "RAS AL-KHAIMA",
        "AJMAN",
        "SHARJAH",
        "UAE",
        "AE",
    )

    private val replacements = listOf(
        Regex("""CR\.?CARD\s*XXX\d+\s*USED\s*FOR\s*[A-Z]{3}[\d,.]+\s*AT\s*""") to "",
        Regex("""CARD\s*XXX\d+\s*USED\s*FOR\s*[A-Z]{3}[\d,.]+\s*AT\s*""") to "",
        Regex("""CR\.?CARDXXX\d+USED""") to "",
        Regex("""CARDXXX\d+USED""") to "",
        Regex("""\(\+\d+(?:\.\d+)?%[^)]*\)""") to "",
        Regex("""AVL\.?\s*CR\.?\s*LIMIT(?:\s*IS)?\s*[A-Z]{3}[\d,.]+""") to "",
        Regex("""AVLCRLIMIT(?:IS)?[A-Z]{3}[\d,.]+""") to "",
        Regex("""[^A-Z0-9&%+./ -]""") to " ",
        Regex("""\s+""") to " ",
    )

    fun normalize(value: String): String {
        var text = value.uppercase()
        for ((pattern, replacement) in replacements) {
            text = text.replace(pattern, replacement)
        }
        text = text.trim(' ', '-', ',', '.')

        var changed = true
        while (changed) {
            changed = false
            for (suffix in locationSuffixes) {
                if (text.endsWith(" $suffix")) {
                    text = text.dropLast(suffix.length).trim(' ', '-', ',', '.')
                    changed = true
                }
                if (text.endsWith("-$suffix")) {
                    text = text.dropLast(suffix.length).trim(' ', '-', ',', '.')
                    changed = true
                }
            }
        }

        return text
    }
}
