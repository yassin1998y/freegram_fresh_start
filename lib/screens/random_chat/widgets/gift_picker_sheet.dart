import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/interaction/interaction_bloc.dart';
import 'package:freegram/blocs/interaction/interaction_event.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/models/gift_model.dart';
import 'package:freegram/locator.dart';

class GiftPickerSheet extends StatelessWidget {
  const GiftPickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    // Ideally use locator<GiftRepository>() if registered, or provider
    final giftRepo =
        locator<GiftRepository>(); // Assuming it is registered in locator

    return Container(
      height: 350,
      decoration: const BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Send a Gift",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<GiftModel>>(
                stream: giftRepo.getAvailableGifts(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: Text("Error: ${snapshot.error}",
                            style: const TextStyle(color: Colors.white)));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final gifts = snapshot.data!;
                  if (gifts.isEmpty) {
                    return const Center(
                        child: Text("No gifts available",
                            style: TextStyle(color: Colors.white)));
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: gifts.length,
                    itemBuilder: (context, index) {
                      final gift = gifts[index];
                      return GestureDetector(
                        onTap: () {
                          context
                              .read<InteractionBloc>()
                              .add(SendGiftEvent(gift));
                          Navigator.pop(context);
                        },
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: _buildGiftPreview(gift),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              gift.name,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "${gift.priceInCoins}",
                              style: const TextStyle(
                                  color: Colors.yellowAccent, fontSize: 10),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftPreview(GiftModel gift) {
    final giftId = gift.id.toLowerCase();
    final giftName = gift.name.toLowerCase();

    if (giftId.contains('teddy') || giftName.contains('teddy')) {
      return Image.asset('assets/seed_data/teddy_bear.gif',
          width: 40, height: 40);
    } else if (giftId.contains('rose') || giftName.contains('rose')) {
      return Image.asset('assets/seed_data/red_rose_animation.gif',
          width: 40, height: 40);
    } else if (giftId.contains('ring') || giftName.contains('ring')) {
      return Image.asset('assets/seed_data/diamond_ring.gif',
          width: 40, height: 40);
    } else if (giftId.contains('balloon') || giftName.contains('balloon')) {
      return Image.asset('assets/seed_data/heart_balloon.gif',
          width: 40, height: 40);
    } else if (giftId.contains('party') || giftName.contains('party')) {
      return Image.asset('assets/seed_data/party_popper.gif',
          width: 40, height: 40);
    }

    return Text(
      gift.thumbnailUrl.isNotEmpty ? gift.thumbnailUrl : "🎁",
      style: const TextStyle(fontSize: 30),
    );
  }
}
