package com.xtreamplayer.app

import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.xtreamplayer.app.data.ContentType
import com.xtreamplayer.app.ui.screens.DetailScreen
import com.xtreamplayer.app.ui.screens.HomeScreen
import com.xtreamplayer.app.ui.screens.LoginScreen
import com.xtreamplayer.app.ui.screens.PlayerScreen
import com.xtreamplayer.app.ui.theme.XtreamTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            XtreamTheme {
                Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                    AppNav()
                }
            }
        }
    }
}

@Composable
fun AppNav(vm: AppViewModel = viewModel()) {
    val ui by vm.ui.collectAsStateWithLifecycle()

    if (!ui.ready) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        return
    }

    val nav = rememberNavController()

    // If the last account is removed, go back to the login screen.
    LaunchedEffect(ui.active) {
        if (ui.active == null && nav.currentDestination?.route != "login") {
            nav.navigate("login") { popUpTo(0) }
        }
    }

    NavHost(nav, startDestination = if (ui.active == null) "login" else "home") {
        composable("login") {
            LoginScreen(
                vm = vm,
                onBack = if (ui.accounts.isNotEmpty() && nav.previousBackStackEntry != null) {
                    { nav.popBackStack() }
                } else null,
                onDone = {
                    nav.navigate("home") { popUpTo(0) }
                },
            )
        }
        composable("home") {
            HomeScreen(
                vm = vm,
                onOpen = { e ->
                    if (e.type == ContentType.LIVE) {
                        vm.prepareLive(e)
                        nav.navigate("player")
                    } else {
                        nav.navigate("detail/${e.type.name}/${Uri.encode(e.id)}")
                    }
                },
                onAddAccount = { nav.navigate("login") },
            )
        }
        composable(
            "detail/{type}/{id}",
            arguments = listOf(
                navArgument("type") { type = NavType.StringType },
                navArgument("id") { type = NavType.StringType },
            ),
        ) { entry ->
            val type = ContentType.valueOf(entry.arguments?.getString("type") ?: "MOVIE")
            val id = entry.arguments?.getString("id") ?: ""
            DetailScreen(
                vm = vm,
                type = type,
                id = id,
                onBack = { nav.popBackStack() },
                onPlay = { nav.navigate("player") },
            )
        }
        composable("player") {
            val pb = vm.playback
            if (pb != null) {
                PlayerScreen(
                    playback = pb,
                    client = vm.playerHttpClient(),
                    loadNowPlaying = { vm.nowPlaying(it) },
                    onBack = { nav.popBackStack() },
                )
            }
        }
    }
}
