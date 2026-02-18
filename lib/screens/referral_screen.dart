import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/referral_service.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:share_plus/share_plus.dart';

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/repositories/achievement_repository.dart';
import 'package:freegram/widgets/common/confetti_overlay.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final _referralService = locator<ReferralService>();
  final _achievementRepo = locator<AchievementRepository>();
  final _codeController = TextEditingController();
  bool _isGenerating = false;
  bool _isApplying = false;
  StreamSubscription<QuerySnapshot>? _commissionSubscription;

  @override
  void initState() {
    super.initState();
    _setupCommissionListener();
  }

  void _setupCommissionListener() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _commissionSubscription = _referralService
        .getReferralCommissionStream(currentUser.uid)
        .listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          // New commission received!
          final data = change.doc.data() as Map<String, dynamic>;
          final amount = data['amount'] ?? 0;

          // Unlock "Ambassador" badge
          // Check if this is the first one or just verify progress
          final unlocked = await _achievementRepo.updateProgress(
            currentUser.uid,
            'referral_first_sale',
            1,
          );

          if (unlocked && mounted) {
            // Show celebration!
            showDialog(
              context: context,
              builder: (context) => ConfettiOverlay(
                child: AlertDialog(
                  backgroundColor: Theme.of(context).cardColor,
                  title: const Text('🎉 Ambassador Badge Unlocked!'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars, size: 60, color: Colors.amber),
                      const SizedBox(height: 16),
                      Text(
                        'Your friend made their first purchase!\nYou earned $amount coins and the Ambassador Badge!',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Awesome!'),
                    ),
                  ],
                ),
              ),
            );
          } else if (mounted) {
            // Just a snackbar for commission if not a new badge
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('💰 You earned $amount coins commission!'),
                backgroundColor: Colors.amber,
              ),
            );
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _commissionSubscription?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to access referrals")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Referrals"),
      ),
      body: FutureBuilder<ReferralStats>(
        future: _referralService.getReferralStats(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: AppProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text("Failed to load referral data"),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text("Retry"),
                  ),
                ],
              ),
            );
          }

          final stats = snapshot.data;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatsCard(stats),
                const SizedBox(height: 24),
                if (stats?.referralCode != null) ...[
                  _buildReferralCodeCard(stats!.referralCode!),
                  const SizedBox(height: 24),
                ] else ...[
                  _buildGenerateCodeButton(currentUser.uid),
                  const SizedBox(height: 24),
                ],
                _buildApplyCodeSection(),
                const SizedBox(height: 24),
                _buildReferralsList(currentUser.uid),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsCard(ReferralStats? stats) {
    return Container(
      decoration: Containers.glassCard(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Your Referral Stats",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatColumn(
                  icon: Icons.people,
                  label: "Total Referrals",
                  value: "${stats?.totalReferrals ?? 0}",
                  color: Colors.blue,
                ),
                _StatColumn(
                  icon: Icons.check_circle,
                  label: "Successful",
                  value: "${stats?.successfulReferrals ?? 0}",
                  color: Colors.green,
                ),
                _StatColumn(
                  icon: Icons.monetization_on,
                  label: "Coins Earned",
                  value: "${stats?.coinsEarned ?? 0}",
                  color: Colors.amber,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralCodeCard(String code) {
    return Container(
      decoration: Containers.glassCard(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Your Referral Code",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00BFA5),
                  width: 1.0,
                ),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _copyCode(code),
                    icon: const Icon(Icons.copy),
                    label: const Text("Copy Code"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _shareCode(code),
                    icon: const Icon(Icons.share),
                    label: const Text("Share"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Earn ${ReferralService.referrerReward} coins for each friend who joins!",
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateCodeButton(String userId) {
    return ElevatedButton.icon(
      onPressed: _isGenerating ? null : () => _generateCode(userId),
      icon: _isGenerating
          ? const SizedBox(
              width: 20,
              height: 20,
              child: AppProgressIndicator(
                size: 20,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.add),
      label: Text(_isGenerating ? "Generating..." : "Generate Referral Code"),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildApplyCodeSection() {
    return Container(
      decoration: Containers.glassCard(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Have a Referral Code?",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                hintText: "Enter code",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isApplying ? null : _applyCode,
                child: _isApplying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: AppProgressIndicator(
                          size: 20,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text("Apply Code"),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Get ${ReferralService.refereeReward} coins when you use a friend's code!",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralsList(String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Your Referrals",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<ReferralRecord>>(
          stream: _referralService.getReferrals(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: AppProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Container(
                decoration: Containers.glassCard(context),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      "No referrals yet. Share your code to get started!",
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: snapshot.data!.map((record) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: Containers.glassCard(context),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: const Text("User joined"),
                    subtitle: Text(_formatDate(record.timestamp)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on,
                            size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          "+${record.referrerReward}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _generateCode(String userId) async {
    setState(() => _isGenerating = true);
    try {
      await _referralService.generateReferralCode(userId);
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Referral code generated!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  Future<void> _applyCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isApplying = true);
    try {
      await _referralService.applyReferralCode(currentUser.uid, code);
      setState(() => _isApplying = false);
      _codeController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Success! You received ${ReferralService.refereeReward} coins!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isApplying = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Code copied to clipboard!")),
    );
  }

  void _shareCode(String code) {
    Share.share(
      "Join Freegram using my referral code: $code and get ${ReferralService.refereeReward} coins!",
      subject: "Join Freegram",
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) return "${diff.inDays}d ago";
    if (diff.inHours > 0) return "${diff.inHours}h ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
    return "Just now";
  }
}

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatColumn({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
