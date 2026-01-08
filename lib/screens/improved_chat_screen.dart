// lib/screens/improved_chat_screen.dart
// Professional Chat Screen with ALL 40 Improvements Integrated

import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/services/chat_state_tracker.dart';
import 'package:freegram/services/message_seen_tracker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/models/message.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/chat_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/repositories/friend_repository.dart';
import 'package:freegram/services/user_stream_provider.dart';
import 'package:freegram/services/cloudinary_service.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/chat_widgets/professional_message_bubble.dart';
import 'package:freegram/widgets/chat_widgets/professional_message_actions_modal.dart';
import 'package:freegram/widgets/chat_widgets/chat_date_separator.dart';
import 'package:freegram/widgets/chat_widgets/enhanced_message_input.dart';
import 'package:freegram/widgets/chat_widgets/professional_presence_indicator.dart';
import 'package:freegram/widgets/island_popup.dart';
import 'package:freegram/widgets/freegram_app_bar.dart';
import 'package:freegram/services/presence_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/widgets/common/app_button.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/friends_bloc/friends_bloc.dart';
import 'package:freegram/blocs/connectivity_bloc.dart';
import 'profile_screen.dart';
import 'package:hive/hive.dart';
import 'package:freegram/widgets/chat_widgets/gift_message_banner.dart';
import 'package:freegram/widgets/chat_widgets/celebration_match_badge.dart';
import 'package:freegram/widgets/chat_widgets/message_reaction_display.dart';

class ImprovedChatScreen extends StatelessWidget {
  final String chatId;
  final String otherUsername;

  const ImprovedChatScreen({
    super.key,
    required this.chatId,
    required this.otherUsername,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('📱 SCREEN: improved_chat_screen.dart');
    // Wrap with FriendsBloc for block functionality
    return BlocProvider(
      create: (context) => FriendsBloc(
        userRepository: locator<UserRepository>(),
        friendRepository: locator<FriendRepository>(),
      )..add(LoadFriends()),
      child: _ImprovedChatScreenContent(
        chatId: chatId,
        otherUsername: otherUsername,
      ),
    );
  }
}

class _ImprovedChatScreenContent extends StatefulWidget {
  final String chatId;
  final String otherUsername;

  const _ImprovedChatScreenContent({
    required this.chatId,
    required this.otherUsername,
  });

  @override
  State<_ImprovedChatScreenContent> createState() => _ImprovedChatScreenState();
}

class _ImprovedChatScreenState extends State<_ImprovedChatScreenContent>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  // Controllers & Services
  final _messageController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  late final ChatRepository _chatRepository;
  late final PresenceManager _presenceManager;

  // State
  List<Message> _messages = [];
  StreamSubscription? _messageSubscription;
  StreamSubscription? _connectivitySubscription;
  Timer? _typingTimer;
  Timer? _draftSaveTimer;
  bool _isUploading = false;
  static const Duration _sendTimeout = Duration(seconds: 8);
  String? _otherUserId; // Track other user ID for stream cleanup

  bool get _isOffline {
    final state = context.read<ConnectivityBloc>().state;
    return state is Offline;
  }

  final Set<String> _pendingRetryMessageIds = <String>{};

  String? _firstUnreadMessageId;
  String? _highlightedMessageId;

  // Reply state
  String? _replyingToMessageId;
  String? _replyingToMessageText;
  String? _replyingToSender;
  String? _replyingToImageUrl;

  // Performance optimization
  static const int _initialMessageCount = 50;
  final bool _hasMoreMessages = true;
  bool _isLoadingMore = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _chatRepository = locator<ChatRepository>();
    _presenceManager = locator<PresenceManager>();

    // Professional behavior: Register that user is viewing this chat
    // This will suppress notifications for messages from this chat
    ChatStateTracker().enterChat(widget.chatId);

    // Auto-mark messages as seen (like WhatsApp)
    MessageSeenTracker().startTracking(widget.chatId);

    // CRITICAL: Check auth before resetting unread count
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _chatRepository.resetUnreadCount(
        widget.chatId,
        currentUser.uid,
      );
    }
    _messageController.addListener(_onTyping);
    _messageController.addListener(_onDraftChanged);
    _listenForMessages();
    _scrollController.addListener(_onScroll);

    // Load per-chat draft
    try {
      final box = Hive.box('settings');
      final draftKey = 'draft_${widget.chatId}';
      final draftText = box.get(draftKey, defaultValue: '') as String;
      if (draftText.isNotEmpty) {
        _messageController.text = draftText;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: draftText.length),
        );
      }
    } catch (_) {}

    // Refresh presence when entering chat
    _presenceManager.refreshPresence();

    // Listen for connectivity changes to process queued retries
    _connectivitySubscription =
        context.read<ConnectivityBloc>().stream.listen((state) async {
      // CRITICAL: Check mounted before any async operations
      if (!mounted) return;

      final isNowOnline = state is Online;
      if (isNowOnline && _pendingRetryMessageIds.isNotEmpty) {
        // Re-check mounted before processing queue
        if (!mounted) return;

        final idsToProcess = List<String>.from(_pendingRetryMessageIds);
        for (final id in idsToProcess) {
          // Check mounted in loop to break early if disposed
          if (!mounted) break;

          final msg = _messages.firstWhere(
            (m) => m.id == id,
            orElse: () => Message(
              id: '',
              senderId: '',
              text: '',
            ),
          );
          if (msg.id.isEmpty) {
            _pendingRetryMessageIds.remove(id);
            continue;
          }
          await _performRetry(msg);
          // Re-check mounted after async operation
          if (!mounted) break;
          _pendingRetryMessageIds.remove(id);
        }
      }
    });
  }

  @override
  void dispose() {
    // Professional behavior: Unregister chat tracking
    ChatStateTracker().exitChat(widget.chatId);

    // Stop auto-marking messages as seen
    MessageSeenTracker().stopTracking(widget.chatId);

    _messageController.removeListener(_onTyping);
    _messageController.removeListener(_onDraftChanged);
    _messageController.dispose();
    _typingTimer?.cancel();
    _draftSaveTimer?.cancel();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _updateTypingStatus(false);
    // CRITICAL: Release user stream subscription
    if (_otherUserId != null) {
      UserStreamProvider().releaseUserStream(_otherUserId!);
    }
    super.dispose();
  }

  void _onScroll() {
    // Load more messages when scrolling near the top
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;

    // CRITICAL: Check mounted before setState
    if (!mounted) return;

    setState(() => _isLoadingMore = true);

    // TODO: Implement pagination
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _isLoadingMore = false;
        // _hasMoreMessages = false; // Set based on actual data
      });
    }
  }

  void _listenForMessages() {
    // CRITICAL: Check auth before listening to messages
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _messageSubscription =
        _chatRepository.getMessagesStream(widget.chatId).listen((snapshot) {
      if (mounted) {
        final serverMessages = snapshot.docs
            .take(_initialMessageCount)
            .map((doc) => Message.fromDoc(doc))
            .toList();

        final optimisticMessages = _messages
            .where((m) => m.status == MessageStatus.sending)
            .where((optimistic) => !serverMessages.any((server) =>
                server.senderId == optimistic.senderId &&
                server.text == optimistic.text))
            .toList();

        setState(() {
          _messages = [...optimisticMessages, ...serverMessages];
        });

        final firstUnread = serverMessages
            .where((m) =>
                m.senderId != currentUser.uid && m.status != MessageStatus.seen)
            .toList()
          ..sort((a, b) => a.timestamp!.compareTo(b.timestamp!));

        if (firstUnread.isNotEmpty && _firstUnreadMessageId == null) {
          setState(() {
            _firstUnreadMessageId = firstUnread.first.id;
          });
        }

        _markMessagesAsSeen(snapshot.docs);
      }
    });
  }

  void _markMessagesAsSeen(List<QueryDocumentSnapshot> docs) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final unreadMessageIds = docs
        .where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['senderId'] != currentUser.uid &&
              (data['isSeen'] == null || data['isSeen'] == false);
        })
        .map((doc) => doc.id)
        .toList();

    if (unreadMessageIds.isNotEmpty) {
      _chatRepository.markMultipleMessagesAsSeen(
          widget.chatId, unreadMessageIds);
    }
  }

  void _onTyping() {
    if (_typingTimer?.isActive ?? false) _typingTimer!.cancel();
    _updateTypingStatus(true);
    _typingTimer = Timer(
      const Duration(milliseconds: 1500),
      () => _updateTypingStatus(false),
    );
  }

  Future<void> _updateTypingStatus(bool isTyping) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await _chatRepository.updateTypingStatus(
        widget.chatId,
        currentUser.uid,
        isTyping,
      );
    }
  }

  void _onDraftChanged() {
    // Debounce disk writes
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 300), () {
      try {
        final box = Hive.box('settings');
        final draftKey = 'draft_${widget.chatId}';
        final text = _messageController.text;
        if (text.isEmpty) {
          box.delete(draftKey);
        } else {
          box.put(draftKey, text);
        }
      } catch (_) {}
    });
  }

  void _addMessageToList(Message message) {
    if (mounted) {
      setState(() {
        _messages.insert(0, message);
      });
    }
  }

  Future<void> _sendMessage() async {
    // CRITICAL: Check auth before sending
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final messageText = _messageController.text.trim();

    if (messageText.isEmpty) return;

    _typingTimer?.cancel();
    _updateTypingStatus(false);

    // Refresh presence when sending message
    _presenceManager.setActive();

    final optimisticMessage = Message.optimistic(
      senderId: currentUser.uid,
      text: messageText,
      replyToMessageId: _replyingToMessageId,
      replyToMessageText: _replyingToMessageText,
      replyToImageUrl: _replyingToImageUrl,
      replyToSender: _replyingToSender,
    );

    _addMessageToList(optimisticMessage);
    _messageController.clear();
    _cancelReply();
    // Clear saved draft on send
    try {
      final box = Hive.box('settings');
      box.delete('draft_${widget.chatId}');
    } catch (_) {}

    // If offline, mark as error immediately so user can retry
    if (_isOffline) {
      final index = _messages.indexWhere((m) => m.id == optimisticMessage.id);
      if (index != -1) {
        setState(() {
          _messages[index] = Message(
            id: optimisticMessage.id,
            senderId: optimisticMessage.senderId,
            text: optimisticMessage.text,
            status: MessageStatus.error,
            timestamp: optimisticMessage.timestamp,
          );
        });
      }
      showIslandPopup(
        context: context,
        message: 'You are offline. Tap the message to retry.',
        icon: Icons.wifi_off,
      );
      return;
    }

    try {
      await _chatRepository
          .sendMessage(
            chatId: widget.chatId,
            senderId: currentUser.uid,
            text: messageText,
            replyToMessageId: optimisticMessage.replyToMessageId,
            replyToMessageText: optimisticMessage.replyToMessageText,
            replyToImageUrl: optimisticMessage.replyToImageUrl,
            replyToSender: optimisticMessage.replyToSender,
          )
          .timeout(_sendTimeout);

      HapticFeedback.lightImpact();
    } on TimeoutException catch (_) {
      // Mark as error on timeout so user can retry
      final index = _messages.indexWhere((m) => m.id == optimisticMessage.id);
      if (index != -1) {
        setState(() {
          _messages[index] = Message(
            id: optimisticMessage.id,
            senderId: optimisticMessage.senderId,
            text: optimisticMessage.text,
            status: MessageStatus.error,
            timestamp: optimisticMessage.timestamp,
          );
        });
      }
      if (mounted) {
        showIslandPopup(
          context: context,
          message: 'No connection. Tap message to retry.',
          icon: Icons.wifi_off,
        );
      }
    } catch (e) {
      if (mounted) {
        showIslandPopup(
          context: context,
          message: e.toString(),
          icon: Icons.error_outline,
        );

        final index = _messages.indexWhere((m) => m.id == optimisticMessage.id);
        if (index != -1) {
          setState(() {
            _messages[index] = Message(
              id: optimisticMessage.id,
              senderId: optimisticMessage.senderId,
              text: optimisticMessage.text,
              status: MessageStatus.error,
              timestamp: optimisticMessage.timestamp,
            );
          });
        }
      }
    }
  }

  // Image upload now handled by CloudinaryService (centralized)

  // OPTIMIZED: Non-blocking image upload with progress
  Future<void> _sendImage({ImageSource? source}) async {
    try {
      final selectedSource = source ??
          await showModalBottomSheet<ImageSource>(
            context: context,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(DesignTokens.radiusXL),
              ),
            ),
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(
                        vertical: DesignTokens.spaceMD),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.onSurface.withOpacity(
                                DesignTokens.opacityMedium,
                              ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text('Camera'),
                    onTap: () => Navigator.of(context).pop(ImageSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('Gallery'),
                    onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                  ),
                  const SizedBox(height: DesignTokens.spaceMD),
                ],
              ),
            ),
          );

      if (selectedSource == null) return;

      if (selectedSource == ImageSource.camera) {
        final permissionStatus = await Permission.camera.status;
        if (!permissionStatus.isGranted) {
          final permission = await Permission.camera.request();
          if (!permission.isGranted) {
            if (mounted) {
              showIslandPopup(
                context: context,
                message: 'Camera permission required',
                icon: Icons.camera_alt_outlined,
              );
            }
            return;
          }
        }
      }

      final pickedFile = await _picker
          .pickImage(
            source: selectedSource,
            imageQuality: 70,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => null,
          );

      if (pickedFile == null) return;

      // OPTIMIZED: Show optimistic message immediately (non-blocking)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final optimisticMessage = Message.optimistic(
        senderId: currentUser.uid,
        text: '',
        imageUrl: pickedFile.path, // Show local path first
        replyToMessageId: _replyingToMessageId,
        replyToMessageText: _replyingToMessageText,
        replyToImageUrl: _replyingToImageUrl,
        replyToSender: _replyingToSender,
      );

      // Add optimistic message to UI immediately
      _addMessageToList(optimisticMessage);
      _cancelReply();

      // Show uploading indicator in bottom sheet area instead of blocking whole UI
      if (mounted) {
        showIslandPopup(
          context: context,
          message: 'Uploading image...',
          icon: Icons.cloud_upload_outlined,
        );
      }

      // Upload in background without blocking (using CloudinaryService)
      try {
        // If offline, fail fast
        if (_isOffline) throw TimeoutException('offline');
        final imageUrl = await CloudinaryService.uploadImageFromFile(
          File(pickedFile.path),
        );
        if (imageUrl == null) throw Exception('Image upload failed');

        // Send actual message after upload
        await _chatRepository
            .sendMessage(
              chatId: widget.chatId,
              senderId: currentUser.uid,
              imageUrl: imageUrl,
              replyToMessageId: optimisticMessage.replyToMessageId,
              replyToMessageText: optimisticMessage.replyToMessageText,
              replyToImageUrl: optimisticMessage.replyToImageUrl,
              replyToSender: optimisticMessage.replyToSender,
            )
            .timeout(_sendTimeout);

        // Remove optimistic message (real message will appear from stream)
        if (mounted) {
          setState(() {
            _messages.removeWhere((m) => m.id == optimisticMessage.id);
          });
        }

        HapticFeedback.mediumImpact();
        if (mounted) {
          showIslandPopup(
            context: context,
            message: 'Image sent!',
            icon: Icons.check_circle_outline,
          );
        }
      } on TimeoutException catch (_) {
        // Mark optimistic image message as error on timeout
        if (mounted) {
          final index =
              _messages.indexWhere((m) => m.id == optimisticMessage.id);
          if (index != -1) {
            setState(() {
              _messages[index] = Message(
                id: optimisticMessage.id,
                senderId: optimisticMessage.senderId,
                text: 'Failed to send image',
                status: MessageStatus.error,
                timestamp: optimisticMessage.timestamp,
                imageUrl: optimisticMessage.imageUrl,
              );
            });
          }
          showIslandPopup(
            context: context,
            message: 'No connection. Tap message to retry.',
            icon: Icons.wifi_off,
          );
        }
      } catch (e) {
        // Update optimistic message to show error
        if (mounted) {
          final index =
              _messages.indexWhere((m) => m.id == optimisticMessage.id);
          if (index != -1) {
            setState(() {
              _messages[index] = Message(
                id: optimisticMessage.id,
                senderId: optimisticMessage.senderId,
                text: 'Failed to send image',
                status: MessageStatus.error,
                timestamp: optimisticMessage.timestamp,
              );
            });
          }
          showIslandPopup(
            context: context,
            message: 'Failed to send image: $e',
            icon: Icons.error_outline,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showIslandPopup(
          context: context,
          message: 'Failed to pick image: $e',
          icon: Icons.error_outline,
        );
      }
    }
  }

  void _startReply(Message message) {
    setState(() {
      _replyingToMessageId = message.id;
      _replyingToMessageText = message.text;
      _replyingToImageUrl = message.imageUrl;
      _replyingToSender =
          message.senderId == (FirebaseAuth.instance.currentUser?.uid ?? '')
              ? 'You'
              : widget.otherUsername;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingToMessageId = null;
      _replyingToMessageText = null;
      _replyingToSender = null;
      _replyingToImageUrl = null;
    });
  }

  void _scrollToMessage(String messageId) {
    setState(() => _highlightedMessageId = messageId);

    // Find message index and scroll
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _scrollController.animateTo(
        index * 100.0, // Approximate height
        duration: AnimationTokens.normal,
        curve: Curves.easeInOut,
      );
    }

    // Clear highlight after animation
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _highlightedMessageId = null);
      }
    });
  }

  void _showMessageActions(Message message, bool isMe) {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfessionalMessageActionsModal(
        message: message,
        isMe: isMe,
        chatId: widget.chatId,
        currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
        onReaction: (emoji) {
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
          if (currentUserId == null) return;
          _chatRepository.toggleMessageReaction(
            widget.chatId,
            message.id,
            currentUserId,
            emoji,
          );
        },
        onReply: () => _startReply(message),
        onEdit: (messageId, newText) {
          _chatRepository.editMessage(widget.chatId, messageId, newText);
        },
        onDelete: (messageId) {
          _chatRepository.deleteMessage(widget.chatId, messageId);
        },
      ),
    );
  }

  Future<void> _retryMessage(Message failed) async {
    if (_isOffline) {
      // Queue for auto-retry when online; don't attempt now
      _pendingRetryMessageIds.add(failed.id);
      if (mounted) {
        showIslandPopup(
          context: context,
          message:
              'You are offline. Will resend automatically when back online.',
          icon: Icons.schedule_send,
        );
      }
      return;
    }
    await _performRetry(failed);
  }

  Future<void> _performRetry(Message failed) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    try {
      if (_isOffline) throw TimeoutException('offline');
      if ((failed.imageUrl ?? '').isNotEmpty &&
          !(failed.imageUrl!.startsWith('http'))) {
        // Retry image: re-upload local file path
        final file = File(failed.imageUrl!);
        if (!await file.exists()) throw Exception('Image not found');
        final imageUrl = await CloudinaryService.uploadImageFromFile(file);
        if (imageUrl == null) throw Exception('Image upload failed');
        await _chatRepository.sendMessage(
          chatId: widget.chatId,
          senderId: currentUser.uid,
          imageUrl: imageUrl,
          replyToMessageId: failed.replyToMessageId,
          replyToMessageText: failed.replyToMessageText,
          replyToImageUrl: failed.replyToImageUrl,
          replyToSender: failed.replyToSender,
        );
      } else {
        // Retry text
        await _chatRepository.sendMessage(
          chatId: widget.chatId,
          senderId: currentUser.uid,
          text: failed.text,
          replyToMessageId: failed.replyToMessageId,
          replyToMessageText: failed.replyToMessageText,
          replyToImageUrl: failed.replyToImageUrl,
          replyToSender: failed.replyToSender,
        );
      }
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == failed.id);
        });
        showIslandPopup(
          context: context,
          message: 'Message resent',
          icon: Icons.check_circle_outline,
        );
      }
    } on TimeoutException catch (_) {
      if (mounted) {
        showIslandPopup(
          context: context,
          message: 'Still offline. Will retry when connected.',
          icon: Icons.wifi_off,
        );
      }
      _pendingRetryMessageIds.add(failed.id);
    } catch (e) {
      if (mounted) {
        showIslandPopup(
          context: context,
          message: 'Retry failed: $e',
          icon: Icons.error_outline,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // CRITICAL: Check if user is authenticated before building chat
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // User logged out - return loading scaffold with background
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: FreegramAppBar(
          title: widget.otherUsername,
          showBackButton: true,
        ),
        body: const Center(
          child: AppProgressIndicator(),
        ),
      );
    }

    // OPTIMIZATION: Add BlocListener to handle FriendsBloc state changes
    return BlocListener<FriendsBloc, FriendsState>(
      listener: (context, state) {
        // Handle block user success/error
        if (state is FriendsActionSuccess) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: SemanticColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
            // Navigate back after blocking
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                Navigator.of(context).pop();
              }
            });
          }
        } else if (state is FriendsActionError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      },
      child: StreamBuilder<DocumentSnapshot>(
        stream: _chatRepository.getChatStream(widget.chatId),
        builder: (context, chatSnapshot) {
          if (!chatSnapshot.hasData || !chatSnapshot.data!.exists) {
            return _buildErrorScaffold('Chat not available');
          }

          final chatData = chatSnapshot.data!.data() as Map<String, dynamic>;
          final List<dynamic> users = chatData['users'] ?? [];

          if (users.isEmpty) {
            return _buildErrorScaffold('Chat data unavailable');
          }

          final otherUserId =
              users.firstWhere((id) => id != currentUser.uid, orElse: () => '');

          // CRITICAL: Store otherUserId for cleanup
          if (_otherUserId != otherUserId) {
            // Release previous user stream if different
            if (_otherUserId != null) {
              UserStreamProvider().releaseUserStream(_otherUserId!);
            }
            _otherUserId = otherUserId;
          }

          final chatType = chatData['chatType'] ?? 'friend';
          final bool isContactRequest = chatType == 'contact_request';
          final initiatorId = chatData['initiatorId'];
          final bool isSender =
              isContactRequest && currentUser.uid == initiatorId;
          final Timestamp? matchTimestamp = chatData['matchTimestamp'];

          return StreamBuilder<UserModel>(
            stream: UserStreamProvider().getUserStream(otherUserId),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) {
                return _buildLoadingScaffold();
              }

              final user = userSnapshot.data!;

              return Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                appBar: _buildProfessionalAppBar(user, otherUserId, chatData),
                body: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      // Messages list
                      Expanded(
                        child: RepaintBoundary(
                          child: _buildMessagesList(
                              matchTimestamp, currentUser.uid),
                        ),
                      ),

                      // Sender info banner
                      if (isSender) _SenderInfoBanner(),

                      // Enhanced input
                      SafeArea(
                        top: false,
                        child: EnhancedMessageInput(
                          controller: _messageController,
                          onSend: _sendMessage,
                          onSendAudio: _handleSendAudio,
                          onCamera: () =>
                              _sendImage(source: ImageSource.camera),
                          onGallery: () =>
                              _sendImage(source: ImageSource.gallery),
                          isUploading: _isUploading,
                          replyingTo: _replyingToMessageText,
                          onCancelReply: _cancelReply,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleSendAudio(String path, Duration duration) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    setState(() {
      _isUploading = true;
    });

    bool didSend = false;
    try {
      await _chatRepository.sendVoiceMessage(
        chatId: widget.chatId,
        senderId: currentUser.uid,
        audioFile: File(path),
        audioDuration: duration,
      );
      didSend = true;
    } catch (e) {
      if (!mounted) return;
      showIslandPopup(
        context: context,
        message: 'Voice message failed to send. Please try again.',
        icon: Icons.error_outline,
      );
    } finally {
      if (didSend) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  PreferredSizeWidget _buildProfessionalAppBar(
    UserModel user,
    String userId,
    Map<String, dynamic> chatData,
  ) {
    final theme = Theme.of(context);
    final photoUrl = user.photoUrl;

    // Get presence stream from PresenceManager
    final presenceStream = _presenceManager.getUserPresence(userId);

    // Check typing status
    final typingStatus =
        chatData['typingStatus'] as Map<String, dynamic>? ?? {};
    final isTyping = typingStatus[userId] == true;

    return FreegramAppBar(
      titleWidget: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          locator<NavigationService>().navigateTo(
            ProfileScreen(userId: userId),
            transition: PageTransition.slide,
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceSM,
            vertical: DesignTokens.spaceXS,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar with presence indicator
              Hero(
                tag: 'avatar_$userId',
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: DesignTokens.avatarSizeSmall + 6,
                      height: DesignTokens.avatarSizeSmall + 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        backgroundImage: photoUrl.isNotEmpty
                            ? CachedNetworkImageProvider(photoUrl)
                                as ImageProvider
                            : null,
                        backgroundColor:
                            theme.colorScheme.primary.withOpacity(0.1),
                        child: photoUrl.isEmpty
                            ? Text(
                                widget.otherUsername.isNotEmpty
                                    ? widget.otherUsername[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                    // Professional presence indicator
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: ProfessionalPresenceIndicator(
                        presenceStream: presenceStream,
                        size: DesignTokens.iconXS,
                        showPulse: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Name and status
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.otherUsername,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: DesignTokens.fontSizeMD,
                            color: theme.colorScheme.onSurface,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: DesignTokens.spaceXS / 4),
                    // Professional presence text
                    ProfessionalPresenceText(
                      presenceStream: presenceStream,
                      isTyping: isTyping,
                      includePrefix: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        // More options
        AppIconButton(
          icon: Icons.more_vert_rounded,
          tooltip: 'More options',
          onPressed: () {
            HapticFeedback.lightImpact();
            _showChatOptions(context, userId);
          },
        ),
      ],
    );
  }

  void _showChatOptions(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(DesignTokens.radiusXL),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: DesignTokens.spaceMD),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(
                      DesignTokens.opacityMedium,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceLG),
                _buildOptionTile(
                  context,
                  icon: Icons.person_outline,
                  title: 'View Profile',
                  onTap: () {
                    locator<NavigationService>().goBack();
                    locator<NavigationService>().navigateTo(
                      ProfileScreen(userId: userId),
                      transition: PageTransition.slide,
                    );
                  },
                ),
                _buildOptionTile(
                  context,
                  icon: Icons.notifications_off_outlined,
                  title: 'Mute Notifications',
                  onTap: () {
                    Navigator.pop(context);
                    showIslandPopup(
                      context: context,
                      message: 'Mute feature coming soon',
                      icon: Icons.info_outline,
                    );
                  },
                ),
                _buildOptionTile(
                  context,
                  icon: Icons.block_outlined,
                  title: 'Block User',
                  color: theme.colorScheme.error,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmBlockUser(context, userId);
                  },
                ),
                const SizedBox(height: DesignTokens.spaceMD),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmBlockUser(BuildContext context, String userId) async {
    final bool? shouldBlock = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Block User?'),
          content: Text(
            'Are you sure you want to block ${widget.otherUsername}? They won\'t be able to message you or see your profile.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Block',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        );
      },
    );

    if (shouldBlock == true && mounted) {
      HapticFeedback.mediumImpact();

      // Block user
      context.read<FriendsBloc>().add(BlockUser(userId));

      // OPTIMIZATION: Use BlocConsumer pattern instead of manual stream subscription
      // The BlocConsumer in the widget tree will handle state changes automatically
      // Just show immediate feedback and let the bloc handle the rest
    }
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final tileColor = color ?? theme.colorScheme.onSurface;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: tileColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
        ),
        child: Icon(
          icon,
          color: tileColor,
          size: DesignTokens.iconMD,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: tileColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }

  Widget _buildMessagesList(Timestamp? matchTimestamp, String currentUserId) {
    return ListView.builder(
      reverse: true,
      controller: _scrollController,
      padding: const EdgeInsets.all(DesignTokens.spaceSM),
      physics: const BouncingScrollPhysics(),
      itemCount: _messages.length +
          (matchTimestamp != null ? 1 : 0) +
          (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Loading indicator at bottom
        if (_isLoadingMore &&
            index == _messages.length + (matchTimestamp != null ? 1 : 0)) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(DesignTokens.spaceMD),
              child: AppProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        // Match badge
        if (matchTimestamp != null && index == _messages.length) {
          return CelebrationMatchBadge(timestamp: matchTimestamp.toDate());
        }

        final message = _messages[index];
        final previousMessage =
            (index + 1 < _messages.length) ? _messages[index + 1] : null;
        final nextMessage = (index > 0) ? _messages[index - 1] : null;

        final messageDate = message.timestamp?.toDate();
        final previousMessageDate = previousMessage?.timestamp?.toDate();

        final bool showDateSeparator = messageDate != null &&
            (previousMessageDate == null ||
                messageDate.day != previousMessageDate.day ||
                messageDate.month != previousMessageDate.month ||
                messageDate.year != previousMessageDate.year);

        final bool showUnreadSeparator = message.id == _firstUnreadMessageId;

        return Column(
          children: [
            if (showDateSeparator) ChatDateSeparator(date: messageDate),
            if (showUnreadSeparator)
              UnreadMessagesDivider(
                onDismiss: () {
                  setState(() => _firstUnreadMessageId = null);
                },
              ),
            if (message.isGiftMessage && message.giftId != null)
              GiftMessageBanner(
                giftId: message.giftId!,
                timestamp: message.timestamp?.toDate() ?? DateTime.now(),
                isMe: message.senderId == currentUserId,
              )
            else
              RepaintBoundary(
                child: ProfessionalMessageBubble(
                  key: ValueKey(message.id),
                  message: message,
                  isMe: message.senderId == currentUserId,
                  onTap: () {
                    final isMe = message.senderId == currentUserId;
                    if (isMe && message.status == MessageStatus.error) {
                      _retryMessage(message);
                    }
                  },
                  previousMessage: previousMessage,
                  nextMessage: nextMessage,
                  otherUsername: widget.otherUsername,
                  onLongPress: () => _showMessageActions(
                    message,
                    message.senderId == currentUserId,
                  ),
                  onReplyTap: message.replyToMessageId != null
                      ? () => _scrollToMessage(message.replyToMessageId!)
                      : null,
                  shouldHighlight: message.id == _highlightedMessageId,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildErrorScaffold(String message) {
    return Scaffold(
      // CRITICAL: Explicit background color to prevent black screen during transitions
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: FreegramAppBar(
        title: widget.otherUsername,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.spaceLG),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: DesignTokens.iconXXL * 1.6,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: DesignTokens.spaceMD),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: DesignTokens.fontSizeMD,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScaffold() {
    return Scaffold(
      // CRITICAL: Explicit background color to prevent black screen during transitions
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: FreegramAppBar(
        title: widget.otherUsername,
      ),
      body: const SafeArea(
        child: Center(
          child: AppProgressIndicator(),
        ),
      ),
    );
  }
}

class _SenderInfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // System theme colors
    final backgroundColor = isDark
        ? theme.colorScheme.primaryContainer.withOpacity(0.3)
        : theme.colorScheme.primaryContainer.withOpacity(0.5);
    final textColor = isDark
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onPrimaryContainer;
    final iconColor = theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceSM),
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceMD,
        vertical: DesignTokens.spaceMD,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(DesignTokens.spaceSM),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              color: iconColor,
              size: DesignTokens.iconSM,
            ),
          ),
          const SizedBox(width: DesignTokens.spaceMD),
          Expanded(
            child: Text(
              'You can send up to 2 messages. Once they reply or accept, you can chat freely.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: textColor,
                    fontSize: DesignTokens.fontSizeSM,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
