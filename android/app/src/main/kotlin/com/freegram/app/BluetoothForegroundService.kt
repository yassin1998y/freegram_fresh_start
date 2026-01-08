package com.freegram.app

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import android.util.Log

/**
 * Foreground Service for MIUI/Redmi devices
 * Prevents MIUI from killing background Bluetooth scanning
 * 
 * MIUI aggressively kills background processes. This service keeps a 
 * persistent notification to prevent the app from being killed.
 */
class BluetoothForegroundService : Service() {
    
    companion object {
        private const val TAG = "BTForegroundService"
        private const val CHANNEL_ID = "bluetooth_scanning_channel"
        private const val CHANNEL_NAME = "Bluetooth Scanning"
        private const val NOTIFICATION_ID = 999
        
        var isServiceRunning = false
            private set
    }
    
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created")
        
        // Create notification channel for Android 8.0+
        createNotificationChannel()
        
        // Acquire wake lock to prevent MIUI from killing the service
        acquireWakeLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service started")
        
        // Create and show foreground notification
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        isServiceRunning = true
        
        // Return START_STICKY to restart service if killed by MIUI
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service destroyed")
        
        isServiceRunning = false
        releaseWakeLock()
    }

    /**
     * Create notification channel for Android 8.0+
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW // Low importance to not disturb user
            ).apply {
                description = "Keeps Bluetooth scanning active in background"
                setShowBadge(false) // Don't show badge
                enableVibration(false) // No vibration
                setSound(null, null) // No sound
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    /**
     * Create the foreground notification
     */
    private fun createNotification(): Notification {
        // Intent to open app when notification is tapped
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Freegram is running")
            .setContentText("Discovering nearby users...")
            .setSmallIcon(R.drawable.ic_stat_freegram) // Freegram F icon
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW) // Low priority
            .setOngoing(true) // Can't be dismissed by user
            .setShowWhen(false) // Don't show time
            .build()
    }

    /**
     * Acquire wake lock to prevent MIUI from killing the service
     * MIUI is notorious for aggressive battery optimization
     */
    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "Freegram::BluetoothScanningWakeLock"
            )
            wakeLock?.acquire(10 * 60 * 1000L) // 10 minutes
            Log.d(TAG, "Wake lock acquired")
        } catch (e: Exception) {
            Log.e(TAG, "Error acquiring wake lock: ${e.message}")
        }
    }

    /**
     * Release wake lock
     */
    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                    Log.d(TAG, "Wake lock released")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing wake lock: ${e.message}")
        }
    }
}

