package com.example.tp_mobile

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class AudioService : Service() {
    private var mediaPlayer: MediaPlayer? = null
    private var isPlaying = false
    private lateinit var mediaSession: MediaSessionCompat
    private lateinit var audioManager: AudioManager
    private var audioFocusRequest: AudioFocusRequest? = null
    private val channel = "com.example.tp_mobile/audio"
    private val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val notificationId = 1

    companion object {
        const val NOTIFICATION_ID = 1
        const val CHANNEL_ID = "AudioServiceChannel"
        const val ACTION_PLAY = "com.example.tp_mobile.PLAY"
        const val ACTION_PAUSE = "com.example.tp_mobile.PAUSE"
        const val ACTION_STOP = "com.example.tp_mobile.STOP"
        const val ACTION_NEXT = "com.example.tp_mobile.NEXT"
        const val ACTION_PREVIOUS = "com.example.tp_mobile.PREVIOUS"
    }

    override fun onCreate() {
        super.onCreate()
        Log.d("AudioService", "onCreate called")

        // Get audio manager
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        // Create notification channel
        createNotificationChannel()

        // Initialize MediaSession
        initMediaSession()

        // Initialize MediaPlayer
        initMediaPlayer()
    }

    private fun initMediaSession() {
        Log.d("AudioService", "Initializing MediaSession")

        mediaSession = MediaSessionCompat(this, "AudioService")

        // Set session activity (for when notification is clicked)
        val sessionActivityPendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )
        mediaSession.setSessionActivity(sessionActivityPendingIntent)

        // Set media session callback
        mediaSession.setCallback(object : MediaSessionCompat.Callback() {
            override fun onPlay() {
                Log.d("AudioService", "MediaSession callback: onPlay")
                playAudio()
            }

            override fun onPause() {
                Log.d("AudioService", "MediaSession callback: onPause")
                pauseAudio()
            }

            override fun onStop() {
                Log.d("AudioService", "MediaSession callback: onStop")
                stopSelf()
            }

            override fun onSkipToNext() {
                Log.d("AudioService", "MediaSession callback: onSkipToNext")
                // Implement if you have playlist functionality
            }

            override fun onSkipToPrevious() {
                Log.d("AudioService", "MediaSession callback: onSkipToPrevious")
                // Implement if you have playlist functionality
            }
        })

        // Set flags for media buttons and transport controls
        mediaSession.setFlags(
            MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
                    MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
        )

        // Start the session
        mediaSession.isActive = true
    }

    private fun initMediaPlayer() {
        Log.d("AudioService", "Initializing MediaPlayer")

        mediaPlayer = MediaPlayer().apply {
            try {
                // Set audio attributes for proper audio focus handling
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )

                // Wake lock to keep CPU running during playback
                setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)

                // Try to load from Flutter assets
                val assetManager = applicationContext.assets
                try {
                    // Try the direct path first
                    val inputStream = assetManager.open("flutter_assets/assets/audio/test.mp3")
                    Log.d("AudioService", "Found audio file at flutter_assets/assets/audio/test.mp3")

                    // Create a temporary file
                    val tempFile = File(applicationContext.cacheDir, "temp_audio.mp3")
                    val outputStream = FileOutputStream(tempFile)

                    // Copy the file
                    val buffer = ByteArray(1024)
                    var read: Int
                    while (inputStream.read(buffer).also { read = it } != -1) {
                        outputStream.write(buffer, 0, read)
                    }
                    inputStream.close()
                    outputStream.flush()
                    outputStream.close()

                    // Use the temporary file
                    setDataSource(tempFile.path)
                    prepare()

                    Log.d("AudioService", "Audio file loaded successfully from assets")
                } catch (e: Exception) {
                    Log.e("AudioService", "Error loading from flutter_assets path: ${e.message}")

                    try {
                        // Try alternative path
                        val inputStream = assetManager.open("assets/audio/test.mp3")
                        Log.d("AudioService", "Found audio file at assets/audio/test.mp3")

                        // Create a temporary file
                        val tempFile = File(applicationContext.cacheDir, "temp_audio.mp3")
                        val outputStream = FileOutputStream(tempFile)

                        // Copy the file
                        val buffer = ByteArray(1024)
                        var read: Int
                        while (inputStream.read(buffer).also { read = it } != -1) {
                            outputStream.write(buffer, 0, read)
                        }
                        inputStream.close()
                        outputStream.flush()
                        outputStream.close()

                        // Use the temporary file
                        setDataSource(tempFile.path)
                        prepare()

                        Log.d("AudioService", "Audio file loaded successfully from alternative path")
                    } catch (e2: Exception) {
                        Log.e("AudioService", "Error loading from alternative path: ${e2.message}")
                        e2.printStackTrace()

                        // Try using a raw resource as last resort
                        try {
                            val resourceId = resources.getIdentifier("test_audio", "raw", packageName)
                            if (resourceId > 0) {
                                Log.d("AudioService", "Found audio file in raw resources")
                                val afd = resources.openRawResourceFd(resourceId)
                                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                                afd.close()
                                prepare()
                                Log.d("AudioService", "Audio file loaded successfully from raw resources")
                            } else {
                                Log.e("AudioService", "Raw resource not found")
                            }
                        } catch (e3: Exception) {
                            Log.e("AudioService", "Error loading from raw resources: ${e3.message}")
                            e3.printStackTrace()
                        }
                    }
                }

                setOnCompletionListener {
                    Log.d("AudioService", "Audio playback completed")
                    updatePlaybackState(PlaybackStateCompat.STATE_STOPPED)
                    stopForeground(true)
                    stopSelf()
                }

                setOnErrorListener { _, what, extra ->
                    Log.e("AudioService", "MediaPlayer error: what=$what, extra=$extra")
                    true
                }

                setOnPreparedListener {
                    Log.d("AudioService", "MediaPlayer prepared")
                }

            } catch (e: Exception) {
                Log.e("AudioService", "Error initializing MediaPlayer: ${e.message}")
                e.printStackTrace()
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("AudioService", "onStartCommand called with action: ${intent?.action}")

        when (intent?.action) {
            ACTION_PLAY -> {
                Log.d("AudioService", "Processing PLAY action")
                playAudio()
            }
            ACTION_PAUSE -> {
                Log.d("AudioService", "Processing PAUSE action")
                pauseAudio()
            }
            ACTION_STOP -> {
                Log.d("AudioService", "Processing STOP action")
                stopSelf()
            }
            ACTION_NEXT -> {
                Log.d("AudioService", "Processing NEXT action")
                // Implement if you have playlist functionality
            }
            ACTION_PREVIOUS -> {
                Log.d("AudioService", "Processing PREVIOUS action")
                // Implement if you have playlist functionality
            }
        }

        // If service is killed, restart it
        return START_STICKY
    }

    private fun requestAudioFocus(): Boolean {
        Log.d("AudioService", "Requesting audio focus")

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .setAcceptsDelayedFocusGain(true)
                .setOnAudioFocusChangeListener { focusChange ->
                    when (focusChange) {
                        AudioManager.AUDIOFOCUS_LOSS -> {
                            Log.d("AudioService", "Audio focus loss")
                            pauseAudio()
                        }
                        AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                            Log.d("AudioService", "Audio focus loss transient")
                            pauseAudio()
                        }
                        AudioManager.AUDIOFOCUS_GAIN -> {
                            Log.d("AudioService", "Audio focus gain")
                            playAudio()
                        }
                    }
                }
                .build()

            val result = audioManager.requestAudioFocus(audioFocusRequest!!)
            result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else {
            @Suppress("DEPRECATION")
            val result = audioManager.requestAudioFocus(
                { focusChange ->
                    when (focusChange) {
                        AudioManager.AUDIOFOCUS_LOSS -> {
                            Log.d("AudioService", "Audio focus loss")
                            pauseAudio()
                        }
                        AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                            Log.d("AudioService", "Audio focus loss transient")
                            pauseAudio()
                        }
                        AudioManager.AUDIOFOCUS_GAIN -> {
                            Log.d("AudioService", "Audio focus gain")
                            playAudio()
                        }
                    }
                },
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN
            )
            result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
    }

    private fun abandonAudioFocus() {
        Log.d("AudioService", "Abandoning audio focus")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let {
                audioManager.abandonAudioFocusRequest(it)
            }
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
        }
    }

    private fun playAudio() {
        Log.d("AudioService", "playAudio called")

        if (mediaPlayer != null && !isPlaying) {
            if (requestAudioFocus()) {
                try {
                    mediaPlayer?.start()
                    isPlaying = true

                    // Update media session
                    updatePlaybackState(PlaybackStateCompat.STATE_PLAYING)
                    updateMediaSessionMetadata()

                    // Start foreground service with notification
                    startForeground(NOTIFICATION_ID, createNotification())

                    updatePlaybackStateUI(true)

                    Log.d("AudioService", "Audio playback started")
                } catch (e: Exception) {
                    Log.e("AudioService", "Error starting playback: ${e.message}")
                    e.printStackTrace()
                }
            } else {
                Log.e("AudioService", "Could not get audio focus")
            }
        } else {
            Log.d("AudioService", "MediaPlayer is null or already playing")
        }
    }

    private fun pauseAudio() {
        Log.d("AudioService", "pauseAudio called")

        if (mediaPlayer != null && isPlaying) {
            try {
                mediaPlayer?.pause()
                isPlaying = false

                // Update media session
                updatePlaybackState(PlaybackStateCompat.STATE_PAUSED)

                // Update notification but keep the service in foreground
                val notification = createNotification()
                startForeground(NOTIFICATION_ID, notification)

                // Update UI via broadcast
                updatePlaybackStateUI(false)

                // Abandon audio focus
                abandonAudioFocus()

                Log.d("AudioService", "Audio playback paused")
            } catch (e: Exception) {
                Log.e("AudioService", "Error pausing playback: ${e.message}")
                e.printStackTrace()
            }
        } else {
            Log.d("AudioService", "MediaPlayer is null or not playing")
        }
    }

    private fun updatePlaybackState(state: Int) {
        Log.d("AudioService", "Updating playback state to: $state")

        val stateBuilder = PlaybackStateCompat.Builder()
            .setActions(
                PlaybackStateCompat.ACTION_PLAY or
                        PlaybackStateCompat.ACTION_PAUSE or
                        PlaybackStateCompat.ACTION_PLAY_PAUSE or
                        PlaybackStateCompat.ACTION_STOP or
                        PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                        PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
            )
            .setState(state, mediaPlayer?.currentPosition?.toLong() ?: 0, 1.0f)

        mediaSession.setPlaybackState(stateBuilder.build())
    }

    private fun updateMediaSessionMetadata() {
        Log.d("AudioService", "Updating media session metadata")

        val metadataBuilder = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, "Your Audio Title")
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, "Artist Name")
            .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, "Album Name")
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, mediaPlayer?.duration?.toLong() ?: 0)

        // Add album art if available
        try {
            // You can replace this with actual album art
            val bitmap = BitmapFactory.decodeResource(resources, android.R.drawable.ic_media_play)
            metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, bitmap)
        } catch (e: Exception) {
            Log.e("AudioService", "Error setting album art: ${e.message}")
        }

        mediaSession.setMetadata(metadataBuilder.build())
    }

    private fun updatePlaybackStateUI(playing: Boolean) {
        // Use broadcast to update the UI
        val intent = Intent("com.example.tp_mobile.PLAYBACK_STATE_CHANGED")
        intent.putExtra("isPlaying", playing)
        sendBroadcast(intent)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                "music_player_channel",
                "Music Player",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Music Player Channel"
            }
            notificationManager.createNotificationChannel(serviceChannel)

            Log.d("AudioService", "Notification channel created")
        }
    }

    private fun createNotification(): Notification {
        Log.d("AudioService", "Creating notification")

        // Create content intent (when notification is clicked)
        val contentIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        // Create play/pause action
        val playPauseIcon = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        val playPauseAction = if (isPlaying) ACTION_PAUSE else ACTION_PLAY
        val playPauseIntent = PendingIntent.getService(
            this, 0,
            Intent(this, AudioService::class.java).setAction(playPauseAction),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        // Create previous action
        val previousIntent = PendingIntent.getService(
            this, 0,
            Intent(this, AudioService::class.java).setAction(ACTION_PREVIOUS),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        // Create next action
        val nextIntent = PendingIntent.getService(
            this, 0,
            Intent(this, AudioService::class.java).setAction(ACTION_NEXT),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        // Create stop action
        val stopIntent = PendingIntent.getService(
            this, 0,
            Intent(this, AudioService::class.java).setAction(ACTION_STOP),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        // Create media style
        val mediaStyle = MediaStyle()
            .setMediaSession(mediaSession.sessionToken)
            .setShowActionsInCompactView(0, 1, 2) // Previous, Play/Pause, Next

        // Build the notification
        val builder = NotificationCompat.Builder(this, "music_player_channel")
            .setContentTitle("Your Audio Title")
            .setContentText("Artist Name")
            .setSubText("Album Name")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(contentIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setStyle(mediaStyle)
            .setShowWhen(false)

            // Add actions
            .addAction(android.R.drawable.ic_media_previous, "Previous", previousIntent)
            .addAction(playPauseIcon, if (isPlaying) "Pause" else "Play", playPauseIntent)
            .addAction(android.R.drawable.ic_media_next, "Next", nextIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stopIntent)

        // Add album art if available
        try {
            // You can replace this with actual album art
            val bitmap = BitmapFactory.decodeResource(resources, android.R.drawable.ic_media_play)
            builder.setLargeIcon(bitmap)
        } catch (e: Exception) {
            Log.e("AudioService", "Error setting large icon: ${e.message}")
        }

        return builder.build()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        Log.d("AudioService", "onDestroy called")

        // Release MediaPlayer resources
        mediaPlayer?.release()
        mediaPlayer = null

        // Release MediaSession
        mediaSession.release()

        // Abandon audio focus
        abandonAudioFocus()

        stopSelf()

        super.onDestroy()
    }

    fun playAudio(title: String, artist: String, imagePath: String) {
        isPlaying = true
        updateNotification(title, artist, imagePath, isPlaying)
    }

    fun updateNotification(title: String, artist: String, imagePath: String, isPlaying: Boolean) {
        this.isPlaying = isPlaying

        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, "music_player_channel")
            .setContentTitle(title)
            .setContentText(artist)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setLargeIcon(BitmapFactory.decodeResource(resources, android.R.drawable.ic_media_play))
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .addAction(
                android.R.drawable.ic_media_play,
                if (isPlaying) "Pause" else "Play",
                PendingIntent.getBroadcast(
                    this,
                    0,
                    Intent(if (isPlaying) "PAUSE" else "PLAY"),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
            .build()

        notificationManager.notify(notificationId, notification)
    }

    fun stopNotification() {
        notificationManager.cancel(notificationId)
    }
}