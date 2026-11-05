package com.xtreamplayer.app.ui.screens

import android.widget.Toast
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.xtreamplayer.app.AppViewModel
import com.xtreamplayer.app.R
import kotlinx.coroutines.launch

private enum class PinAction { SET, DISABLE, CHANGE_OLD, CHANGE_NEW }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(vm: AppViewModel, onBack: () -> Unit) {
    val lock by vm.adultLock.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var action by remember { mutableStateOf<PinAction?>(null) }
    var oldPin by remember { mutableStateOf("") }
    var wrong by remember { mutableStateOf(false) }

    val current = action
    if (current != null) {
        key(current) {
            PinDialog(
                title = stringResource(
                    when (current) {
                        PinAction.SET -> R.string.pin_set
                        PinAction.DISABLE -> R.string.pin_enter
                        PinAction.CHANGE_OLD -> R.string.pin_enter
                        PinAction.CHANGE_NEW -> R.string.pin_new
                    }
                ),
                error = wrong,
                onDismiss = { action = null; wrong = false },
                onConfirm = { pin ->
                    scope.launch {
                        when (current) {
                            PinAction.SET -> {
                                vm.enableAdultLock(pin)
                                action = null
                            }
                            PinAction.DISABLE -> {
                                if (vm.disableAdultLock(pin)) {
                                    action = null
                                    wrong = false
                                } else {
                                    wrong = true
                                }
                            }
                            PinAction.CHANGE_OLD -> {
                                if (vm.verifyPin(pin)) {
                                    oldPin = pin
                                    wrong = false
                                    action = PinAction.CHANGE_NEW
                                } else {
                                    wrong = true
                                }
                            }
                            PinAction.CHANGE_NEW -> {
                                vm.changePin(oldPin, pin)
                                action = null
                            }
                        }
                    }
                },
            )
        }
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.background),
                title = { Text(stringResource(R.string.settings)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                },
            )
        },
    ) { padding ->
        Column(
            Modifier
                .padding(padding)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp),
        ) {
            Text(
                stringResource(R.string.parental),
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(top = 8.dp, bottom = 8.dp),
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(stringResource(R.string.parental_title), style = MaterialTheme.typography.bodyLarge)
                    Text(
                        stringResource(R.string.parental_desc),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Switch(
                    checked = lock,
                    onCheckedChange = { on ->
                        wrong = false
                        action = if (on) PinAction.SET else PinAction.DISABLE
                    },
                )
            }
            if (lock) {
                TextButton(onClick = { wrong = false; action = PinAction.CHANGE_OLD }) {
                    Text(stringResource(R.string.change_pin))
                }
            }

            HorizontalDivider(Modifier.padding(vertical = 16.dp))

            Text(
                stringResource(R.string.history),
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(bottom = 8.dp),
            )
            FilledTonalButton(onClick = {
                vm.clearHistory()
                Toast.makeText(context, R.string.done, Toast.LENGTH_SHORT).show()
            }) {
                Text(stringResource(R.string.clear_history))
            }
            Text(
                stringResource(R.string.clear_history_desc),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 6.dp),
            )

            HorizontalDivider(Modifier.padding(vertical = 16.dp))

            Text(
                stringResource(R.string.tip_favorites),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.navigationBarsPadding().height(24.dp))
        }
    }
}

@Composable
private fun PinDialog(title: String, error: Boolean, onDismiss: () -> Unit, onConfirm: (String) -> Unit) {
    var pin by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            Column {
                OutlinedTextField(
                    value = pin,
                    onValueChange = { v -> if (v.length <= 8 && v.all { it.isDigit() }) pin = v },
                    singleLine = true,
                    label = { Text(stringResource(R.string.pin)) },
                    visualTransformation = PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                )
                if (error) {
                    Spacer(Modifier.height(8.dp))
                    Text(stringResource(R.string.pin_wrong), color = MaterialTheme.colorScheme.error)
                }
            }
        },
        confirmButton = {
            TextButton(onClick = { onConfirm(pin) }, enabled = pin.length >= 4) {
                Text(stringResource(R.string.ok))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) }
        },
    )
}
