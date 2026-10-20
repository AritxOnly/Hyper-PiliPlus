package com.aritxonly.hyperpiliplus

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Android 13+ atomic alias updates keep a single launcher entry without killing Flutter. */
class AppIconSwitcher(private val context: Context, engine: FlutterEngine) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "hyper_piliplus/app_icon")
    private val aliases = linkedMapOf(
        "system" to "LauncherSystem",
        "mint" to "LauncherMint",
        "ocean" to "LauncherOcean",
        "rose" to "LauncherRose",
        "violet" to "LauncherViolet",
        "sunset" to "LauncherSunset",
        "graphite" to "LauncherGraphite",
    )

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "get" -> result.success(state())
                    "set" -> {
                        val style = call.arguments as? String
                        require(style in aliases) { "Unknown launcher icon" }
                        val changes = aliases.map { (id, name) ->
                            PackageManager.ComponentEnabledSetting(
                                component(name),
                                if (id == style) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                                else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                                PackageManager.DONT_KILL_APP,
                            )
                        }
                        // MainActivity always stays enabled for deep links, PiP and audio service.
                        context.packageManager.setComponentEnabledSettings(changes)
                        result.success(state())
                    }
                    else -> result.notImplemented()
                }
            } catch (error: IllegalArgumentException) {
                result.error("invalid_icon", error.message, null)
            } catch (error: RuntimeException) {
                result.error("icon_unavailable", "Unable to update launcher icon", null)
            }
        }
    }

    private fun component(name: String) = ComponentName(context, "com.aritxonly.hyperpiliplus.$name")

    private fun state(): Map<String, Any> {
        val selected = aliases.entries.firstOrNull { (id, name) ->
            when (context.packageManager.getComponentEnabledSetting(component(name))) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
                PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> id == "system"
                else -> false
            }
        }?.key ?: "system"
        return mapOf(
            "style" to selected,
            "foreground" to (context.getColor(R.color.ic_launcher_foreground).toLong() and 0xFFFFFFFFL),
            "background" to (context.getColor(R.color.ic_launcher_background).toLong() and 0xFFFFFFFFL),
        )
    }

    fun dispose() = channel.setMethodCallHandler(null)
}
