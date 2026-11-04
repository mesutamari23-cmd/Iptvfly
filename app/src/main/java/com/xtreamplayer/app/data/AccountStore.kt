package com.xtreamplayer.app.data

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.encodeToString
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json

private val Context.dataStore by preferencesDataStore(name = "xtream_player")

class AccountStore(private val context: Context, private val json: Json) {

    private val accountsKey = stringPreferencesKey("accounts")
    private val activeKey = stringPreferencesKey("active")
    private val favsKey = stringSetPreferencesKey("favorites")

    val accounts: Flow<List<Account>> = context.dataStore.data.map { p ->
        p[accountsKey]?.let { runCatching { json.decodeFromString<List<Account>>(it) }.getOrNull() }
            ?: emptyList()
    }

    val activeId: Flow<String?> = context.dataStore.data.map { it[activeKey] }

    val favorites: Flow<Set<String>> = context.dataStore.data.map { it[favsKey] ?: emptySet() }

    suspend fun save(account: Account) = context.dataStore.edit { p ->
        val cur = p[accountsKey]?.let { runCatching { json.decodeFromString<List<Account>>(it) }.getOrNull() }
            ?: emptyList()
        p[accountsKey] = json.encodeToString(cur.filterNot { it.id == account.id } + account)
    }

    suspend fun setActive(id: String) = context.dataStore.edit { it[activeKey] = id }

    suspend fun remove(id: String) = context.dataStore.edit { p ->
        val cur = p[accountsKey]?.let { runCatching { json.decodeFromString<List<Account>>(it) }.getOrNull() }
            ?: emptyList()
        val left = cur.filterNot { it.id == id }
        p[accountsKey] = json.encodeToString(left)
        if (p[activeKey] == id) {
            left.firstOrNull()?.let { p[activeKey] = it.id } ?: p.remove(activeKey)
        }
        p[favsKey] = (p[favsKey] ?: emptySet()).filterNot { it.startsWith("$id|") }.toSet()
    }

    suspend fun toggleFavorite(key: String) = context.dataStore.edit { p ->
        val cur = p[favsKey] ?: emptySet()
        p[favsKey] = if (key in cur) cur - key else cur + key
    }
}
