package com.aritxonly.hyperpiliplus

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.MotionEvent
import android.view.PixelCopy
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterSurfaceView
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.roundToInt

internal data class FlutterBackdropBounds(
    val left: Int,
    val top: Int,
    val width: Int,
    val height: Int,
)

/** A downsampled crop of Flutter content, expressed in the source's pixel space. */
internal data class FlutterBackdropSnapshot(
    val bitmap: Bitmap,
    val sourceWidthPx: Int,
    val sourceHeightPx: Int,
)

internal data class FlutterBackdropDebugState(
    val status: String = "未启用",
    val surfaceWidthPx: Int = 0,
    val surfaceHeightPx: Int = 0,
    val sourceViewClass: String = "-",
    val barBounds: FlutterBackdropBounds? = null,
    val cropLeftPx: Int = 0,
    val cropTopPx: Int = 0,
    val cropWidthPx: Int = 0,
    val cropHeightPx: Int = 0,
    val bitmapWidthPx: Int = 0,
    val bitmapHeightPx: Int = 0,
    val pixelCopyResult: Int? = null,
    val captureCount: Long = 0,
    val captureFps: Int = 0,
    val latencyMs: Long = 0,
    val firstSampleLatencyMs: Long = 0,
    val contentSignature: String = "-",
)

/**
 * Copies only the Flutter pixels behind the native navigation capsule. The
 * source is Flutter's own SurfaceView rather than the Window, so this never
 * captures the Compose overlay and cannot create a recursive glass reflection.
 */
internal class FlutterSurfaceBackdropSampler(
    private val activity: Activity,
    private val onSnapshotChanged: (FlutterBackdropSnapshot?) -> Unit,
    private val onDebugStateChanged: (FlutterBackdropDebugState) -> Unit,
) {
    private val handler = Handler(Looper.getMainLooper())
    private var enabled = false
    private var navigationBounds: FlutterBackdropBounds? = null
    private var captureScheduled = false
    private var captureScheduledAt = Long.MAX_VALUE
    private var captureInFlight = false
    private var captureAgain = false
    private var initialRetryCount = 0
    private var flutterUiDisplayed = false
    private var samplingEnabledAt = Long.MIN_VALUE
    private var hasSnapshot = false
    private var lastCaptureStartedAt = Long.MIN_VALUE
    private var lastSnapshotAt = Long.MIN_VALUE
    private var smoothedFrameIntervalMs = 0f
    private var pointerDown = false
    private var keepCapturingUntil = Long.MIN_VALUE
    private val bitmapBuffers = arrayOfNulls<Bitmap>(2)
    private var displayedBitmap: Bitmap? = null
    private var debugState = FlutterBackdropDebugState()
    private val captureRunnable = Runnable {
        captureScheduled = false
        captureScheduledAt = Long.MAX_VALUE
        capture()
    }

    fun setEnabled(value: Boolean) {
        if (enabled == value) return
        enabled = value
        if (!value) {
            // Never remove the PixelCopy completion callback: a quick hide/show
            // could otherwise leave captureInFlight stuck forever.
            handler.removeCallbacks(captureRunnable)
            captureScheduled = false
            captureScheduledAt = Long.MAX_VALUE
            captureAgain = false
            initialRetryCount = 0
            samplingEnabledAt = Long.MIN_VALUE
            lastSnapshotAt = Long.MIN_VALUE
            smoothedFrameIntervalMs = 0f
            pointerDown = false
            keepCapturingUntil = Long.MIN_VALUE
            // Visibility changes while scrolling or navigating are temporary.
            // Keep the last good frame so the glass never falls back to a flat
            // translucent material when the bar becomes visible again.
            updateDebugState {
                if (hasSnapshot) {
                    it.copy(status = "采样暂停（保留上次成功帧）", captureFps = 0)
                } else {
                    it.copy(status = "未启用", captureFps = 0)
                }
            }
        } else {
            initialRetryCount = 0
            if (!hasSnapshot) samplingEnabledAt = SystemClock.uptimeMillis()
            updateDebugState {
                it.copy(
                    status = when {
                        hasSnapshot -> "采样成功"
                        navigationBounds == null -> "等待底栏坐标"
                        else -> "准备采样"
                    },
                )
            }
            scheduleCapture(preemptDelayed = true)
        }
    }

    /** Flutter has committed a frame, so a previously delayed retry is obsolete. */
    fun onFlutterUiDisplayed() {
        flutterUiDisplayed = true
        initialRetryCount = 0
        scheduleCapture(preemptDelayed = true)
    }

    fun onFlutterUiNoLongerDisplayed() {
        flutterUiDisplayed = false
    }

    fun setNavigationBounds(bounds: FlutterBackdropBounds) {
        if (navigationBounds == bounds) return
        navigationBounds = bounds
        updateDebugState {
            it.copy(
                status = when {
                    !enabled -> it.status
                    hasSnapshot -> "采样成功"
                    else -> "准备采样"
                },
                barBounds = bounds,
            )
        }
        scheduleCapture(preemptDelayed = true)
    }

    /** Called after Activity has dispatched the event to Flutter, without consuming it. */
    fun onTouchEvent(event: MotionEvent) {
        if (!enabled) return
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                pointerDown = true
                keepCapturingUntil = Long.MIN_VALUE
                // Do not fold the idle gap into the active-frame FPS metric.
                lastSnapshotAt = Long.MIN_VALUE
                smoothedFrameIntervalMs = 0f
                scheduleCapture(preemptDelayed = true)
            }

            MotionEvent.ACTION_MOVE -> scheduleCapture(preemptDelayed = true)

            MotionEvent.ACTION_UP,
            MotionEvent.ACTION_CANCEL,
            -> {
                pointerDown = false
                // Keep sampling briefly after release so Flutter's ballistic
                // scrolling remains visible through the glass. Sampling then
                // stops completely while the page is idle.
                keepCapturingUntil = SystemClock.uptimeMillis() + FLING_CAPTURE_WINDOW_MS
                scheduleCapture(preemptDelayed = true)
            }
        }
    }

    fun dispose() {
        enabled = false
        hasSnapshot = false
        displayedBitmap = null
        pointerDown = false
        keepCapturingUntil = Long.MIN_VALUE
        handler.removeCallbacks(captureRunnable)
        onSnapshotChanged(null)
    }

    private fun scheduleCapture(
        delayMillis: Long = 0,
        preemptDelayed: Boolean = false,
    ) {
        if (!enabled || navigationBounds == null) return
        val now = SystemClock.uptimeMillis()
        val rateLimitDelay = if (lastCaptureStartedAt == Long.MIN_VALUE) {
            0L
        } else {
            (MIN_CAPTURE_INTERVAL_MS - (now - lastCaptureStartedAt)).coerceAtLeast(0)
        }
        val scheduledAt = now + max(delayMillis, rateLimitDelay)
        if (captureScheduled) {
            if (!preemptDelayed || scheduledAt >= captureScheduledAt) return
            handler.removeCallbacks(captureRunnable)
        }
        captureScheduled = true
        captureScheduledAt = scheduledAt
        handler.postAtTime(captureRunnable, scheduledAt)
    }

    private fun capture() {
        if (!enabled) return
        if (captureInFlight) {
            captureAgain = true
            return
        }
        val bounds = navigationBounds ?: return
        val source = findFlutterSurfaceView(activity.window.decorView)
        if (source == null || !source.isAttachedToWindow || source.width <= 0 || source.height <= 0) {
            updateDebugState {
                it.copy(
                    status = retainedStatus(if (source == null) {
                        "未找到 FlutterSurfaceView"
                    } else {
                        "FlutterSurfaceView 尚未就绪"
                    }),
                    barBounds = bounds,
                )
            }
            retryInitialCapture()
            return
        }
        if (!source.holder.surface.isValid) {
            updateDebugState {
                it.copy(
                    status = retainedStatus("Flutter Surface 尚未创建"),
                    surfaceWidthPx = source.width,
                    surfaceHeightPx = source.height,
                    sourceViewClass = source.javaClass.name,
                    barBounds = bounds,
                )
            }
            retryInitialCapture()
            return
        }

        val sourceLocation = IntArray(2)
        source.getLocationInWindow(sourceLocation)
        val bleedPx = ceil(source.resources.displayMetrics.density * SAMPLE_BLEED_DP).toInt()
        val sourceRect = Rect(
            bounds.left - sourceLocation[0] - bleedPx,
            bounds.top - sourceLocation[1] - bleedPx,
            bounds.left - sourceLocation[0] + bounds.width + bleedPx,
            bounds.top - sourceLocation[1] + bounds.height + bleedPx,
        ).also { it.intersect(0, 0, source.width, source.height) }
        if (sourceRect.isEmpty) {
            updateDebugState {
                it.copy(
                    status = retainedStatus("等待有效采样区域"),
                    surfaceWidthPx = source.width,
                    surfaceHeightPx = source.height,
                    sourceViewClass = source.javaClass.name,
                    barBounds = bounds,
                )
            }
            retryInitialCapture()
            return
        }

        val destination = obtainDestination(
            width = max(1, (sourceRect.width() * SAMPLE_SCALE).toInt()),
            height = max(1, (sourceRect.height() * SAMPLE_SCALE).toInt()),
        )
        captureInFlight = true
        lastCaptureStartedAt = SystemClock.uptimeMillis()
        updateDebugState {
            it.copy(
                status = if (hasSnapshot) "采样成功" else "PixelCopy 请求中",
                surfaceWidthPx = source.width,
                surfaceHeightPx = source.height,
                sourceViewClass = source.javaClass.name,
                barBounds = bounds,
                cropLeftPx = sourceRect.left,
                cropTopPx = sourceRect.top,
                cropWidthPx = sourceRect.width(),
                cropHeightPx = sourceRect.height(),
                bitmapWidthPx = destination.width,
                bitmapHeightPx = destination.height,
            )
        }
        try {
            PixelCopy.request(source, sourceRect, destination, { result ->
                captureInFlight = false
                if (enabled && result == PixelCopy.SUCCESS) {
                    initialRetryCount = 0
                    val snapshotAt = SystemClock.uptimeMillis()
                    val firstSampleLatency = if (!hasSnapshot && samplingEnabledAt != Long.MIN_VALUE) {
                        snapshotAt - samplingEnabledAt
                    } else {
                        debugState.firstSampleLatencyMs
                    }
                    if (lastSnapshotAt != Long.MIN_VALUE) {
                        val frameInterval = (snapshotAt - lastSnapshotAt).coerceAtLeast(1).toFloat()
                        smoothedFrameIntervalMs = if (smoothedFrameIntervalMs == 0f) {
                            frameInterval
                        } else {
                            smoothedFrameIntervalMs * 0.75f + frameInterval * 0.25f
                        }
                    }
                    lastSnapshotAt = snapshotAt
                    val captureFps = if (smoothedFrameIntervalMs > 0f) {
                        (1_000f / smoothedFrameIntervalMs).roundToInt()
                    } else {
                        0
                    }
                    hasSnapshot = true
                    displayedBitmap = destination
                    onSnapshotChanged(
                        FlutterBackdropSnapshot(
                            bitmap = destination,
                            sourceWidthPx = sourceRect.width(),
                            sourceHeightPx = sourceRect.height(),
                        ),
                    )
                    updateDebugState {
                        it.copy(
                            status = "采样成功",
                            pixelCopyResult = result,
                            captureCount = it.captureCount + 1,
                            captureFps = captureFps,
                            latencyMs = snapshotAt - lastCaptureStartedAt,
                            firstSampleLatencyMs = firstSampleLatency,
                            contentSignature = contentSignature(destination),
                        )
                    }
                } else if (enabled) {
                    updateDebugState {
                        it.copy(
                            status = retainedStatus("PixelCopy 失败"),
                            pixelCopyResult = result,
                            latencyMs = SystemClock.uptimeMillis() - lastCaptureStartedAt,
                        )
                    }
                    retryInitialCapture()
                }
                if (captureAgain) {
                    captureAgain = false
                    scheduleCapture()
                } else if (shouldKeepCapturing()) {
                    scheduleCapture()
                }
            }, handler)
        } catch (_: IllegalArgumentException) {
            captureInFlight = false
            updateDebugState { it.copy(status = retainedStatus("PixelCopy 参数异常")) }
            retryInitialCapture()
        }
    }

    /** Flutter's SurfaceView may become ready a few frames after the overlay. */
    private fun retryInitialCapture() {
        initialRetryCount += 1
        scheduleCapture(
            delayMillis = when {
                !flutterUiDisplayed -> INITIAL_RETRY_WAITING_FOR_FLUTTER_MS
                initialRetryCount <= INITIAL_RETRY_FAST_LIMIT -> INITIAL_RETRY_FAST_DELAY_MS
                else -> INITIAL_RETRY_SLOW_DELAY_MS
            },
        )
    }

    private fun shouldKeepCapturing(): Boolean =
        pointerDown || SystemClock.uptimeMillis() < keepCapturingUntil

    private fun retainedStatus(waitingStatus: String): String =
        if (hasSnapshot) "采样成功（刷新失败，保留上一帧）" else waitingStatus

    private inline fun updateDebugState(
        transform: (FlutterBackdropDebugState) -> FlutterBackdropDebugState,
    ) {
        debugState = transform(debugState)
        onDebugStateChanged(debugState)
    }

    /** Small diagnostic fingerprint; it proves whether sampled pixels change. */
    private fun contentSignature(bitmap: Bitmap): String {
        var hash = 17
        for (yStep in 1..3) {
            for (xStep in 1..3) {
                val x = bitmap.width * xStep / 4
                val y = bitmap.height * yStep / 4
                hash = 31 * hash + bitmap.getPixel(x, y)
            }
        }
        return Integer.toHexString(hash)
    }

    /**
     * Alternate between two mutable bitmaps. PixelCopy writes into the buffer
     * that is not currently displayed by Compose, avoiding allocation churn
     * without racing the active backdrop frame.
     */
    private fun obtainDestination(width: Int, height: Int): Bitmap {
        bitmapBuffers.forEach { existing ->
            if (existing !== displayedBitmap &&
                existing != null &&
                !existing.isRecycled &&
                existing.width == width &&
                existing.height == height
            ) {
                return existing
            }
        }

        val replacementIndex = bitmapBuffers.indexOfFirst { it !== displayedBitmap }
            .coerceAtLeast(0)
        return Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also { replacement ->
            bitmapBuffers[replacementIndex] = replacement
        }
    }

    private fun findFlutterSurfaceView(view: View): SurfaceView? {
        // Use type identity rather than javaClass.name. R8 is free to rename
        // Flutter embedding classes in Release builds, which made the old
        // string comparison reject a valid FlutterSurfaceView.
        if (view is FlutterSurfaceView) return view
        if (view !is ViewGroup) return null
        for (index in 0 until view.childCount) {
            findFlutterSurfaceView(view.getChildAt(index))?.let { return it }
        }
        return null
    }

    private companion object {
        const val SAMPLE_BLEED_DP = 32f
        // A 20% linear sample still has ample detail under the strong blur,
        // while reducing PixelCopy work enough to target the display cadence.
        const val SAMPLE_SCALE = 0.20f
        const val MIN_CAPTURE_INTERVAL_MS = 16L
        const val FLING_CAPTURE_WINDOW_MS = 1_200L
        // The renderer signal preempts this polling. Once Flutter reports a
        // committed frame, retry at display cadence for up to two seconds.
        const val INITIAL_RETRY_WAITING_FOR_FLUTTER_MS = 250L
        const val INITIAL_RETRY_FAST_DELAY_MS = 16L
        const val INITIAL_RETRY_FAST_LIMIT = 120
        const val INITIAL_RETRY_SLOW_DELAY_MS = 250L
    }
}
