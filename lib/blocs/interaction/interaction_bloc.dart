import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/interaction/interaction_event.dart';
import 'package:freegram/blocs/interaction/interaction_state.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/gift_model.dart';
import 'package:freegram/services/webrtc_service.dart';
import 'package:freegram/repositories/report_repository.dart';
import 'package:freegram/models/report_model.dart';
import 'package:flutter/foundation.dart';

class InteractionBloc extends Bloc<InteractionEvent, InteractionState> {
  final WebRTCService _webRTCService = locator<WebRTCService>();
  StreamSubscription? _interactionSubscription;

  InteractionBloc() : super(InteractionInitial()) {
    // Listen to incoming
    _interactionSubscription = _webRTCService.interactionStream.listen((data) {
      add(IncomingInteractionEvent(data));
    });

    on<SendGiftEvent>((event, emit) {
      _webRTCService.sendInteraction('GIFT', {
        'giftId': event.gift.id,
        'giftUrl':
            event.gift.animationUrl, // Assume animationUrl exists in GiftModel
        'name': event.gift.name,
      });
    });

    on<SendMessageEvent>((event, emit) {
      _webRTCService.sendInteraction('CHAT', {
        'text': event.text,
      });
    });

    on<SendFriendRequestEvent>((event, emit) {
      _webRTCService.sendInteraction('FRIEND_REQUEST', {});
      // Also call legacy addFriend() if dual support needed
      _webRTCService.addFriend();
    });

    on<BlockUserEvent>((event, emit) {
      _webRTCService.blockUser(event.userId);
    });

    on<ReportUserEvent>((event, emit) async {
      // 1. Block locally & Disconnect immediately
      await _webRTCService.blockUser(event.userId);

      // 2. Submit to backend (Fire-and-forget or await if needed)
      // locator<ReportRepository>().submitReport(...)
      // We'll trust the repository is resilient.
      final reportRepo = locator<ReportRepository>();
      try {
        await reportRepo.reportContent(
          contentType: ReportContentType.user,
          contentId: event.userId,
          userId: _webRTCService.currentUserId ?? 'unknown',
          category: _mapCategory(event.category),
          reason: event.reason,
        );
      } catch (e) {
        debugPrint("Report submission failed: $e");
      }
    });

    on<IncomingInteractionEvent>((event, emit) {
      final type = event.data['type'];
      final payload = event.data['payload'];

      if (type == 'GIFT') {
        // Construct a temporary GiftModel for display
        final gift = GiftModel(
          id: payload['giftId'] ?? 'unknown',
          name: payload['name'] ?? 'Gift',
          description: 'Gift from partner',
          priceInCoins: 0,
          animationUrl: payload['giftUrl'] ?? '',
          thumbnailUrl: '', // Not used for animation
          category: GiftCategory.special,
          rarity: GiftRarity.common,
          isLimited: false,
          soldCount: 0,
          createdAt: DateTime.now(),
        );
        emit(GiftReceivedState(gift: gift, senderName: "Partner"));
      } else if (type == 'CHAT') {
        emit(ChatReceivedState(
          text: payload['text'] ?? '',
          senderName: "Partner",
        ));
      } else if (type == 'FRIEND_REQUEST') {
        emit(FriendRequestReceivedState("Partner"));
      }
    });
  }

  @override
  Future<void> close() {
    _interactionSubscription?.cancel();
    return super.close();
  }

  ReportCategory _mapCategory(String category) {
    switch (category) {
      case 'spam':
        return ReportCategory.spam;
      case 'harassment':
        return ReportCategory.harassment;
      case 'nudity':
        return ReportCategory.inappropriate;
      case 'violence':
        return ReportCategory.violence;
      default:
        return ReportCategory.other;
    }
  }
}
