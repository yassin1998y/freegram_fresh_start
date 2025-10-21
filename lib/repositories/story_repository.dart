import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/models/story_model.dart';
import 'package:freegram/models/user_model.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class StoryRepository {
  final FirebaseFirestore _db;

  StoryRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Uploads story media to Cloudinary and returns the URL.
  Future<String?> _uploadToCloudinary(XFile mediaFile, MediaType type) async {
    final resourceType = type == MediaType.image ? 'image' : 'video';
    final url = Uri.parse('https://api.cloudinary.com/v1_1/dq0mb16fk/$resourceType/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = 'Prototype';

    final bytes = await mediaFile.readAsBytes();
    final multipartFile = http.MultipartFile.fromBytes('file', bytes, filename: mediaFile.name);
    request.files.add(multipartFile);

    final response = await request.send();
    if (response.statusCode == 200) {
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);
      final jsonMap = jsonDecode(responseString);
      return jsonMap['secure_url'];
    }
    return null;
  }

  /// Creates a new story document in Firestore after uploading the media.
  Future<void> createStory({required XFile mediaFile, required MediaType mediaType}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final mediaUrl = await _uploadToCloudinary(mediaFile, mediaType);
    if (mediaUrl == null) {
      throw Exception('Failed to upload story media.');
    }

    final newStory = Story(
      id: '', // Firestore will generate this
      userId: currentUser.uid,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      timestamp: DateTime.now(),
      viewers: [],
    );

    await _db.collection('stories').add(newStory.toMap());
  }

  /// Fetches a list of friends who have posted a story in the last 24 hours.
  Future<List<UserModel>> getFriendsWithActiveStories(List<String> friendIds) async {
    if (friendIds.isEmpty) return [];

    final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
    final List<String> userIdsWithStories = [];

    // Firestore 'in' queries are limited to 30 items.
    // For larger friend lists, this should be broken into chunks.
    final querySnapshot = await _db
        .collection('stories')
        .where('userId', whereIn: friendIds.take(30).toList())
        .where('timestamp', isGreaterThan: twentyFourHoursAgo)
        .orderBy('timestamp', descending: true)
        .get();

    for (var doc in querySnapshot.docs) {
      final story = Story.fromDoc(doc);
      if (!userIdsWithStories.contains(story.userId)) {
        userIdsWithStories.add(story.userId);
      }
    }

    if (userIdsWithStories.isEmpty) return [];

    // Fetch the full UserModel for each user with an active story
    final usersSnapshot = await _db.collection('users').where(FieldPath.documentId, whereIn: userIdsWithStories).get();
    return usersSnapshot.docs.map((doc) => UserModel.fromDoc(doc)).toList();
  }

  /// Fetches all active stories for a single user.
  Future<List<Story>> getUserStories(String userId) async {
    final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
    final querySnapshot = await _db
        .collection('stories')
        .where('userId', isEqualTo: userId)
        .where('timestamp', isGreaterThan: twentyFourHoursAgo)
        .orderBy('timestamp', descending: false) // Show oldest first
        .get();

    return querySnapshot.docs.map((doc) => Story.fromDoc(doc)).toList();
  }

  /// Marks a story as viewed by the current user.
  Future<void> markStoryAsViewed(String storyId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await _db.collection('stories').doc(storyId).update({
      'viewers': FieldValue.arrayUnion([currentUser.uid]),
    });
  }
}