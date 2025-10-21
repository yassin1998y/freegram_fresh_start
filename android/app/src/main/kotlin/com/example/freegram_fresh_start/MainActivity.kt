package com.example.freegram_fresh_start

import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.StandardCharsets
import java.util.*

@SuppressLint("MissingPermission") // Permissions are handled in Dart
class MainActivity : FlutterActivity() {
    private val CHANNEL = "freegram/gatt" // We keep the channel name for simplicity
    private var advertiserManager: AdvertiserManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        advertiserManager = AdvertiserManager(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // Renamed for clarity
                "startAdvertising" -> {
                    val uid = call.argument<String>("uid") ?: ""
                    val success = advertiserManager?.startAdvertising(uid) ?: false
                    result.success(success)
                }
                "stopAdvertising" -> {
                    advertiserManager?.stopAdvertising()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        advertiserManager?.stopAdvertising()
        super.onDestroy()
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

            // Non-connectable advertisement settings
            val settings = AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
                .setConnectable(false) // Set to false for broadcast-only
                .build()

            // Main packet contains the service UUID
            val mainAdvertisement = AdvertiseData.Builder()
                .addServiceUuid(ParcelUuid(SERVICE_UUID))
                .setIncludeDeviceName(false)
                .build()

            // Scan Response packet contains our custom data (the UID)
            // This is the correct way to broadcast more than a few bytes of data.
            val manufacturerId = 0xFFFF // A common ID for custom data
            val scanResponse = AdvertiseData.Builder()
                .addManufacturerData(manufacturerId, uid.toByteArray(StandardCharsets.UTF_8))
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