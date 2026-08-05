package com.farshadghanzanfari.promoneymanager.importing

import android.content.Context
import android.net.Uri
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.pdmodel.PDPage
import com.tom_roush.pdfbox.pdmodel.PDPageContentStream
import com.tom_roush.pdfbox.pdmodel.font.PDType1Font
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ImportDocumentReaderTest {
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private val documents = mutableMapOf<Uri, ByteArray>()
    private val dispatcher = StandardTestDispatcher()
    private val reader = ImportDocumentReader(
        streamSource = DocumentStreamSource { uri ->
            documents[uri]?.let(::ByteArrayInputStream)
                ?: error("Missing fixture for $uri")
        },
        initializePdfBox = { PDFBoxResourceLoader.init(context) },
        ioDispatcher = dispatcher,
        maxBytes = 1_000_000,
    )

    @Test
    fun extractsTextFromSearchablePdf() = runTest(dispatcher) {
        val uri = fixture("statement.pdf", searchablePdf(
            "Transaction Date Description Amount",
            "10/06/2026 CAREEM 58.00",
        ))

        val result = reader.read(uri, "application/pdf", "statement.pdf")

        assertThat(result.displayName).isEqualTo("statement.pdf")
        assertThat(result.format.name).isEqualTo("PDF")
        assertThat(result.text).contains("CAREEM 58.00")
    }

    @Test
    fun readsUtf8CsvExactly() = runTest(dispatcher) {
        val csv = "Date,Description,Amount\n2026-06-10,Café,58.00"
        val uri = fixture("statement.csv", csv.toByteArray(Charsets.UTF_8))

        val result = reader.read(uri, "text/csv", "statement.csv")

        assertThat(result.format.name).isEqualTo("CSV")
        assertThat(result.text).isEqualTo(csv)
    }

    @Test
    fun rejectsPdfWithoutSearchableText() = runTest(dispatcher) {
        val uri = fixture("scan.pdf", searchablePdf())

        val failure = runCatching {
            reader.read(uri, "application/pdf", "scan.pdf")
        }.exceptionOrNull()

        assertThat(failure).isInstanceOf(ImportDocumentFailure.EmptyDocument::class.java)
    }

    @Test
    fun rejectsUnsupportedDocumentType() = runTest(dispatcher) {
        val uri = fixture("archive.zip", byteArrayOf(1, 2, 3))

        val failure = runCatching {
            reader.read(uri, "application/zip", "archive.zip")
        }.exceptionOrNull()

        assertThat(failure).isInstanceOf(ImportDocumentFailure.UnsupportedFormat::class.java)
    }

    private fun fixture(name: String, bytes: ByteArray): Uri =
        Uri.parse("content://fixtures/$name").also { documents[it] = bytes }

    private fun searchablePdf(vararg lines: String): ByteArray {
        PDFBoxResourceLoader.init(context)
        return PDDocument().use { document ->
            val page = PDPage()
            document.addPage(page)
            PDPageContentStream(document, page).use { content ->
                if (lines.isNotEmpty()) {
                    content.beginText()
                    content.setFont(PDType1Font.HELVETICA, 12f)
                    content.newLineAtOffset(72f, 720f)
                    lines.forEachIndexed { index, line ->
                        if (index > 0) content.newLineAtOffset(0f, -20f)
                        content.showText(line)
                    }
                    content.endText()
                }
            }
            ByteArrayOutputStream().use { output ->
                document.save(output)
                output.toByteArray()
            }
        }
    }
}
