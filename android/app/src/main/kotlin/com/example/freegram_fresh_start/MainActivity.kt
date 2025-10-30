package com.example.freegram_fresh_start

import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.ParcelUuid
import android.util.Log
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.StandardCharsets
import java.util.*

@SuppressLint("MissingPermission") // Permissions are handled in Dart
class MainActivity : FlutterActivity() {
    private val CHANNEL = "freegram/gatt" // We keep the channel name for simplicity
    private val FOREGROUND_SERVICE_CHANNEL = "freegram/foreground_service"
    private var advertiserManager: AdvertiserManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Check Google Play Services availability
        checkGooglePlayServices()
        
        // Wrap initialization in try-catch to prevent crashes during startup
        try {
            advertiserManager = AdvertiserManager(applicationContext)
        } catch (e: Exception) {
            Log.e("MainActivity", "Error initializing AdvertiserManager: ${e.message}", e)
            // Continue without advertiser - it will be created later when needed
        }

        // Setup GATT/Advertising channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    // Renamed for clarity
                    "startAdvertising" -> {
                        val uid = call.argument<String>("uid") ?: ""
                        val success = advertiserManager?.startAdvertising(uid) ?: false
                        result.success(success)
                    }
                    "startWaveAdvertising" -> {
                        val payload = call.argument<String>("payload") ?: ""
                        val success = advertiserManager?.startWaveAdvertising(payload) ?: false
                        result.success(success)
                    }
                    "startServiceDataWaveAdvertising" -> {
                        val payload = call.argument<String>("payload") ?: ""
                        val success = advertiserManager?.startServiceDataWaveAdvertising(payload) ?: false
                        result.success(success)
                    }
                    "stopAdvertising" -> {
                        advertiserManager?.stopAdvertising()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.e("MainActivity", "Error in method channel: ${e.message}", e)
                result.error("ERROR", e.message, null)
            }
        }

        // Setup Foreground Service channel (MIUI/Redmi fix)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOREGROUND_SERVICE_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "startForegroundService" -> {
                        val intent = Intent(this, BluetoothForegroundService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                    "stopForegroundService" -> {
                        val intent = Intent(this, BluetoothForegroundService::class.java)
                        stopService(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.e("MainActivity", "Error in foreground service channel: ${e.message}", e)
                result.error("ERROR", e.message, null)
            }
        }
    }

    override fun onDestroy() {
        advertiserManager?.stopAdvertising()
        // Stop foreground service when app is destroyed
        val intent = Intent(this, BluetoothForegroundService::class.java)
        stopService(intent)
        super.onDestroy()
    }
    
    private fun checkGooglePlayServices() {
        val googleApiAvailability = GoogleApiAvailability.getInstance()
        val resultCode = googleApiAvailability.isGooglePlayServicesAvailable(this)
        
        when (resultCode) {
            ConnectionResult.SUCCESS -> {
                Log.i("MainActivity", "Google Play Services is available")
            }
            ConnectionResult.SERVICE_MISSING -> {
                Log.w("MainActivity", "Google Play Services is missing")
            }
            ConnectionResult.SERVICE_VERSION_UPDATE_REQUIRED -> {
                Log.w("MainActivity", "Google Play Services needs to be updated")
            }
            ConnectionResult.SERVICE_DISABLED -> {
                Log.w("MainActivity", "Google Play Services is disabled")
            }
            ConnectionResult.SERVICE_INVALID -> {
                Log.w("MainActivity", "Google Play Services is invalid")
            }
            else -> {
                Log.w("MainActivity", "Google Play Services error: $resultCode")
            }
        }
    }
}

// This class is now ONLY responsible for advertising. No GATT server logic.
@SuppressLint("MissingPermission")
class AdvertiserManager(private val context: Context) {
    private val tag = "AdvertiserManager"

    private val SERVICE_UUID: UUID = UUID.fromString("12345678-1234-5678-1234-56789abcdef0")

    private var bluetoothManager: BluetoothManager? = null
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var advertiseCallback: AdvertiseCallback? = null

    fun startAdvertising(uid: String): Boolean {
        stopAdvertising() // Ensure a clean state
        try {
            // Check if context is valid
            if (context == null) {
                Log.e(tag, "Context is null")
                return false
            }
            
            bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            bluetoothAdapter = bluetoothManager?.adapter
            if (bluetoothAdapter == null || !bluetoothAdapter!!.isEnabled) {
                Log.e(tag, "Bluetooth adapter not available or not enabled")
                return false
            }

            advertiser = bluetoothAdapter?.bluetoothLeAdvertiser
            if (advertiser == null) {
                Log.e(tag, "Device does not support BLE advertising.")
                return false
            }

            // MIUI-optimized settings: Lower power, lower latency to reduce slot usage
            val settings = AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED) // More aggressive mode for MIUI
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_LOW) // Low power for MIUI
                .setConnectable(false) // Set to false for broadcast-only
                .setTimeout(0) // Advertise indefinitely
                .build()

            // Convert hex string UID to bytes (e.g., "d02ebe8b01" -> [0xd0, 0x2e, 0xbe, 0x8b, 0x01])
            val uidBytes = try {
                uid.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
            } catch (e: Exception) {
                Log.e(tag, "Failed to parse UID hex string: $uid")
                return false
            }

            // CRITICAL FIX FOR MIUI: Put data in MAIN packet, not scan response!
            // MIUI filters scan responses aggressively
            val manufacturerId = 0x0075 // Match BleAdvertiser.MANUFACTURER_ID_DISCOVERY
            val mainAdvertisement = AdvertiseData.Builder()
                .addServiceUuid(ParcelUuid(SERVICE_UUID))
                .addManufacturerData(manufacturerId, uidBytes) // User data in MAIN packet
                .setIncludeDeviceName(false)
                .build()

            // Empty scan response for MIUI compatibility
            val scanResponse = AdvertiseData.Builder()
                .setIncludeDeviceName(false)
                .build()

            advertiseCallback = object : AdvertiseCallback() {
                override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                    Log.i(tag, "Discovery advertisement started successfully.")
                }
                override fun onStartFailure(errorCode: Int) {
                    Log.e(tag, "Discovery advertisement failed with error code: $errorCode")
                }
            }

            advertiser?.startAdvertising(settings, mainAdvertisement, scanResponse, advertiseCallback)

            Log.i(tag, "Advertising process initiated.")
            return true
        } catch (e: Exception) {
            Log.e(tag, "Failed to start advertising: ${e.message}", e)
            stopAdvertising()
            return false
        }
    }

    fun startWaveAdvertising(payload: String): Boolean {
        stopAdvertising() // Stop any current advertising
        
        try {
            // Check if context is valid
            if (context == null) {
                Log.e(tag, "Context is null")
                return false
            }
            
            bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            bluetoothAdapter = bluetoothManager?.adapter
            if (bluetoothAdapter == null || !bluetoothAdapter!!.isEnabled) {
                Log.e(tag, "Bluetooth adapter not available or not enabled")
                return false
            }

            advertiser = bluetoothAdapter?.bluetoothLeAdvertiser
            if (advertiser == null) {
                Log.e(tag, "Device does not support BLE advertising.")
                return false
            }

            // Convert hex string payload to bytes (e.g., "d02ebe8be58e8059" -> 8 bytes)
            val payloadBytes = try {
                payload.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
            } catch (e: Exception) {
                Log.e(tag, "Failed to parse wave payload hex string: $payload")
                return false
            }

            Log.i(tag, "Wave payload size: ${payloadBytes.size} bytes")

            // Wave settings: High priority for better delivery
            // CRITICAL: Use timeout=0 because MIUI ignores native timeouts!
            val settings = AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
                .setConnectable(false)
                .setTimeout(0) // 0 = no timeout, Dart will stop it explicitly
                .build()

            // CRITICAL FIX FOR MIUI: Use SAME manufacturer ID as discovery (117)!
            // MIUI filters manufacturer ID 118 even in main packet!
            // Differentiate waves by payload length: discovery=5 bytes, wave=8 bytes
            val waveManufacturerId = 0x0075 // SAME as discovery - MIUI only allows this!
            val mainAdvertisement = AdvertiseData.Builder()
                .addServiceUuid(ParcelUuid(SERVICE_UUID))
                .addManufacturerData(waveManufacturerId, payloadBytes) // Wave data in MAIN packet
                .setIncludeDeviceName(false)
                .build()

            // Empty scan response for MIUI compatibility
            val scanResponse = AdvertiseData.Builder()
                .setIncludeDeviceName(false)
                .build()

            advertiseCallback = object : AdvertiseCallback() {
                override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                    Log.i(tag, "Wave advertisement started successfully.")
                }
                override fun onStartFailure(errorCode: Int) {
                    Log.e(tag, "Wave advertisement failed with error code: $errorCode")
                }
            }

            advertiser?.startAdvertising(settings, mainAdvertisement, scanResponse, advertiseCallback)

            Log.i(tag, "Wave advertising process initiated.")
            return true
        } catch (e: Exception) {
            Log.e(tag, "Failed to start wave advertising: ${e.message}", e)
            stopAdvertising()
            return false
        }
    }

    fun startServiceDataWaveAdvertising(payload: String): Boolean {
        stopAdvertising() // Stop any current advertising
        
        try {
            // Check if context is valid
            if (context == null) {
                Log.e(tag, "Context is null")
                return false
            }
            
            bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            bluetoothAdapter = bluetoothManager?.adapter
            if (bluetoothAdapter == null || !bluetoothAdapter!!.isEnabled) {
                Log.e(tag, "Bluetooth adapter not available or not enabled")
                return false
            }

            advertiser = bluetoothAdapter?.bluetoothLeAdvertiser
            if (advertiser == null) {
                Log.e(tag, "Device does not support BLE advertising.")
                return false
            }

            // Convert hex string payload to bytes (e.g., "acc44d4407b30fce" -> 8 bytes)
            val payloadBytes = try {
                payload.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
            } catch (e: Exception) {
                Log.e(tag, "Failed to parse wave payload hex string: $payload")
                return false
            }

            Log.i(tag, "Service Data Wave payload size: ${payloadBytes.size} bytes")

            // CRITICAL FIX FOR MIUI: Use Service Data instead of Manufacturer Data!
            // MIUI filters 8-byte manufacturer data but is less likely to filter service data
            // Service Data is part of the standard BLE specification and more trusted by MIUI
            // IMPORTANT: Don't add ServiceUuid separately - it's automatically included with ServiceData!
            val mainAdvertisement = AdvertiseData.Builder()
                .addServiceData(ParcelUuid(SERVICE_UUID), payloadBytes) // Wave data in SERVICE DATA (UUID is auto-included)
                .setIncludeDeviceName(false)
                .build()

            // Empty scan response for MIUI compatibility
            val scanResponse = AdvertiseData.Builder()
                .setIncludeDeviceName(false)
                .build()

            // CRITICAL: Use timeout=0 because MIUI ignores native timeouts!
            // Dart timer will explicitly stop the advertising after 3 seconds
            val settings = AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
                .setConnectable(false)
                .setTimeout(0) // 0 = no timeout, Dart will stop it
                .build()

            advertiseCallback = object : AdvertiseCallback() {
                override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                    Log.i(tag, "Service Data Wave advertisement started successfully.")
                }
                override fun onStartFailure(errorCode: Int) {
                    Log.e(tag, "Service Data Wave advertisement failed with error code: $errorCode")
                }
            }

            advertiser?.startAdvertising(settings, mainAdvertisement, scanResponse, advertiseCallback)

            Log.i(tag, "Service Data Wave advertising process initiated.")
            return true
        } catch (e: Exception) {
            Log.e(tag, "Failed to start service data wave advertising: ${e.message}", e)
            stopAdvertising()
            return false
        }
    }

    fun stopAdvertising() {
        try {
            advertiser?.stopAdvertising(advertiseCallback)
            Log.i(tag, "Advertising stopped.")
        } catch (e: Exception) {
            Log.w(tag, "Error stopping advertiser: ${e.message}")
        }
        advertiser = null
        advertiseCallback = null
    }
}