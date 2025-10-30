// lib/widgets/network_status_banner.dart
// ⭐ PHASE 5: RELIABILITY - Network Awareness Indicator

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/connectivity_bloc.dart';
import 'package:freegram/theme/design_tokens.dart';

class NetworkStatusBanner extends StatelessWidget {
  const NetworkStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityBloc, ConnectivityState>(
      builder: (context, state) {
        // Bug #40 fix: Handle all connectivity states explicitly
        if (state is Online || state is ConnectivityInitial) {
          return const SizedBox.shrink();
        }

        if (state is! Offline) {
          return const SizedBox.shrink();
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceMD,
            vertical: DesignTokens.spaceSM,
          ),
          decoration: BoxDecoration(
            color: Colors.red.shade700,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.cloud_off,
                color: Colors.white,
                size: 18,
              ),
              SizedBox(width: DesignTokens.spaceSM),
              const Expanded(
                child: Text(
                  'You\'re offline. Actions will sync when you reconnect.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
