// lib/repositories/page_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/page_model.dart';
import 'package:freegram/models/post_model.dart';

class PageRepository {
  final FirebaseFirestore _db;

  PageRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Create a new page
  Future<String> createPage({
    required String ownerId,
    required String pageName,
    required String pageHandle,
    required PageType pageType,
    String category = '',
    String description = '',
    String profileImageUrl = '',
    String? coverImageUrl,
    String? website,
    String? contactEmail,
    String? contactPhone,
  }) async {
    try {
      // Validate handle format and uniqueness
      await _validateHandle(pageHandle);

      final pageRef = _db.collection('pages').doc();
      final now = FieldValue.serverTimestamp();

      await pageRef.set({
        'pageId': pageRef.id,
        'pageName': pageName,
        'pageHandle': pageHandle,
        'ownerId': ownerId,
        'admins': [ownerId], // Owner is first admin
        'moderators': [],
        'followerCount': 0,
        'postCount': 0,
        'verificationStatus': 'unverified',
        'pageType': pageType.toString().split('.').last,
        'category': category,
        'description': description,
        'profileImageUrl': profileImageUrl,
        'coverImageUrl': coverImageUrl,
        'website': website,
        'contactEmail': contactEmail,
        'contactPhone': contactPhone,
        'createdAt': now,
        'updatedAt': now,
        'isActive': true,
      });

      // Auto-follow page for creator
      await followPage(pageRef.id, ownerId);

      return pageRef.id;
    } catch (e) {
      debugPrint('PageRepository: Error creating page: $e');
      rethrow;
    }
  }

  /// Validate page handle (format and uniqueness)
  Future<void> _validateHandle(String handle) async {
    // Validate format: alphanumeric, lowercase, underscores/hyphens allowed
    if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(handle)) {
      throw Exception(
          'Handle must contain only lowercase letters, numbers, underscores, or hyphens');
    }

    // Check uniqueness
    final existingPage = await _db
        .collection('pages')
        .where('pageHandle', isEqualTo: handle)
        .limit(1)
        .get();

    if (existingPage.docs.isNotEmpty) {
      throw Exception('This handle is already taken');
    }
  }

  /// Update page information
  Future<void> updatePage({
    required String pageId,
    required String userId,
    String? pageName,
    String? category,
    String? description,
    String? profileImageUrl,
    String? coverImageUrl,
    String? website,
    String? contactEmail,
    String? contactPhone,
  }) async {
    try {
      // Verify user has permission
      final page = await getPage(pageId);
      if (page == null) {
        throw Exception('Page not found');
      }

      if (!page.isAdmin(userId)) {
        throw Exception('User does not have permission to update this page');
      }

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (pageName != null) updateData['pageName'] = pageName;
      if (category != null) updateData['category'] = category;
      if (description != null) updateData['description'] = description;
      if (profileImageUrl != null) {
        updateData['profileImageUrl'] = profileImageUrl;
      }
      if (coverImageUrl != null) updateData['coverImageUrl'] = coverImageUrl;
      if (website != null) updateData['website'] = website;
      if (contactEmail != null) updateData['contactEmail'] = contactEmail;
      if (contactPhone != null) updateData['contactPhone'] = contactPhone;

      await _db.collection('pages').doc(pageId).update(updateData);
    } catch (e) {
      debugPrint('PageRepository: Error updating page: $e');
      rethrow;
    }
  }

  /// Get page by ID
  Future<PageModel?> getPage(String pageId) async {
    try {
      final doc = await _db.collection('pages').doc(pageId).get();
      if (!doc.exists) {
        return null;
      }
      return PageModel.fromDoc(doc);
    } catch (e) {
      debugPrint('PageRepository: Error getting page: $e');
      rethrow;
    }
  }

  /// Get page by handle (@handle)
  Future<PageModel?> getPageByHandle(String handle) async {
    try {
      final snapshot = await _db
          .collection('pages')
          .where('pageHandle', isEqualTo: handle)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return PageModel.fromDoc(snapshot.docs.first);
    } catch (e) {
      debugPrint('PageRepository: Error getting page by handle: $e');
      rethrow;
    }
  }

  /// User follows a page - Atomic batch operation
  /// Updates both the user's 'followedPages' array and the page's 'followerCount'
  /// Also maintains subcollection for backward compatibility
  Future<void> followPage(String pageId, String userId) async {
    try {
      final userRef = _db.collection('users').doc(userId);
      final pageRef = _db.collection('pages').doc(pageId);

      final batch = _db.batch();

      // Add pageId to user's 'followedPages' array
      batch.update(userRef, {
        'followedPages': FieldValue.arrayUnion([pageId])
      });

      // Increment the page's 'followerCount'
      batch.update(pageRef, {
        'followerCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Also maintain subcollection for backward compatibility (optional, but recommended)
      final followerRef = _db
          .collection('pages')
          .doc(pageId)
          .collection('followers')
          .doc(userId);
      batch.set(followerRef, {
        'userId': userId,
        'followedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      debugPrint(
          'PageRepository: User $userId successfully followed page $pageId');
    } catch (e) {
      debugPrint('PageRepository: Error following page: $e');
      rethrow;
    }
  }

  /// User unfollows a page - Atomic batch operation
  /// Updates both the user's 'followedPages' array and the page's 'followerCount'
  /// Also removes from subcollection for consistency
  Future<void> unfollowPage(String pageId, String userId) async {
    try {
      final userRef = _db.collection('users').doc(userId);
      final pageRef = _db.collection('pages').doc(pageId);

      final batch = _db.batch();

      // Remove pageId from user's 'followedPages' array
      batch.update(userRef, {
        'followedPages': FieldValue.arrayRemove([pageId])
      });

      // Decrement the page's 'followerCount'
      batch.update(pageRef, {
        'followerCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Also remove from subcollection for consistency
      final followerRef = _db
          .collection('pages')
          .doc(pageId)
          .collection('followers')
          .doc(userId);
      batch.delete(followerRef);

      await batch.commit();

      debugPrint(
          'PageRepository: User $userId successfully unfollowed page $pageId');
    } catch (e) {
      debugPrint('PageRepository: Error unfollowing page: $e');
      rethrow;
    }
  }

  /// Check if user is following a page
  Future<bool> isFollowingPage(String pageId, String userId) async {
    try {
      final doc = await _db
          .collection('pages')
          .doc(pageId)
          .collection('followers')
          .doc(userId)
          .get();

      return doc.exists;
    } catch (e) {
      debugPrint('PageRepository: Error checking if following page: $e');
      return false;
    }
  }

  /// Get pages owned or managed by a user
  Future<List<PageModel>> getUserPages(String userId) async {
    try {
      // Get pages where user is owner or admin
      final snapshot = await _db
          .collection('pages')
          .where('isActive', isEqualTo: true)
          .where(
            Filter.or(
              Filter('ownerId', isEqualTo: userId),
              Filter('admins', arrayContains: userId),
            ),
          )
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => PageModel.fromDoc(doc)).toList();
    } catch (e) {
      debugPrint('PageRepository: Error getting user pages: $e');
      rethrow;
    }
  }

  /// Get page followers list
  Future<List<String>> getPageFollowers({
    required String pageId,
    DocumentSnapshot? lastDocument,
    int limit = 50,
  }) async {
    try {
      var query = _db
          .collection('pages')
          .doc(pageId)
          .collection('followers')
          .orderBy('followedAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => doc.data()['userId'] as String)
          .toList();
    } catch (e) {
      debugPrint('PageRepository: Error getting page followers: $e');
      rethrow;
    }
  }

  /// Search pages by name or category
  Future<List<PageModel>> searchPages({
    String? query,
    String? category,
    int limit = 20,
  }) async {
    try {
      Query firestoreQuery =
          _db.collection('pages').where('isActive', isEqualTo: true);

      if (category != null && category.isNotEmpty) {
        firestoreQuery = firestoreQuery.where('category', isEqualTo: category);
      }

      if (query != null && query.isNotEmpty) {
        // Firestore doesn't support full-text search natively
        // For now, we'll search by pageName starting with query (case-insensitive would require Cloud Functions)
        firestoreQuery = firestoreQuery
            .where('pageName', isGreaterThanOrEqualTo: query)
            .where('pageName', isLessThan: '$query\uf8ff');
      }

      firestoreQuery = firestoreQuery
          .orderBy('followerCount', descending: true)
          .limit(limit);

      final snapshot = await firestoreQuery.get();
      return snapshot.docs.map((doc) => PageModel.fromDoc(doc)).toList();
    } catch (e) {
      debugPrint('PageRepository: Error searching pages: $e');
      rethrow;
    }
  }

  /// Get page suggestions for a user
  /// Returns popular pages, pages with similar interests, or trending pages
  Future<List<PageModel>> getPageSuggestions(String userId,
      {int limit = 10}) async {
    try {
      debugPrint('PageRepository: Getting page suggestions for $userId');

      // Get user's followed pages to exclude them
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return [];
      }

      final userData = userDoc.data() ?? {};
      final followedPages = List<String>.from(userData['followedPages'] ?? []);
      final userInterests = List<String>.from(userData['interests'] ?? []);

      // Get popular pages (high follower count)
      final popularPagesSnapshot = await _db
          .collection('pages')
          .where('isActive', isEqualTo: true)
          .orderBy('followerCount', descending: true)
          .limit(limit * 2)
          .get();

      final pages = popularPagesSnapshot.docs
          .where((doc) => !followedPages.contains(doc.id))
          .map((doc) => PageModel.fromDoc(doc))
          .toList();

      // If user has interests, prioritize pages with similar categories/interests
      if (userInterests.isNotEmpty && pages.length > limit) {
        pages.sort((a, b) {
          // Prioritize pages with categories matching user interests
          final aMatches = userInterests
              .where((interest) =>
                  a.category.toLowerCase().contains(interest.toLowerCase()))
              .length;
          final bMatches = userInterests
              .where((interest) =>
                  b.category.toLowerCase().contains(interest.toLowerCase()))
              .length;

          if (aMatches != bMatches) {
            return bMatches.compareTo(aMatches);
          }

          // Secondary sort by follower count
          return (b.followerCount).compareTo(a.followerCount);
        });
      }

      return pages.take(limit).toList();
    } catch (e) {
      debugPrint('PageRepository: Error getting page suggestions: $e');
      return [];
    }
  }

  /// Get posts for a specific page
  Future<List<PostModel>> getPagePosts({
    required String pageId,
    DocumentSnapshot? lastDocument,
    int limit = 20,
  }) async {
    try {
      var query = _db
          .collection('posts')
          .where('pageId', isEqualTo: pageId)
          .where('deleted', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => PostModel.fromDoc(doc)).toList();
    } catch (e) {
      debugPrint('PageRepository: Error getting page posts: $e');
      rethrow;
    }
  }

  /// Add admin to page
  Future<void> addAdmin(
      String pageId, String ownerId, String newAdminId) async {
    try {
      final page = await getPage(pageId);
      if (page == null) {
        throw Exception('Page not found');
      }

      if (page.ownerId != ownerId) {
        throw Exception('Only the page owner can add admins');
      }

      if (page.admins.contains(newAdminId)) {
        throw Exception('User is already an admin');
      }

      await _db.collection('pages').doc(pageId).update({
        'admins': FieldValue.arrayUnion([newAdminId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('PageRepository: Error adding admin: $e');
      rethrow;
    }
  }

  /// Remove admin from page
  Future<void> removeAdmin(
      String pageId, String ownerId, String adminId) async {
    try {
      final page = await getPage(pageId);
      if (page == null) {
        throw Exception('Page not found');
      }

      if (page.ownerId != ownerId) {
        throw Exception('Only the page owner can remove admins');
      }

      if (page.ownerId == adminId) {
        throw Exception('Cannot remove the page owner');
      }

      await _db.collection('pages').doc(pageId).update({
        'admins': FieldValue.arrayRemove([adminId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('PageRepository: Error removing admin: $e');
      rethrow;
    }
  }

  /// Add moderator to page
  Future<void> addModerator(
      String pageId, String userId, String newModeratorId) async {
    try {
      final page = await getPage(pageId);
      if (page == null) {
        throw Exception('Page not found');
      }

      if (!page.isAdmin(userId)) {
        throw Exception('User does not have permission to add moderators');
      }

      if (page.moderators.contains(newModeratorId)) {
        throw Exception('User is already a moderator');
      }

      await _db.collection('pages').doc(pageId).update({
        'moderators': FieldValue.arrayUnion([newModeratorId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('PageRepository: Error adding moderator: $e');
      rethrow;
    }
  }

  /// Remove moderator from page
  Future<void> removeModerator(
      String pageId, String userId, String moderatorId) async {
    try {
      final page = await getPage(pageId);
      if (page == null) {
        throw Exception('Page not found');
      }

      if (!page.isAdmin(userId)) {
        throw Exception('User does not have permission to remove moderators');
      }

      await _db.collection('pages').doc(pageId).update({
        'moderators': FieldValue.arrayRemove([moderatorId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('PageRepository: Error removing moderator: $e');
      rethrow;
    }
  }

  /// Get pages followed by a user
  Future<List<PageModel>> getUserFollowedPages(String userId) async {
    try {
      // Get all pages where user is a follower
      final followersSnapshot = await _db
          .collectionGroup('followers')
          .where('userId', isEqualTo: userId)
          .get();

      if (followersSnapshot.docs.isEmpty) {
        return [];
      }

      // Extract page IDs
      final pageIds = followersSnapshot.docs
          .map((doc) => doc.reference.parent.parent!.id)
          .toSet()
          .toList();

      if (pageIds.isEmpty) {
        return [];
      }

      // Batch fetch pages (Firestore has a limit of 10 for 'in' queries)
      final List<PageModel> pages = [];
      for (int i = 0; i < pageIds.length; i += 10) {
        final batch = pageIds.sublist(
          i,
          i + 10 > pageIds.length ? pageIds.length : i + 10,
        );

        final pagesSnapshot = await _db
            .collection('pages')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        pages.addAll(
          pagesSnapshot.docs.map((doc) => PageModel.fromDoc(doc)).toList(),
        );
      }

      return pages;
    } catch (e) {
      debugPrint('PageRepository: Error getting user followed pages: $e');
      rethrow;
    }
  }

  /// Get page feed (posts from followed pages)
  Future<List<PostModel>> getPageFeed({
    required String userId,
    DocumentSnapshot? lastDocument,
    int limit = 20,
  }) async {
    try {
      // Get user's followed pages
      final followedPages = await getUserFollowedPages(userId);
      if (followedPages.isEmpty) {
        return [];
      }

      final pageIds = followedPages.map((page) => page.pageId).toList();

      // Firestore 'in' query limit is 10, so we need to batch
      final List<PostModel> allPosts = [];
      for (int i = 0; i < pageIds.length; i += 10) {
        final batch = pageIds.sublist(
          i,
          i + 10 > pageIds.length ? pageIds.length : i + 10,
        );

        var query = _db
            .collection('posts')
            .where('pageId', whereIn: batch)
            .where('deleted', isEqualTo: false)
            .orderBy('timestamp', descending: true)
            .limit(limit);

        if (lastDocument != null && i == 0) {
          query = query.startAfterDocument(lastDocument);
        }

        final snapshot = await query.get();
        allPosts.addAll(
          snapshot.docs.map((doc) => PostModel.fromDoc(doc)).toList(),
        );
      }

      // Sort by timestamp and return limited results
      allPosts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return allPosts.take(limit).toList();
    } catch (e) {
      debugPrint('PageRepository: Error getting page feed: $e');
      rethrow;
    }
  }

  /// Request verification for a page
  Future<void> requestVerification({
    required String pageId,
    required String userId,
    required String businessDocumentation,
    required String identityProof,
    String? additionalInfo,
  }) async {
    try {
      // Verify user has permission (owner or admin)
      final page = await getPage(pageId);
      if (page == null) {
        throw Exception('Page not found');
      }

      if (!page.isAdmin(userId)) {
        throw Exception('Only page admins can request verification');
      }

      // Check if already verified
      if (page.verificationStatus == VerificationStatus.verified) {
        throw Exception('Page is already verified');
      }

      // Check if request already pending
      final existingRequest = await _db
          .collection('verificationRequests')
          .where('pageId', isEqualTo: pageId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        throw Exception('Verification request already pending');
      }

      // Create verification request
      await _db.collection('verificationRequests').add({
        'pageId': pageId,
        'requestedBy': userId,
        'businessDocumentation': businessDocumentation,
        'identityProof': identityProof,
        'additionalInfo': additionalInfo,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update page status to pending
      await _db.collection('pages').doc(pageId).update({
        'verificationStatus': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('PageRepository: Error requesting verification: $e');
      rethrow;
    }
  }

  /// Get verification request for a page
  Future<Map<String, dynamic>?> getVerificationRequest(String pageId) async {
    try {
      final snapshot = await _db
          .collection('verificationRequests')
          .where('pageId', isEqualTo: pageId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      final data = doc.data();
      return {
        'requestId': doc.id,
        ...data,
      };
    } catch (e) {
      debugPrint('PageRepository: Error getting verification request: $e');
      return null;
    }
  }

  /// Get all verification requests (admin only)
  Future<List<Map<String, dynamic>>> getVerificationRequests({
    String? status,
    int limit = 50,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _db.collection('verificationRequests');

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'requestId': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      debugPrint('PageRepository: Error getting verification requests: $e');
      return [];
    }
  }

  /// Get verification request count by status (for admin dashboard)
  Future<Map<String, int>> getVerificationRequestCounts() async {
    try {
      final pendingSnapshot = await _db
          .collection('verificationRequests')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      final approvedSnapshot = await _db
          .collection('verificationRequests')
          .where('status', isEqualTo: 'approved')
          .count()
          .get();

      final rejectedSnapshot = await _db
          .collection('verificationRequests')
          .where('status', isEqualTo: 'rejected')
          .count()
          .get();

      return {
        'pending': pendingSnapshot.count ?? 0,
        'approved': approvedSnapshot.count ?? 0,
        'rejected': rejectedSnapshot.count ?? 0,
      };
    } catch (e) {
      debugPrint(
          'PageRepository: Error getting verification request counts: $e');
      return {'pending': 0, 'approved': 0, 'rejected': 0};
    }
  }

  /// Approve verification request (admin only)
  Future<void> approveVerificationRequest({
    required String requestId,
    required String adminUserId,
  }) async {
    try {
      // Get the request
      final requestDoc =
          await _db.collection('verificationRequests').doc(requestId).get();

      if (!requestDoc.exists) {
        throw Exception('Verification request not found');
      }

      final requestData = requestDoc.data() ?? {};
      final pageId = requestData['pageId'] as String?;
      final status = requestData['status'] as String?;

      if (status != 'pending') {
        throw Exception('Request is already $status');
      }

      if (pageId == null) {
        throw Exception('Page ID not found in request');
      }

      // Update verification request status
      await _db.collection('verificationRequests').doc(requestId).update({
        'status': 'approved',
        'approvedBy': adminUserId,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update page verification status
      await _db.collection('pages').doc(pageId).update({
        'verificationStatus': 'verified',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update all posts from this page to include pageIsVerified flag
      await _updatePagePostsVerificationStatus(pageId, true);
    } catch (e) {
      debugPrint('PageRepository: Error approving verification request: $e');
      rethrow;
    }
  }

  /// Reject verification request (admin only)
  Future<void> rejectVerificationRequest({
    required String requestId,
    required String adminUserId,
    String? reason,
  }) async {
    try {
      // Get the request
      final requestDoc =
          await _db.collection('verificationRequests').doc(requestId).get();

      if (!requestDoc.exists) {
        throw Exception('Verification request not found');
      }

      final requestData = requestDoc.data() ?? {};
      final pageId = requestData['pageId'] as String?;
      final status = requestData['status'] as String?;

      if (status != 'pending') {
        throw Exception('Request is already $status');
      }

      if (pageId == null) {
        throw Exception('Page ID not found in request');
      }

      // Update verification request status
      await _db.collection('verificationRequests').doc(requestId).update({
        'status': 'rejected',
        'rejectedBy': adminUserId,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason ?? 'No reason provided',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update page verification status back to unverified
      await _db.collection('pages').doc(pageId).update({
        'verificationStatus': 'unverified',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update all posts from this page to remove pageIsVerified flag
      await _updatePagePostsVerificationStatus(pageId, false);
    } catch (e) {
      debugPrint('PageRepository: Error rejecting verification request: $e');
      rethrow;
    }
  }

  /// Remove verification from a verified page (admin only)
  Future<void> removeVerification({
    required String pageId,
    required String adminUserId,
    String? reason,
  }) async {
    try {
      // Get the page
      final pageDoc = await _db.collection('pages').doc(pageId).get();
      if (!pageDoc.exists) {
        throw Exception('Page not found');
      }

      final pageData = pageDoc.data() ?? {};
      final currentStatus = pageData['verificationStatus'] as String?;

      if (currentStatus != 'verified') {
        throw Exception('Page is not verified');
      }

      // Update page verification status to unverified
      await _db.collection('pages').doc(pageId).update({
        'verificationStatus': 'unverified',
        'verificationRemovedAt': FieldValue.serverTimestamp(),
        'verificationRemovedBy': adminUserId,
        'verificationRemovalReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update all posts from this page to remove pageIsVerified flag
      await _updatePagePostsVerificationStatus(pageId, false);

      // Create a verification request record for audit trail
      await _db.collection('verificationRequests').add({
        'pageId': pageId,
        'requestedBy': pageData['ownerId'],
        'status': 'rejected',
        'rejectedBy': adminUserId,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason ?? 'Verification removed by admin',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('PageRepository: Error removing verification: $e');
      rethrow;
    }
  }

  /// Update pageIsVerified flag for all posts from a page
  Future<void> _updatePagePostsVerificationStatus(
    String pageId,
    bool isVerified,
  ) async {
    try {
      final postsSnapshot = await _db
          .collection('posts')
          .where('pageId', isEqualTo: pageId)
          .limit(500)
          .get();

      if (postsSnapshot.docs.isEmpty) {
        return;
      }

      // Batch update in chunks of 500 (Firestore batch limit)
      final batches = <WriteBatch>[];
      WriteBatch? currentBatch;
      int batchCount = 0;

      for (final doc in postsSnapshot.docs) {
        if (batchCount % 500 == 0) {
          if (currentBatch != null) {
            batches.add(currentBatch);
          }
          currentBatch = _db.batch();
        }

        currentBatch!.update(doc.reference, {
          'pageIsVerified': isVerified,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        batchCount++;
      }

      if (currentBatch != null) {
        batches.add(currentBatch);
      }

      // Commit all batches
      for (final batch in batches) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint(
          'PageRepository: Error updating posts verification status: $e');
      // Don't rethrow - this is a background update
    }
  }
}
