package com.example.tp_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.tp_mobile/audio"
    private var broadcastReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        Log.d("MainActivity", "Setting up method channel: $CHANNEL")

        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            Log.d("MainActivity", "Received method call: ${call.method}")

            when (call.method) {
                "playAudio" -> {
                    Log.d("MainActivity", "Play audio called")
                    try {
                        // Register broadcast receiver if not already registered
                        registerBroadcastReceiver(methodChannel)

                        // Create explicit intent with the correct action
                        val intent = Intent(this, AudioService::class.java)
                        intent.action = AudioService.ACTION_PLAY

                        // Log the intent details
                        Log.d("MainActivity", "Starting service with intent: ${intent.action}")
                        Log.d("MainActivity", "Service class: ${AudioService::class.java.name}")

                        // Start the service
                        startService(intent)

                        // Return success to Flutter
                        result.success("Playing audio")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error starting service: ${e.message}")
                        e.printStackTrace()
                        result.error("SERVICE_ERROR", "Error starting service", e.message)
                    }
                }
                "pauseAudio" -> {
                    Log.d("MainActivity", "Pause audio called")
                    try {
                        val intent = Intent(this, AudioService::class.java)
                        intent.action = AudioService.ACTION_PAUSE
                        startService(intent)
                        result.success("Pausing audio")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error pausing service: ${e.message}")
                        e.printStackTrace()
                        result.error("SERVICE_ERROR", "Error pausing service", e.message)
                    }
                }
                "registerBroadcastReceiver" -> {
                    registerBroadcastReceiver(methodChannel)
                    result.success(null)
                }
                "unregisterBroadcastReceiver" -> {
                    unregisterBroadcastReceiver()
                    result.success(null)
                }
                else -> {
                    Log.d("MainActivity", "Method not implemented: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }

    private fun registerBroadcastReceiver(methodChannel: MethodChannel) {
        if (broadcastReceiver == null) {
            Log.d("MainActivity", "Registering broadcast receiver")

            broadcastReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == "com.example.tp_mobile.PLAYBACK_STATE_CHANGED") {
                        val isPlaying = intent.getBooleanExtra("isPlaying", false)
                        Log.d("MainActivity", "Received broadcast: isPlaying=$isPlaying")

                        // Invoke method on Flutter side
                        methodChannel.invokeMethod("onPlaybackStateChanged", isPlaying)
                    }
                }
            }

            val filter = IntentFilter("com.example.tp_mobile.PLAYBACK_STATE_CHANGED")
            registerReceiver(broadcastReceiver, filter)
        }
    }

    private fun unregisterBroadcastReceiver() {
        if (broadcastReceiver != null) {
            Log.d("MainActivity", "Unregistering broadcast receiver")
            unregisterReceiver(broadcastReceiver)
            broadcastReceiver = null
        }
    }

    override fun onDestroy() {
        unregisterBroadcastReceiver()

        val intent = Intent(this, AudioService::class.java)
        stopService(intent)


        super.onDestroy()
    }
}