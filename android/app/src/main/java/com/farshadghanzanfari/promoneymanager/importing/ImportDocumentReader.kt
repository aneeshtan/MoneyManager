package com.farshadghanzanfari.promoneymanager.importing

import android.content.Context
import android.net.Uri
import com.farshadghanzanfari.promoneymanager.core.model.ImportFormat
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.pdmodel.encryption.InvalidPasswordException
import com.tom_roush.pdfbox.text.PDFTextStripper
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.ByteArrayOutputStream
import java.io.InputStream
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

fun interface DocumentStreamSource {
    fun open(uri: Uri): InputStream
}

@Singleton
class ImportDocumentReader private constructor(
    private val streamSource: DocumentStreamSource,
    private val initializePdfBox: () -> Unit,
    private val ioDispatcher: CoroutineDispatcher,
    private val maxBytes: Long,
) {
    @Inject
    constructor(
        @ApplicationContext context: Context,
    ) : this(
        streamSource = DocumentStreamSource { uri ->
            context.contentResolver.openInputStream(uri)
                ?: throw ImportDocumentFailure.CannotOpen(uri.lastPathSegment ?: "selected document")
        },
        initializePdfBox = { PDFBoxResourceLoader.init(context.applicationContext) },
        ioDispatcher = Dispatchers.IO,
        maxBytes = DEFAULT_MAX_BYTES,
    )

    internal constructor(
        streamSource: DocumentStreamSource,
        initializePdfBox: () -> Unit,
        ioDispatcher: CoroutineDispatcher,
        maxBytes: Long,
        @Suppress("UNUSED_PARAMETER") testOnly: Unit = Unit,
    ) : this(streamSource, initializePdfBox, ioDispatcher, maxBytes)

    suspend fun read(uri: Uri, mimeType: String?, displayName: String?): ImportDocumentContent =
        withContext(ioDispatcher) {
            val safeName = displayName?.trim().takeUnless { it.isNullOrEmpty() }
                ?: uri.lastPathSegment?.substringAfterLast('/')
                ?: "selected document"
            val format = detectFormat(mimeType, safeName)
            val bytes = try {
                streamSource.open(uri).use(::readCapped)
            } catch (failure: ImportDocumentFailure) {
                throw failure
            } catch (failure: Throwable) {
                throw ImportDocumentFailure.CannotOpen(safeName, failure)
            }
            val text = when (format) {
                ImportFormat.PDF -> extractPdfText(bytes, safeName)
                ImportFormat.CSV, ImportFormat.PLAIN_TEXT -> bytes.toString(Charsets.UTF_8)
                else -> throw ImportDocumentFailure.UnsupportedFormat(mimeType, safeName)
            }
            if (text.isBlank()) throw ImportDocumentFailure.EmptyDocument(safeName)
            ImportDocumentContent(
                displayName = safeName,
                format = format,
                text = text.trimEnd(),
            )
        }

    private fun detectFormat(mimeType: String?, displayName: String): ImportFormat {
        val normalizedMime = mimeType?.substringBefore(';')?.trim()?.lowercase()
        val extension = displayName.substringAfterLast('.', missingDelimiterValue = "").lowercase()
        return when {
            normalizedMime == "application/pdf" || extension == "pdf" -> ImportFormat.PDF
            normalizedMime in CSV_MIME_TYPES || extension == "csv" -> ImportFormat.CSV
            normalizedMime == "text/plain" || extension in setOf("txt", "text") -> ImportFormat.PLAIN_TEXT
            else -> throw ImportDocumentFailure.UnsupportedFormat(mimeType, displayName)
        }
    }

    private fun readCapped(input: InputStream): ByteArray {
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        var total = 0L
        while (true) {
            val count = input.read(buffer)
            if (count < 0) break
            total += count
            if (total > maxBytes) throw ImportDocumentFailure.TooLarge(maxBytes)
            output.write(buffer, 0, count)
        }
        return output.toByteArray()
    }

    private fun extractPdfText(bytes: ByteArray, displayName: String): String {
        initializePdfBox()
        return try {
            PDDocument.load(bytes).use { document ->
                PDFTextStripper().getText(document)
            }
        } catch (failure: InvalidPasswordException) {
            throw ImportDocumentFailure.ProtectedPdf(displayName, failure)
        } catch (failure: ImportDocumentFailure) {
            throw failure
        } catch (failure: Throwable) {
            throw ImportDocumentFailure.CannotOpen(displayName, failure)
        }
    }

    private companion object {
        const val DEFAULT_MAX_BYTES = 25L * 1024L * 1024L
        val CSV_MIME_TYPES = setOf("text/csv", "application/csv", "application/vnd.ms-excel")
    }
}
