import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sudoku_game/main.dart';
import 'package:sudoku_game/screens/game_screen.dart';
import 'package:sudoku_game/screens/home_screen.dart';
import 'package:sudoku_game/screens/settings_screen.dart';
import 'package:sudoku_game/screens/statistics_screen.dart';
import 'package:sudoku_game/screens/world_map_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SudokuApp', () {
    /// ------------------------------------------------------------------------
    /// BASIC APPLICATION STARTUP
    /// ------------------------------------------------------------------------

    testWidgets('renders the application successfully', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const SudokuApp());

      await tester.pump();

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('starts on the home route', (WidgetTester tester) async {
      await tester.pumpWidget(const SudokuApp());

      await tester.pump();

      expect(SudokuApp.navigatorKey.currentState, isNotNull);

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    /// ------------------------------------------------------------------------
    /// STATIC ROUTES
    /// ------------------------------------------------------------------------

    testWidgets('can navigate to settings screen', (WidgetTester tester) async {
      await tester.pumpWidget(const SudokuApp());

      await tester.pump();

      final navigator = SudokuApp.navigatorKey.currentState;

      expect(navigator, isNotNull);

      navigator!.pushNamed(AppRoutes.settings);

      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('can navigate to statistics screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const SudokuApp());

      await tester.pump();

      final navigator = SudokuApp.navigatorKey.currentState;

      expect(navigator, isNotNull);

      navigator!.pushNamed(AppRoutes.statistics);

      await tester.pumpAndSettle();

      expect(find.byType(StatisticsScreen), findsOneWidget);
    });

    testWidgets('can navigate to worlds screen', (WidgetTester tester) async {
      await tester.pumpWidget(const SudokuApp());

      await tester.pump();

      final navigator = SudokuApp.navigatorKey.currentState;

      expect(navigator, isNotNull);

      navigator!.pushNamed(AppRoutes.worlds);

      await tester.pumpAndSettle();

      expect(find.byType(WorldMapScreen), findsOneWidget);
    });

    /// ------------------------------------------------------------------------
    /// LEVEL MAP ROUTE
    /// ------------------------------------------------------------------------

    testWidgets('rejects invalid level map arguments', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const SudokuApp());

      await tester.pump();

      final navigator = SudokuApp.navigatorKey.currentState;

      expect(navigator, isNotNull);

      navigator!.pushNamed(AppRoutes.levels, arguments: 'invalid-world-id');

      await tester.pumpAndSettle();

      expect(find.text('Unable to open this screen'), findsOneWidget);

      expect(find.text('Invalid world navigation arguments.'), findsOneWidget);
    });

    testWidgets('rejects world number below one', (WidgetTester tester) async {
      await tester.pumpWidget(const SudokuApp());

      await tester.pump();

      final navigator = SudokuApp.navigatorKey.currentState;

      expect(navigator, isNotNull);

      navigator!.pushNamed(AppRoutes.levels, arguments: 0);

      await tester.pumpAndSettle();

      expect(find.text('Unable to open this screen'), findsOneWidget);

      expect(find.text('Invalid world number: 0.'), findsOneWidget);
    });

    testWidgets('rejects world number above configured limit', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const SudokuApp());

      await tester.pump();

      final navigator = SudokuApp.navigatorKey.currentState;

      expect(navigator, isNotNull);

      navigator!.pushNamed(
        AppRoutes.levels,
        arguments: GameConfig.totalWorlds + 1,
      );

      await tester.pumpAndSettle();

      expect(find.text('Unable to open this screen'), findsOneWidget);

      expect(
        find.text('Invalid world number: ${GameConfig.totalWorlds + 1}.'),
        findsOneWidget,
      );
    });

    /// ------------------------------------------------------------------------
    /// GAME ROUTE
    /// ------------------------------------------------------------------------

    testWidgets('rejects invalid game navigation arguments', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const SudokuApp());

      await tester.pump();

      final navigator = SudokuApp.navigatorKey.currentState;

      expect(navigator, isNotNull);

      navigator!.pushNamed(AppRoutes.game, arguments: 'invalid-game-arguments');

      await tester.pumpAndSettle();

      expect(find.text('Unable to open this screen'), findsOneWidget);

      expect(
        find.text(
          'Invalid game navigation arguments.\n\n'
          'Expected GameArguments.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('accepts valid GameArguments', (WidgetTester tester) async {
      await tester.pumpWidget(const SudokuApp());

      await tester.pump();

      final navigator = SudokuApp.navigatorKey.currentState;

      expect(navigator, isNotNull);

      navigator!.pushNamed(
        AppRoutes.game,
        arguments: const GameArguments(levelNumber: 1),
      );

      // Do not use pumpAndSettle() here.
      //
      // GameScreen starts a periodic timer after loading the level.
      // pumpAndSettle() can therefore wait indefinitely.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(GameScreen), findsOneWidget);
    });

    testWidgets('rejects game level number below one', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const SudokuApp());

      await tester.pump();

      final navigator = SudokuApp.navigatorKey.currentState;

      expect(navigator, isNotNull);

      navigator!.pushNamed(
        AppRoutes.game,
        arguments: const GameArguments(levelNumber: 0),
      );

      await tester.pumpAndSettle();

      expect(find.text('Unable to open this screen'), findsOneWidget);

      expect(find.text('Invalid level number: 0.'), findsOneWidget);
    });

    testWidgets('rejects game level number above configured limit', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const SudokuApp());

      await tester.pump();

      final navigator = SudokuApp.navigatorKey.currentState;

      expect(navigator, isNotNull);

      final invalidLevel = GameConfig.totalLevels + 1;

      navigator!.pushNamed(
        AppRoutes.game,
        arguments: GameArguments(levelNumber: invalidLevel),
      );

      await tester.pumpAndSettle();

      expect(find.text('Unable to open this screen'), findsOneWidget);

      expect(find.text('Invalid level number: $invalidLevel.'), findsOneWidget);
    });

    /// ------------------------------------------------------------------------
    /// NAVIGATION ERROR RECOVERY
    /// ------------------------------------------------------------------------

    testWidgets('can return home from a navigation error', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const SudokuApp());

      await tester.pump();

      final navigator = SudokuApp.navigatorKey.currentState;

      expect(navigator, isNotNull);

      navigator!.pushNamed(AppRoutes.game, arguments: 'invalid');

      await tester.pumpAndSettle();

      expect(find.text('Unable to open this screen'), findsOneWidget);

      final returnHomeButton = find.widgetWithText(
        ElevatedButton,
        'Return Home',
      );

      expect(returnHomeButton, findsOneWidget);

      await tester.tap(returnHomeButton);

      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    /// ------------------------------------------------------------------------
    /// UNKNOWN ROUTES
    /// ------------------------------------------------------------------------

    testWidgets('handles unknown routes safely', (WidgetTester tester) async {
      await tester.pumpWidget(const SudokuApp());

      await tester.pump();

      final navigator = SudokuApp.navigatorKey.currentState;

      expect(navigator, isNotNull);

      navigator!.pushNamed('/does-not-exist');

      await tester.pumpAndSettle();

      expect(find.text('Unable to open this screen'), findsOneWidget);

      expect(find.text('Unknown route:\n/does-not-exist'), findsOneWidget);
    });
  });
}
