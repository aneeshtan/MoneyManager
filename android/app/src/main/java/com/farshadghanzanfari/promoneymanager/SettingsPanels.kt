package com.farshadghanzanfari.promoneymanager

import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.farshadghanzanfari.promoneymanager.core.designsystem.ProMoneySurface
import com.farshadghanzanfari.promoneymanager.core.domain.BackupEngine
import com.farshadghanzanfari.promoneymanager.core.model.BackupRecordType
import com.farshadghanzanfari.promoneymanager.core.model.CompleteBackupSnapshot
import com.farshadghanzanfari.promoneymanager.core.model.NotificationPermissionState
import com.farshadghanzanfari.promoneymanager.core.model.NotificationSettings
import com.farshadghanzanfari.promoneymanager.core.model.RestorePreview

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun BackupSettingsPanel(
    snapshotForReport: CompleteBackupSnapshot,
    backupStatus: String?,
    restorePreview: RestorePreview?,
    onExportBackup: (Uri) -> Unit,
    onExportCsv: (Uri) -> Unit,
    onPreviewRestore: (Uri) -> Unit,
    onConfirmRestore: () -> Unit,
    onCancelRestore: () -> Unit,
) {
    val backupLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/json"),
    ) { uri -> uri?.let(onExportBackup) }
    val csvLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("text/comma-separated-values"),
    ) { uri -> uri?.let(onExportCsv) }
    val restoreLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument(),
    ) { uri -> uri?.let(onPreviewRestore) }

    ProMoneySurface(Modifier.fillMaxWidth()) {
        Text(stringResource(R.string.backup_details_title), style = MaterialTheme.typography.titleMedium)
        Text(
            text = stringResource(
                R.string.backup_details_counts,
                snapshotForReport.accounts.size,
                snapshotForReport.transactions.size,
                snapshotForReport.budgets.size,
            ),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Button(
                onClick = { backupLauncher.launch("promoneymanager-backup.json") },
                shape = MaterialTheme.shapes.small,
            ) {
                Text(stringResource(R.string.export_backup))
            }
            FilledTonalButton(
                onClick = { csvLauncher.launch("transactions.csv") },
                shape = MaterialTheme.shapes.small,
            ) {
                Text(stringResource(R.string.export_csv))
            }
            FilledTonalButton(
                onClick = { restoreLauncher.launch(arrayOf("application/json", "text/plain", "application/octet-stream")) },
                shape = MaterialTheme.shapes.small,
            ) {
                Text(stringResource(R.string.restore_from_backup))
            }
        }
        backupStatus?.let {
            Text(
                it,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.primary,
            )
        }

        val report = BackupEngine.legacyIosCompatibilityReport(snapshotForReport)
        Text(
            text = if (report.canExportWithoutLoss) {
                stringResource(R.string.legacy_export_lossless)
            } else {
                stringResource(
                    R.string.legacy_export_excluded,
                    report.excludedCounts.values.sum(),
                )
            },
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }

    if (restorePreview != null) {
        AlertDialog(
            onDismissRequest = onCancelRestore,
            title = { Text(stringResource(R.string.restore_preview)) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        stringResource(
                            R.string.restore_preview_counts,
                            restorePreview.recordCounts[BackupRecordType.ACCOUNTS] ?: 0,
                            restorePreview.recordCounts[BackupRecordType.TRANSACTIONS] ?: 0,
                            restorePreview.recordCounts.values.sum(),
                        ),
                    )
                    Text(
                        stringResource(R.string.restore_replaces_warning),
                        fontWeight = FontWeight.SemiBold,
                    )
                    restorePreview.warnings.forEach { warning ->
                        Text(warning, color = MaterialTheme.colorScheme.error)
                    }
                }
            },
            confirmButton = {
                TextButton(
                    onClick = onConfirmRestore,
                    enabled = restorePreview.canRestore,
                ) {
                    Text(stringResource(R.string.restore_action))
                }
            },
            dismissButton = {
                TextButton(onClick = onCancelRestore) {
                    Text(stringResource(R.string.cancel_action))
                }
            },
        )
    }
}

@Composable
internal fun NotificationsSettingsPanel(
    settings: NotificationSettings,
    onSetRemindersEnabled: (Boolean, NotificationPermissionState) -> Unit,
) {
    val context = LocalContext.current
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        onSetRemindersEnabled(
            granted,
            if (granted) NotificationPermissionState.GRANTED else NotificationPermissionState.DENIED,
        )
    }

    val permissionText = when (settings.permissionState) {
        NotificationPermissionState.NOT_REQUIRED -> stringResource(R.string.notif_state_not_required)
        NotificationPermissionState.NOT_REQUESTED -> stringResource(R.string.reminder_permission_not_requested)
        NotificationPermissionState.GRANTED -> stringResource(R.string.notif_state_granted)
        NotificationPermissionState.DENIED -> stringResource(R.string.notif_state_denied)
        NotificationPermissionState.DISABLED_IN_SETTINGS -> stringResource(R.string.notif_state_disabled_settings)
    }
    ProMoneySurface(Modifier.fillMaxWidth()) {
        Text(stringResource(R.string.notification_details_title), style = MaterialTheme.typography.titleMedium)
        Text(stringResource(R.string.notification_state, permissionText), style = MaterialTheme.typography.bodyMedium)
        Text(
            text = stringResource(R.string.reminder_prompts_local),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        if (settings.remindersEnabled) {
            FilledTonalButton(
                onClick = { onSetRemindersEnabled(false, settings.permissionState) },
                shape = MaterialTheme.shapes.small,
            ) {
                Text(stringResource(R.string.disable_reminders))
            }
        } else {
            Button(
                onClick = {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val alreadyGranted = ContextCompat.checkSelfPermission(
                            context,
                            Manifest.permission.POST_NOTIFICATIONS,
                        ) == PackageManager.PERMISSION_GRANTED
                        if (alreadyGranted) {
                            onSetRemindersEnabled(true, NotificationPermissionState.GRANTED)
                        } else {
                            permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                        }
                    } else {
                        onSetRemindersEnabled(true, NotificationPermissionState.NOT_REQUIRED)
                    }
                },
                shape = MaterialTheme.shapes.small,
            ) {
                Text(stringResource(R.string.enable_reminders))
            }
        }
    }
}
