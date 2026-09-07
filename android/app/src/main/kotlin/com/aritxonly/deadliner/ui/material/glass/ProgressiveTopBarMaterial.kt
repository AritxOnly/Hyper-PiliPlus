package com.aritxonly.deadliner.ui.material.glass

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.statusBars
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.SubcomposeLayout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import com.aritxonly.deadliner.ui.theme.LocalAdvancedMaterialBackdrop
import com.aritxonly.deadliner.ui.theme.LocalAdvancedMaterialSpec
import top.yukonga.miuix.kmp.blur.LayerBackdrop
import top.yukonga.miuix.kmp.blur.ProgressiveBlur
import top.yukonga.miuix.kmp.blur.progressiveTextureBlur
import kotlin.math.ceil
import kotlin.math.max

val LocalImmersiveExperienceEnabled = staticCompositionLocalOf { false }
val LocalImmersiveTopBarEnabled = staticCompositionLocalOf { false }
val LocalProgressiveTopBarMaterialHosted = staticCompositionLocalOf { false }
val LocalTopBarButtonMaterialProgress = staticCompositionLocalOf { 0f }
val LocalTopBarScrollProgress = staticCompositionLocalOf<Float?> { null }

private const val BlurRadiusDp = 8f
private const val BlurFadeStart = 0.60f
private const val OverlayTopAlpha = 0.94f
private const val OverlayEndFraction = 0.80f
private const val ContentEndFraction = 0.75f
private const val MinimumContentHeightDp = 56f
private const val MaterialHeightTrimDp = 18f

/** Direct copy of Deadliner's progressive top-bar material host. */
@Composable
fun ProgressiveTopBarMaterial(
    enabled: Boolean,
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.() -> Unit,
) {
    if (!enabled) {
        Box(modifier = modifier, content = content)
        return
    }
    val materialProgress by animateFloatAsState(
        targetValue = (LocalTopBarScrollProgress.current ?: 0f).coerceIn(0f, 1f),
        animationSpec = tween(280, easing = FastOutSlowInEasing),
        label = "progressive-top-bar-material",
    )
    val density = LocalDensity.current
    val statusBarHeightPx = WindowInsets.statusBars.getTop(density)
    val minimumContentHeightPx = with(density) { MinimumContentHeightDp.dp.roundToPx() }
    val trimPx = with(density) { MaterialHeightTrimDp.dp.roundToPx() }

    SubcomposeLayout(modifier = modifier) { constraints ->
        val foreground = subcompose("foreground") {
            CompositionLocalProvider(
                LocalImmersiveTopBarEnabled provides true,
                LocalProgressiveTopBarMaterialHosted provides true,
            ) { Box(Modifier.fillMaxWidth(), content = content) }
        }.map { it.measure(constraints.copy(minHeight = 0)) }
        val width = (foreground.maxOfOrNull { it.width } ?: constraints.minWidth)
            .coerceIn(constraints.minWidth, constraints.maxWidth)
        val height = (foreground.maxOfOrNull { it.height } ?: constraints.minHeight)
            .coerceIn(constraints.minHeight, constraints.maxHeight)
        val occupied = max(height, statusBarHeightPx + minimumContentHeightPx)
        val materialHeight = (ceil(occupied / ContentEndFraction).toInt() - trimPx).coerceAtLeast(occupied)
        val background = subcompose("background") {
            DeadlinerProgressiveTopBarBackground(materialProgress, Modifier.fillMaxSize())
        }.map { it.measure(Constraints.fixed(width, materialHeight)) }
        layout(width, height) {
            background.forEach { it.placeRelative(0, 0) }
            foreground.forEach { it.placeRelative(0, 0) }
        }
    }
}

@Composable
private fun DeadlinerProgressiveTopBarBackground(progress: Float, modifier: Modifier) {
    if (progress <= 0f) return
    val backdrop = LocalAdvancedMaterialBackdrop.current
    val advanced = LocalAdvancedMaterialSpec.current
    Box(modifier.graphicsLayer(alpha = progress)) {
        if (advanced.enabled && backdrop != null) {
            Box(Modifier.matchParentSize().progressiveTextureBlur(
                backdrop = backdrop,
                shape = RectangleShape,
                blurRadius = BlurRadiusDp,
                gradient = ProgressiveBlur.Top.copy(startFraction = BlurFadeStart),
            ))
        }
        Box(Modifier.matchParentSize().background(Brush.verticalGradient(
            0f to MaterialTheme.colorScheme.surface.copy(alpha = OverlayTopAlpha),
            OverlayEndFraction to Color.Transparent,
            1f to Color.Transparent,
        )))
    }
}
