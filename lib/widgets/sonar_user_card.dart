import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freegram/widgets/core/user_avatar.dart';
import 'package:freegram/theme/app_theme.dart'; // For SonarPulseTheme
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/models/user_model.dart' as server_user_model;

class SonarUserCard extends StatelessWidget {
  final String username;
  final String photoUrl;
  final String statusMessage;
  final String genderValue;
  final bool isNew;
  final bool isRecentlyActive;
  final bool isProfileSynced;
  final int rssi;
  final server_user_model.UserModel? userModel;
  final String? badgeUrl;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const SonarUserCard({
    super.key,
    required this.username,
    required this.photoUrl,
    required this.statusMessage,
    required this.genderValue,
    required this.isNew,
    required this.isRecentlyActive,
    required this.isProfileSynced,
    required this.rssi,
    this.userModel,
    this.badgeUrl,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Glassmorphic Design Implementation
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1.0,
              ),
            ),
            padding: const EdgeInsets.all(DesignTokens.spaceMD),
            child: Row(
              children: [
                // Avatar with 3D Depth Shadow (blurRadius: 12)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: UserAvatar(
                    url: photoUrl,
                    badgeUrl: badgeUrl,
                    size: AvatarSize.medium,
                    // Use transparent background to mix with shadow correctly
                    backgroundColor: Colors.transparent,
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceMD),
                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white, // High contrast
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (statusMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            statusMessage,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: DesignTokens.fontSizeXS,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      // Indicators (New, Syncing)
                      if (isNew || !isProfileSynced)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              if (isNew)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6.0),
                                  child: _buildBadge(
                                    context,
                                    "NEW",
                                    SonarPulseTheme.primaryAccent,
                                  ),
                                ),
                              if (!isProfileSynced)
                                _buildBadge(
                                  context,
                                  "SYNCING",
                                  Colors.orangeAccent,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Delete Action
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: DesignTokens.iconSM,
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    onDelete();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class SonarShimmerUserCard extends StatefulWidget {
  const SonarShimmerUserCard({super.key});

  @override
  State<SonarShimmerUserCard> createState() => _SonarShimmerUserCardState();
}

class _SonarShimmerUserCardState extends State<SonarShimmerUserCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _opacityAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            // Circular placeholder
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            const SizedBox(width: DesignTokens.spaceMD),
            // Text placeholders
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 60,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
