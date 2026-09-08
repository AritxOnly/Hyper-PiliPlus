package com.aritxonly.hyperpiliplus

import android.app.Activity
import android.app.AlertDialog
import android.widget.Toast
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Separate dialog windows sit above the activity's native navigation overlay. */
class NativeFeedback(private val activity: Activity, engine: FlutterEngine) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "hyper_piliplus/native_feedback")
    private var toast: Toast? = null
    private var toastId: Int? = null
    private var dialog: AlertDialog? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "showToast" -> {
                    val message = call.argument<String>("message")
                    if (message == null) {
                        result.error("arguments", "Missing message", null)
                    } else {
                        toast?.cancel()
                        toastId = call.argument<Int>("id")
                        toast = Toast.makeText(activity.applicationContext, message, Toast.LENGTH_LONG)
                        toast?.show()
                        result.success(null)
                    }
                }
                "cancelToast" -> {
                    if (toastId == call.argument<Int>("id")) {
                        toast?.cancel()
                        toast = null
                        toastId = null
                    }
                    result.success(null)
                }
                "showActions" -> {
                    val items = call.argument<List<String>>("items")
                    if (items.isNullOrEmpty() || activity.isFinishing || activity.isDestroyed) {
                        result.error("unavailable", "No active activity or actions", null)
                    } else {
                        dialog?.dismiss()
                        val theme = if (call.argument<Boolean>("dark") == true)
                            android.R.style.Theme_Material_Dialog_Alert
                        else android.R.style.Theme_Material_Light_Dialog_Alert
                        var selected: Int? = null
                        val next = AlertDialog.Builder(activity, theme)
                            .setItems(items.toTypedArray()) { _, index -> selected = index }
                            .create()
                        next.setOnDismissListener {
                            if (dialog === next) dialog = null
                            result.success(selected)
                        }
                        dialog = next
                        next.show()
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun dispose() {
        dialog?.dismiss()
        dialog = null
        toast?.cancel()
        toast = null
        channel.setMethodCallHandler(null)
    }
}
