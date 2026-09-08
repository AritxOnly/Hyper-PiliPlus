package com.aritxonly.hyperpiliplus

import android.app.Activity
import android.graphics.Rect
import android.view.ActionMode
import android.view.Menu
import android.view.MenuItem
import android.view.View
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

class NativeSelectionToolbar(private val activity: Activity, engine: FlutterEngine) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "hyper_piliplus/text_selection")
    private var mode: ActionMode? = null
    private var owner: Int? = null
    private var pending: MethodChannel.Result? = null
    private var items = emptyList<Map<String, Any>>()
    private val rect = Rect()

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "show", "update" -> {
                    val id = call.argument<Int>("id")
                    if (call.method == "update" && owner != id) {
                        result.success(null)
                    } else if (activity.isFinishing || activity.isDestroyed) {
                        result.error("unavailable", "No active activity", null)
                    } else {
                        if (call.method == "show") {
                            finish(null)
                            owner = id
                            pending = result
                        }
                        items = call.argument<List<Map<String, Any>>>("items") ?: emptyList()
                        val x = call.argument<Number>("x")!!.toDouble().roundToInt()
                        val y = call.argument<Number>("y")!!.toDouble().roundToInt()
                        val endX = call.argument<Number>("endX")!!.toDouble().roundToInt()
                        val endY = call.argument<Number>("endY")!!.toDouble().roundToInt()
                        rect.set(min(x, endX), min(y, endY), max(x, endX) + 1, max(y, endY) + 1)
                        if (call.method == "show") {
                            val root = activity.findViewById<View>(android.R.id.content)
                            mode = root.startActionMode(object : ActionMode.Callback2() {
                                override fun onCreateActionMode(mode: ActionMode, menu: Menu): Boolean {
                                    populate(menu)
                                    return true
                                }
                                override fun onPrepareActionMode(mode: ActionMode, menu: Menu): Boolean {
                                    populate(menu)
                                    return true
                                }
                                override fun onActionItemClicked(mode: ActionMode, item: MenuItem): Boolean {
                                    finish(item.itemId)
                                    return true
                                }
                                override fun onDestroyActionMode(mode: ActionMode) {
                                    if (this@NativeSelectionToolbar.mode === mode) {
                                        this@NativeSelectionToolbar.mode = null
                                        owner = null
                                        pending?.success(null)
                                        pending = null
                                    }
                                }
                                override fun onGetContentRect(mode: ActionMode, view: View, outRect: Rect) {
                                    outRect.set(rect)
                                }
                            }, ActionMode.TYPE_FLOATING)
                            if (mode == null) {
                                pending = null
                                owner = null
                                result.error("unavailable", "Floating ActionMode unavailable", null)
                            }
                        } else {
                            mode?.invalidate()
                            mode?.invalidateContentRect()
                            result.success(null)
                        }
                    }
                }
                "hide" -> {
                    if (owner == call.argument<Int>("id")) finish(null)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun populate(menu: Menu) {
        menu.clear()
        items.forEachIndexed { index, item ->
            menu.add(Menu.NONE, index, index, item["label"] as String).apply {
                isEnabled = item["enabled"] as? Boolean ?: true
                setShowAsAction(MenuItem.SHOW_AS_ACTION_IF_ROOM)
            }
        }
    }

    private fun finish(selected: Int?) {
        val reply = pending
        pending = null
        owner = null
        val previous = mode
        mode = null
        previous?.finish()
        reply?.success(selected)
    }

    fun dispose() {
        finish(null)
        channel.setMethodCallHandler(null)
    }
}
