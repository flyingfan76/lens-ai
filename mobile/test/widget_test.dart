// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:lens_ai/main.dart';
import 'package:lens_ai/core/state/state_manager.dart';

void main() {
  testWidgets('Lens AI app smoke test', (WidgetTester tester) async {
    // Create a state manager instance for testing
    final stateManager = await StateManager.initialize();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(LensAIApp(stateManager: stateManager));

    // Verify that the splash screen loads
    expect(find.text('Lens AI'), findsOneWidget);
  });
}
