// Touch controls: a floating joystick on the left and game-pad buttons on the
// right. They only record intent into the engine's InputState (see
// input); the simulation acts on it each tick.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/engine.dart';

const gold = Color(0xffefcb80);
const goldHi = Color(0xffffe7ad);
const mint = Color(0xff8ed9bb);
const teal = Color(0xff7fffe0);

double _clamp(double v, double lo, double hi) => math.max(lo, math.min(hi, v));

/// Lays out the joystick and the button cluster in the bottom area of the screen.
class TouchControls extends StatelessWidget {
  const TouchControls({super.key, required this.engine, required this.onJoystick});
  final SkyrootEngine engine;
  final ValueChanged<Offset?> onJoystick;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final q = math.min(mq.size.width, mq.size.height);
    final bottom = math.max(mq.padding.bottom, 12.0);
    final clusterSize = _clamp(q * 0.48, 184, 224);
    final zoneH = math.min(mq.size.height * 0.56, 300.0);
    return Stack(
      children: [
        Positioned(
          left: mq.padding.left,
          bottom: bottom,
          width: (mq.size.width - mq.padding.left - mq.padding.right) / 2,
          height: zoneH,
          child: JoystickZone(diameter: _clamp(q * 0.30, 112, 144), inset: Offset(_clamp(q * 0.04, 14, 26), _clamp(q * 0.03, 8, 20)), onChanged: onJoystick),
        ),
        Positioned(
          right: mq.padding.right + _clamp(q * 0.03, 10, 22),
          bottom: bottom + _clamp(q * 0.02, 6, 16),
          width: clusterSize,
          height: clusterSize,
          child: ActionCluster(engine: engine, size: clusterSize),
        ),
      ],
    );
  }
}

class JoystickZone extends StatefulWidget {
  const JoystickZone({super.key, required this.diameter, required this.inset, required this.onChanged});
  final double diameter;
  final Offset inset;
  final ValueChanged<Offset?> onChanged;

  @override
  State<JoystickZone> createState() => _JoystickZoneState();
}

class _JoystickZoneState extends State<JoystickZone> {
  int? _id;
  Offset? _center; // base centre in zone coordinates while a finger is down
  Offset _knob = Offset.zero;

  double get _r => widget.diameter * 0.42;

  void _move(Offset local) {
    final c = _center;
    if (c == null) return;
    var v = local - c;
    final d = v.distance;
    if (d > _r) v = v / d * _r;
    setState(() => _knob = v);
    widget.onChanged(Offset(v.dx / _r, v.dy / _r));
  }

  void _end(PointerEvent e) {
    if (e.pointer != _id) return;
    _id = null;
    setState(() {
      _center = null;
      _knob = Offset.zero;
    });
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final d = widget.diameter;
          final half = d / 2;
          final active = _center != null;
          final center = _center ?? Offset(widget.inset.dx + half, box.maxHeight - widget.inset.dy - half);
          return Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) {
              if (_id != null) return;
              _id = e.pointer;
              final p = e.localPosition;
              _center = Offset(_clamp(p.dx, half, box.maxWidth - half), _clamp(p.dy, half, box.maxHeight - half));
              _move(p);
            },
            onPointerMove: (e) {
              if (e.pointer == _id) _move(e.localPosition);
            },
            onPointerUp: _end,
            onPointerCancel: _end,
            child: SizedBox.expand(
              child: CustomPaint(painter: _JoyPainter(center: center, diameter: d, knob: _knob, active: active)),
            ),
          );
        },
      );
}

class _JoyPainter extends CustomPainter {
  _JoyPainter({required this.center, required this.diameter, required this.knob, required this.active});
  final Offset center;
  final double diameter;
  final Offset knob;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final r = diameter / 2;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(colors: const [Color(0x26081612), Color(0x8C081612)], stops: const [0.3, 0.7])
            .createShader(Rect.fromCircle(center: center, radius: r)),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = active ? const Color(0xBFFFE7AD) : const Color(0x61EFCB80),
    );
    canvas.drawCircle(
      center,
      r * 0.82,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0x478ED9BB),
    );
    final k = center + knob;
    final kr = diameter * 0.22;
    canvas.drawCircle(k + const Offset(0, 4), kr, Paint()..color = const Color(0x80000000));
    canvas.drawCircle(
      k,
      kr,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFFF6DC), Color(0xFFE2BB6D), Color(0xFF8A5C1D)],
          stops: [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: k, radius: kr)),
    );
    canvas.drawCircle(
      k,
      kr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xD9FFF6DC),
    );
  }

  @override
  bool shouldRepaint(_JoyPainter old) => old.center != center || old.knob != knob || old.active != active || old.diameter != diameter;
}

/// Bow, jump, dash, arrow-swap and skill buttons laid out like the original cluster.
class ActionCluster extends StatelessWidget {
  const ActionCluster({super.key, required this.engine, required this.size});
  final SkyrootEngine engine;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = engine.state;
    final p = engine.progress;
    final input = engine.input;
    final footingArrow = s.arrowType == 'footing' && p.footing;
    final skin = s.tune.skin;

    Widget at({double? right, double? bottom, required double width, required Widget child}) =>
        Positioned(right: right == null ? null : right * size, bottom: bottom == null ? null : bottom * size, width: width * size, height: width * size, child: child);

    return Stack(
      children: [
        if (skin.skill != null)
          at(
            right: 0.40,
            bottom: 0.76,
            width: 0.26,
            child: ActButton(
              colors: const [Color(0xFF6B4A9C), Color(0xFF26163F)],
              rim: s.skillCd <= 0 ? gold : const Color(0x73FFD36A),
              glow: const Color(0x8CFFD36A),
              cooldown: math.max(0, s.skillCd / 10),
              onDown: (_) => input.skillPressed = true,
              child: Icon(Icons.auto_awesome, color: s.skillCd <= 0 ? goldHi : const Color(0xA6FFE6A0)),
            ),
          ),
        if (p.footing)
          at(
            right: 0.46,
            bottom: 0.42,
            width: 0.24,
            child: ActButton(
              colors: footingArrow ? const [Color(0xFF2AA58A), Color(0xFF0C463A)] : const [Color(0xFF4B5D57), Color(0xFF18241F)],
              rim: footingArrow ? teal : const Color(0x99E1EEE2),
              glow: const Color(0x997FFFE0),
              onDown: (_) => input.switchPressed = true,
              child: Icon(footingArrow ? Icons.eco : Icons.north_east),
            ),
          ),
        if (p.dash)
          at(
            right: 0.46,
            bottom: 0.02,
            width: 0.28,
            child: ActButton(
              colors: const [Color(0xFF3F7FB8), Color(0xFF142D4A)],
              rim: const Color(0xFFA9D8FF),
              glow: const Color(0x8C96D2FF),
              onDown: (_) => input.dashPressed = true,
              child: const Icon(Icons.fast_forward_rounded),
            ),
          ),
        at(
          right: 0.03,
          bottom: 0.46,
          width: 0.30,
          child: ActButton(
            colors: const [Color(0xFF3B9A78), Color(0xFF11402F)],
            rim: const Color(0xCC8ED9BB),
            glow: const Color(0x738ED9BB),
            onDown: (_) {
              input.jumpPressed = true;
              input.jumpHeld = true;
            },
            onUp: () => input.jumpHeld = false,
            child: const Icon(Icons.keyboard_double_arrow_up_rounded),
          ),
        ),
        at(
          right: 0,
          bottom: 0,
          width: 0.38,
          child: _BowButton(engine: engine, footing: footingArrow, held: s.player.aiming),
        ),
      ],
    );
  }
}

class ActButton extends StatefulWidget {
  const ActButton({
    super.key,
    required this.colors,
    required this.rim,
    required this.glow,
    required this.child,
    this.onDown,
    this.onUp,
    this.onMove,
    this.cooldown = 0,
    this.held = false,
  });
  final List<Color> colors;
  final Color rim, glow;
  final Widget child;
  final void Function(Offset global)? onDown;
  final VoidCallback? onUp;
  final void Function(Offset global)? onMove;
  final double cooldown;
  final bool held;

  @override
  State<ActButton> createState() => _ActButtonState();
}

class _ActButtonState extends State<ActButton> {
  int? _id;

  void _release(PointerEvent e) {
    if (e.pointer != _id) return;
    _id = null;
    setState(() {});
    widget.onUp?.call();
  }

  @override
  Widget build(BuildContext context) {
    final down = _id != null || widget.held;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (_id != null) return;
        _id = e.pointer;
        setState(() {});
        widget.onDown?.call(e.position);
      },
      onPointerMove: (e) {
        if (e.pointer == _id) widget.onMove?.call(e.position);
      },
      onPointerUp: _release,
      onPointerCancel: _release,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: Matrix4.translationValues(0, down ? 3 : 0, 0)..scaleByDouble(down ? 0.95 : 1.0, down ? 0.95 : 1.0, 1.0, 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: widget.rim, width: 2.5),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: widget.colors),
          boxShadow: [
            const BoxShadow(color: Color(0x73000000), offset: Offset(0, 4), blurRadius: 0),
            if (down) BoxShadow(color: widget.glow, blurRadius: 18) else const BoxShadow(color: Color(0x59000000), offset: Offset(0, 8), blurRadius: 16),
          ],
        ),
        child: ClipOval(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Domed highlight, as on the original buttons.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(center: const Alignment(-0.3, -0.5), radius: 0.8, colors: [Colors.white.withValues(alpha: 0.28), Colors.transparent], stops: const [0, 0.55]),
                  ),
                ),
              ),
              if (widget.cooldown > 0)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(heightFactor: widget.cooldown.clamp(0.0, 1.0), widthFactor: 1, child: const ColoredBox(color: Color(0x9E040C0A))),
                ),
              FractionallySizedBox(
                widthFactor: 0.56,
                heightFactor: 0.56,
                child: FittedBox(child: IconTheme(data: const IconThemeData(color: Colors.white, size: 40), child: widget.child)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bow button: a gilded medallion whose bow turns toward the aim, draws its
/// string back with the shot's power and lights a charge ring at full draw.
class _BowButton extends StatefulWidget {
  const _BowButton({required this.engine, required this.footing, required this.held});
  final SkyrootEngine engine;
  final bool footing, held;

  @override
  State<_BowButton> createState() => _BowButtonState();
}

class _BowButtonState extends State<_BowButton> with SingleTickerProviderStateMixin {
  // Drives the idle shimmer and the full-draw pulse.
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  int? _id;
  Offset? _start;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _release(PointerEvent e) {
    if (e.pointer != _id) return;
    _id = null;
    _start = null;
    widget.engine.input
      ..bowHeld = false
      ..bowReleased = true;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final p = engine.state.player;
    final aiming = widget.held || _id != null;
    final fullDraw = 0.55 * engine.state.tune.skin.draw;
    final power = p.aiming ? (p.aimT / fullDraw).clamp(0.0, 1.0) : 0.0;
    // The icon points right; while aiming it swings toward the shot.
    final angle = p.aiming ? math.atan2(p.aimY, p.aimX) : (p.face < 0 ? math.pi : 0.0);
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (_id != null) return;
        _id = e.pointer;
        _start = e.position;
        engine.input
          ..bowDown = true
          ..bowHeld = true
          ..aimSource = 'drag'
          ..dragX = 0
          ..dragY = 0
          ..dragLen = 0;
        setState(() {});
      },
      onPointerMove: (e) {
        final s = _start;
        if (e.pointer != _id || s == null) return;
        engine.input
          ..dragX = e.position.dx - s.dx
          ..dragY = e.position.dy - s.dy
          ..dragLen = (e.position - s).distance;
      },
      onPointerUp: _release,
      onPointerCancel: _release,
      child: AnimatedScale(
        scale: aiming ? 0.94 : 1,
        duration: const Duration(milliseconds: 80),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, _) => CustomPaint(
            size: Size.infinite,
            painter: BowButtonPainter(
              power: power,
              angle: angle,
              aiming: aiming,
              footing: widget.footing,
              phase: _pulse.value,
            ),
          ),
        ),
      ),
    );
  }
}

class BowButtonPainter extends CustomPainter {
  const BowButtonPainter({required this.power, required this.angle, required this.aiming, required this.footing, required this.phase});
  final double power, angle, phase;
  final bool aiming, footing;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final full = power >= 1;
    final pulse = 0.5 + 0.5 * math.sin(phase * math.pi * 2);

    // Theme: gold/amber normally, teal for Footing Arrows.
    final rimHi = footing ? const Color(0xFFB8FFF0) : const Color(0xFFFFF1C4);
    final rimLo = footing ? const Color(0xFF1E7A66) : const Color(0xFF8A5A1A);
    final faceHi = footing ? const Color(0xFF2FB898) : const Color(0xFFE0A548);
    final faceLo = footing ? const Color(0xFF07352C) : const Color(0xFF4A2A0A);
    final glow = footing ? teal : const Color(0xFFFFD27A);

    // Drop shadow and outer glow (stronger while drawing, pulsing at full draw).
    canvas.drawCircle(
      c + const Offset(0, 5),
      r * 0.94,
      Paint()
        ..color = const Color(0x8C000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    final glowA = aiming ? (full ? 0.55 + 0.35 * pulse : 0.25 + 0.3 * power) : 0.12 + 0.06 * pulse;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = glow.withValues(alpha: glowA)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.28),
    );

    // Metallic rim: a slowly turning sweep gradient.
    final rimRect = Rect.fromCircle(center: c, radius: r * 0.92);
    canvas.drawCircle(
      c,
      r * 0.92,
      Paint()
        ..shader = SweepGradient(
          colors: [rimHi, rimLo, rimHi, rimLo, rimHi],
          stops: const [0, 0.25, 0.5, 0.75, 1],
          transform: GradientRotation(phase * math.pi * 2 * 0.15 - 0.6),
        ).createShader(rimRect),
    );
    // Domed face.
    final faceR = r * 0.80;
    canvas.drawCircle(
      c,
      faceR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.05,
          colors: [faceHi, Color.lerp(faceHi, faceLo, 0.55)!, faceLo],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: c, radius: faceR)),
    );
    // Engraved rune ring.
    final rune = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, r * 0.025)
      ..color = rimHi.withValues(alpha: 0.32);
    canvas.drawCircle(c, faceR * 0.86, rune);
    for (var i = 0; i < 12; i++) {
      final a = i / 12 * math.pi * 2 + phase * 0.2;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * faceR * 0.80, c + dir * faceR * (i.isEven ? 0.92 : 0.88), rune);
    }
    // Glossy highlight.
    canvas.drawOval(
      Rect.fromCenter(center: c + Offset(-faceR * 0.2, -faceR * 0.48), width: faceR * 1.1, height: faceR * 0.55),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: faceR)),
    );

    // Charge ring around the rim.
    if (aiming && power > 0) {
      final arcRect = Rect.fromCircle(center: c, radius: r * 0.98);
      canvas.drawArc(
        arcRect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.09
          ..color = const Color(0x66000000),
      );
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        math.pi * 2 * power,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = r * 0.09
          ..shader = SweepGradient(
            colors: [glow.withValues(alpha: 0.6), full ? Colors.white : glow],
            transform: const GradientRotation(-math.pi / 2),
          ).createShader(arcRect),
      );
      if (full) {
        canvas.drawCircle(
          c,
          r * 0.98,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.05
            ..color = Colors.white.withValues(alpha: 0.35 + 0.4 * pulse)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.06),
        );
      }
    }

    // The bow, rotated toward the aim.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    _drawBow(canvas, faceR * 0.74);
    canvas.restore();
  }

  /// Recurve bow facing right, centred on the origin; [s] is its half height.
  void _drawBow(Canvas canvas, double s) {
    final pull = s * (0.12 + 0.42 * power); // how far the string is drawn back
    final gripX = -s * 0.12;
    final top = Offset(-s * 0.30, -s);
    final bottom = Offset(-s * 0.30, s);
    final nock = Offset(gripX - s * 0.42 - pull, 0);
    final limb = _limb(s, gripX);

    // Soft shadow under the limbs.
    canvas.save();
    canvas.translate(0, s * 0.06);
    canvas.drawPath(
      limb,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x59000000),
    );
    canvas.restore();

    // String.
    final string = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, s * 0.05)
      ..color = const Color(0xFFFFF6DC);
    canvas.drawLine(top, nock, string);
    canvas.drawLine(nock, bottom, string);

    // Limbs: polished wood with a dark grain line.
    canvas.drawPath(
      limb,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.22
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE2A6), Color(0xFFB0712A), Color(0xFFFFE2A6)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: s)),
    );
    canvas.drawPath(
      limb,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.05
        ..color = const Color(0xCC5A3410),
    );
    // Leather grip wrap.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(gripX + s * 0.04, 0), width: s * 0.22, height: s * 0.34),
        Radius.circular(s * 0.06),
      ),
      Paint()..color = const Color(0xFF6B3A12),
    );

    // Nocked arrow.
    final tipX = s * 0.95;
    canvas.drawLine(
      nock,
      Offset(tipX - s * 0.2, 0),
      Paint()
        ..strokeWidth = math.max(2, s * 0.1)
        ..strokeCap = StrokeCap.round
        ..color = Colors.white,
    );
    // Fletching.
    final fletch = Paint()..color = footing ? const Color(0xFF9CFFE4) : const Color(0xFFFF8A5A);
    for (final dir in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(nock.dx + s * 0.04, 0)
          ..lineTo(nock.dx - s * 0.08, dir * s * 0.16)
          ..lineTo(nock.dx + s * 0.22, dir * s * 0.04)
          ..close(),
        fletch,
      );
    }
    // Head: a leaf for Footing Arrows, a steel point otherwise, glowing as power builds.
    final headGlow = footing ? teal : const Color(0xFFFFE08A);
    canvas.drawCircle(
      Offset(tipX - s * 0.1, 0),
      s * (0.16 + 0.18 * power),
      Paint()
        ..color = headGlow.withValues(alpha: 0.25 + 0.5 * power)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.15),
    );
    final head = Path();
    if (footing) {
      head
        ..moveTo(tipX - s * 0.32, 0)
        ..quadraticBezierTo(tipX - s * 0.12, -s * 0.2, tipX, 0)
        ..quadraticBezierTo(tipX - s * 0.12, s * 0.2, tipX - s * 0.32, 0);
    } else {
      head
        ..moveTo(tipX, 0)
        ..lineTo(tipX - s * 0.28, -s * 0.15)
        ..lineTo(tipX - s * 0.2, 0)
        ..lineTo(tipX - s * 0.28, s * 0.15)
        ..close();
    }
    canvas.drawPath(head, Paint()..color = footing ? const Color(0xFF7CF5C8) : const Color(0xFFF2F6FF));
    canvas.drawPath(
      head,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, s * 0.035)
        ..color = const Color(0xAA1A1A1A),
    );
  }

  Path _limb(double s, double gripX) => Path()
    ..moveTo(-s * 0.30, -s)
    ..cubicTo(s * 0.05, -s * 0.95, s * 0.15, -s * 0.55, gripX + s * 0.06, -s * 0.12)
    ..lineTo(gripX + s * 0.06, s * 0.12)
    ..cubicTo(s * 0.15, s * 0.55, s * 0.05, s * 0.95, -s * 0.30, s);

  @override
  bool shouldRepaint(BowButtonPainter old) =>
      old.power != power || old.angle != angle || old.aiming != aiming || old.footing != footing || old.phase != phase;
}
