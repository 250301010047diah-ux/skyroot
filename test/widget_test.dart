import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyroot/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({'progress': 85, 'stage': 8});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          originalProgress,
          (MethodCall call) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(originalProgress, null);
  });

  testWidgets('main menu renders', (tester) async {
    await tester.pumpWidget(const SkyrootApp());
    await tester.pump();
    expect(find.text('SKYROOT'), findsOneWidget);
    expect(find.text('MULAI PETUALANGAN'), findsOneWidget);
    expect(find.text('RESET PROGRESS'), findsOneWidget);
  });

  testWidgets(
    'all original themes and skins are selectable, also after reset',
    (tester) async {
      await tester.pumpWidget(const SkyrootApp());
      await tester.pumpAndSettle();
      expect(find.text('MULAI PETUALANGAN'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      for (var pass = 0; pass < 2; pass++) {
        if (pass == 1) {
          await tester.ensureVisible(find.text('RESET PROGRESS'));
          await tester.tap(find.text('RESET PROGRESS'));
          await tester.pumpAndSettle();
          // Reset asks for confirmation before deleting progress.
          await tester.tap(find.text('YA, RESET'));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.byType(ListView).at(0));
        await tester.dragUntilVisible(
          find.text('Mahkota Bintang'),
          find.byType(ListView).at(0),
          const Offset(-500, 0),
        );
        await tester.tap(find.text('Mahkota Bintang'));
        await tester.pumpAndSettle();
        expect(prefs.getInt('stage'), 10);
        expect(prefs.getString('theme'), 'bg_10.webp');
        await tester.ensureVisible(find.byType(ListView).at(1));
        await tester.dragUntilVisible(
          find.text('Mahkota Akar'),
          find.byType(ListView).at(1),
          const Offset(-500, 0),
        );
        await tester.tap(find.text('Mahkota Akar'));
        await tester.pumpAndSettle();
        expect(prefs.getString('skin'), 'skin10_a-transparent.webp');
        expect(find.byIcon(Icons.lock), findsNothing);
      }
    },
  );
}
