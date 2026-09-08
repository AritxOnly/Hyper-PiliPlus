package com.aritxonly.hyperpiliplus

import android.app.Activity
import android.graphics.Color as AndroidColor
import android.view.Gravity
import android.view.MotionEvent
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.renderer.FlutterUiDisplayListener
import io.flutter.plugin.common.MethodChannel
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.theme.darkColorScheme
import top.yukonga.miuix.kmp.theme.lightColorScheme

private const val MIUIX_NAVIGATION_CHANNEL = "com.aritxonly.hyperpiliplus/miuix_navigation"

/**
 * A thin native shell around Flutter's main destinations.  Flutter remains
 * the source of truth for pages; this overlay only owns the Android chrome.
 */
internal class MiuixNavigationOverlay(
    private val activity: Activity,
    flutterEngine: FlutterEngine,
) {
    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MIUIX_NAVIGATION_CHANNEL)
    private var uiState by mutableStateOf(NavigationUiState())
    private var backdropSnapshot by mutableStateOf<FlutterBackdropSnapshot?>(null)
    private var backdropDebugState by mutableStateOf(FlutterBackdropDebugState())
    private var composeView: ComposeView? = null
    private var viewTreeOwner: OverlayViewTreeOwner? = null
    private val flutterRenderer = flutterEngine.renderer
    private val backdropSampler = FlutterSurfaceBackdropSampler(
        activity = activity,
        onSnapshotChanged = { snapshot -> backdropSnapshot = snapshot },
        onDebugStateChanged = { debugState -> backdropDebugState = debugState },
    )
    private val flutterUiDisplayListener = object : FlutterUiDisplayListener {
        override fun onFlutterUiDisplayed() {
            backdropSampler.onFlutterUiDisplayed()
        }

        override fun onFlutterUiNoLongerDisplayed() {
            backdropSampler.onFlutterUiNoLongerDisplayed()
        }
    }

    init {
        // Unlike a polling delay, this callback fires exactly when Flutter has
        // committed its first usable frame to the rendering surface. FlutterRenderer
        // also invokes it immediately when the UI was already being displayed.
        flutterRenderer.addIsDisplayingFlutterUiListener(flutterUiDisplayListener)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    uiState = NavigationUiState.from(call.arguments as? Map<*, *>)
                    backdropSampler.setDebugEnabled(uiState.backdropDebug)
                    backdropSampler.setEnabled(uiState.visible && uiState.backdropSampling)
                    result.success(null)
                }
                "hide" -> {
                    uiState = uiState.copy(visible = false)
                    backdropSampler.setEnabled(false)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun attach() {
        if (composeView != null) return
        val lifecycleOwner = activity as? LifecycleOwner ?: return
        val owner = OverlayViewTreeOwner(lifecycleOwner)
        val view = ComposeView(activity).apply {
            // This view is attached beside Flutter's root view, so it cannot
            // inherit FlutterActivity's lifecycle through the usual parent
            // hierarchy. FlutterActivity does not implement the ViewModel or
            // saved-state owner interfaces, so the overlay owns those trees.
            setViewTreeLifecycleOwner(owner)
            setViewTreeViewModelStoreOwner(owner)
            setViewTreeSavedStateRegistryOwner(owner)
            setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnDetachedFromWindow)
            setContent {
                DeadlinerNavigationOverlayContent(
                    state = uiState,
                    backdropSnapshot = backdropSnapshot,
                    backdropDebugState = backdropDebugState,
                    onBackdropBoundsChanged = backdropSampler::setNavigationBounds,
                    onDestinationSelected = ::selectDestination,
                )
            }
        }
        val content = activity.findViewById<ViewGroup>(android.R.id.content)
        content.addView(
            view,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM,
            ),
        )
        composeView = view
        viewTreeOwner = owner
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        flutterRenderer.removeIsDisplayingFlutterUiListener(flutterUiDisplayListener)
        composeView?.let { view ->
            (view.parent as? ViewGroup)?.removeView(view)
        }
        composeView = null
        backdropSampler.dispose()
        viewTreeOwner?.dispose()
        viewTreeOwner = null
    }

    fun onTouchEvent(event: MotionEvent) {
        backdropSampler.onTouchEvent(event)
    }

    private fun selectDestination(index: Int) {
        channel.invokeMethod("selectDestination", index)
    }
}

/**
 * FlutterActivity supplies a LifecycleOwner but not ComponentActivity's
 * ViewModelStore/SavedState owners. Compose's current Android runtime requires
 * all three ViewTree owners even for a standalone overlay, so provide a small,
 * lifecycle-synchronised owner rather than casting FlutterActivity.
 */
private class OverlayViewTreeOwner(
    host: LifecycleOwner,
) : LifecycleOwner, ViewModelStoreOwner, SavedStateRegistryOwner, DefaultLifecycleObserver {
    private val hostLifecycle = host.lifecycle
    private val lifecycleRegistry = LifecycleRegistry(this)
    private val savedStateController = SavedStateRegistryController.create(this)

    override val lifecycle: Lifecycle
        get() = lifecycleRegistry
    override val viewModelStore = ViewModelStore()
    override val savedStateRegistry: SavedStateRegistry
        get() = savedStateController.savedStateRegistry

    init {
        savedStateController.performAttach()
        savedStateController.performRestore(null)
        hostLifecycle.addObserver(this)
        lifecycleRegistry.currentState = hostLifecycle.currentState
    }

    override fun onCreate(owner: LifecycleOwner) = moveTo(Lifecycle.State.CREATED)

    override fun onStart(owner: LifecycleOwner) = moveTo(Lifecycle.State.STARTED)

    override fun onResume(owner: LifecycleOwner) = moveTo(Lifecycle.State.RESUMED)

    override fun onPause(owner: LifecycleOwner) = moveTo(Lifecycle.State.STARTED)

    override fun onStop(owner: LifecycleOwner) = moveTo(Lifecycle.State.CREATED)

    override fun onDestroy(owner: LifecycleOwner) = dispose()

    fun dispose() {
        hostLifecycle.removeObserver(this)
        if (lifecycleRegistry.currentState != Lifecycle.State.DESTROYED) {
            lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
            viewModelStore.clear()
        }
    }

    private fun moveTo(state: Lifecycle.State) {
        if (lifecycleRegistry.currentState != Lifecycle.State.DESTROYED)
            lifecycleRegistry.currentState = state
    }
}

internal data class NavigationDestination(
    val key: String,
    val label: String,
)

internal data class NavigationUiState(
    val destinations: List<NavigationDestination> = emptyList(),
    val selectedIndex: Int = 0,
    val visible: Boolean = false,
    val backdropSampling: Boolean = false,
    val backdropDebug: Boolean = false,
    val dark: Boolean = false,
    val primary: Int = AndroidColor.rgb(52, 130, 255),
    val background: Int = AndroidColor.rgb(243, 243, 243),
    val surface: Int = AndroidColor.rgb(243, 243, 243),
    val surfaceContainer: Int = AndroidColor.WHITE,
    val onSurface: Int = AndroidColor.BLACK,
    val outline: Int = AndroidColor.rgb(217, 217, 217),
) {
    companion object {
        fun from(args: Map<*, *>?): NavigationUiState {
            if (args == null) return NavigationUiState()
            val destinations = (args["destinations"] as? List<*>)
                ?.mapNotNull { raw ->
                    val item = raw as? Map<*, *> ?: return@mapNotNull null
                    val key = item["key"] as? String ?: return@mapNotNull null
                    val label = item["label"] as? String ?: return@mapNotNull null
                    NavigationDestination(key, label)
                }
                .orEmpty()
            fun color(name: String, fallback: Int) = (args[name] as? Number)?.toInt() ?: fallback
            return NavigationUiState(
                destinations = destinations,
                selectedIndex = ((args["selectedIndex"] as? Number)?.toInt() ?: 0)
                    .coerceIn(0, (destinations.size - 1).coerceAtLeast(0)),
                visible = (args["visible"] as? Boolean == true) && destinations.size > 1,
                backdropSampling = args["backdropSampling"] as? Boolean ?: false,
                backdropDebug = args["backdropDebug"] as? Boolean ?: false,
                dark = args["dark"] as? Boolean ?: false,
                primary = color("primary", AndroidColor.rgb(52, 130, 255)),
                background = color("background", AndroidColor.rgb(243, 243, 243)),
                surface = color("surface", AndroidColor.rgb(243, 243, 243)),
                surfaceContainer = color("surfaceContainer", AndroidColor.WHITE),
                onSurface = color("onSurface", AndroidColor.BLACK),
                outline = color("outline", AndroidColor.rgb(217, 217, 217)),
            )
        }
    }
}

@Composable
private fun NavigationOverlayContent(
    state: NavigationUiState,
    onDestinationSelected: (Int) -> Unit,
) {
    val colors = if (state.dark) {
        darkColorScheme(
            primary = Color(state.primary),
            background = Color(state.background),
            surface = Color(state.surface),
            surfaceContainer = Color(state.surfaceContainer),
            onSurface = Color(state.onSurface),
            outline = Color(state.outline),
        )
    } else {
        lightColorScheme(
            primary = Color(state.primary),
            background = Color(state.background),
            surface = Color(state.surface),
            surfaceContainer = Color(state.surfaceContainer),
            onSurface = Color(state.onSurface),
            outline = Color(state.outline),
        )
    }
    MiuixTheme(colors = colors) {
        AnimatedVisibility(
            visible = state.visible,
            enter = fadeIn(tween(180)) + slideInVertically(tween(260)) { it / 2 },
            exit = fadeOut(tween(140)) + slideOutVertically(tween(220)) { it / 2 },
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .navigationBarsPadding()
                    .padding(start = 16.dp, top = 12.dp, end = 16.dp, bottom = 4.dp),
                contentAlignment = Alignment.Center,
            ) {
                FloatingMiuixNavigationBar(
                    state = state,
                    onDestinationSelected = onDestinationSelected,
                )
            }
        }
    }
}

/**
 * The Flutter surface cannot be registered as Miuix's [LayerBackdrop], so this
 * deliberately uses the same readable, translucent soft-glass fallback on all
 * API levels instead of pretending to provide backdrop blur.
 */
@Composable
private fun FloatingMiuixNavigationBar(
    state: NavigationUiState,
    onDestinationSelected: (Int) -> Unit,
) {
    val shape = RoundedCornerShape(percent = 50)
    val scheme = MiuixTheme.colorScheme
    val glassColor = scheme.surfaceContainer.copy(alpha = if (state.dark) 0.82f else 0.78f)
    val hairlineColor = if (state.dark) Color.White.copy(alpha = 0.14f) else Color.White.copy(alpha = 0.72f)
    val indicatorColor = if (state.dark) Color.White.copy(alpha = 0.14f) else Color.Black.copy(alpha = 0.075f)
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(54.dp)
            .shadow(
                elevation = if (state.dark) 16.dp else 10.dp,
                shape = shape,
                ambientColor = Color.Black.copy(alpha = if (state.dark) 0.45f else 0.17f),
                spotColor = Color.Black.copy(alpha = if (state.dark) 0.34f else 0.12f),
            )
            .clip(shape)
            .background(glassColor)
            .border(1.dp, hairlineColor, shape)
            .padding(horizontal = 7.dp, vertical = 3.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            state.destinations.forEachIndexed { index, destination ->
                val selected = index == state.selectedIndex
                val itemShape = RoundedCornerShape(percent = 50)
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                        .clip(itemShape)
                        .background(if (selected) indicatorColor else Color.Transparent)
                        .clickable(
                            role = Role.Tab,
                            onClick = { onDestinationSelected(index) },
                        )
                        .padding(horizontal = 4.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    NavigationGlyph(destination.key, selected, scheme.onSurfaceContainer)
                    Spacer(Modifier.height(1.dp))
                    androidx.compose.foundation.text.BasicText(
                        text = destination.label,
                        style = TextStyle(
                            color = scheme.onSurfaceContainer,
                            fontSize = 10.sp,
                            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
                            textAlign = TextAlign.Center,
                        ),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }
}

@Composable
private fun NavigationGlyph(key: String, selected: Boolean, color: Color) {
    Canvas(Modifier.size(22.dp)) {
        val stroke = Stroke(width = 1.9.dp.toPx(), cap = StrokeCap.Round)
        val center = Offset(size.width / 2f, size.height / 2f)
        when (key) {
            "home" -> {
                val roof = listOf(
                    Offset(size.width * .18f, size.height * .48f),
                    Offset(size.width * .5f, size.height * .2f),
                    Offset(size.width * .82f, size.height * .48f),
                )
                drawLine(color, roof[0], roof[1], strokeWidth = stroke.width, cap = StrokeCap.Round)
                drawLine(color, roof[1], roof[2], strokeWidth = stroke.width, cap = StrokeCap.Round)
                drawRoundRect(
                    color = color,
                    topLeft = Offset(size.width * .27f, size.height * .45f),
                    size = androidx.compose.ui.geometry.Size(size.width * .46f, size.height * .35f),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(2.dp.toPx()),
                    style = if (selected) androidx.compose.ui.graphics.drawscope.Fill else stroke,
                )
            }
            "dynamics" -> {
                drawCircle(color, radius = size.minDimension * .29f, center = center, style = stroke)
                drawCircle(color, radius = size.minDimension * .09f, center = center, style = if (selected) androidx.compose.ui.graphics.drawscope.Fill else stroke)
                drawCircle(color.copy(alpha = .72f), radius = size.minDimension * .06f, center = Offset(size.width * .78f, size.height * .3f))
            }
            else -> {
                drawCircle(color, radius = size.minDimension * .18f, center = Offset(center.x, size.height * .35f), style = if (selected) androidx.compose.ui.graphics.drawscope.Fill else stroke)
                drawRoundRect(
                    color = color,
                    topLeft = Offset(size.width * .24f, size.height * .54f),
                    size = androidx.compose.ui.geometry.Size(size.width * .52f, size.height * .23f),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(size.height * .12f),
                    style = if (selected) androidx.compose.ui.graphics.drawscope.Fill else stroke,
                )
            }
        }
    }
}
