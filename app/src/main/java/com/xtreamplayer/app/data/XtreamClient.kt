package com.xtreamplayer.app.data

import android.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.decodeFromString
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.IOException
import java.net.URLEncoder
import java.util.concurrent.TimeUnit

/** Thin client for the Xtream Codes player_api.php protocol. */
class XtreamClient {

    val http: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
        .followRedirects(true)
        .followSslRedirects(true)
        .build()

    val json = Json {
        ignoreUnknownKeys = true
        isLenient = true          // Xtream mixes numbers and strings freely
        coerceInputValues = true
        explicitNulls = false
    }

    private suspend fun fetch(url: String): String = withContext(Dispatchers.IO) {
        val req = Request.Builder().url(url).header("User-Agent", USER_AGENT).build()
        http.newCall(req).execute().use { r ->
            if (!r.isSuccessful) throw IOException("HTTP ${r.code}")
            r.body?.string() ?: throw IOException("Empty response")
        }
    }

    private fun enc(s: String) = URLEncoder.encode(s, "UTF-8")

    private fun api(a: Account, action: String? = null, extra: String = ""): String {
        val base = "${a.baseUrl}/player_api.php?username=${enc(a.username)}&password=${enc(a.password)}"
        return if (action == null) base else "$base&action=$action$extra"
    }

    private inline fun <reified T> decodeList(body: String): List<T> =
        runCatching { json.decodeFromString<List<T>>(body) }.getOrDefault(emptyList())

    suspend fun authenticate(a: Account) {
        val body = fetch(api(a))
        val r = runCatching { json.decodeFromString<AuthResponse>(body) }
            .getOrElse { throw IOException("Invalid server response") }
        if (r.userInfo?.auth != "1") throw AuthFailed()
    }

    suspend fun liveCategories(a: Account) = decodeList<Category>(fetch(api(a, "get_live_categories")))
    suspend fun live(a: Account) = decodeList<LiveStream>(fetch(api(a, "get_live_streams")))
    suspend fun vodCategories(a: Account) = decodeList<Category>(fetch(api(a, "get_vod_categories")))
    suspend fun vod(a: Account) = decodeList<VodStream>(fetch(api(a, "get_vod_streams")))
    suspend fun seriesCategories(a: Account) = decodeList<Category>(fetch(api(a, "get_series_categories")))
    suspend fun series(a: Account) = decodeList<SeriesItem>(fetch(api(a, "get_series")))

    suspend fun vodInfo(a: Account, vodId: String): VodDetail {
        val root = json.parseToJsonElement(fetch(api(a, "get_vod_info", "&vod_id=${enc(vodId)}"))).jsonObject
        val info = root["info"] as? JsonObject ?: JsonObject(emptyMap())
        return VodDetail(
            plot = info.str("plot") ?: info.str("description"),
            genre = info.str("genre"),
            year = (info.str("releasedate") ?: info.str("release_date"))?.take(4),
            duration = info.str("duration"),
            cover = info.str("movie_image") ?: info.str("cover_big"),
        )
    }

    suspend fun seriesInfo(a: Account, seriesId: String): SeriesDetail {
        val root = json.parseToJsonElement(fetch(api(a, "get_series_info", "&series_id=${enc(seriesId)}"))).jsonObject
        val info = root["info"] as? JsonObject ?: JsonObject(emptyMap())
        val result = sortedMapOf<Int, List<Episode>>()

        fun parse(season: Int, arr: JsonArray) {
            val list = arr.mapNotNull { el ->
                val o = el as? JsonObject ?: return@mapNotNull null
                val id = o.str("id") ?: return@mapNotNull null
                val ei = o["info"] as? JsonObject
                Episode(
                    id = id,
                    title = o.str("title") ?: "",
                    season = season,
                    number = o.str("episode_num")?.toIntOrNull() ?: 0,
                    ext = o.str("container_extension") ?: "mp4",
                    image = ei?.str("movie_image"),
                    plot = ei?.str("plot"),
                )
            }.sortedBy { it.number }
            if (list.isNotEmpty()) result[season] = list
        }

        when (val eps = root["episodes"]) {
            is JsonObject -> eps.forEach { (k, v) ->
                (v as? JsonArray)?.let { parse(k.toIntOrNull() ?: 1, it) }
            }
            is JsonArray -> eps.forEachIndexed { i, v -> (v as? JsonArray)?.let { parse(i + 1, it) } }
            else -> Unit
        }
        return SeriesDetail(info.str("plot"), info.str("cover"), result)
    }

    /** Returns the title of the programme currently airing, if the server provides EPG data. */
    suspend fun nowPlaying(a: Account, streamId: String): String? {
        val body = fetch(api(a, "get_short_epg", "&stream_id=${enc(streamId)}&limit=1"))
        val listings = json.parseToJsonElement(body).jsonObject["epg_listings"] as? JsonArray ?: return null
        val title = (listings.firstOrNull() as? JsonObject)?.str("title") ?: return null
        return runCatching { String(Base64.decode(title, Base64.DEFAULT), Charsets.UTF_8) }.getOrDefault(title)
    }

    fun liveUrl(a: Account, id: String) = "${a.baseUrl}/live/${a.username}/${a.password}/$id.m3u8"
    fun movieUrl(a: Account, id: String, ext: String?) =
        "${a.baseUrl}/movie/${a.username}/${a.password}/$id.${ext ?: "mp4"}"
    fun episodeUrl(a: Account, id: String, ext: String) =
        "${a.baseUrl}/series/${a.username}/${a.password}/$id.$ext"

    private fun JsonObject.str(key: String): String? =
        (this[key] as? JsonPrimitive)?.contentOrNull?.takeIf { it.isNotBlank() }

    companion object {
        const val USER_AGENT = "Mozilla/5.0 (Linux; Android 14) XtreamPlayer/1.0"
    }
}
