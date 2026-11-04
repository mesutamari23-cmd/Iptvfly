package com.xtreamplayer.app.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class Account(
    val id: String,
    val name: String,
    val baseUrl: String,
    val username: String,
    val password: String,
)

@Serializable
data class AuthResponse(
    @SerialName("user_info") val userInfo: UserInfo? = null,
)

@Serializable
data class UserInfo(
    val auth: String? = null,
    val status: String? = null,
    @SerialName("exp_date") val expDate: String? = null,
)

@Serializable
data class Category(
    @SerialName("category_id") val id: String = "",
    @SerialName("category_name") val name: String = "",
)

@Serializable
data class LiveStream(
    @SerialName("stream_id") val id: String = "",
    val name: String = "",
    @SerialName("stream_icon") val icon: String? = null,
    @SerialName("category_id") val categoryId: String? = null,
)

@Serializable
data class VodStream(
    @SerialName("stream_id") val id: String = "",
    val name: String = "",
    @SerialName("stream_icon") val icon: String? = null,
    @SerialName("category_id") val categoryId: String? = null,
    val rating: String? = null,
    @SerialName("container_extension") val ext: String? = null,
)

@Serializable
data class SeriesItem(
    @SerialName("series_id") val id: String = "",
    val name: String = "",
    val cover: String? = null,
    @SerialName("category_id") val categoryId: String? = null,
    val rating: String? = null,
)

enum class ContentType { LIVE, MOVIE, SERIES }

/** A unified catalog entry used by the UI for live channels, movies and series. */
data class Entry(
    val type: ContentType,
    val id: String,
    val name: String,
    val image: String?,
    val categoryId: String?,
    val rating: String? = null,
    val ext: String? = null,
)

data class Catalog(
    val categories: List<Category> = emptyList(),
    val items: List<Entry> = emptyList(),
)

data class VodDetail(
    val plot: String?,
    val genre: String?,
    val year: String?,
    val duration: String?,
    val cover: String?,
)

data class Episode(
    val id: String,
    val title: String,
    val season: Int,
    val number: Int,
    val ext: String,
    val image: String?,
    val plot: String?,
)

data class SeriesDetail(
    val plot: String?,
    val cover: String?,
    val episodes: Map<Int, List<Episode>>,
)

data class Playback(
    val url: String,
    val title: String,
    val liveId: String? = null,
)

class AuthFailed : Exception()
