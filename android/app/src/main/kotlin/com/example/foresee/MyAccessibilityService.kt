package com.ufine.foresee

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class MyAccessibilityService : AccessibilityService() {

    private var methodChannel: MethodChannel? = null
    private val handler = android.os.Handler()
    private var lastText: String = ""

    override fun onCreate() {
        super.onCreate()
        val flutterEngine = FlutterEngine(this)
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.foresee/accessibility")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val source = event?.source ?: return
        val text = StringBuilder()
        collectText(source, text)

        val newText = text.toString()
        if (newText.isNotEmpty() && newText != lastText) {
            lastText = newText
            handler.removeCallbacksAndMessages(null)
            handler.postDelayed({
                methodChannel?.invokeMethod("onScreenContent", newText)
            }, 1000) // Debounce for 1 second
        }
    }

    private fun collectText(node: AccessibilityNodeInfo?, text: StringBuilder) {
        if (node == null) return
        if (node.text != null && node.text.isNotEmpty()) {
            text.append(node.text).append("\n")
        }
        for (i in 0 until node.childCount) {
            collectText(node.getChild(i), text)
        }
    }

    override fun onInterrupt() {}
}
