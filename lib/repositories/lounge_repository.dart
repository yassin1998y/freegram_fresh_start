import 'package:freegram/models/lounge_user.dart';

class LoungeRepository {
  Future<List<LoungeUser>> getLiveUsers() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    return [
      const LoungeUser(
          id: '1',
          name: 'Sophie',
          imageUrl: 'https://randomuser.me/api/portraits/women/44.jpg',
          flagEmoji: '🇫🇷',
          age: 23),
      const LoungeUser(
          id: '2',
          name: 'Maria',
          imageUrl: 'https://randomuser.me/api/portraits/women/68.jpg',
          flagEmoji: '🇪🇸',
          age: 25),
      const LoungeUser(
          id: '3',
          name: 'Yuki',
          imageUrl: 'https://randomuser.me/api/portraits/women/90.jpg',
          flagEmoji: '🇯🇵',
          age: 20),
      const LoungeUser(
          id: '4',
          name: 'Elena',
          imageUrl: 'https://randomuser.me/api/portraits/women/22.jpg',
          flagEmoji: '🇷🇺',
          age: 22),
      const LoungeUser(
          id: '5',
          name: 'Jasmine',
          imageUrl: 'https://randomuser.me/api/portraits/women/33.jpg',
          flagEmoji: '🇹🇷',
          age: 24),
      const LoungeUser(
          id: '6',
          name: 'Anna',
          imageUrl: 'https://randomuser.me/api/portraits/women/12.jpg',
          flagEmoji: '🇩🇪',
          age: 21),
      const LoungeUser(
          id: '7',
          name: 'Isabella',
          imageUrl: 'https://randomuser.me/api/portraits/women/55.jpg',
          flagEmoji: '🇮🇹',
          age: 26),
      const LoungeUser(
          id: '8',
          name: 'Minji',
          imageUrl: 'https://randomuser.me/api/portraits/women/76.jpg',
          flagEmoji: '🇰🇷',
          age: 22),
      const LoungeUser(
          id: '9',
          name: 'Camila',
          imageUrl: 'https://randomuser.me/api/portraits/women/88.jpg',
          flagEmoji: '🇧🇷',
          age: 23),
      const LoungeUser(
          id: '10',
          name: 'Sarah',
          imageUrl: 'https://randomuser.me/api/portraits/women/29.jpg',
          flagEmoji: '🇺🇸',
          age: 25),
    ];
  }
}
