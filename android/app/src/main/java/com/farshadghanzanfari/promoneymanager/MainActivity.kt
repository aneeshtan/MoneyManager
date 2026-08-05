package com.farshadghanzanfari.promoneymanager

import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.farshadghanzanfari.promoneymanager.core.designsystem.ProMoneyManagerTheme
import dagger.hilt.android.AndroidEntryPoint
import androidx.appcompat.app.AppCompatActivity

@AndroidEntryPoint
class MainActivity : AppCompatActivity() {
    private var sharedImportText by mutableStateOf<String?>(null)
    private var shortcutDestination by mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sharedImportText = AndroidShareImportIntake.reviewableText(intent)
        shortcutDestination = intent.shortcutDestination()
        AndroidShortcutPublisher.publish(this)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        enableEdgeToEdge()
        setContent {
            ProMoneyManagerTheme {
                ProMoneyManagerApp(
                    sharedImportText = sharedImportText,
                    shortcutDestination = shortcutDestination,
                    onSecureScreenChanged = ::setSecureScreen,
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        sharedImportText = AndroidShareImportIntake.reviewableText(intent)
        shortcutDestination = intent.shortcutDestination()
    }

    private fun Intent.shortcutDestination(): String? =
        getStringExtra("shortcut_destination")?.trim()?.takeIf { it.isNotEmpty() }

    private fun setSecureScreen(enabled: Boolean) {
        if (enabled) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
