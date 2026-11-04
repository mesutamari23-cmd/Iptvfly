# Xtream Player (Android)

Professional Xtream Codes player: Kotlin, Jetpack Compose (Material 3), Media3/ExoPlayer, OkHttp, DataStore.
UI languages: English and Arabic (RTL supported).

## Features
- Multi-account login (server URL, username, password) with credential verification
- Live TV, Movies, Series, Favorites tabs, category filter chips, instant search
- Poster grid, movie details (plot, year, duration, genre), series with seasons and episodes
- Media3 player: HLS/TS/MP4/MKV, immersive landscape, error retry, now-playing (short EPG) for live channels
- Per-account favorites, account switching and removal, pull of catalogs in parallel

## Build
1. Open the folder in Android Studio (Ladybug or newer, JDK 17). It will create the Gradle wrapper and sync.
2. Run on a device or emulator (minSdk 24).
3. Release build: `./gradlew assembleRelease` (configure signing first).

## Structure
- `data/` models, `XtreamClient` (player_api.php), `AccountStore` (DataStore)
- `AppViewModel` shared state, `MainActivity` navigation
- `ui/screens/` Login, Home, Detail, Player, shared components

## Before publishing
- Encrypt stored passwords (Android Keystore) and add an app icon.
- The app ships with no content or server. Users enter their own subscription.
- Live streams use `.m3u8`; if a provider only serves `.ts`, change `liveUrl` in `XtreamClient`.
