package com.xtreamplayer.app.data

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

private val Context.dataStore by preferencesDataStore(name = "xtream_player")

class AccountStore(private val context: Context, private val json: Json) {

    private val accountsKey = stringPreferencesKey("accounts")
    private val activeKey = stringPreferencesKey("active")
    private val favsKey = stringSetPreferencesKey("favorites")
    private val adultLockKey = booleanPreferencesKey("adult_lock")
    private val pinKey = stringPreferencesKey("pin_hash")
    private val positionsKey = stringPreferencesKey("positions")

    val accounts: Flow<List<Account>> = context.dataStore.data.map { p ->
        p[accountsKey]?.let { runCatching { json.decodeFromString<List<Account>>(it) }.getOrNull() }
            ?: emptyList()
    }

    val activeId: Flow<String?> = context.dataStore.data.map { it[activeKey] }

    val favorites: Flow<Set<String>> = context.dataStore.data.map { it[favsKey] ?: emptySet() }

    val adultLock: Flow<Boolean> = context.dataStore.data.map { it[adultLockKey] ?: false }

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
            val next = left.firstOrNull()
            if (next != null) p[activeKey] = next.id else p.remove(activeKey)
        }
        p[favsKey] = (p[favsKey] ?: emptySet()).filterNot { it.startsWith("$id|") }.toSet()
    }

    suspend fun toggleFavorite(key: String) = context.dataStore.edit { p ->
        val cur = p[favsKey] ?: emptySet()
        p[favsKey] = if (key in cur) cur - key else cur + key
    }

    // ---------- Parental control ----------

    suspend fun pinHash(): String? = context.dataStore.data.first()[pinKey]

    suspend fun setAdultLock(enabled: Boolean, pinHash: String?) = context.dataStore.edit { p ->
        p[adultLockKey] = enabled
        if (pinHash == null) p.remove(pinKey) else p[pinKey] = pinHash
    }

    // ---------- Resume positions ----------

    private fun readPositions(p: Preferences): LinkedHashMap<String, Long> {
        val raw = p[positionsKey] ?: return LinkedHashMap()
        val map = runCatching { json.decodeFromString<Map<String, Long>>(raw) }.getOrNull()
            ?: return LinkedHashMap()
        return LinkedHashMap(map)
    }

    suspend fun position(key: String): Long =
        readPositions(context.dataStore.data.first())[key] ?: 0L

    suspend fun savePosition(key: String, pos: Long) = context.dataStore.edit { p ->
        val m = readPositions(p)
        m.remove(key)
        if (pos > 0) m[key] = pos
        while (m.size > 300) m.remove(m.keys.first())
        p[positionsKey] = json.encodeToString<Map<String, Long>>(m)
    }

    suspend fun clearPositions() = context.dataStore.edit { it.remove(positionsKey) }
}
