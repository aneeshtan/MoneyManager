package com.farshadghanzanfari.promoneymanager

import android.content.Intent

object AndroidShareImportIntake {
    fun reviewableText(intent: Intent): String? {
        if (intent.action != Intent.ACTION_SEND) return null
        val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim()
        if (!sharedText.isNullOrEmpty()) return sharedText
        val mimeType = intent.type ?: "shared file"
        if (intent.extras?.containsKey(Intent.EXTRA_STREAM) != true) return null
        return if (mimeType.startsWith("image/")) {
            "Shared $mimeType receipt from Android share target. OCR review required before saving."
        } else {
            "Shared $mimeType file from Android share target"
        }
    }
}
