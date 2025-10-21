// This file is used as a fallback when compiling for the web.
// It provides the same class and enum names as the real bluetooth_service.dart
// but with no-op implementations, preventing compilation errors.

// Mocking BluetoothAdapterState from flutter_blue_plus
enum BluetoothAdapterState {
  unknown,
  unavailable,
  unauthorized,
  turningOn,
  on,
  turningOff,
  off,
}

// Mocking FlutterBluePlus
class FlutterBluePlus {
  static BluetoothAdapterState get adapterStateNow => BluetoothAdapterState.unavailable;
}
