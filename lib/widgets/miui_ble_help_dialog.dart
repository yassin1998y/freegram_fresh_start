// lib/widgets/miui_ble_help_dialog.dart
import 'package:flutter/material.dart';

/// Dialog to help MIUI users fix BLE advertising Error 18
/// Provides step-by-step guidance for closing conflicting apps
class MiuiBleHelpDialog extends StatelessWidget {
  const MiuiBleHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.bluetooth_disabled, color: Colors.orange, size: 28),
          SizedBox(width: 12),
          Flexible(
            child: Text(
              'Fix BLE Advertising (Error 18)',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'MIUI limits Bluetooth advertising slots to 3-5 system-wide',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Step 1: Close These Apps',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildAppList(),
            const SizedBox(height: 16),
            const Text(
              'Step 2: Clear Bluetooth Cache',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildStep(
              '1.',
              'Go to Settings → Apps → Show system apps',
            ),
            _buildStep(
              '2.',
              'Find "Bluetooth" and tap it',
            ),
            _buildStep(
              '3.',
              'Tap "Clear cache" (NOT Clear data)',
            ),
            const SizedBox(height: 16),
            const Text(
              'Step 3: Restart Bluetooth',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildStep(
              '1.',
              'Turn Bluetooth OFF',
            ),
            _buildStep(
              '2.',
              'Wait 10 seconds',
            ),
            _buildStep(
              '3.',
              'Turn Bluetooth ON',
            ),
            const SizedBox(height: 16),
            const Text(
              'Step 4: Restart Freegram',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildStep(
              '1.',
              'Close Freegram completely (swipe away from recent apps)',
            ),
            _buildStep(
              '2.',
              'Reopen Freegram',
            ),
            _buildStep(
              '3.',
              'Try scanning again',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This is a MIUI limitation, not a Freegram bug. Xiaomi restricts how many apps can advertise via Bluetooth simultaneously.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // TODO: Could open app settings here
          },
          child: const Text('I Did This'),
        ),
      ],
    );
  }

  Widget _buildAppList() {
    final apps = [
      '✗ Mi Home / Mi Smart Home',
      '✗ Mi Fit / Xiaomi Fitness',
      '✗ Mi Remote',
      '✗ Find My Device',
      '✗ Any other Bluetooth apps',
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: apps
            .map((app) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    app,
                    style: const TextStyle(fontSize: 13),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
