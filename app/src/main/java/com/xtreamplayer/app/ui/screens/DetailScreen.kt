package com.xtreamplayer.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import com.xtreamplayer.app.AppViewModel
import com.xtreamplayer.app.R
import com.xtreamplayer.app.data.ContentType
import com.xtreamplayer.app.data.SeriesDetail
import com.xtreamplayer.app.data.VodDetail

@Composable
fun DetailScreen(
    vm: AppViewModel,
    type: ContentType,
    id: String,
    onBack: () -> Unit,
    onPlay: () -> Unit,
) {
    val entry = remember(type, id) { vm.find(type, id) }
    if (entry == null) {
        LaunchedEffect(Unit) { onBack() }
        return
    }

    val favs by vm.favorites.collectAsStateWithLifecycle()
    val isFav = vm.isFavorite(favs, entry)

    val vod by produceState<VodDetail?>(null, id) {
        if (type == ContentType.MOVIE) value = vm.vodDetail(id)
    }
    val series by produceState<SeriesDetail?>(null, id) {
        if (type == ContentType.SERIES) value = vm.seriesDetail(id)
    }

    var selectedSeason by rememberSaveable { mutableIntStateOf(-1) }
    val seasons = series?.episodes?.keys?.toList().orEmpty()
    val currentSeason = if (selectedSeason in seasons) selectedSeason else seasons.firstOrNull()

    val plot = vod?.plot ?: series?.plot
    val backdrop = vod?.cover ?: series?.cover ?: entry.image

    LazyColumn(Modifier.fillMaxSize()) {
        item {
            Box(Modifier.fillMaxWidth().height(320.dp)) {
                AsyncImage(
                    model = backdrop, contentDescription = null, contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize().background(MaterialTheme.colorScheme.surfaceVariant),
                )
                Box(
                    Modifier.fillMaxSize().background(
                        Brush.verticalGradient(listOf(Color.Black.copy(alpha = 0.35f), Color.Transparent, MaterialTheme.colorScheme.background))
                    )
                )
                Row(
                    Modifier.fillMaxWidth().statusBarsPadding().padding(horizontal = 8.dp, vertical = 4.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    val btnColors = IconButtonDefaults.iconButtonColors(containerColor = Color.Black.copy(alpha = 0.45f))
                    IconButton(onClick = onBack, colors = btnColors) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                    IconButton(onClick = { vm.toggleFavorite(entry) }, colors = btnColors) {
                        Icon(
                            if (isFav) Icons.Default.Favorite else Icons.Default.FavoriteBorder,
                            contentDescription = stringResource(R.string.favorites),
                            tint = if (isFav) MaterialTheme.colorScheme.primary else Color.White,
                        )
                    }
                }
                Text(
                    entry.name,
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.align(Alignment.BottomStart).padding(horizontal = 16.dp, vertical = 8.dp),
                )
            }
        }

        item {
            Column(Modifier.padding(horizontal = 16.dp)) {
                val meta = listOfNotNull(
                    vod?.year,
                    vod?.duration,
                    vod?.genre,
                    entry.rating?.toDoubleOrNull()?.takeIf { it > 0 }?.let { "★ " + String.format("%.1f", it) },
                ).joinToString("  •  ")
                if (meta.isNotBlank()) {
                    Text(meta, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(12.dp))
                }
                if (type == ContentType.MOVIE) {
                    Button(
                        onClick = { vm.prepareMovie(entry); onPlay() },
                        shape = RoundedCornerShape(14.dp),
                        modifier = Modifier.fillMaxWidth().height(52.dp),
                    ) {
                        Icon(Icons.Default.PlayArrow, contentDescription = null)
                        Spacer(Modifier.width(8.dp))
                        Text(stringResource(R.string.play), fontWeight = FontWeight.SemiBold)
                    }
                    Spacer(Modifier.height(14.dp))
                }
                if (!plot.isNullOrBlank()) {
                    Text(plot, style = MaterialTheme.typography.bodyMedium)
                    Spacer(Modifier.height(16.dp))
                }
            }
        }

        if (type == ContentType.SERIES) {
            if (seasons.isNotEmpty()) {
                item {
                    LazyRow(
                        contentPadding = PaddingValues(horizontal = 12.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        items(seasons) { s ->
                            FilterChip(
                                selected = s == currentSeason,
                                onClick = { selectedSeason = s },
                                label = { Text(stringResource(R.string.season_n, s)) },
                            )
                        }
                    }
                    Spacer(Modifier.height(8.dp))
                }
            } else if (series == null) {
                item {
                    Box(Modifier.fillMaxWidth().padding(24.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                }
            }
            val episodes = series?.episodes?.get(currentSeason).orEmpty()
            items(episodes, key = { it.id }) { ep ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable { vm.prepareEpisode(entry.name, ep); onPlay() }
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(
                        Modifier.width(120.dp).aspectRatio(16f / 9f).clip(RoundedCornerShape(8.dp))
                            .background(MaterialTheme.colorScheme.surfaceVariant)
                    ) {
                        AsyncImage(
                            model = ep.image ?: backdrop, contentDescription = null,
                            contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize(),
                        )
                        Icon(
                            Icons.Default.PlayArrow, contentDescription = null, tint = Color.White,
                            modifier = Modifier.align(Alignment.Center).size(28.dp),
                        )
                    }
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(
                            "${ep.number}. " + ep.title.ifBlank { stringResource(R.string.episode_n, ep.number) },
                            style = MaterialTheme.typography.bodyLarge, maxLines = 2, overflow = TextOverflow.Ellipsis,
                        )
                        if (!ep.plot.isNullOrBlank()) {
                            Text(
                                ep.plot, style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 2, overflow = TextOverflow.Ellipsis,
                            )
                        }
                    }
                }
            }
        }
        item { Spacer(Modifier.navigationBarsPadding().height(24.dp)) }
    }
}
