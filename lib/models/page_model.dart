// lib/models/page_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

enum PageType {
  business,
  community,
  creator,
}

enum VerificationStatus {
  unverified,
  pending,
  verified,
}

class PageModel extends Equatable {
  final String pageId;
  final String pageName;
  final String pageHandle; // @handle format
  final String ownerId;
  final List<String> admins; // User IDs who can manage the page
  final List<String> moderators; // User IDs who can moderate
  final int followerCount;
  final int postCount;
  final VerificationStatus verificationStatus;
  final PageType pageType;
  final String category;
  final String description;
  final String profileImageUrl;
  final String? coverImageUrl;
  final String? website;
  final String? contactEmail;
  final String? contactPhone;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  PageModel({
    required this.pageId,
    required this.pageName,
    required this.pageHandle,
    required this.ownerId,
    this.admins = const [],
    this.moderators = const [],
    this.followerCount = 0,
    this.postCount = 0,
    this.verificationStatus = VerificationStatus.unverified,
    required this.pageType,
    this.category = '',
    this.description = '',
    this.profileImageUrl = '',
    this.coverImageUrl,
    this.website,
    this.contactEmail,
    this.contactPhone,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory PageModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PageModel.fromMap(doc.id, data);
  }

  factory PageModel.fromMap(String pageId, Map<String, dynamic> data) {
    return PageModel(
      pageId: pageId,
      pageName: data['pageName'] ?? '',
      pageHandle: data['pageHandle'] ?? '',
      ownerId: data['ownerId'] ?? '',
      admins: List<String>.from(data['admins'] ?? []),
      moderators: List<String>.from(data['moderators'] ?? []),
      followerCount: data['followerCount'] ?? 0,
      postCount: data['postCount'] ?? 0,
      verificationStatus: _stringToVerificationStatus(
        data['verificationStatus'] ?? 'unverified',
      ),
      pageType: _stringToPageType(data['pageType'] ?? 'community'),
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      coverImageUrl: data['coverImageUrl'],
      website: data['website'],
      contactEmail: data['contactEmail'],
      contactPhone: data['contactPhone'],
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pageId': pageId,
      'pageName': pageName,
      'pageHandle': pageHandle,
      'ownerId': ownerId,
      'admins': admins,
      'moderators': moderators,
      'followerCount': followerCount,
      'postCount': postCount,
      'verificationStatus': verificationStatus.toString().split('.').last,
      'pageType': pageType.toString().split('.').last,
      'category': category,
      'description': description,
      'profileImageUrl': profileImageUrl,
      'coverImageUrl': coverImageUrl,
      'website': website,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  PageModel copyWith({
    String? pageId,
    String? pageName,
    String? pageHandle,
    String? ownerId,
    List<String>? admins,
    List<String>? moderators,
    int? followerCount,
    int? postCount,
    VerificationStatus? verificationStatus,
    PageType? pageType,
    String? category,
    String? description,
    String? profileImageUrl,
    String? coverImageUrl,
    String? website,
    String? contactEmail,
    String? contactPhone,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return PageModel(
      pageId: pageId ?? this.pageId,
      pageName: pageName ?? this.pageName,
      pageHandle: pageHandle ?? this.pageHandle,
      ownerId: ownerId ?? this.ownerId,
      admins: admins ?? this.admins,
      moderators: moderators ?? this.moderators,
      followerCount: followerCount ?? this.followerCount,
      postCount: postCount ?? this.postCount,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      pageType: pageType ?? this.pageType,
      category: category ?? this.category,
      description: description ?? this.description,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      website: website ?? this.website,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  static DateTime _toDateTime(dynamic timestamp) {
    if (timestamp == null) {
      debugPrint('PageModel: Null timestamp, using now as fallback');
      return DateTime.now();
    }

    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is String) {
      return DateTime.tryParse(timestamp) ?? DateTime.now();
    }
    if (timestamp is int) {
      if (timestamp > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else {
        return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      }
    }
    if (timestamp is Map && timestamp.containsKey('_seconds')) {
      return Timestamp(timestamp['_seconds'], timestamp['_nanoseconds'] ?? 0)
          .toDate();
    }
    debugPrint(
        'PageModel WARNING: Unhandled timestamp type: ${timestamp.runtimeType}');
    return DateTime.now();
  }

  static VerificationStatus _stringToVerificationStatus(String statusStr) {
    switch (statusStr.toLowerCase()) {
      case 'verified':
        return VerificationStatus.verified;
      case 'pending':
        return VerificationStatus.pending;
      case 'unverified':
      default:
        return VerificationStatus.unverified;
    }
  }

  static PageType _stringToPageType(String typeStr) {
    switch (typeStr.toLowerCase()) {
      case 'business':
        return PageType.business;
      case 'creator':
        return PageType.creator;
      case 'community':
      default:
        return PageType.community;
    }
  }

  /// Check if a user has admin permissions (owner or admin)
  bool isAdmin(String userId) {
    return ownerId == userId || admins.contains(userId);
  }

  /// Check if a user has moderator permissions
  bool isModerator(String userId) {
    return isAdmin(userId) || moderators.contains(userId);
  }

  @override
  List<Object?> get props => [
        pageId,
        pageName,
        pageHandle,
        ownerId,
        admins,
        moderators,
        followerCount,
        postCount,
        verificationStatus,
        pageType,
        category,
        description,
        profileImageUrl,
        coverImageUrl,
        website,
        contactEmail,
        contactPhone,
        createdAt,
        updatedAt,
        isActive,
      ];
}

