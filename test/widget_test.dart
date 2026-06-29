import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_interpreter/app.dart';

void main() {
  testWidgets('shows the Pocket Interpreter home screen', (tester) async {
    await tester.pumpWidget(const PocketInterpreterApp());

    expect(find.text('Pocket Interpreter'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
    expect(find.text('Target'), findsOneWidget);
    expect(find.text('Offline pack ready'), findsOneWidget);
    expect(find.text('Hold to interpret'), findsOneWidget);
  });

  testWidgets('shows release information', (tester) async {
    await tester.pumpWidget(const PocketInterpreterApp());

    await tester.tap(find.byTooltip('About release'));
    await tester.pumpAndSettle();

    expect(find.text('Pocket Interpreter'), findsWidgets);
    expect(find.text('1.0.0+1 MVP'), findsOneWidget);
  });
}
