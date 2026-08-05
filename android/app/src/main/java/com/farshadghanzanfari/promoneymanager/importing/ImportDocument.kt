package com.farshadghanzanfari.promoneymanager.importing

import com.farshadghanzanfari.promoneymanager.core.model.ImportFormat
import java.io.IOException

data class ImportDocumentContent(
    val displayName: String,
    val format: ImportFormat,
    val text: String,
)

sealed class ImportDocumentFailure(message: String, cause: Throwable? = null) : IOException(message, cause) {
    class UnsupportedFormat(val mimeType: String?, val displayName: String) : ImportDocumentFailure(
        "This file type is not supported. Choose a searchable PDF, CSV, or text file.",
    )

    class EmptyDocument(val displayName: String) : ImportDocumentFailure(
        "No searchable text was found in $displayName. The PDF may be scanned.",
    )

    class TooLarge(val maxBytes: Long) : ImportDocumentFailure(
        "The selected file is larger than ${maxBytes / (1024 * 1024)} MB.",
    )

    class CannotOpen(val displayName: String, cause: Throwable? = null) : ImportDocumentFailure(
        "Android could not read $displayName. Choose the file again and retry.",
        cause,
    )

    class ProtectedPdf(val displayName: String, cause: Throwable? = null) : ImportDocumentFailure(
        "$displayName is password protected. Export an unlocked searchable PDF and retry.",
        cause,
    )
}
