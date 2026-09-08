package com.aritxonly.hyperpiliplus

import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.view.MotionEvent
import android.view.WindowManager.LayoutParams
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AudioServiceActivity() {
    private var nativeFeedback: NativeFeedback? = null
    private var miuixNavigationOverlay: MiuixNavigationOverlay? = null

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (AndroidHelper.isFoldable) {
            AndroidHelper.ToDart.onConfigurationChanged?.run()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Required by HyperOS to keep an edge-to-edge light navigation bar.
            window.isNavigationBarContrastEnforced = false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nativeFeedback = NativeFeedback(this, flutterEngine)
        miuixNavigationOverlay = MiuixNavigationOverlay(this, flutterEngine)
        window.decorView.post { miuixNavigationOverlay?.attach() }
    }

    override fun onDestroy() {
        nativeFeedback?.dispose()
        nativeFeedback = null
        miuixNavigationOverlay?.dispose()
        miuixNavigationOverlay = null
        stopService(Intent(this, com.ryanheise.audioservice.AudioService::class.java))
        super.onDestroy()
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        // Let Flutter enqueue the pointer update first. Starting PixelCopy
        // before dispatch consistently captures the frame preceding the gesture
        // and makes the glass look one update behind the page.
        val handled = super.dispatchTouchEvent(event)
        miuixNavigationOverlay?.onTouchEvent(event)
        return handled
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        AndroidHelper.ToDart.onUserLeaveHint?.run()
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration?) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        AndroidHelper.isPipMode = isInPictureInPictureMode
    }
}
