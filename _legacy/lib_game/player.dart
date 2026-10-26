import 'package:flame/components.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;

import 'controls.dart';

/// The player avatar, built from one of the ARCHER_* sprite sheets.
///
/// Mirrors the hero handling in `game js/game/player.js` / `hero.js`; for now
/// it is a movable sprite driven by the arrow keys. Animation slicing follows
/// once the frame sidecars are bundled.
class Player extends SpriteComponent {
  Player({
    required super.sprite,
    required super.size,
    required Vector2 position,
  }) : super(position: position, anchor: Anchor.center);

  final double speed = 240;

  void move(Set<dynamic> held, double dt) {
    final v = Vector2.zero();
    if (held.contains(LogicalKeyboardKey.arrowLeft) ||
        held.contains(GameDirection.left)) {
      v.x -= 1;
    }
    if (held.contains(LogicalKeyboardKey.arrowRight) ||
        held.contains(GameDirection.right)) {
      v.x += 1;
    }
    if (held.contains(LogicalKeyboardKey.arrowUp) ||
        held.contains(GameDirection.up)) {
      v.y -= 1;
    }
    if (held.contains(LogicalKeyboardKey.arrowDown) ||
        held.contains(GameDirection.down)) {
      v.y += 1;
    }
    if (v.length2 > 0) {
      v.normalize();
      position += v * speed * dt;
    }
  }

  void clampTo(Vector2 bounds) {
    final halfW = size.x / 2;
    final halfH = size.y / 2;
    position.x = position.x.clamp(halfW, bounds.x - halfW).toDouble();
    position.y = position.y.clamp(halfH, bounds.y - halfH).toDouble();
  }
}
