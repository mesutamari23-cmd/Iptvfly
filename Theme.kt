package com.xtreamplayer.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val Accent = Color(0xFF7C5CFF)
val AccentAlt = Color(0xFF00D1B2)

private val DarkColors = darkColorScheme(
    primary = Accent,
    onPrimary = Color.White,
    secondary = AccentAlt,
    background = Color(0xFF0B0D12),
    onBackground = Color(0xFFF2F4F8),
    surface = Color(0xFF141821),
    onSurface = Color(0xFFF2F4F8),
    surfaceVariant = Color(0xFF1C2230),
    onSurfaceVariant = Color(0xFFA9B1C3),
    error = Color(0xFFFF6B6B),
)

@Composable
fun XtreamTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = DarkColors, content = content)
}
