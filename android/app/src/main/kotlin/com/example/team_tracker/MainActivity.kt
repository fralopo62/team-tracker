package com.example.team_tracker

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.team_tracker/shared_file"
    private val LAUNCHER_CHANNEL = "com.teamtracker/app_launcher"
    private val DEEP_LINK_CHANNEL = "com.teamtracker/deep_links"

    private var methodChannel: MethodChannel? = null
    private var deepLinkChannel: MethodChannel? = null

    private var pendingSharedFilePath: String? = null
    private var pendingDeepLinkUri: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharedFile" -> {
                    val path = pendingSharedFilePath ?: extractSharedFilePathFromIntent(intent)
                    pendingSharedFilePath = null
                    result.success(path)
                }
                else -> result.notImplemented()
            }
        }

        deepLinkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEEP_LINK_CHANNEL)
        deepLinkChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialDeepLink" -> {
                    val link = pendingDeepLinkUri ?: extractActivityDeepLink(intent)
                    pendingDeepLinkUri = null
                    result.success(link)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LAUNCHER_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "openApp") {
                    val packageName = call.argument<String>("packageName")
                    if (packageName.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                        if (launchIntent != null) {
                            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(launchIntent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (_: Exception) {
                        result.success(false)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingDeepLinkUri = extractActivityDeepLink(intent)
        if (pendingDeepLinkUri == null) {
            pendingSharedFilePath = extractSharedFilePathFromIntent(intent)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val deepLink = extractActivityDeepLink(intent)
        if (deepLink != null) {
            if (deepLinkChannel != null) {
                deepLinkChannel?.invokeMethod("onDeepLinkReceived", deepLink)
            } else {
                pendingDeepLinkUri = deepLink
            }
            return
        }

        val path = extractSharedFilePathFromIntent(intent)
        if (path != null) {
            if (methodChannel != null) {
                methodChannel?.invokeMethod("onSharedFileReceived", path)
            } else {
                pendingSharedFilePath = path
            }
        }
    }

    private fun extractActivityDeepLink(intent: Intent?): String? {
        if (intent == null || intent.action != Intent.ACTION_VIEW) return null
        val uri: Uri = intent.data ?: return null
        val scheme = uri.scheme?.lowercase()
        val host = uri.host?.lowercase()

        val isCustomScheme = scheme == "teamtracker" && host == "activity"
        val isHttpsLink = (scheme == "https" || scheme == "http") &&
            host == "fralopo62.github.io" &&
            (uri.path?.startsWith("/team-tracker/activity") == true)

        if (isCustomScheme || isHttpsLink) {
            return uri.toString()
        }
        return null
    }

    private fun extractSharedFilePathFromIntent(intent: Intent?): String? {
        if (intent == null) return null
        if (extractActivityDeepLink(intent) != null) return null

        val uri: Uri? = if (intent.action == Intent.ACTION_SEND) {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
        } else if (intent.action == Intent.ACTION_VIEW) {
            intent.data
        } else {
            null
        }

        if (uri == null) return null

        return copyUriToCache(uri)
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val fileName = getFileName(uri) ?: "imported_activity_${System.currentTimeMillis()}"
            val outFile = File(cacheDir, fileName)
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(outFile).use { output ->
                    input.copyTo(output)
                }
            } ?: return null
            outFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun getFileName(uri: Uri): String? {
        if (uri.scheme == "content") {
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex >= 0 && cursor.moveToFirst()) {
                    return cursor.getString(nameIndex)
                }
            }
        }
        return uri.lastPathSegment
    }
}