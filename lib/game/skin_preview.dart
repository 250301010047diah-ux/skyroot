import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One named portrait from the atlas, instead of scaling the entire animation sheet.
class SkinPreview extends StatelessWidget {
  const SkinPreview({super.key, required this.index});
  final int index;

  static final _atlas = _load();
  static Future<(ui.Image, List<Rect>)> _load() async {
    final bytes = await rootBundle.load(
      'assets/images/skin_icons-transparent.webp',
    );
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    final data =
        jsonDecode(
              await rootBundle.loadString('assets/game/frames/SKIN_ICONS.json'),
            )
            as Map<String, dynamic>;
    final frames = (data['frames'] as List).map((frame) {
      final c = frame['content'] as Map<String, dynamic>;
      return Rect.fromLTWH(
        (c['x'] as num).toDouble(),
        (c['y'] as num).toDouble(),
        (c['w'] as num).toDouble(),
        (c['h'] as num).toDouble(),
      );
    }).toList();
    return (image, frames);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _atlas,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: Icon(Icons.person_outline));
      }
      final (image, frames) = snapshot.data!;
      return CustomPaint(
        painter: _PortraitPainter(
          image,
          frames[index.clamp(0, frames.length - 1)],
        ),
      );
    },
  );
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.image, this.source);
  final ui.Image image;
  final Rect source;

  @override
  void paint(Canvas canvas, Size size) {
    final fitted = applyBoxFit(BoxFit.contain, source.size, size);
    final target = Alignment.topCenter.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    canvas.drawImageRect(
      image,
      source,
      target,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_PortraitPainter old) =>
      old.image != image || old.source != source;
}
