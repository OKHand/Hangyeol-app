package com.hangyeolseed.hangyeol_platform

import android.net.Uri
import androidx.browser.customtabs.CustomTabsClient
import androidx.browser.customtabs.CustomTabsIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private fun loginUri(value: String): Uri? {
        if (value.length > 8192) return null
        val uri = Uri.parse(value)
        if (uri.scheme != "https" || uri.host != "accounts.google.com" ||
            uri.path != "/AccountChooser" || uri.port !in listOf(-1, 443) ||
            !uri.userInfo.isNullOrEmpty() || !uri.fragment.isNullOrEmpty() ||
            uri.queryParameterNames != setOf("continue", "service", "hl") ||
            uri.getQueryParameters("continue").size != 1 ||
            uri.getQueryParameters("service") != listOf("wise") ||
            uri.getQueryParameters("hl") != listOf("ko")) return null
        val target = Uri.parse(uri.getQueryParameter("continue") ?: return null)
        if (target.scheme != "https" || target.host != "script.google.com" ||
            target.port !in listOf(-1, 443) || !target.userInfo.isNullOrEmpty() ||
            !target.fragment.isNullOrEmpty() ||
            !Regex("^/macros/s/[A-Za-z0-9_-]+/exec$").matches(target.path ?: "") ||
            target.queryParameterNames != setOf("device") ||
            target.getQueryParameters("device").size != 1 ||
            !Regex("^[a-f0-9]{64}$").matches(target.getQueryParameter("device") ?: "")) return null
        return uri
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hangyeol/isolated_auth_browser")
            .setMethodCallHandler { call, result ->
                if (call.method != "open") { result.notImplemented(); return@setMethodCallHandler }
                try {
                    val uri = loginUri(call.arguments as? String ?: "")
                    if (uri == null) {
                        result.error("INVALID_URL", "Invalid Google login URL", null)
                        return@setMethodCallHandler
                    }
                    // Only use providers that advertise official ephemeral tabs.
                    val browser = listOf("com.android.chrome", "com.chrome.beta", "com.chrome.dev", "com.chrome.canary")
                        .firstOrNull { CustomTabsClient.isEphemeralBrowsingSupported(this, it) }
                    if (browser == null) { result.success(false); return@setMethodCallHandler }
                    val tab = CustomTabsIntent.Builder().setEphemeralBrowsingEnabled(true).setShowTitle(true).build()
                    tab.intent.setPackage(browser)
                    tab.launchUrl(this, uri)
                    result.success(true)
                } catch (_: Exception) { result.success(false) }
            }
    }
}
