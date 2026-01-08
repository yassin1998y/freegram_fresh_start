import 'package:flutter/material.dart';

/// Message template model for quick gift messages
class MessageTemplate {
  final String id;
  final String text;
  final String category;
  final IconData icon;
  final bool isCustom;

  const MessageTemplate({
    required this.id,
    required this.text,
    required this.category,
    required this.icon,
    this.isCustom = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'category': category,
      'isCustom': isCustom,
    };
  }

  factory MessageTemplate.fromMap(Map<String, dynamic> map) {
    return MessageTemplate(
      id: map['id'] as String,
      text: map['text'] as String,
      category: map['category'] as String,
      icon: _getIconForCategory(map['category'] as String),
      isCustom: map['isCustom'] as bool? ?? false,
    );
  }

  static IconData _getIconForCategory(String category) {
    switch (category) {
      case 'birthday':
        return Icons.cake;
      case 'love':
        return Icons.favorite;
      case 'thanks':
        return Icons.thumb_up;
      case 'celebration':
        return Icons.celebration;
      case 'friendship':
        return Icons.people;
      case 'encouragement':
        return Icons.star;
      default:
        return Icons.message;
    }
  }
}

/// Predefined message templates
class MessageTemplates {
  static const List<MessageTemplate> templates = [
    // Birthday
    MessageTemplate(
      id: 'birthday_1',
      text: '🎂 Happy Birthday! Hope your day is amazing!',
      category: 'birthday',
      icon: Icons.cake,
    ),
    MessageTemplate(
      id: 'birthday_2',
      text: '🎉 Wishing you the best birthday ever!',
      category: 'birthday',
      icon: Icons.cake,
    ),
    MessageTemplate(
      id: 'birthday_3',
      text: '🎈 Another year older, another year wiser! Happy Birthday!',
      category: 'birthday',
      icon: Icons.cake,
    ),

    // Love & Romance
    MessageTemplate(
      id: 'love_1',
      text: '❤️ Thinking of you!',
      category: 'love',
      icon: Icons.favorite,
    ),
    MessageTemplate(
      id: 'love_2',
      text: '💕 You mean the world to me!',
      category: 'love',
      icon: Icons.favorite,
    ),
    MessageTemplate(
      id: 'love_3',
      text: '🌹 Just because you\'re special!',
      category: 'love',
      icon: Icons.favorite,
    ),

    // Thanks & Appreciation
    MessageTemplate(
      id: 'thanks_1',
      text: '🙏 Thank you so much!',
      category: 'thanks',
      icon: Icons.thumb_up,
    ),
    MessageTemplate(
      id: 'thanks_2',
      text: '💙 Really appreciate you!',
      category: 'thanks',
      icon: Icons.thumb_up,
    ),
    MessageTemplate(
      id: 'thanks_3',
      text: '✨ You\'re the best!',
      category: 'thanks',
      icon: Icons.thumb_up,
    ),

    // Celebration
    MessageTemplate(
      id: 'celebration_1',
      text: '🎊 Congratulations!',
      category: 'celebration',
      icon: Icons.celebration,
    ),
    MessageTemplate(
      id: 'celebration_2',
      text: '🏆 You did it! So proud of you!',
      category: 'celebration',
      icon: Icons.celebration,
    ),
    MessageTemplate(
      id: 'celebration_3',
      text: '🎉 Let\'s celebrate!',
      category: 'celebration',
      icon: Icons.celebration,
    ),

    // Friendship
    MessageTemplate(
      id: 'friendship_1',
      text: '👋 Hey friend! Thinking of you!',
      category: 'friendship',
      icon: Icons.people,
    ),
    MessageTemplate(
      id: 'friendship_2',
      text: '🤗 Miss you! Hope you\'re doing great!',
      category: 'friendship',
      icon: Icons.people,
    ),
    MessageTemplate(
      id: 'friendship_3',
      text: '💛 You\'re an amazing friend!',
      category: 'friendship',
      icon: Icons.people,
    ),

    // Encouragement
    MessageTemplate(
      id: 'encouragement_1',
      text: '💪 You got this!',
      category: 'encouragement',
      icon: Icons.star,
    ),
    MessageTemplate(
      id: 'encouragement_2',
      text: '⭐ Believe in yourself!',
      category: 'encouragement',
      icon: Icons.star,
    ),
    MessageTemplate(
      id: 'encouragement_3',
      text: '🌟 Keep shining!',
      category: 'encouragement',
      icon: Icons.star,
    ),

    // General
    MessageTemplate(
      id: 'general_1',
      text: '😊 Hope this makes you smile!',
      category: 'general',
      icon: Icons.message,
    ),
    MessageTemplate(
      id: 'general_2',
      text: '💝 A little something for you!',
      category: 'general',
      icon: Icons.message,
    ),
    MessageTemplate(
      id: 'general_3',
      text: '✨ Just wanted to brighten your day!',
      category: 'general',
      icon: Icons.message,
    ),
  ];

  /// Get templates by category
  static List<MessageTemplate> getByCategory(String category) {
    return templates.where((t) => t.category == category).toList();
  }

  /// Get all categories
  static List<String> get categories => [
        'birthday',
        'love',
        'thanks',
        'celebration',
        'friendship',
        'encouragement',
        'general',
      ];

  /// Get category display name
  static String getCategoryName(String category) {
    switch (category) {
      case 'birthday':
        return 'Birthday';
      case 'love':
        return 'Love';
      case 'thanks':
        return 'Thanks';
      case 'celebration':
        return 'Celebration';
      case 'friendship':
        return 'Friendship';
      case 'encouragement':
        return 'Encouragement';
      case 'general':
        return 'General';
      default:
        return category;
    }
  }
}
