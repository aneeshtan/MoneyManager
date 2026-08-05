package com.farshadghanzanfari.promoneymanager.backup

import android.content.Context
import android.net.Uri
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

private const val MAX_BACKUP_BYTES = 32L * 1024 * 1024

/** Reads and writes user-selected backup documents through the Storage Access Framework. */
@Singleton
class BackupFileStore @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    suspend fun writeText(uri: Uri, text: String) = withContext(Dispatchers.IO) {
        context.contentResolver.openOutputStream(uri, "wt")
            ?.use { stream -> stream.write(text.toByteArray(Charsets.UTF_8)) }
            ?: throw BackupFormatException("The selected destination could not be opened for writing.")
    }

    suspend fun readText(uri: Uri): String = withContext(Dispatchers.IO) {
        context.contentResolver.openInputStream(uri)?.use { stream ->
            val bytes = stream.readBytes()
            if (bytes.size > MAX_BACKUP_BYTES) {
                throw BackupFormatException("The selected file is too large to be a backup document.")
            }
            String(bytes, Charsets.UTF_8)
        } ?: throw BackupFormatException("The selected file could not be opened.")
    }
}
