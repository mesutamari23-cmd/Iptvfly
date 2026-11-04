package com.xtreamplayer.app.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.xtreamplayer.app.AppViewModel
import com.xtreamplayer.app.R
import com.xtreamplayer.app.data.Catalog
import com.xtreamplayer.app.data.ContentType
import com.xtreamplayer.app.data.Entry

private data class HomeTab(val labelRes: Int, val icon: ImageVector)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(vm: AppViewModel, onOpen: (Entry) -> Unit, onAddAccount: () -> Unit) {
    val ui by vm.ui.collectAsStateWithLifecycle()
    val favs by vm.favorites.collectAsStateWithLifecycle()

    var tab by rememberSaveable { mutableIntStateOf(0) }
    var query by rememberSaveable { mutableStateOf("") }
    var searching by rememberSaveable { mutableStateOf(false) }
    var category by rememberSaveable { mutableStateOf<String?>(null) }
    var menu by remember { mutableStateOf(false) }

    val tabs = remember {
        listOf(
            HomeTab(R.string.live, Icons.Default.Tv),
            HomeTab(R.string.movies, Icons.Default.Movie),
            HomeTab(R.string.series, Icons.Default.VideoLibrary),
            HomeTab(R.string.favorites, Icons.Default.Favorite),
        )
    }

    val catalog: Catalog? = when (tab) {
        0 -> ui.live
        1 -> ui.movies
        2 -> ui.series
        else -> null
    }
    val base: List<Entry> = if (tab == 3) {
        remember(ui.live, ui.movies, ui.series, favs, ui.active) { vm.favoriteEntries(ui, favs) }
    } else catalog?.items.orEmpty()

    val filtered = remember(base, category, query) {
        base.filter { e ->
            (category == null || e.categoryId == category) &&
                (query.isBlank() || e.name.contains(query.trim(), ignoreCase = true))
        }
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.background),
                title = {
                    if (searching) {
                        val focus = remember { FocusRequester() }
                        LaunchedEffect(Unit) { focus.requestFocus() }
                        TextField(
                            value = query, onValueChange = { query = it }, singleLine = true,
                            placeholder = { Text(stringResource(R.string.search)) },
                            colors = TextFieldDefaults.colors(
                                focusedContainerColor = Color.Transparent,
                                unfocusedContainerColor = Color.Transparent,
                                focusedIndicatorColor = Color.Transparent,
                                unfocusedIndicatorColor = Color.Transparent,
                            ),
                            modifier = Modifier.fillMaxWidth().focusRequester(focus),
                        )
                    } else {
                        Text(ui.active?.name ?: stringResource(R.string.app_name), maxLines = 1)
                    }
                },
                actions = {
                    if (searching) {
                        IconButton(onClick = { searching = false; query = "" }) {
                            Icon(Icons.Default.Close, contentDescription = null)
                        }
                    } else {
                        IconButton(onClick = { searching = true }) {
                            Icon(Icons.Default.Search, contentDescription = stringResource(R.string.search))
                        }
                        Box {
                            IconButton(onClick = { menu = true }) {
                                Icon(Icons.Default.AccountCircle, contentDescription = null)
                            }
                            DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                                ui.accounts.forEach { acc ->
                                    DropdownMenuItem(
                                        text = { Text(acc.name) },
                                        leadingIcon = {
                                            if (acc.id == ui.active?.id) Icon(Icons.Default.Check, contentDescription = null)
                                        },
                                        onClick = { menu = false; vm.switchAccount(acc.id) },
                                    )
                                }
                                HorizontalDivider()
                                DropdownMenuItem(
                                    text = { Text(stringResource(R.string.add_account)) },
                                    leadingIcon = { Icon(Icons.Default.Add, contentDescription = null) },
                                    onClick = { menu = false; onAddAccount() },
                                )
                                DropdownMenuItem(
                                    text = { Text(stringResource(R.string.retry)) },
                                    leadingIcon = { Icon(Icons.Default.Refresh, contentDescription = null) },
                                    onClick = { menu = false; vm.reload() },
                                )
                                DropdownMenuItem(
                                    text = { Text(stringResource(R.string.remove_account), color = MaterialTheme.colorScheme.error) },
                                    leadingIcon = {
                                        Icon(Icons.Default.Delete, contentDescription = null, tint = MaterialTheme.colorScheme.error)
                                    },
                                    onClick = { menu = false; ui.active?.let { vm.removeAccount(it.id) } },
                                )
                            }
                        }
                    }
                },
            )
        },
        bottomBar = {
            NavigationBar(containerColor = MaterialTheme.colorScheme.surface) {
                tabs.forEachIndexed { i, t ->
                    NavigationBarItem(
                        selected = tab == i,
                        onClick = { tab = i; category = null },
                        icon = { Icon(t.icon, contentDescription = null) },
                        label = { Text(stringResource(t.labelRes)) },
                    )
                }
            }
        },
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            if (catalog != null && catalog.categories.isNotEmpty()) {
                CategoryRow(catalog.categories, category) { category = it }
            }
            when {
                base.isEmpty() && ui.loading -> Box(Modifier.fillMaxSize(), contentAlignment = androidx.compose.ui.Alignment.Center) {
                    CircularProgressIndicator()
                }
                base.isEmpty() && ui.error != null && tab != 3 ->
                    CenterMessage(stringResource(R.string.error_load), stringResource(R.string.retry)) { vm.reload() }
                filtered.isEmpty() -> CenterMessage(stringResource(R.string.no_results))
                tab == 0 -> LazyColumn(Modifier.fillMaxSize()) {
                    items(filtered, key = { it.id }) { e ->
                        LiveRow(e, vm.isFavorite(favs, e)) { onOpen(e) }
                    }
                }
                else -> LazyVerticalGrid(
                    columns = GridCells.Adaptive(112.dp),
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(12.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    items(filtered, key = { "${it.type}-${it.id}" }) { e ->
                        PosterCard(e, vm.isFavorite(favs, e)) { onOpen(e) }
                    }
                }
            }
        }
    }
}
