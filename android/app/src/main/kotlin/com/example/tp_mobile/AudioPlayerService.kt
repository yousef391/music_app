package com.example.tp_mobile

import android.app.Service
import android.content.Intent
import android.media.MediaPlayer
import android.os.IBinder
import android.util.Log

class AudioPlayerService : Service() {
    private var mediaPlayer: MediaPlayer? = null
    private var isPlaying = false

    companion object {
        const val ACTION_PLAY = "com.example.tp_mobile.PLAY"
        const val ACTION_PAUSE = "com.example.tp_mobile.PAUSE"
        const val ACTION_STOP = "com.example.tp_mobile.STOP"
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> playAudio()
            ACTION_PAUSE -> pauseAudio()
            ACTION_STOP -> stopSelf()
        }
        return START_STICKY
    }

    private fun playAudio() {
        if (mediaPlayer == null) {
            mediaPlayer = MediaPlayer()
            try {
                // Set up your media player here
                // For example:
                // mediaPlayer?.setDataSource(path)
                // mediaPlayer?.prepare()
            } catch (e: Exception) {
                Log.e("AudioPlayerService", "Error setting up media player", e)
            }
        }
        
        if (!isPlaying) {
            mediaPlayer?.start()
            isPlaying = true
        }
    }

    private fun pauseAudio() {
        if (isPlaying) {
            mediaPlayer?.pause()
            isPlaying = false
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        mediaPlayer?.release()
        mediaPlayer = null
    }
} 