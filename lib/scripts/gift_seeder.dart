import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class GiftSeeder {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  GiftSeeder({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  /// Generic method to seed any gift with animation and thumbnail
  Future<void> seedGift({
    required String giftId,
    required String animationFileName,
    required String thumbnailFileName,
  }) async {
    try {
      print('Starting $giftId seeding...');

      // 1. Load animation file from assets
      print('Loading animation from assets...');
      final animationBytes =
          await rootBundle.load('assets/seed_data/$animationFileName');
      final animationData = animationBytes.buffer.asUint8List();
      print('Loaded animation bytes: ${animationData.length}');

      // 2. Load thumbnail file from assets
      print('Loading thumbnail from assets...');
      final thumbnailBytes =
          await rootBundle.load('assets/seed_data/$thumbnailFileName');
      final thumbnailData = thumbnailBytes.buffer.asUint8List();
      print('Loaded thumbnail bytes: ${thumbnailData.length}');

      // Determine file extensions
      final animationExt = animationFileName.split('.').last;
      final thumbnailExt = thumbnailFileName.split('.').last;

      // Determine content types
      final animationContentType = _getContentType(animationExt);
      final thumbnailContentType = _getContentType(thumbnailExt);

      // 3. Upload animation to Firebase Storage
      print('Uploading animation to Firebase Storage...');
      final animationRef =
          _storage.ref().child('gifts/animations/$giftId.$animationExt');
      final animationUploadTask = animationRef.putData(
        animationData,
        SettableMetadata(contentType: animationContentType),
      );
      final animationSnapshot = await animationUploadTask;
      final animationUrl = await animationSnapshot.ref.getDownloadURL();
      print('Animation uploaded: $animationUrl');

      // 4. Upload thumbnail to Firebase Storage
      print('Uploading thumbnail to Firebase Storage...');
      final thumbnailRef =
          _storage.ref().child('gifts/thumbnails/$giftId.$thumbnailExt');
      final thumbnailUploadTask = thumbnailRef.putData(
        thumbnailData,
        SettableMetadata(contentType: thumbnailContentType),
      );
      final thumbnailSnapshot = await thumbnailUploadTask;
      final thumbnailUrl = await thumbnailSnapshot.ref.getDownloadURL();
      print('Thumbnail uploaded: $thumbnailUrl');

      // 5. Update Firestore document
      print('Updating Firestore...');
      await _db.collection('gifts').doc(giftId).update({
        'animationUrl': animationUrl,
        'thumbnailUrl': thumbnailUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Firestore updated successfully!');

      print('✅ $giftId seeded successfully!');
    } catch (e, stackTrace) {
      print('❌ Error seeding $giftId: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Helper to determine content type from file extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'gif':
        return 'image/gif';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'json':
        return 'application/json';
      default:
        return 'application/octet-stream';
    }
  }

  /// Convenience method for Red Rose
  Future<void> seedRedRose() async {
    await seedGift(
      giftId: 'love_rose',
      animationFileName: 'red_rose_animation.gif',
      thumbnailFileName: 'red_rose_thumbnail.png',
    );
  }

  /// Convenience method for Heart Balloon
  Future<void> seedHeartBalloon() async {
    await seedGift(
      giftId: 'love_heart_balloon',
      animationFileName: 'heart_balloon.gif',
      thumbnailFileName: 'heart_balloon_thumbnail.png',
    );
  }

  /// Convenience method for Teddy Bear
  Future<void> seedTeddyBear() async {
    await seedGift(
      giftId: 'love_teddy',
      animationFileName: 'teddy_bear.gif',
      thumbnailFileName: 'teddy_bear_thumbnail.png',
    );
  }

  /// Convenience method for Diamond Ring
  Future<void> seedDiamondRing() async {
    await seedGift(
      giftId: 'love_ring',
      animationFileName: 'diamond_ring.gif',
      thumbnailFileName: 'diamond_ring_thumbnail.png',
    );
  }

  /// Convenience method for Party Popper
  Future<void> seedPartyPopper() async {
    await seedGift(
      giftId: 'cel_popper',
      animationFileName: 'party_popper.gif',
      thumbnailFileName: 'party_popper_thumbnail.png',
    );
  }
}
