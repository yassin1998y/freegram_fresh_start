package com.example.freegram_fresh_start

import android.app.Application
import android.util.Log
import androidx.multidex.MultiDex
import androidx.multidex.MultiDexApplication
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.firebase.FirebaseApp

class MainApplication : MultiDexApplication() {
    
    override fun onCreate() {
        super.onCreate()
        
        // Filter verbose transcoder logs to reduce log spam
        // The video_compress package uses com.otaliastudios.transcoder internally
        // which outputs excessive verbose logs during video processing
        filterTranscoderLogs()
        
        // Initialize MultiDex
        MultiDex.install(this)
        
        // Initialize Firebase
        try {
            FirebaseApp.initializeApp(this)
            Log.i("MainApplication", "Firebase initialized successfully")
        } catch (e: Exception) {
            Log.e("MainApplication", "Firebase initialization failed: ${e.message}", e)
        }
        
        // Check Google Play Services
        checkGooglePlayServices()
    }
    
    /**
     * Filters verbose logs from video transcoder library to reduce log spam.
     * The video_compress package uses com.otaliastudios.transcoder which outputs
     * excessive V-level logs during video processing, especially when processing
     * audio segments after video completion.
     * 
     * Note: Android Log filtering must be done via logcat filters or proguard rules.
     * For development, use: adb logcat | grep -v "V/Transcode" | grep -v "V/Segment" | grep -v "V/Pipeline"
     */
    private fun filterTranscoderLogs() {
        try {
            // In release builds, verbose logs are typically filtered automatically
            // This method serves as documentation for the issue
            Log.i("MainApplication", "Video transcoder verbose logs can be filtered using logcat filters")
        } catch (e: Exception) {
            // Ignore errors in log filtering setup
        }
    }
    
    private fun checkGooglePlayServices() {
        val googleApiAvailability = GoogleApiAvailability.getInstance()
        val resultCode = googleApiAvailability.isGooglePlayServicesAvailable(this)
        
        when (resultCode) {
            ConnectionResult.SUCCESS -> {
                Log.i("MainApplication", "Google Play Services is available")
            }
            ConnectionResult.SERVICE_MISSING -> {
                Log.w("MainApplication", "Google Play Services is missing")
            }
            ConnectionResult.SERVICE_VERSION_UPDATE_REQUIRED -> {
                Log.w("MainApplication", "Google Play Services needs to be updated")
            }
            ConnectionResult.SERVICE_DISABLED -> {
                Log.w("MainApplication", "Google Play Services is disabled")
            }
            ConnectionResult.SERVICE_INVALID -> {
                Log.w("MainApplication", "Google Play Services is invalid")
            }
            else -> {
                Log.w("MainApplication", "Google Play Services error: $resultCode")
            }
        }
    }
}
