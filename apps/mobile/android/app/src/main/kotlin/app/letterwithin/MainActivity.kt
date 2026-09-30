package app.letterwithin

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val privacyChannelName = "app.letterwithin/privacy"
    private var screenCoverEnabled = true

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyScreenCoverPreference()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            privacyChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setScreenCoverEnabled" -> {
                    screenCoverEnabled = call.arguments as? Boolean ?: true
                    applyScreenCoverPreference()
                    result.success(null)
                }
                "clearPosthogQueues" -> {
                    val projectToken = call.arguments as? String
                    if (projectToken == null || !projectToken.matches(Regex("^[A-Za-z0-9._-]+$"))) {
                        result.error("invalid_argument", "Invalid analytics project token.", null)
                        return@setMethodCallHandler
                    }
                    clearPosthogQueues(projectToken)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun clearPosthogQueues(projectToken: String) {
        val roots = listOf(filesDir, noBackupFilesDir, cacheDir)
        val queueNames = listOf(
            "posthog-disk-queue",
            "posthog-disk-replay-queue",
            "posthog-disk-logs-queue",
        )
        roots.forEach { root ->
            queueNames.forEach { queueName ->
                val queueRoot = java.io.File(root, queueName).canonicalFile
                val projectQueue = java.io.File(queueRoot, projectToken).canonicalFile
                if (projectQueue.parentFile == queueRoot) {
                    projectQueue.deleteRecursively()
                }
            }
        }
        // Pre-UUID SDK versions used Context.getDir for the event queue.
        val legacyRoot = getDir("app_posthog-disk-queue", MODE_PRIVATE).canonicalFile
        val legacyProjectQueue = java.io.File(legacyRoot, projectToken).canonicalFile
        if (legacyProjectQueue.parentFile == legacyRoot) {
            legacyProjectQueue.deleteRecursively()
        }
    }

    private fun applyScreenCoverPreference() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(!screenCoverEnabled)
        } else if (screenCoverEnabled) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
