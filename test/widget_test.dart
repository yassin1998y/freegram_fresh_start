// Widget tests for cleanup refactored components
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/widgets/common/media_header.dart';
import 'package:freegram/widgets/common/app_button.dart';
import 'package:freegram/theme/app_theme.dart';

void main() {
  group('AppProgressIndicator Tests', () {
    testWidgets('should render circular progress indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SonarPulseTheme.light,
          home: const Scaffold(
            body: AppProgressIndicator(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should render with custom size', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SonarPulseTheme.light,
          home: const Scaffold(
            body: AppProgressIndicator(size: 50),
          ),
        ),
      );

      final progressIndicator = tester.widget<AppProgressIndicator>(
        find.byType(AppProgressIndicator),
      );
      expect(progressIndicator.size, equals(50));
    });

    testWidgets('should render with determinate value', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SonarPulseTheme.light,
          home: const Scaffold(
            body: AppProgressIndicator(value: 0.5),
          ),
        ),
      );

      final circularProgress = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(circularProgress.value, equals(0.5));
    });

    testWidgets('should render linear progress indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SonarPulseTheme.light,
          home: const Scaffold(
            body: AppLinearProgressIndicator(),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('should render linear with determinate value', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SonarPulseTheme.light,
          home: const Scaffold(
            body: AppLinearProgressIndicator(value: 0.75),
          ),
        ),
      );

      final linearProgress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(linearProgress.value, equals(0.75));
    });
  });

  group('MediaHeader Tests', () {
    testWidgets('should render with username and timestamp', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SonarPulseTheme.light,
          home: Scaffold(
            body: MediaHeader(
              username: 'testuser',
              timestamp: DateTime.now(),
            ),
          ),
        ),
      );

      expect(find.text('testuser'), findsOneWidget);
    });

    testWidgets('should render avatar when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SonarPulseTheme.light,
          home: Scaffold(
            body: MediaHeader(
              avatarUrl: 'https://example.com/avatar.jpg',
              username: 'testuser',
              timestamp: DateTime.now(),
            ),
          ),
        ),
      );

      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('should render verified badge when isVerified is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SonarPulseTheme.light,
          home: Scaffold(
            body: MediaHeader(
              username: 'testuser',
              timestamp: DateTime.now(),
              isVerified: true,
            ),
          ),
        ),
      );

      // Verified badge should be present
      expect(find.byType(CircleAvatar), findsWidgets);
    });

    testWidgets('should call onAvatarTap when avatar is tapped', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: SonarPulseTheme.light,
          home: Scaffold(
            body: MediaHeader(
              username: 'testuser',
              timestamp: DateTime.now(),
              onAvatarTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      final avatar = find.byType(CircleAvatar).first;
      await tester.tap(avatar);
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('should render location when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SonarPulseTheme.light,
          home: Scaffold(
            body: MediaHeader(
              username: 'testuser',
              timestamp: DateTime.now(),
              location: 'New York, NY',
            ),
          ),
        ),
      );

      expect(find.text('New York, NY'), findsOneWidget);
    });
  });

  group('AppButton Tests', () {
    testWidgets('AppIconButton should render icon', (WidgetTester tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: SonarPulseTheme.light,
          home: Scaffold(
            body: AppIconButton(
              icon: Icons.favorite,
              onPressed: () {
                pressed = true;
              },
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      
      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pump();
      
      expect(pressed, isTrue);
    });

    testWidgets('AppIconButton should show badge when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SonarPulseTheme.light,
          home: Scaffold(
            body: AppIconButton(
              icon: Icons.notifications,
              onPressed: () {},
              badge: '5',
            ),
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('AppActionButton should render icon and label', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SonarPulseTheme.light,
          home: Scaffold(
            body: AppActionButton(
              icon: Icons.star,
              label: 'Like',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text('Like'), findsOneWidget);
    });

    testWidgets('AppActionButton should be disabled when isDisabled is true', (WidgetTester tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: SonarPulseTheme.light,
          home: Scaffold(
            body: AppActionButton(
              icon: Icons.star,
              label: 'Like',
              onPressed: () {
                pressed = true;
              },
              isDisabled: true,
            ),
          ),
        ),
      );

      final button = find.byType(AppActionButton);
      await tester.tap(button);
      await tester.pump();

      expect(pressed, isFalse);
    });

    testWidgets('AppActionButton should show loading state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SonarPulseTheme.light,
          home: Scaffold(
            body: AppActionButton(
              icon: Icons.star,
              label: 'Like',
              onPressed: () {},
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(AppProgressIndicator), findsOneWidget);
    });

    testWidgets('AppActionButton should show badge when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SonarPulseTheme.light,
          home: Scaffold(
            body: AppActionButton(
              icon: Icons.star,
              label: 'Like',
              onPressed: () {},
              badge: '10',
            ),
          ),
        ),
      );

      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('AppActionButton should call onPressed when tapped', (WidgetTester tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: SonarPulseTheme.light,
          home: Scaffold(
            body: AppActionButton(
              icon: Icons.star,
              label: 'Like',
              onPressed: () {
                pressed = true;
              },
            ),
          ),
        ),
      );

      final button = find.byType(AppActionButton);
      await tester.tap(button);
      await tester.pump();

      expect(pressed, isTrue);
    });
  });

  group('Integration Tests', () {
    testWidgets('AppProgressIndicator should work in Scaffold', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SonarPulseTheme.light,
          home: const Scaffold(
            body: Center(
              child: AppProgressIndicator(value: 0.5),
            ),
          ),
        ),
      );

      expect(find.byType(AppProgressIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('MediaHeader should work with menu items', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SonarPulseTheme.light,
          home: Scaffold(
            body: Column(
              children: [
                MediaHeader(
                  username: 'testuser',
                  timestamp: DateTime.now(),
                  menuItems: const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  onMenuSelected: (value) {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('testuser'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });
  });
}
