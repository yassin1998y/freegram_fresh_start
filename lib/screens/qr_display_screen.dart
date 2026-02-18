import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/widgets/freegram_app_bar.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class QrDisplayScreen extends StatelessWidget {
  final UserModel user;

  const QrDisplayScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    debugPrint('📱 SCREEN: qr_display_screen.dart');
    // This is the data that will be embedded in the QR code.
    // It's a "deep link" that could be used to open the app to a specific profile.
    final String qrData = 'freegram://user/${user.id}';

    return Scaffold(
      appBar: const FreegramAppBar(
        title: 'My QR Code',
        showBackButton: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: Containers.glassCard(context).copyWith(
                  boxShadow: [
                    BoxShadow(
                      color: (user.presence
                              ? const Color(0xFF00BFA5)
                              : Colors.grey)
                          .withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 250.0,
                  // Embedded image for branding
                  embeddedImage: user.photoUrl.isNotEmpty
                      ? CachedNetworkImageProvider(user.photoUrl)
                      : null,
                  embeddedImageStyle: const QrEmbeddedImageStyle(
                    size: Size(60, 60),
                  ),
                  errorStateBuilder: (cxt, err) {
                    return const Center(
                      child: Text(
                        "Uh oh! Something went wrong...",
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Scan this code to view profile',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
