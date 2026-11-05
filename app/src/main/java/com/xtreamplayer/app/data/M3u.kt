package com.xtreamplayer.app.data

import android.util.Xml
import org.xmlpull.v1.XmlPullParser
import java.io.BufferedInputStream
import java.io.InputStream
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone
import java.util.zip.GZIPInputStream

data class M3uResult(val live: Catalog, val movies: Catalog, val epgUrl: String?)

/** Parser for extended M3U playlists (#EXTINF). */
object M3uParser {

    private val attrRegex = Regex("([A-Za-z0-9_\\-]+)=\"([^\"]*)\"")

    private fun attrs(line: String): Map<String, String> =
        attrRegex.findAll(line).associate { it.groupValues[1].lowercase() to it.groupValues[2] }

    fun parse(text: String): M3uResult {
        val liveItems = ArrayList<Entry>()
        val movieItems = ArrayList<Entry>()
        val liveGroups = LinkedHashMap<String, String>()
        val movieGroups = LinkedHashMap<String, String>()
        val seen = HashSet<String>()
        var epgUrl: String? = null

        var curName: String? = null
        var curAttrs: Map<String, String> = emptyMap()
        var curGroup: String? = null

        for (raw in text.lineSequence()) {
            val line = raw.trim()
            if (line.isEmpty()) continue

            if (line.startsWith("#EXTM3U", ignoreCase = true)) {
                val a = attrs(line)
                epgUrl = a["url-tvg"] ?: a["x-tvg-url"]
            } else if (line.startsWith("#EXTINF", ignoreCase = true)) {
                curAttrs = attrs(line)
                val lastQuote = line.lastIndexOf('"')
                val comma = line.indexOf(',', if (lastQuote >= 0) lastQuote else 0)
                curName = if (comma >= 0) line.substring(comma + 1).trim() else null
                curGroup = curAttrs["group-title"]
            } else if (line.startsWith("#EXTGRP:", ignoreCase = true)) {
                if (curGroup.isNullOrBlank()) curGroup = line.substringAfter(':').trim()
            } else if (line.startsWith("#")) {
                // other directive, ignore
            } else {
                val url = line
                val lower = url.lowercase()
                val path = lower.substringBefore('?')
                val isMovie = "/movie/" in lower || "/series/" in lower ||
                    path.endsWith(".mp4") || path.endsWith(".mkv") || path.endsWith(".avi")

                var title = (curName ?: "").trim()
                if (title.isEmpty()) title = curAttrs["tvg-name"].orEmpty().trim()
                if (title.isEmpty()) title = url.substringAfterLast('/')

                val groupName = (curGroup ?: "").trim().ifEmpty { "Other" }
                val groups = if (isMovie) movieGroups else liveGroups
                val catId = groups.getOrPut(groupName) { groupName }

                var id = Integer.toHexString(url.hashCode())
                if (!seen.add(id)) {
                    var n = 2
                    while (!seen.add(id + "_" + n)) n++
                    id = id + "_" + n
                }

                val logo = curAttrs["tvg-logo"]?.takeIf { it.isNotBlank() }
                val epgId = curAttrs["tvg-id"]?.takeIf { it.isNotBlank() }
                val entry = Entry(
                    type = if (isMovie) ContentType.MOVIE else ContentType.LIVE,
                    id = id,
                    name = title,
                    image = logo,
                    categoryId = catId,
                    url = url,
                    epgId = epgId,
                )
                if (isMovie) movieItems.add(entry) else liveItems.add(entry)

                curName = null
                curAttrs = emptyMap()
                curGroup = null
            }
        }

        return M3uResult(
            live = Catalog(liveGroups.keys.map { Category(it, it) }, liveItems),
            movies = Catalog(movieGroups.keys.map { Category(it, it) }, movieItems),
            epgUrl = epgUrl,
        )
    }
}

/** Streaming XMLTV parser that keeps only the wanted channels inside a time window. */
object XmltvParser {

    fun parse(input: InputStream, wanted: Set<String>, from: Long, to: Long): Map<String, List<Program>> {
        val buffered = BufferedInputStream(input)
        buffered.mark(2)
        val b1 = buffered.read()
        val b2 = buffered.read()
        buffered.reset()
        val source: InputStream = if (b1 == 0x1f && b2 == 0x8b) GZIPInputStream(buffered) else buffered

        val parser = Xml.newPullParser()
        parser.setInput(source, null)

        val withZone = SimpleDateFormat("yyyyMMddHHmmss Z", Locale.US)
        val noZone = SimpleDateFormat("yyyyMMddHHmmss", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }

        fun toMillis(value: String?): Long? {
            if (value.isNullOrBlank()) return null
            val t = value.trim()
            return runCatching {
                if (t.length > 14) withZone.parse(t)!!.time else noZone.parse(t)!!.time
            }.getOrNull()
        }

        val result = HashMap<String, MutableList<Program>>()
        var channel = ""
        var start = 0L
        var end = 0L
        var title: String? = null
        var desc: String? = null
        var keep = false

        var event = parser.eventType
        while (event != XmlPullParser.END_DOCUMENT) {
            if (event == XmlPullParser.START_TAG) {
                val tag = parser.name
                if (tag == "programme") {
                    channel = parser.getAttributeValue(null, "channel") ?: ""
                    val s = toMillis(parser.getAttributeValue(null, "start"))
                    val e = toMillis(parser.getAttributeValue(null, "stop"))
                    keep = channel.isNotEmpty() && wanted.contains(channel) &&
                        s != null && e != null && e > from && s < to
                    start = s ?: 0L
                    end = e ?: 0L
                    title = null
                    desc = null
                } else if (keep && tag == "title" && title == null) {
                    title = runCatching { parser.nextText() }.getOrNull()
                } else if (keep && tag == "desc" && desc == null) {
                    desc = runCatching { parser.nextText() }.getOrNull()
                }
            } else if (event == XmlPullParser.END_TAG && parser.name == "programme") {
                if (keep) {
                    val t = title
                    if (!t.isNullOrBlank()) {
                        result.getOrPut(channel) { ArrayList() }
                            .add(Program(t.trim(), start, end, desc?.trim()?.takeIf { it.isNotEmpty() }))
                    }
                }
                keep = false
            }
            event = parser.next()
        }
        return result
    }
}
