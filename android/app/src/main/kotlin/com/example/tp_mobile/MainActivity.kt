package com.example.tp_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.tp_mobile/audio"
    private var broadcastReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playAudio" -> {
                    val intent = Intent(this, AudioPlayerService::class.java).apply {
                        action = AudioPlayerService.ACTION_PLAY
                    }
                    startService(intent)
                    result.success(null)
                }
                "pauseAudio" -> {
                    val intent = Intent(this, AudioPlayerService::class.java).apply {
                        action = AudioPlayerService.ACTION_PAUSE
                    }
                    startService(intent)
                    result.success(null)
                }
                "stopAudio" -> {
                    val intent = Intent(this, AudioPlayerService::class.java).apply {
                        action = AudioPlayerService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(null)
                }
                "registerBroadcastReceiver" -> {
                    registerBroadcastReceiver()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun registerBroadcastReceiver() {
        broadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    "PLAY" -> {
                        val serviceIntent = Intent(context, AudioPlayerService::class.java).apply {
                            action = AudioPlayerService.ACTION_PLAY
                        }
                        startService(serviceIntent)
                    }
                    "PAUSE" -> {
                        val serviceIntent = Intent(context, AudioPlayerService::class.java).apply {
                            action = AudioPlayerService.ACTION_PAUSE
                        }
                        startService(serviceIntent)
                    }
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction("PLAY")
            addAction("PAUSE")
        }
        registerReceiver(broadcastReceiver, filter)
    }

    override fun onDestroy() {
        super.onDestroy()
        broadcastReceiver?.let {
            unregisterReceiver(it)
        }
    }
}