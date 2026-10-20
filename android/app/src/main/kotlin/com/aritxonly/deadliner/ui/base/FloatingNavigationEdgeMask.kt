package com.aritxonly.deadliner.ui.base

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.aritxonly.deadliner.ui.navigation.MiuixFloatingTabBarDefaults
import top.yukonga.miuix.kmp.theme.MiuixTheme

/** Extracted from Deadliner 9119af22 ImmersiveMiuixCompactNavigationScaffold.
 * Flutter owns the lift setting; the surface fade stays outside the backdrop recorder.
 */
@Composable
internal fun FloatingNavigationEdgeMask(
    bottomLift: Dp,
    modifier: Modifier = Modifier,
) {
    val navigationBarHeight = with(LocalDensity.current) {
        WindowInsets.navigationBars.getBottom(this).toDp()
    }
    val coverageHeight = MiuixFloatingTabBarDefaults.Height + 4.dp + 32.dp +
        navigationBarHeight + bottomLift
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(coverageHeight)
            .edgeFade(top = coverageHeight, bottom = 0.dp)
            .background(MiuixTheme.colorScheme.surface),
    )
}
