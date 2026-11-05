package com.xtreamplayer.app

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.xtreamplayer.app.data.*
import kotlinx.coroutines.Dispatchers
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
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.net.URI
import java.security.MessageDigest
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

enum class LoginResult { OK, AUTH, NETWORK, INVALID }

class AppViewModel(app: Application) : AndroidViewModel(app) {

    private val client = XtreamClient()
    private val store = AccountStore(app, client.json)

    private val _ui = MutableStateFlow(UiState())
    val ui: StateFlow<UiState> = _ui.asStateFlow()

    val favorites: StateFlow<Set<String>> =
        store.favorites.stateIn(viewModelScope, SharingStarted.Eagerly, emptySet())

    /** Starts as true so adult categories never flash before the saved setting is loaded. */
    val adultLock: StateFlow<Boolean> =
        store.adultLock.stateIn(viewModelScope, SharingStarted.Eagerly, true)

    /** Set right before navigating to the player screen. */
    var playback: Playback? = null

    private var loadJob: Job? = null

    private var playlistEpgUrl: String? = null
    private var epgCache: Map<String, List<Program>>? = null
    private val epgMutex = Mutex()

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

    suspend fun addPlaylist(name: String, url: String, epg: String): LoginResult {
        val base = normalizeUrl(url)
        return try {
            val text = client.playlist(base)
            val parsed = withContext(Dispatchers.Default) { M3uParser.parse(text) }
            if (parsed.live.items.isEmpty() && parsed.movies.items.isEmpty()) {
                LoginResult.INVALID
            } else {
                val account = Account(
                    id = UUID.randomUUID().toString(),
                    name = name.trim().ifBlank { hostOf(base) },
                    baseUrl = base,
                    type = "M3U",
                    epgUrl = epg.trim(),
                )
                store.save(account)
                store.setActive(account.id)
                LoginResult.OK
            }
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

    fun reload() { _ui.value.active?.let { loadCatalog(it) } }

    private fun loadCatalog(a: Account) {
        loadJob?.cancel()
        epgCache = null
        playlistEpgUrl = null
        loadJob = viewModelScope.launch {
            _ui.update { it.copy(loading = true, error = null, live = Catalog(), movies = Catalog(), series = Catalog()) }

            if (a.isM3u) {
                val result = runCatching {
                    val text = client.playlist(a.baseUrl)
                    withContext(Dispatchers.Default) { M3uParser.parse(text) }
                }
                val parsed = result.getOrNull()
                if (parsed != null) {
                    playlistEpgUrl = parsed.epgUrl
                    _ui.update { it.copy(live = parsed.live, movies = parsed.movies, series = Catalog(), loading = false) }
                } else {
                    _ui.update { it.copy(loading = false, error = result.exceptionOrNull()?.message ?: "error") }
                }
                return@launch
            }

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

    // ---------- Programme guide ----------

    suspend fun guide(pb: Playback): List<Program> {
        val a = _ui.value.active ?: return emptyList()
        val liveId = pb.liveId
        val epgId = pb.epgId
        return when {
            !a.isM3u && liveId != null ->
                runCatching { client.schedule(a, liveId) }.getOrDefault(emptyList())
            a.isM3u && epgId != null -> playlistGuide(a, epgId)
            else -> emptyList()
        }
    }

    private suspend fun playlistGuide(a: Account, epgId: String): List<Program> = epgMutex.withLock {
        if (epgCache == null) {
            val url = a.epgUrl.ifBlank { playlistEpgUrl.orEmpty() }.split(",").first().trim()
            if (url.isBlank()) {
                epgCache = emptyMap()
            } else {
                val wanted = _ui.value.live.items.mapNotNull { it.epgId }.toSet()
                val now = System.currentTimeMillis()
                epgCache = runCatching {
                    client.xmltv(url, wanted, now - 3 * 3_600_000L, now + 36 * 3_600_000L)
                }.getOrDefault(emptyMap())
            }
        }
        epgCache?.get(epgId).orEmpty().sortedBy { it.start }
    }

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
        playback = Playback(
            url = client.liveUrl(a, e.id),
            title = e.name,
            liveId = e.id,
            fallbackUrl = client.liveTsUrl(a, e.id),
        )
    }

    /** Plays an entry that carries its own URL (M3U playlists). */
    fun prepareDirect(e: Entry) {
        val a = _ui.value.active ?: return
        val url = e.url ?: return
        playback = Playback(
            url = url,
            title = e.name,
            epgId = e.epgId,
            resumeKey = if (e.type == ContentType.LIVE) null else "${a.id}|${e.id}",
        )
    }

    fun prepareMovie(e: Entry) {
        val a = _ui.value.active ?: return
        playback = Playback(client.movieUrl(a, e.id, e.ext), e.name, resumeKey = "${a.id}|M|${e.id}")
    }

    fun prepareEpisode(seriesName: String, ep: Episode) {
        val a = _ui.value.active ?: return
        val title = "$seriesName · S${ep.season}E${ep.number}"
        playback = Playback(client.episodeUrl(a, ep.id, ep.ext), title, resumeKey = "${a.id}|E|${ep.id}")
    }

    fun playerHttpClient() = client.http

    // ---------- Resume ----------

    suspend fun startPosition(key: String?): Long = if (key == null) 0L else store.position(key)

    fun savePosition(key: String, positionMs: Long) {
        viewModelScope.launch { store.savePosition(key, positionMs) }
    }

    fun clearHistory() {
        viewModelScope.launch { store.clearPositions() }
    }

    // ---------- Parental control ----------

    private fun hashPin(pin: String): String =
        MessageDigest.getInstance("SHA-256").digest("xp:$pin".toByteArray())
            .joinToString("") { "%02x".format(it) }

    suspend fun verifyPin(pin: String): Boolean = store.pinHash() == hashPin(pin)

    suspend fun enableAdultLock(pin: String) {
        store.setAdultLock(true, hashPin(pin))
    }

    suspend fun disableAdultLock(pin: String): Boolean {
        if (!verifyPin(pin)) return false
        store.setAdultLock(false, null)
        return true
    }

    suspend fun changePin(oldPin: String, newPin: String): Boolean {
        if (!verifyPin(oldPin)) return false
        store.setAdultLock(true, hashPin(newPin))
        return true
    }
}
