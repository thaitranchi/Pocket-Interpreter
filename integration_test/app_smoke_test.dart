import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pocket_interpreter/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'home screen renders and streaming session starts and stops cleanly',
    (tester) async {
      await tester.pumpWidget(const PocketInterpreterApp());
      await tester.pumpAndSettle();

      expect(find.text('Pocket Interpreter'), findsOneWidget);
      expect(find.text('Offline pack ready'), findsOneWidget);
      expect(find.text('Hold to interpret'), findsOneWidget);

      await tester.tap(find.text('Conversation'));
      await tester.pump();

      await tester.tap(find.text('Start continuous interpreting'));
      await tester.pump();

      expect(find.text('Stop continuous interpreting'), findsOneWidget);

      await tester.tap(find.text('Stop continuous interpreting'));
      await tester.pump();

      expect(find.text('Session stopped'), findsOneWidget);
      expect(find.text('Start continuous interpreting'), findsOneWidget);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets(
    'swap languages flips direction and shows status',
    (tester) async {
      await tester.pumpWidget(const PocketInterpreterApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Swap languages'));
      await tester.pump();

      expect(find.textContaining('Vietnamese -> English'), findsWidgets);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}