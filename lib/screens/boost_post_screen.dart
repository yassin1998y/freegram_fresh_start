// lib/screens/boost_post_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/models/boost_package_model.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/widgets/common/keyboard_safe_area.dart';
import 'package:freegram/screens/store_screen.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

class BoostPostScreen extends StatefulWidget {
  final PostModel post;

  const BoostPostScreen({
    Key? key,
    required this.post,
  }) : super(key: key);

  @override
  State<BoostPostScreen> createState() => _BoostPostScreenState();
}

class _BoostPostScreenState extends State<BoostPostScreen> {
  final PostRepository _postRepository = locator<PostRepository>();
  final UserRepository _userRepository = locator<UserRepository>();

  BoostPackageModel? _selectedPackage;
  bool _isProcessing = false;

  // Targeting options
  bool _enableLocationTargeting = false;
  int? _targetRadiusKm = 50; // Default 50km
  bool _enableAgeTargeting = false;
  int? _minAge = 18;
  int? _maxAge = 65;
  bool _enableGenderTargeting = false;
  String _targetGender = 'all'; // 'all', 'male', 'female', 'other'
  bool _enableInterestTargeting = false;
  final List<String> _selectedInterests = [];

  // Available interests (you can expand this)
  final List<String> _availableInterests = [
    'Music',
    'Sports',
    'Travel',
    'Food',
    'Art',
    'Technology',
    'Fashion',
    'Gaming',
    'Photography',
    'Fitness',
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: boost_post_screen.dart');
    _selectedPackage = BoostPackageModel.getDefaultPackages().first;
  }

  Map<String, dynamic> _buildTargetingData() {
    final targeting = <String, dynamic>{};

    if (_enableLocationTargeting && _targetRadiusKm != null) {
      targeting['location'] = {
        'radiusKm': _targetRadiusKm,
      };
    }

    if (_enableAgeTargeting && _minAge != null && _maxAge != null) {
      targeting['ageRange'] = {
        'min': _minAge,
        'max': _maxAge,
      };
    }

    if (_enableGenderTargeting) {
      targeting['gender'] = _targetGender;
    }

    if (_enableInterestTargeting && _selectedInterests.isNotEmpty) {
      targeting['interests'] = _selectedInterests;
    }

    return targeting;
  }

  Future<void> _boostPost() async {
    if (_selectedPackage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a boost package')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to boost posts')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Atomic transaction handles both coin deduction and boost activation
      final targetingData = _buildTargetingData();
      await _postRepository.boostPost(
        postId: widget.post.id,
        userId: currentUser.uid,
        boostPackage: _selectedPackage!,
        targetingData: targetingData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: SemanticColors.success,
            content: Text(
              'Post boosted successfully! It will be promoted for ${_selectedPackage!.duration} day(s).',
            ),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString();
        final isInsufficientCoins = errorMessage.contains('Insufficient coins');
        final snackBarTheme = Theme.of(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: SemanticColors.error,
            content: Text('Error boosting post: ${e.toString()}'),
            action: isInsufficientCoins
                ? SnackBarAction(
                    label: 'Get Coins',
                    textColor: snackBarTheme.colorScheme.onError,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StoreScreen(),
                        ),
                      ).then((_) {
                        // Refresh user data when returning from store
                        setState(() {});
                      });
                    },
                  )
                : null,
            duration: isInsufficientCoins
                ? const Duration(seconds: 5)
                : const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Boost Post',
          style: theme.textTheme.titleLarge,
        ),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      resizeToAvoidBottomInset: true,
      body: _isProcessing
          ? Center(
              child: AppProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            )
          : KeyboardSafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(DesignTokens.spaceMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Coin Balance Display
                    if (currentUser != null)
                      FutureBuilder(
                        future: _userRepository.getUser(currentUser.uid),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox.shrink();
                          }

                          final user = snapshot.data!;
                          return Card(
                            color: theme.colorScheme.primaryContainer
                                .withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(DesignTokens.radiusMD),
                            ),
                            margin: const EdgeInsets.only(
                                bottom: DesignTokens.spaceMD),
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(DesignTokens.spaceMD),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet,
                                    color: theme.colorScheme.primary,
                                    size: DesignTokens.iconLG,
                                  ),
                                  const SizedBox(width: DesignTokens.spaceSM),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Your Balance',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(
                                              DesignTokens.opacityMedium,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${user.coins} Coins',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const StoreScreen(),
                                        ),
                                      ).then((_) {
                                        // Refresh user data when returning from store
                                        setState(() {});
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      size: DesignTokens.iconSM,
                                    ),
                                    label: Text(
                                      'Get Coins',
                                      style: theme.textTheme.labelSmall,
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    // Package Selection
                    _buildSectionTitle(theme, 'Select Boost Package'),
                    const SizedBox(height: DesignTokens.spaceSM),
                    ...BoostPackageModel.getDefaultPackages().map((package) {
                      return _buildPackageCard(theme, package);
                    }),
                    const SizedBox(height: DesignTokens.spaceLG),

                    // Targeting Options
                    _buildSectionTitle(theme, 'Targeting (Optional)'),
                    const SizedBox(height: DesignTokens.spaceSM),

                    // Location Targeting
                    _buildTargetingOption(
                      theme: theme,
                      title: 'Location',
                      enabled: _enableLocationTargeting,
                      onChanged: (value) {
                        setState(() => _enableLocationTargeting = value);
                      },
                      child: _enableLocationTargeting
                          ? Column(
                              children: [
                                const SizedBox(height: DesignTokens.spaceSM),
                                Text(
                                  'Radius: ${_targetRadiusKm}km',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                Slider(
                                  value: _targetRadiusKm?.toDouble() ?? 50.0,
                                  min: 5,
                                  max: 200,
                                  divisions: 39,
                                  label: '${_targetRadiusKm}km',
                                  activeColor: theme.colorScheme.primary,
                                  onChanged: (value) {
                                    setState(
                                        () => _targetRadiusKm = value.toInt());
                                  },
                                ),
                              ],
                            )
                          : null,
                    ),

                    const SizedBox(height: DesignTokens.spaceMD),

                    // Age Targeting
                    _buildTargetingOption(
                      theme: theme,
                      title: 'Age Range',
                      enabled: _enableAgeTargeting,
                      onChanged: (value) {
                        setState(() => _enableAgeTargeting = value);
                      },
                      child: _enableAgeTargeting
                          ? Column(
                              children: [
                                const SizedBox(height: DesignTokens.spaceSM),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        decoration: InputDecoration(
                                          labelText: 'Min Age',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              DesignTokens.radiusMD,
                                            ),
                                          ),
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          _minAge = int.tryParse(value);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: DesignTokens.spaceMD),
                                    Expanded(
                                      child: TextField(
                                        decoration: InputDecoration(
                                          labelText: 'Max Age',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              DesignTokens.radiusMD,
                                            ),
                                          ),
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          _maxAge = int.tryParse(value);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : null,
                    ),

                    const SizedBox(height: DesignTokens.spaceMD),

                    // Gender Targeting
                    _buildTargetingOption(
                      theme: theme,
                      title: 'Gender',
                      enabled: _enableGenderTargeting,
                      onChanged: (value) {
                        setState(() => _enableGenderTargeting = value);
                      },
                      child: _enableGenderTargeting
                          ? Column(
                              children: [
                                const SizedBox(height: DesignTokens.spaceSM),
                                SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(
                                        value: 'all', label: Text('All')),
                                    ButtonSegment(
                                        value: 'male', label: Text('Male')),
                                    ButtonSegment(
                                      value: 'female',
                                      label: Text('Female'),
                                    ),
                                  ],
                                  selected: {_targetGender},
                                  onSelectionChanged: (Set<String> selected) {
                                    setState(() {
                                      _targetGender = selected.first;
                                    });
                                  },
                                ),
                              ],
                            )
                          : null,
                    ),

                    const SizedBox(height: DesignTokens.spaceMD),

                    // Interests Targeting
                    _buildTargetingOption(
                      theme: theme,
                      title: 'Interests',
                      enabled: _enableInterestTargeting,
                      onChanged: (value) {
                        setState(() => _enableInterestTargeting = value);
                      },
                      child: _enableInterestTargeting
                          ? Column(
                              children: [
                                const SizedBox(height: DesignTokens.spaceSM),
                                Wrap(
                                  spacing: DesignTokens.spaceSM,
                                  runSpacing: DesignTokens.spaceSM,
                                  children: _availableInterests.map((interest) {
                                    final isSelected =
                                        _selectedInterests.contains(interest);
                                    return FilterChip(
                                      label: Text(interest),
                                      selected: isSelected,
                                      selectedColor:
                                          theme.colorScheme.primaryContainer,
                                      checkmarkColor: theme.colorScheme.primary,
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            _selectedInterests.add(interest);
                                          } else {
                                            _selectedInterests.remove(interest);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            )
                          : null,
                    ),

                    const SizedBox(height: DesignTokens.spaceXL),

                    // Boost Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _boostPost,
                        style: theme.elevatedButtonTheme.style?.copyWith(
                          backgroundColor: WidgetStateProperty.all(
                            theme.colorScheme.primary,
                          ),
                          foregroundColor: WidgetStateProperty.all(
                            theme.colorScheme.onPrimary,
                          ),
                          padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(
                              vertical: DesignTokens.spaceMD,
                              horizontal: DesignTokens.spaceLG,
                            ),
                          ),
                        ),
                        child: _isProcessing
                            ? SizedBox(
                                width: DesignTokens.iconMD,
                                height: DesignTokens.iconMD,
                                child: AppProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : Text(
                                _selectedPackage != null
                                    ? 'Boost Now (${_selectedPackage!.price} Coins)'
                                    : 'Select Package',
                                style: theme.textTheme.labelLarge,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _buildPackageCard(ThemeData theme, BoostPackageModel package) {
    final isSelected = _selectedPackage?.packageId == package.packageId;

    return Card(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceSM),
      elevation: isSelected ? DesignTokens.elevation2 : DesignTokens.elevation1,
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        side: isSelected
            ? BorderSide(
                color: theme.colorScheme.primary,
                width: DesignTokens.borderWidthThick,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedPackage = package),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spaceMD),
          child: Row(
            children: [
              Radio<BoostPackageModel>(
                value: package,
                groupValue: _selectedPackage,
                onChanged: (value) => setState(() => _selectedPackage = value),
                activeColor: theme.colorScheme.primary,
              ),
              const SizedBox(width: DesignTokens.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceXS),
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: DesignTokens.iconSM,
                          color: theme.colorScheme.onSurface.withOpacity(
                            DesignTokens.opacityMedium,
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spaceXS),
                        Text(
                          '~${_formatNumber(package.targetReach)} estimated reach',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(
                              DesignTokens.opacityMedium,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignTokens.spaceXS),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: DesignTokens.iconSM,
                          color: theme.colorScheme.onSurface.withOpacity(
                            DesignTokens.opacityMedium,
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spaceXS),
                        Text(
                          '${package.duration} ${package.duration == 1 ? 'day' : 'days'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(
                              DesignTokens.opacityMedium,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${package.price}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    'Coins',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(
                        DesignTokens.opacityMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetingOption({
    required ThemeData theme,
    required String title,
    required bool enabled,
    required ValueChanged<bool> onChanged,
    Widget? child,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: onChanged,
                  activeThumbColor: theme.colorScheme.primary,
                ),
              ],
            ),
            if (child != null) child,
          ],
        ),
      ),
    );
  }
}
