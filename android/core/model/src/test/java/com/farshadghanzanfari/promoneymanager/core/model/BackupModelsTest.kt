package com.farshadghanzanfari.promoneymanager.core.model

import com.google.common.truth.Truth.assertThat
import java.time.Instant
import org.junit.Assert.assertThrows
import org.junit.Test

class BackupModelsTest {
    @Test
    fun backupManifestRequiresSupportedVersionAndCompleteCounts() {
        val manifest = BackupManifest(
            schemaVersion = 1,
            createdAt = Instant.parse("2026-07-11T00:00:00Z"),
            recordCounts = mapOf(
                BackupRecordType.ACCOUNTS to 4,
                BackupRecordType.TRANSACTIONS to 12,
            ),
        )

        assertThat(manifest.recordCounts[BackupRecordType.ACCOUNTS]).isEqualTo(4)
        assertThat(manifest.recordCounts[BackupRecordType.TRANSACTIONS]).isEqualTo(12)
        assertThat(manifest.packageName).isEqualTo("ProMoneyManager")

        val futureVersion = assertThrows(IllegalArgumentException::class.java) {
            BackupManifest(
                schemaVersion = 99,
                createdAt = Instant.parse("2026-07-11T00:00:00Z"),
                recordCounts = emptyMap(),
            )
        }
        assertThat(futureVersion).hasMessageThat().contains("version")
    }

    @Test
    fun restorePreviewSummarizesFutureVersionAsBlocked() {
        val preview = RestorePreview(
            canRestore = false,
            schemaVersion = 99,
            recordCounts = mapOf(BackupRecordType.ACCOUNTS to 1),
            warnings = listOf("Backup version 99 is newer than this app supports."),
        )

        assertThat(preview.canRestore).isFalse()
        assertThat(preview.warnings.single()).contains("newer")
    }
}
