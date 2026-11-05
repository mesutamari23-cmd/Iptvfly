package com.xtreamplayer.app

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.xtreamplayer.app.data.*
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.net.URI
import java.util.UUID

data class UiState(
    val ready: Boolean = false,
    val accounts: List<Account> = emptyList(),
    val active: Account? = null,
    val loading: Boolean = false,
    val error: String? = null,
    val live: Catalog = Catalog(),
    val movies: Catalog = Catalog(),
    val series: Catalog = Catalog(),
)

enum class LoginResult { OK, AUTH, NETWORK }

class AppViewModel(app: Application) : AndroidViewModel(app) {

    private val client = XtreamClient()
    private val store = AccountStore(app, client.json)

    private val _ui = MutableStateFlow(UiState())
    val ui: StateFlow<UiState> = _ui.asStateFlow()

    val favorites: StateFlow<Set<String>> =
        store.favorites.stateIn(viewModelScope, SharingStarted.Eagerly, emptySet())

    /** Set right before navigating to the player screen. */
    var playback: Playback? = null

    private var loadJob: Job? = null

    init {
        viewModelScope.launch {
            combine(store.accounts, store.activeId) { list, id ->
                list to (list.firstOrNull { it.id == id } ?: list.firstOrNull())
            }.collect { (list, active) ->
                val changed = active?.id != _ui.value.active?.id
                _ui.update { it.copy(ready = true, accounts = list, active = active) }
                if (changed) {
                    if (active != null) loadCatalog(active)
                    else _ui.update { it.copy(live = Catalog(), movies = Catalog(), series = Catalog(), loading = false) }
                }
            }
        }
    }

    // ---------- Accounts ----------

    suspend fun addAccount(name: String, url: String, user: String, pass: String): LoginResult {
        val base = normalizeUrl(url)
        val account = Account(
            id = UUID.randomUUID().toString(),
            name = name.trim().ifBlank { hostOf(base) },
            baseUrl = base,
            username = user.trim(),
            password = pass,
        )
        return try {
            client.authenticate(account)
            store.save(account)
            store.setActive(account.id)
            LoginResult.OK
        } catch (e: AuthFailed) {
            LoginResult.AUTH
        } catch (e: Exception) {
            LoginResult.NETWORK
        }
    }

    fun switchAccount(id: String) = viewModelScope.launch { store.setActive(id) }
    fun removeAccount(id: String) = viewModelScope.launch { store.remove(id) }

    private fun normalizeUrl(raw: String): String {
        var u = raw.trim().trimEnd('/')
        if (!u.startsWith("http://", true) && !u.startsWith("https://", true)) u = "http://$u"
        return u
    }

    private fun hostOf(url: String) = runCatching { URI(url).host }.getOrNull() ?: url

    // ---------- Catalog ----------

    fun reload() { _ui.value.active?.let(::loadCatalog) }

    private fun loadCatalog(a: Account) {
        loadJob?.cancel()
        loadJob = viewModelScope.launch {
            _ui.update { it.copy(loading = true, error = null, live = Catalog(), movies = Catalog(), series = Catalog()) }
            val results = coroutineScope {
                listOf(
                    async {
                        runCatching {
                            Catalog(client.liveCategories(a), client.live(a).map {
                                Entry(ContentType.LIVE, it.id, it.name, it.icon, it.categoryId)
                            })
                        }.onSuccess { c -> _ui.update { it.copy(live = c) } }
                    },
                    async {
                        runCatching {
                            Catalog(client.vodCategories(a), client.vod(a).map {
                                Entry(ContentType.MOVIE, it.id, it.name, it.icon, it.categoryId, it.rating, it.ext)
                            })
                        }.onSuccess { c -> _ui.update { it.copy(movies = c) } }
                    },
                    async {
                        runCatching {
                            Catalog(client.seriesCategories(a), client.series(a).map {
                                Entry(ContentType.SERIES, it.id, it.name, it.cover, it.categoryId, it.rating)
                            })
                        }.onSuccess { c -> _ui.update { it.copy(series = c) } }
                    },
                ).awaitAll()
            }
            val allFailed = results.all { it.isFailure }
            _ui.update {
                it.copy(loading = false, error = if (allFailed) results.first().exceptionOrNull()?.message ?: "error" else null)
            }
        }
    }

    fun find(type: ContentType, id: String): Entry? {
        val s = _ui.value
        val list = when (type) {
            ContentType.LIVE -> s.live.items
            ContentType.MOVIE -> s.movies.items
            ContentType.SERIES -> s.series.items
        }
        return list.firstOrNull { it.id == id }
    }

    suspend fun vodDetail(id: String): VodDetail? =
        _ui.value.active?.let { a -> runCatching { client.vodInfo(a, id) }.getOrNull() }

    suspend fun seriesDetail(id: String): SeriesDetail? =
        _ui.value.active?.let { a -> runCatching { client.seriesInfo(a, id) }.getOrNull() }

    suspend fun nowPlaying(streamId: String): String? =
        _ui.value.active?.let { a -> runCatching { client.nowPlaying(a, streamId) }.getOrNull() }

    // ---------- Favorites ----------

    private fun favKey(accountId: String, e: Entry) = "$accountId|${e.type.name}|${e.id}"

    fun isFavorite(favs: Set<String>, e: Entry): Boolean {
        val a = _ui.value.active ?: return false
        return favKey(a.id, e) in favs
    }

    fun toggleFavorite(e: Entry) {
        val a = _ui.value.active ?: return
        viewModelScope.launch { store.toggleFavorite(favKey(a.id, e)) }
    }

    fun favoriteEntries(ui: UiState, favs: Set<String>): List<Entry> {
        val a = ui.active ?: return emptyList()
        return (ui.live.items + ui.movies.items + ui.series.items).filter { favKey(a.id, it) in favs }
    }

    // ---------- Playback ----------

    fun prepareLive(e: Entry) {
        val a = _ui.value.active ?: return
        playback = Playback(client.liveUrl(a, e.id), e.name, liveId = e.id)
    }

    fun prepareMovie(e: Entry) {
        val a = _ui.value.active ?: return
        playback = Playback(client.movieUrl(a, e.id, e.ext), e.name)
    }

    fun prepareEpisode(seriesName: String, ep: Episode) {
        val a = _ui.value.active ?: return
        val title = "$seriesName · S${ep.season}E${ep.number}"
        playback = Playback(client.episodeUrl(a, ep.id, ep.ext), title)
    }

    fun playerHttpClient() = client.http
}
