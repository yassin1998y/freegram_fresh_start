import 'package:flutter/material.dart';
import 'package:freegram/models/profile_item_model.dart';
import 'package:freegram/repositories/profile_repository.dart';
import 'package:freegram/locator.dart';

class ProfileBorderWidget extends StatelessWidget {
  final String? borderId;
  final Widget child;
  final double size;

  const ProfileBorderWidget({
    Key? key,
    required this.borderId,
    required this.child,
    this.size = 100,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (borderId == null || borderId!.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: child,
      );
    }

    // In a real app, we'd cache the border URL or fetch it from a provider.
    // For now, we'll fetch it directly (not optimal for lists, but works for profile).
    // A better approach would be to have the border URL in the User object or cached.

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: size * 0.85, // Avatar is slightly smaller than border
          height: size * 0.85,
          child: child,
        ),
        FutureBuilder<List<ProfileItemModel>>(
          future: locator<ProfileRepository>()
              .getProfileItems(type: ProfileItemType.border)
              .first,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();

            try {
              final border =
                  snapshot.data!.firstWhere((item) => item.id == borderId);
              return SizedBox(
                width: size,
                height: size,
                child: Image.network(
                  border.assetUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              );
            } catch (e) {
              return const SizedBox();
            }
          },
        ),
      ],
    );
  }
}
