import 'package:flutter_test/flutter_test.dart';
import 'package:skyroot/engine/content.dart';
import 'package:skyroot/render/art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every sprite sheet, backdrop and skin loads from the Flutter bundle', (tester) async {
    await tester.runAsync(() async {
      final art = ArtLibrary();
      await art.loadCore();
      for (var i = 0; i < areas.length; i++) {
        await art.ensureArea(i);
      }
      for (var i = 0; i < skins.length; i++) {
        await art.ensureSkin(i);
      }
      expect(art.atlas, isNotNull);
      // Every frame must sit inside its sheet, or the renderer would sample outside the image.
      for (final entry in art.sheets.entries) {
        final img = entry.value.img;
        for (final f in entry.value.frames.values) {
          final c = f.content;
          expect(c.x >= 0 && c.y >= 0 && c.x + c.w <= img.width + 1 && c.y + c.h <= img.height + 1, isTrue,
              reason: '${entry.key}/${f.name}');
        }
      }
      for (final a in areas) {
        expect(art.singles[a.bg], isNotNull, reason: a.bg);
      }
      for (final s in skins) {
        for (final sheet in s.sheets) {
          expect(art.sheets[sheet], isNotNull, reason: sheet);
        }
      }
      art.dispose();
    });
  });
}
