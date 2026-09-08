package com.aritxonly.hyperpiliplus

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.Image
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.aritxonly.deadliner.ui.navigation.MiuixFloatingTabBar
import com.aritxonly.deadliner.ui.navigation.MiuixFloatingTabBarDefaults
import com.aritxonly.deadliner.ui.navigation.MiuixFloatingTabItem
import com.aritxonly.deadliner.ui.navigation.MiuixFloatingTabLayout
import com.aritxonly.deadliner.ui.theme.AdvancedMaterialSpec
import com.aritxonly.deadliner.ui.theme.LocalAdvancedMaterialSpec
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ContactsCircle
import top.yukonga.miuix.kmp.icon.extended.Home
import top.yukonga.miuix.kmp.icon.extended.Messages
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.theme.darkColorScheme as miuixDarkColorScheme
import top.yukonga.miuix.kmp.theme.lightColorScheme as miuixLightColorScheme
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
import kotlin.math.roundToInt

/**
 * Application bridge for Deadliner's unmodified floating tab bar. Flutter owns
 * routes and state; the copied Compose implementation owns all chrome motion
 * and glass rendering. The bridge imports a PixelCopy snapshot of Flutter
 * into a Compose [LayerBackdrop] source for the untouched glass pipeline.
 */
@Composable
internal fun DeadlinerNavigationOverlayContent(
    state: NavigationUiState,
    backdropSnapshot: FlutterBackdropSnapshot?,
    backdropDebugState: FlutterBackdropDebugState,
    onBackdropBoundsChanged: (FlutterBackdropBounds) -> Unit,
    onDestinationSelected: (Int) -> Unit,
) {
    val miuixColors = if (state.dark) {
        miuixDarkColorScheme(
            primary = Color(state.primary),
            background = Color(state.background),
            surface = Color(state.surface),
            surfaceContainer = Color(state.surfaceContainer),
            onSurface = Color(state.onSurface),
            outline = Color(state.outline),
        )
    } else {
        miuixLightColorScheme(
            primary = Color(state.primary),
            background = Color(state.background),
            surface = Color(state.surface),
            surfaceContainer = Color(state.surfaceContainer),
            onSurface = Color(state.onSurface),
            outline = Color(state.outline),
        )
    }
    val materialColors = if (state.dark) {
        darkColorScheme(
            primary = Color(state.primary),
            background = Color(state.background),
            surface = Color(state.surface),
            surfaceVariant = Color(state.surfaceContainer),
            onSurface = Color(state.onSurface),
            outline = Color(state.outline),
        )
    } else {
        lightColorScheme(
            primary = Color(state.primary),
            background = Color(state.background),
            surface = Color(state.surface),
            surfaceVariant = Color(state.surfaceContainer),
            onSurface = Color(state.onSurface),
            outline = Color(state.outline),
        )
    }
    val items = state.destinations.map { destination ->
        val icon = when (destination.key) {
            "home" -> MiuixIcons.Home
            "dynamics" -> MiuixIcons.Messages
            else -> MiuixIcons.ContactsCircle
        }
        MiuixFloatingTabItem(
            key = destination.key,
            label = destination.label,
            selectedIcon = rememberVectorPainter(icon),
            unselectedIcon = rememberVectorPainter(icon),
            iconScale = if (destination.key == "home") 0.95f else 1f,
        )
    }
    val backdrop = rememberLayerBackdrop()

    MaterialTheme(colorScheme = materialColors) {
        MiuixTheme(colors = miuixColors) {
            CompositionLocalProvider(
                LocalAdvancedMaterialSpec provides AdvancedMaterialSpec(enabled = true),
            ) {
                AnimatedVisibility(
                    visible = state.visible,
                    enter = fadeIn(tween(180)) + slideInVertically(tween(260)) { it / 2 },
                    exit = fadeOut(tween(140)) + slideOutVertically(tween(220)) { it / 2 },
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .navigationBarsPadding()
                            .padding(start = 16.dp, top = 12.dp, end = 16.dp, bottom = 4.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        if (state.backdropDebug) {
                            BackdropDebugPanel(
                                snapshot = backdropSnapshot,
                                debugState = backdropDebugState,
                            )
                            Spacer(Modifier.height(8.dp))
                        }
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(MiuixFloatingTabBarDefaults.Height),
                            contentAlignment = Alignment.Center,
                        ) {
                            FlutterBackdropLayer(
                                snapshot = backdropSnapshot,
                                backdrop = backdrop,
                            )
                            MiuixFloatingTabBar(
                                items = items,
                                selectedKey = state.destinations
                                    .getOrNull(state.selectedIndex)
                                    ?.key
                                    .orEmpty(),
                                onItemSelected = { selected ->
                                    onDestinationSelected(
                                        items.indexOfFirst { it.key == selected.key }
                                            .coerceAtLeast(0),
                                    )
                                },
                                modifier = Modifier.onGloballyPositioned { coordinates ->
                                    val position = coordinates.positionInWindow()
                                    onBackdropBoundsChanged(
                                        FlutterBackdropBounds(
                                            left = position.x.roundToInt(),
                                            top = position.y.roundToInt(),
                                            width = coordinates.size.width,
                                            height = coordinates.size.height,
                                        ),
                                    )
                                },
                                layout = MiuixFloatingTabLayout.Stacked,
                                backdrop = backdropSnapshot?.let { backdrop },
                            )
                        }
                    }
                }
            }
        }
    }
}

/**
 * Shows every observable boundary in the cross-surface pipeline. The preview
 * is the unmodified PixelCopy bitmap; the actual navigation bar immediately
 * below it is the LayerBackdrop consumer, making source and output directly
 * comparable on a physical device.
 */
@Composable
private fun BackdropDebugPanel(
    snapshot: FlutterBackdropSnapshot?,
    debugState: FlutterBackdropDebugState,
) {
    val colors = MaterialTheme.colorScheme
    val shape = RoundedCornerShape(18.dp)
    val bounds = debugState.barBounds
    val result = debugState.pixelCopyResult?.toString() ?: "-"
    val sourceText =
        "${debugState.sourceViewClass.substringAfterLast('.')} " +
            "${debugState.surfaceWidthPx}×${debugState.surfaceHeightPx}  " +
            "bar ${bounds?.left ?: 0},${bounds?.top ?: 0} " +
            "${bounds?.width ?: 0}×${bounds?.height ?: 0}"
    val cropText =
        "crop ${debugState.cropLeftPx},${debugState.cropTopPx} " +
            "${debugState.cropWidthPx}×${debugState.cropHeightPx} → " +
            "${debugState.bitmapWidthPx}×${debugState.bitmapHeightPx}"
    val metricsText =
        "frame ${debugState.captureCount}  ${debugState.captureFps}fps  " +
            "result $result  ${debugState.latencyMs}ms " +
            "first ${debugState.firstSampleLatencyMs}ms  sig ${debugState.contentSignature}"
    Column(
        modifier = Modifier
            .widthIn(max = 380.dp)
            .fillMaxWidth()
            .clip(shape)
            .background(colors.surfaceContainer.copy(alpha = 0.97f))
            .border(1.dp, colors.outline.copy(alpha = 0.35f), shape)
            .padding(10.dp),
    ) {
        BasicText(
            text = "Backdrop 调试 · ${debugState.status}",
            style = TextStyle(
                color = colors.onSurface,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
            ),
        )
        Spacer(Modifier.height(7.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .width(116.dp)
                    .height(70.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(colors.onSurface.copy(alpha = 0.08f)),
                contentAlignment = Alignment.Center,
            ) {
                if (snapshot == null) {
                    BasicText(
                        text = "无原始采样",
                        style = TextStyle(
                            color = colors.onSurface.copy(alpha = 0.58f),
                            fontSize = 11.sp,
                        ),
                    )
                } else {
                    Image(
                        bitmap = snapshot.bitmap.asImageBitmap(),
                        contentDescription = "PixelCopy 原始采样",
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxSize(),
                    )
                }
            }
            Spacer(Modifier.width(9.dp))
            Column(modifier = Modifier.weight(1f)) {
                DebugLine(sourceText, colors.onSurface)
                DebugLine(cropText, colors.onSurface)
                DebugLine(metricsText, colors.onSurface)
                DebugLine(
                    if (snapshot == null) {
                        "LayerBackdrop：等待 Bitmap"
                    } else {
                        "LayerBackdrop：已注册；下方底栏为输出"
                    },
                    colors.onSurface,
                )
            }
        }
    }
}

@Composable
private fun DebugLine(text: String, color: Color) {
    BasicText(
        text = text,
        style = TextStyle(
            color = color.copy(alpha = 0.72f),
            fontSize = 10.sp,
            lineHeight = 13.sp,
        ),
    )
}

/**
 * Imports an asynchronously copied Flutter crop into Compose's layer tree.
 *
 * The crop is recorded into Miuix's [LayerBackdrop] but is nearly invisible in
 * the normal Compose output. Modifier order is important: [graphicsLayer]
 * wraps the source recorder, so its alpha only affects final composition and
 * not the pixels stored in [LayerBackdrop]. A tiny non-zero alpha avoids layer
 * culling observed on some HyperOS renderers.
 */
@Composable
private fun FlutterBackdropLayer(
    snapshot: FlutterBackdropSnapshot?,
    backdrop: top.yukonga.miuix.kmp.blur.LayerBackdrop,
) {
    if (snapshot == null) return
    val density = LocalDensity.current
    val sourceSize =
        (snapshot.sourceWidthPx / density.density).dp to
            (snapshot.sourceHeightPx / density.density).dp
    Box(
        modifier = Modifier
            .graphicsLayer(alpha = BACKDROP_SOURCE_ALPHA)
            .requiredSize(width = sourceSize.first, height = sourceSize.second)
            .layerBackdrop(backdrop),
    ) {
        Image(
            bitmap = snapshot.bitmap.asImageBitmap(),
            contentDescription = null,
            contentScale = ContentScale.FillBounds,
            modifier = Modifier.fillMaxSize(),
        )
    }
}

private const val BACKDROP_SOURCE_ALPHA = 0.001f
