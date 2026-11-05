package com.xtreamplayer.app.ui.screens

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.ActivityInfo
import android.os.Build
import android.util.Rational
import android.view.View
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AspectRatio
import androidx.compose.material.icons.filled.PictureInPictureAlt
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.Subtitles
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.app.PictureInPictureModeChangedInfo
import androidx.core.util.Consumer
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import com.xtreamplayer.app.MainActivity
import com.xtreamplayer.app.R
import com.xtreamplayer.app.data.Playback
import com.xtreamplayer.app.data.Program
import com.xtreamplayer.app.data.XtreamClient
import kotlinx.coroutines.delay
import okhttp3.OkHttpClient
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}

private enum class PlayerDialog { TRACKS, SPEED, GUIDE }

private val SPEEDS = listOf(0.5f, 0.75f, 1f, 1.25f, 1.5f, 2f)

private class TrackOption(
    val label: String,
    val group: Tracks.Group,
    val index: Int,
    val selected: Boolean,
)

private fun trackLabel(f: Format, index: Int): String {
    val lang = f.language?.takeIf { it != "und" }?.let { code ->
        Locale.forLanguageTag(code).displayLanguage.ifBlank { code }
    }
    val parts = listOfNotNull(f.label, lang).distinct()
    return if (parts.isEmpty()) "#${index + 1}" else parts.joinToString(" · ")
}

private fun trackOptions(tracks: Tracks, type: Int): List<TrackOption> {
    val result = ArrayList<TrackOption>()
    for (g in tracks.groups) {
        if (g.type != type) continue
        for (i in 0 until g.length) {
            if (!g.isTrackSupported(i)) continue
            result.add(TrackOption(trackLabel(g.getTrackFormat(i), i), g, i, g.isTrackSelected(i)))
        }
    }
    return result
}

private fun selectTrack(player: Player, option: TrackOption) {
    player.trackSelectionParameters = player.trackSelectionParameters.buildUpon()
        .setTrackTypeDisabled(option.group.type, false)
        .setOverrideForType(TrackSelectionOverride(option.group.mediaTrackGroup, option.index))
        .build()
}

private fun disableSubtitles(player: Player) {
    player.trackSelectionParameters = player.trackSelectionParameters.buildUpon()
        .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
        .build()
}

private fun enterPip(activity: Activity?) {
    if (activity != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        activity.enterPictureInPictureMode(
            PictureInPictureParams.Builder().setAspectRatio(Rational(16, 9)).build()
        )
    }
}

@Composable
fun PlayerScreen(
    playback: Playback,
    client: OkHttpClient,
    loadStart: suspend () -> Long,
    loadGuide: suspend () -> List<Program>,
    onSavePosition: (String, Long) -> Unit,
    onBack: () -> Unit,
) {
    var start by remember(playback) { mutableStateOf<Long?>(null) }
    LaunchedEffect(playback) { start = loadStart() }

    val s = start
    if (s == null) {
        BackHandler(onBack = onBack)
        Box(Modifier.fillMaxSize().background(Color.Black), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(color = Color.White)
        }
        return
    }
    PlayerContent(playback, client, s, loadGuide, onSavePosition, onBack)
}

@androidx.annotation.OptIn(UnstableApi::class)
@Composable
private fun PlayerContent(
    playback: Playback,
    client: OkHttpClient,
    startMs: Long,
    loadGuide: suspend () -> List<Program>,
    onSavePosition: (String, Long) -> Unit,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val view = LocalView.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val isLive = playback.resumeKey == null

    val triedFallback = remember(playback) { booleanArrayOf(false) }

    val player = remember(playback) {
        val dataSource = OkHttpDataSource.Factory(client).setUserAgent(XtreamClient.USER_AGENT)
        ExoPlayer.Builder(context)
            .setMediaSourceFactory(DefaultMediaSourceFactory(dataSource))
            .setLoadControl(
                DefaultLoadControl.Builder()
                    .setBufferDurationsMs(15_000, 60_000, 2_500, 5_000)
                    .build()
            )
            .build().apply {
                setMediaItem(MediaItem.fromUri(playback.url), if (startMs > 0) startMs else C.TIME_UNSET)
                playWhenReady = true
                prepare()
            }
    }

    var error by remember { mutableStateOf<String?>(null) }
    var controlsVisible by remember { mutableStateOf(true) }
    var tracks by remember { mutableStateOf(Tracks.EMPTY) }
    var resizeIndex by remember { mutableIntStateOf(0) }
    var speed by remember { mutableFloatStateOf(1f) }
    var inPip by remember { mutableStateOf(false) }
    var dialog by remember { mutableStateOf<PlayerDialog?>(null) }
    var guide by remember { mutableStateOf<List<Program>>(emptyList()) }
    var guideLoaded by remember { mutableStateOf(false) }
    var tick by remember { mutableLongStateOf(System.currentTimeMillis()) }

    val resizeModes = remember {
        listOf(
            AspectRatioFrameLayout.RESIZE_MODE_FIT,
            AspectRatioFrameLayout.RESIZE_MODE_ZOOM,
            AspectRatioFrameLayout.RESIZE_MODE_FILL,
        )
    }

    fun persist() {
        val key = playback.resumeKey ?: return
        val duration = player.duration
        val position = player.currentPosition
        val finished = duration != C.TIME_UNSET && duration > 0 && position > duration - 45_000
        onSavePosition(key, if (finished || position < 5_000) 0L else position)
    }

    LaunchedEffect(playback) {
        if (isLive) guide = loadGuide()
        guideLoaded = true
    }

    LaunchedEffect(Unit) {
        while (true) {
            delay(30_000)
            tick = System.currentTimeMillis()
        }
    }

    LaunchedEffect(player) {
        if (playback.resumeKey != null) {
            while (true) {
                delay(15_000)
                if (player.isPlaying) persist()
            }
        }
    }

    val nowPlaying = guide.firstOrNull { it.start <= tick && tick < it.end }?.title

    // Immersive landscape mode while playing.
    DisposableEffect(Unit) {
        val activity = context.findActivity()
        val window = activity?.window
        val controller = window?.let { WindowCompat.getInsetsController(it, view) }
        activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        controller?.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        controller?.hide(WindowInsetsCompat.Type.systemBars())
        view.keepScreenOn = true
        onDispose {
            view.keepScreenOn = false
            controller?.show(WindowInsetsCompat.Type.systemBars())
            activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        }
    }

    // Track picture-in-picture state so the overlay can hide itself.
    DisposableEffect(context) {
        val activity = context.findActivity() as? ComponentActivity
        val listener = Consumer<PictureInPictureModeChangedInfo> { info ->
            inPip = info.isInPictureInPictureMode
        }
        activity?.addOnPictureInPictureModeChangedListener(listener)
        onDispose { activity?.removeOnPictureInPictureModeChangedListener(listener) }
    }

    DisposableEffect(player) {
        val mainActivity = context.findActivity() as? MainActivity
        val listener = object : Player.Listener {
            override fun onPlayerError(e: PlaybackException) {
                val fallback = playback.fallbackUrl
                if (fallback != null && !triedFallback[0]) {
                    triedFallback[0] = true
                    player.setMediaItem(MediaItem.fromUri(fallback))
                    player.prepare()
                } else {
                    error = e.errorCodeName
                }
            }

            override fun onPlaybackStateChanged(state: Int) {
                if (state == Player.STATE_READY) error = null
            }

            override fun onTracksChanged(t: Tracks) {
                tracks = t
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                mainActivity?.canEnterPip = isPlaying
            }
        }
        player.addListener(listener)
        onDispose {
            persist()
            mainActivity?.canEnterPip = false
            player.removeListener(listener)
            player.release()
        }
    }

    DisposableEffect(lifecycleOwner, player) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_STOP) {
                persist()
                player.pause()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    BackHandler(onBack = onBack)

    Box(Modifier.fillMaxSize().background(Color.Black)) {
        AndroidView(
            modifier = Modifier.fillMaxSize(),
            factory = { ctx ->
                PlayerView(ctx).apply {
                    this.player = player
                    useController = true
                    controllerShowTimeoutMs = 3500
                    setShowBuffering(PlayerView.SHOW_BUFFERING_ALWAYS)
                    setControllerVisibilityListener(
                        PlayerView.ControllerVisibilityListener { v -> controlsVisible = v == View.VISIBLE }
                    )
                }
            },
            update = { pv ->
                pv.player = player
                pv.resizeMode = resizeModes[resizeIndex]
                pv.useController = !inPip
            },
        )

        AnimatedVisibility(controlsVisible && !inPip, modifier = Modifier.align(Alignment.TopStart)) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .background(Brush.verticalGradient(listOf(Color.Black.copy(alpha = 0.7f), Color.Transparent)))
                    .padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = onBack) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back), tint = Color.White)
                }
                Column(Modifier.padding(start = 4.dp).weight(1f)) {
                    Text(playback.title, color = Color.White, style = MaterialTheme.typography.titleMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    nowPlaying?.let {
                        Text(it, color = Color.White.copy(alpha = 0.75f), style = MaterialTheme.typography.bodySmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                }
                if (isLive) {
                    IconButton(onClick = { dialog = PlayerDialog.GUIDE }) {
                        Icon(Icons.Default.Schedule, contentDescription = stringResource(R.string.guide), tint = Color.White)
                    }
                }
                IconButton(onClick = { dialog = PlayerDialog.TRACKS }) {
                    Icon(Icons.Default.Subtitles, contentDescription = stringResource(R.string.subtitles), tint = Color.White)
                }
                if (!isLive) {
                    IconButton(onClick = { dialog = PlayerDialog.SPEED }) {
                        Icon(Icons.Default.Speed, contentDescription = stringResource(R.string.speed), tint = Color.White)
                    }
                }
                IconButton(onClick = { resizeIndex = (resizeIndex + 1) % resizeModes.size }) {
                    Icon(Icons.Default.AspectRatio, contentDescription = stringResource(R.string.aspect_ratio), tint = Color.White)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    IconButton(onClick = { enterPip(context.findActivity()) }) {
                        Icon(Icons.Default.PictureInPictureAlt, contentDescription = stringResource(R.string.pip), tint = Color.White)
                    }
                }
            }
        }

        error?.let {
            Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(stringResource(R.string.playback_error), color = Color.White)
                Text(it, color = Color.White.copy(alpha = 0.6f), style = MaterialTheme.typography.bodySmall)
                Spacer(Modifier.height(8.dp))
                FilledTonalButton(onClick = { error = null; player.prepare() }) { Text(stringResource(R.string.retry)) }
            }
        }
    }

    when (dialog) {
        PlayerDialog.TRACKS -> TracksDialog(player, tracks) { dialog = null }
        PlayerDialog.SPEED -> SpeedDialog(
            current = speed,
            onPick = { value ->
                speed = value
                player.setPlaybackSpeed(value)
                dialog = null
            },
            onDismiss = { dialog = null },
        )
        PlayerDialog.GUIDE -> GuideDialog(guide, guideLoaded, tick) { dialog = null }
        null -> Unit
    }
}

@Composable
private fun OptionRow(label: String, selected: Boolean, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RadioButton(selected = selected, onClick = null)
        Spacer(Modifier.width(12.dp))
        Text(label, style = MaterialTheme.typography.bodyLarge, maxLines = 2, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun TracksDialog(player: Player, tracks: Tracks, onDismiss: () -> Unit) {
    val audio = trackOptions(tracks, C.TRACK_TYPE_AUDIO)
    val text = trackOptions(tracks, C.TRACK_TYPE_TEXT)
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.ok)) } },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState())) {
                Text(stringResource(R.string.audio), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary)
                Spacer(Modifier.height(4.dp))
                if (audio.isEmpty()) {
                    Text("-", color = MaterialTheme.colorScheme.onSurfaceVariant)
                } else {
                    audio.forEach { o ->
                        OptionRow(o.label, o.selected) { selectTrack(player, o); onDismiss() }
                    }
                }
                Spacer(Modifier.height(16.dp))
                Text(stringResource(R.string.subtitles), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary)
                Spacer(Modifier.height(4.dp))
                OptionRow(stringResource(R.string.subtitles_off), text.none { it.selected }) {
                    disableSubtitles(player)
                    onDismiss()
                }
                text.forEach { o ->
                    OptionRow(o.label, o.selected) { selectTrack(player, o); onDismiss() }
                }
            }
        },
    )
}

@Composable
private fun SpeedDialog(current: Float, onPick: (Float) -> Unit, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.ok)) } },
        title = { Text(stringResource(R.string.speed)) },
        text = {
            Column {
                SPEEDS.forEach { s ->
                    val label = if (s == s.toInt().toFloat()) "${s.toInt()}x" else "${s}x"
                    OptionRow(label, s == current) { onPick(s) }
                }
            }
        },
    )
}

@Composable
private fun GuideDialog(guide: List<Program>, loaded: Boolean, now: Long, onDismiss: () -> Unit) {
    val upcoming = remember(guide, now / 60_000) { guide.filter { it.end > now } }
    val fmt = remember { SimpleDateFormat("HH:mm", Locale.getDefault()) }
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.ok)) } },
        title = { Text(stringResource(R.string.guide)) },
        text = {
            when {
                !loaded -> Box(Modifier.fillMaxWidth().padding(16.dp), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                upcoming.isEmpty() -> Text(stringResource(R.string.no_guide))
                else -> LazyColumn(Modifier.heightIn(max = 320.dp)) {
                    items(upcoming) { p ->
                        val current = p.start <= now && now < p.end
                        Column(Modifier.fillMaxWidth().padding(vertical = 6.dp)) {
                            Text(
                                fmt.format(Date(p.start)) + " – " + fmt.format(Date(p.end)),
                                style = MaterialTheme.typography.labelMedium,
                                color = if (current) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Text(
                                p.title,
                                style = MaterialTheme.typography.bodyLarge,
                                fontWeight = if (current) FontWeight.Bold else FontWeight.Normal,
                            )
                            val d = p.description
                            if (!d.isNullOrBlank()) {
                                Text(
                                    d,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    maxLines = 2,
                                    overflow = TextOverflow.Ellipsis,
                                )
                            }
                        }
                    }
                }
            }
        },
    )
}
