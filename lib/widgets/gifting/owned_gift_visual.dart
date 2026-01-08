import 'package:flutter/material.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/gift_model.dart';
import 'package:freegram/models/user_inventory_model.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/widgets/gifting/gift_visual.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

class OwnedGiftVisual extends StatelessWidget {
  final OwnedGift ownedGift;
  final double size;
  final bool showRarityBackground;
  final bool animate;

  const OwnedGiftVisual({
    super.key,
    required this.ownedGift,
    this.size = 100,
    this.showRarityBackground = true,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GiftModel?>(
      future: locator<GiftRepository>().getGiftById(ownedGift.giftId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: size,
            height: size,
            child: const Center(child: AppProgressIndicator(size: 20)),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return SizedBox(
            width: size,
            height: size,
            child:
                Icon(Icons.error_outline, size: size * 0.5, color: Colors.grey),
          );
        }

        return GiftVisual(
          gift: snapshot.data!,
          size: size,
          showRarityBackground: showRarityBackground,
          animate: animate,
        );
      },
    );
  }
}
