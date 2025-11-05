// lib/services/mention_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:freegram/repositories/user_repository.dart';

class MentionService {
  final FirebaseFirestore _db;
  final UserRepository _userRepository;

  MentionService({
    FirebaseFirestore? firestore,
    required UserRepository userRepository,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _userRepository = userRepository;

  /// Extract mentions from text using regex
  /// Returns a list of unique usernames (without the @ symbol)
  List<String> extractMentions(String text) {
    if (text.isEmpty) return [];

    // Regex to match mentions: @ followed by username (alphanumeric and underscore)
    final regex = RegExp(r'@(\w+)', caseSensitive: false);
    final matches = regex.allMatches(text);

    // Extract unique mentions
    final Set<String> uniqueMentions = {};
    for (final match in matches) {
      if (match.groupCount > 0) {
        final mention = match.group(1)!;
        if (mention.isNotEmpty) {
          uniqueMentions.add(mention);
        }
      }
    }

    return uniqueMentions.toList();
  }

  /// Validate that mentioned users exist
  /// Returns a map of {username: userId} for valid mentions
  Future<Map<String, String>> validateMentions(
    List<String> usernames,
  ) async {
    try {
      final Map<String, String> validMentions = {};

      for (final username in usernames) {
        try {
          final user = await _userRepository.getUserByUsername(username);
          if (user != null) {
            validMentions[username.toLowerCase()] = user.id;
          }
        } catch (e) {
          debugPrint('MentionService: User not found: $username');
          // Skip invalid mentions
        }
      }

      return validMentions;
    } catch (e) {
      debugPrint('MentionService: Error validating mentions: $e');
      return {};
    }
  }

  /// Get posts where a user is mentioned
  Future<List<String>> getMentionedPosts(
    String userId, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _db
          .collection('posts')
          .where('mentions', arrayContains: userId)
          .where('deleted', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('MentionService: Error getting mentioned posts: $e');
      return [];
    }
  }

  /// Get posts where a username is mentioned (for @username searches)
  Future<List<String>> getMentionedPostsByUsername(
    String username, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      // First, find the user by username
      final user = await _userRepository.getUserByUsername(username);
      if (user == null) {
        return [];
      }

      // Then get posts where this user is mentioned
      return getMentionedPosts(user.id, limit: limit, startAfter: startAfter);
    } catch (e) {
      debugPrint(
          'MentionService: Error getting mentioned posts by username: $e');
      return [];
    }
  }

  /// Get mention count for a user
  Future<int> getMentionCount(String userId) async {
    try {
      final snapshot = await _db
          .collection('posts')
          .where('mentions', arrayContains: userId)
          .where('deleted', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('MentionService: Error getting mention count: $e');
      return 0;
    }
  }

  /// Format text with clickable mentions and hashtags
  /// Returns a TextSpan tree for RichText widget
  List<TextSpan> formatTextWithMentionsAndHashtags(
    String text, {
    TextStyle? defaultStyle,
    TextStyle? mentionStyle,
    TextStyle? hashtagStyle,
    Function(String username)? onMentionTap,
    Function(String hashtag)? onHashtagTap,
  }) {
    final List<TextSpan> spans = [];
    defaultStyle ??= const TextStyle();
    mentionStyle ??= TextStyle(color: Colors.blue, fontWeight: FontWeight.w500);
    hashtagStyle ??= TextStyle(color: Colors.blue, fontWeight: FontWeight.w500);

    // Regex to match both mentions and hashtags
    final pattern = RegExp(r'(@\w+|#\w+)', caseSensitive: false);
    final matches = pattern.allMatches(text);

    int lastIndex = 0;

    for (final match in matches) {
      // Add text before the match
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: defaultStyle,
        ));
      }

      final matchedText = match.group(0)!;
      final isMention = matchedText.startsWith('@');
      final value = matchedText.substring(1); // Remove @ or #

      spans.add(TextSpan(
        text: matchedText,
        style: isMention ? mentionStyle : hashtagStyle,
        recognizer: isMention && onMentionTap != null
            ? (TapGestureRecognizer()..onTap = () => onMentionTap(value))
            : !isMention && onHashtagTap != null
                ? (TapGestureRecognizer()..onTap = () => onHashtagTap(value))
                : null,
      ));

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: defaultStyle,
      ));
    }

    return spans;
  }
}
