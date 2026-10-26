// HUD and overlay panels: hearts, energy, boss bar, toast, speech bubble, map,
// wardrobe, pause menu, tutorial and ending.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/boss.dart';
import '../engine/content.dart';
import '../engine/engine.dart';
import '../engine/save.dart';
import '../engine/world.dart';
import '../render/art.dart';
import 'controls.dart';

const _heart = Color(0xffff5a52);
const _text = Color(0xfff3f7ec);
const _muted = Color(0xbce1eee2);
const _panelEdge = Color(0x6Aefcb80);
const _panelEdgeSoft = Color(0x2Eefcb80);

double _clamp(double v, double lo, double hi) => math.max(lo, math.min(hi, v));

/// The in-game overlay: status pips, boss bar, toast and speech bubble.
class HudLayer extends StatelessWidget {
  const HudLayer({super.key, required this.engine, required this.onPause, required this.onMap, required this.onWardrobe});
  final SkyrootEngine engine;
  final VoidCallback onPause, onMap, onWardrobe;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final q = math.min(mq.size.width, mq.size.height);
    final g = engine.state;
    final pad = _clamp(q * 0.024, 8, 14);
    final top = mq.padding.top + pad;
    final boss = g.boss;
    final showBoss = boss != null && boss.state != 'sleep' && boss.state != 'gone';
    final bossName = boss is AreaBoss ? bosses[boss.area]!.name : 'Rusa Menara';
    final toast = g.toast;
    final toastVisible = toast != null && toast.t < toast.dur;

    return Stack(
      children: [
        Positioned(
          left: mq.padding.left + pad,
          top: top,
          width: math.min(mq.size.width * 0.46, 230),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PipRow(count: g.maxHp, filled: g.player.hp.ceil(), on: _heart, icon: Icons.favorite),
              if (engine.progress.footing) ...[
                const SizedBox(height: 6),
                PipRow(count: g.maxEnergy, filled: (g.player.energy + 0.001).floor(), on: teal, icon: Icons.diamond),
              ],
            ],
          ),
        ),
        Positioned(
          right: mq.padding.right + pad,
          top: top,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HudIconButton(icon: Icons.checkroom, label: 'Lemari Skin', onTap: onWardrobe),
              const SizedBox(width: 10),
              HudIconButton(icon: Icons.map_outlined, label: 'Peta', onTap: onMap),
              const SizedBox(width: 10),
              HudIconButton(icon: Icons.pause, label: 'Jeda', onTap: onPause),
            ],
          ),
        ),
        if (showBoss)
          Positioned(
            top: mq.padding.top + _clamp(q * 0.16, 68, 88),
            left: 0,
            right: 0,
            child: Center(child: BossBar(name: bossName, fraction: _clamp(boss.hp / boss.maxHp, 0, 1))),
          ),
        if (toastVisible)
          Positioned(
            top: mq.padding.top + (showBoss ? _clamp(q * 0.27, 112, 136) : _clamp(q * 0.17, 68, 96)),
            left: 24,
            right: 24,
            child: Center(
              child: Opacity(
                opacity: math.min(1.0, math.min((toast.dur - toast.t) / 0.4, toast.t / 0.15)).clamp(0.0, 1.0),
                child: _ToastBubble(text: toast.text),
              ),
            ),
          ),
        if (g.speech != null) _SpeechBubble(engine: engine),
      ],
    );
  }
}

class HudIconButton extends StatelessWidget {
  const HudIconButton({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xCC09180F),
              border: Border.all(color: _panelEdge, width: 1.5),
              boxShadow: const [BoxShadow(color: Color(0x73000000), offset: Offset(0, 3), blurRadius: 0)],
            ),
            child: Icon(icon, color: goldHi, size: 24),
          ),
        ),
      );
}

class PipRow extends StatelessWidget {
  const PipRow({super.key, required this.count, required this.filled, required this.on, required this.icon});
  final int count, filled;
  final Color on;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final off = on.withValues(alpha: 0.22);
    Widget pip(bool lit) => Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Icon(icon, size: 24, color: lit ? on : off, shadows: const [Shadow(color: Color(0x8C000000), offset: Offset(0, 1.5))]),
        );
    if (count > 8) {
      // Long rows collapse into one pip and a counter so the HUD never overflows.
      return Row(mainAxisSize: MainAxisSize.min, children: [
        pip(true),
        Text('$filled/$count', style: const TextStyle(color: _text, fontWeight: FontWeight.w800, fontSize: 15, shadows: [Shadow(color: Colors.black54, blurRadius: 2)])),
      ]);
    }
    return Wrap(children: [for (var i = 0; i < count; i++) pip(i < filled)]);
  }
}

class BossBar extends StatelessWidget {
  const BossBar({super.key, required this.name, required this.fraction});
  final String name;
  final double fraction;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: math.min(MediaQuery.of(context).size.width * 0.8, 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name.toUpperCase(),
                style: const TextStyle(color: goldHi, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 12, shadows: [Shadow(color: Colors.black87, blurRadius: 3)])),
            const SizedBox(height: 4),
            Container(
              height: 12,
              decoration: BoxDecoration(color: const Color(0xB3081612), borderRadius: BorderRadius.circular(8), border: Border.all(color: _panelEdge)),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction,
                child: const DecoratedBox(
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFF8A5A), Color(0xFFD83B3B)])),
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      );
}

class _ToastBubble extends StatelessWidget {
  const _ToastBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xDB09180F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _panelEdge),
        ),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 14, height: 1.3)),
      );
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.engine});
  final SkyrootEngine engine;

  @override
  Widget build(BuildContext context) {
    final g = engine.state;
    final sp = g.speech!;
    final box = engine.camBox(g.cam);
    final sc = engine.view.scale * g.cam.zoom;
    final x = (sp.x - box.left) * sc;
    final y = (sp.y - box.top) * sc;
    final w = MediaQuery.of(context).size.width;
    final half = math.min(135.0, w / 2);
    return Positioned(
      left: _clamp(x, half, w - half) - half,
      top: y - 4,
      width: half * 2,
      child: FractionalTranslation(
        translation: const Offset(0, -1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xEBF6EBC8), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF7A5A28), width: 1.5)),
          child: Text(sp.text, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF2A1D0C), fontSize: 13, fontWeight: FontWeight.w600, height: 1.3)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Panels

class PanelShell extends StatelessWidget {
  const PanelShell({super.key, required this.title, required this.child, this.onClose, this.maxWidth = 440});
  final String title;
  final Widget child;
  final VoidCallback? onClose;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      color: const Color(0xD1030907),
      padding: EdgeInsets.fromLTRB(mq.padding.left + 16, mq.padding.top + 16, mq.padding.right + 16, mq.padding.bottom + 16),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _panelEdge, width: 1.5),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1C3A30), Color(0xFF0B1D17)]),
            boxShadow: const [BoxShadow(color: Color(0x8C000000), blurRadius: 40, offset: Offset(0, 18))],
          ),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(color: gold, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: 0.6))),
                  if (onClose != null) HudIconButton(icon: Icons.close, label: 'Tutup', onTap: onClose!),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class GameButton extends StatelessWidget {
  const GameButton({super.key, required this.label, required this.onTap, this.primary = false, this.ghost = false});
  final String label;
  final VoidCallback onTap;
  final bool primary, ghost;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 50),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: ghost ? null : Border.all(color: primary ? goldHi : _panelEdgeSoft, width: 1.5),
            gradient: ghost
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: primary ? const [Color(0xFFFFE0A0), Color(0xFFD9A64B)] : const [Color(0xFF21463A), Color(0xFF11291F)],
                  ),
            boxShadow: ghost ? null : const [BoxShadow(color: Color(0x73000000), offset: Offset(0, 3))],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primary ? const Color(0xFF1D2A16) : (ghost ? _muted : _text),
              fontSize: 15,
              fontWeight: primary ? FontWeight.w800 : FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
      );
}

class PauseMenu extends StatelessWidget {
  const PauseMenu({super.key, required this.muted, required this.onResume, required this.onRespawn, required this.onMap, required this.onSound, required this.onHelp, required this.onHome});
  final bool muted;
  final VoidCallback onResume, onRespawn, onMap, onSound, onHelp, onHome;

  @override
  Widget build(BuildContext context) => PanelShell(
        title: 'Jeda',
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              GameButton(label: 'Lanjutkan', primary: true, onTap: onResume),
              GameButton(label: 'Kembali ke checkpoint', onTap: onRespawn),
              GameButton(label: 'Peta', onTap: onMap),
              GameButton(label: muted ? 'Suara: Mati' : 'Suara: Aktif', onTap: onSound),
              GameButton(label: 'Cara bermain', onTap: onHelp),
              GameButton(label: 'Menu utama', ghost: true, onTap: onHome),
            ],
          ),
        ),
      );
}

class TutorialCard extends StatelessWidget {
  const TutorialCard({super.key, required this.onPlay});
  final VoidCallback onPlay;

  static const _tips = [
    ('Bergerak', 'Geser joystick kiri untuk bergerak dan memanjat.'),
    ('Lompat', 'Tombol hijau ↑. Tahan untuk lompatan tinggi.'),
    ('Busur', 'Tombol emas. Tahan, geser untuk membidik, lalu lepas.'),
    ('Sulur', 'Dekati bagian bawahnya lalu tahan joystick ke atas. Lompat sambil mengarah ke samping untuk pindah ke platform.'),
    ('Jelajah', 'Semua 11 wilayah dan 11 skin terbuka lewat peta dan lemari di kanan atas. Dash dan panah pijakan ada di relik Akar Berkabut.'),
  ];

  @override
  Widget build(BuildContext context) => PanelShell(
        title: 'Petualangan Skyroot',
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              for (final (title, body) in _tips)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0x8C081611), borderRadius: BorderRadius.circular(12), border: Border.all(color: _panelEdgeSoft)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title.toUpperCase(), style: const TextStyle(color: goldHi, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text(body, style: const TextStyle(color: _muted, fontSize: 14, height: 1.4)),
                    ],
                  ),
                ),
              GameButton(label: 'MULAI BERMAIN', primary: true, onTap: onPlay),
            ],
          ),
        ),
      );
}

class EndPanel extends StatelessWidget {
  const EndPanel({super.key, required this.progress, required this.onContinue, required this.onRestart});
  final Progress progress;
  final VoidCallback onContinue, onRestart;

  String _time() {
    final t = progress.time.floor();
    final hh = t ~/ 3600, mm = (t % 3600) ~/ 60;
    return hh > 0 ? '$hh:${mm.toString().padLeft(2, '0')}' : '$mm:${(t % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    Widget stat(String v, String l) => Expanded(
          child: Column(children: [
            Text(v, style: const TextStyle(color: goldHi, fontSize: 20, fontWeight: FontWeight.w800)),
            Text(l, style: const TextStyle(color: _muted, fontSize: 12)),
          ]),
        );
    return PanelShell(
      title: 'Kabut Sirna',
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            const Text('Mahkota Langit kembali bersinar di atas pohon.', textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 14)),
            Row(children: [
              stat(_time(), 'Waktu'),
              stat('${progress.secretsFound}/$totalSecrets', 'Rahasia'),
              stat('${progress.skinsOwned}/11', 'Skin'),
              stat('${progress.deaths}', 'Tumbang'),
            ]),
            GameButton(label: 'Jelajah lagi', primary: true, onTap: onContinue),
            GameButton(label: 'Main dari awal', onTap: onRestart),
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, required this.message, required this.error, required this.onRetry});
  final String message;
  final bool error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: error ? onRetry : null,
        child: Container(
          color: const Color(0xFF07130F),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Skyroot', style: TextStyle(color: gold, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 18),
              SizedBox(
                width: 200,
                child: error
                    ? const SizedBox.shrink()
                    : ClipRRect(borderRadius: BorderRadius.circular(6), child: const LinearProgressIndicator(minHeight: 6, color: gold, backgroundColor: Color(0xFF14332B))),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 14)),
              ),
            ],
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Map

const _mapColor = <int, Color>{
  Tile.bark: Color(0xFF7A5232), Tile.soft: Color(0xFFC9A06A), Tile.moss: Color(0xFF6F9A3C), Tile.oneway: Color(0xFFB5D05E),
  Tile.vine: Color(0xFF4FA372), Tile.wind: Color(0xFF4A9C96), Tile.spike: Color(0xFFD0503E), Tile.sap: Color(0xFFD9A441),
  Tile.crystal: Color(0xFF8F7AD8), Tile.ice: Color(0xFF9FD8F0), Tile.ember: Color(0xFFE0743A),
};

class MapPanel extends StatefulWidget {
  const MapPanel({super.key, required this.engine, required this.onClose, required this.onReset});
  final SkyrootEngine engine;
  final VoidCallback onClose, onReset;

  @override
  State<MapPanel> createState() => _MapPanelState();
}

class _MapPanelState extends State<MapPanel> {
  bool _armed = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.engine.state;
    final p = widget.engine.progress;
    return PanelShell(
      title: areas[g.areaIndex].name,
      onClose: widget.onClose,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: areas.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final on = i == g.areaIndex;
                  return GestureDetector(
                    onTap: () => widget.engine.travelTo(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: on ? const Color(0xFFD9A64B) : const Color(0xB3102A22),
                        border: Border.all(color: on ? goldHi : _panelEdgeSoft),
                      ),
                      child: Text('${(i + 1).toString().padLeft(2, '0')}  ${areas[i].name}',
                          style: TextStyle(color: on ? const Color(0xFF1D2A16) : _text, fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  );
                },
              ),
            ),
            AspectRatio(
              aspectRatio: 0.72,
              child: ClipRRect(borderRadius: BorderRadius.circular(12), child: CustomPaint(painter: _MapPainter(widget.engine))),
            ),
            Wrap(spacing: 14, runSpacing: 4, alignment: WrapAlignment.center, children: const [
              _Legend(color: Color(0xFFFFF6DC), label: 'Kamu'),
              _Legend(color: Color(0xFF7FFFE0), label: 'Checkpoint'),
              _Legend(color: Color(0xFF4B5A58), label: 'Gerbang'),
              _Legend(color: Color(0xFFFFD36A), label: 'Lonceng'),
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              Text.rich(TextSpan(text: 'Rahasia ', children: [TextSpan(text: '${p.secretsFound}/$totalSecrets', style: const TextStyle(fontWeight: FontWeight.w800, color: goldHi))]), style: const TextStyle(color: _muted)),
              Text.rich(TextSpan(text: 'Skin ', children: [TextSpan(text: '${p.skinsOwned}/11', style: const TextStyle(fontWeight: FontWeight.w800, color: goldHi))]), style: const TextStyle(color: _muted)),
            ]),
            GameButton(
              label: _armed ? 'Yakin? Ketuk lagi' : 'Mulai dari awal',
              onTap: () {
                if (!_armed) {
                  setState(() => _armed = true);
                } else {
                  widget.onReset();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
      ]);
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.engine);
  final SkyrootEngine engine;

  @override
  void paint(Canvas canvas, Size size) {
    final g = engine.state;
    final world = engine.world;
    final cols = world.cols, rows = world.rows;
    final ex = g.areaProg.explored;
    // Fit the whole world in the frame, square tiles, centred.
    final cell = math.min(size.width / cols, size.height / rows);
    final ox = (size.width - cell * cols) / 2;
    final oy = (size.height - cell * rows) / 2;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF14332B), Color(0xFF07140F)]).createShader(Offset.zero & size),
    );
    final bw = (cols / exploreBlock).ceil();
    final bh = (rows / exploreBlock).ceil();
    final block = exploreBlock * cell;
    bool seenBlock(int bx, int by) {
      final i = by * bw + bx;
      return i < ex.length && ex[i] == '1';
    }

    // Unexplored blocks are veiled in fog, so the explored shape reads at a glance.
    final fog = Paint()..color = const Color(0x0FBEF0DC);
    for (var by = 0; by < bh; by++) {
      for (var bx = 0; bx < bw; bx++) {
        if (seenBlock(bx, by)) continue;
        canvas.drawRect(
          Rect.fromLTWH(ox + bx * block, oy + by * block, math.min(block, ox + cols * cell - (ox + bx * block)), math.min(block, oy + rows * cell - (oy + by * block))),
          fog,
        );
      }
    }
    final gap = cell >= 5 ? 1.0 : 0.0;
    final paint = Paint();
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        if (!seenBlock(x ~/ exploreBlock, y ~/ exploreBlock)) continue;
        final t = world.tileAt(x, y);
        paint.color = _mapColor[t] ?? (t == Tile.empty ? const Color(0x1296E6C8) : const Color(0xFF2E5A50));
        canvas.drawRect(Rect.fromLTWH(ox + x * cell, oy + y * cell, cell - gap, cell - gap), paint);
      }
    }

    bool seen(int x, int y) => seenBlock(x ~/ exploreBlock, y ~/ exploreBlock);
    void dot(double x, double y, Color col, double r, Color? ring) {
      final c = Offset(ox + (x + 0.5) * cell, oy + (y + 0.5) * cell);
      canvas.drawCircle(c, r, Paint()..color = col);
      if (ring != null) {
        canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = ring);
      }
    }

    // Markers only show inside explored blocks, so unexplored parts stay a surprise.
    for (final k in g.checkpoints) {
      if (!seen(k.x, k.y)) continue;
      final current = g.areaProg.cp == k.id;
      dot(k.x.toDouble(), k.y.toDouble(), current ? const Color(0xFF7FFFE0) : const Color(0xFF3C8F80), math.max(3, cell * 0.7), current ? const Color(0xFFEAFFF6) : null);
    }
    final gate = g.gate;
    if (gate != null && seen(gate.x, gate.y)) {
      dot(gate.x.toDouble(), gate.y.toDouble(), gate.active ? const Color(0xFF7FFFE0) : const Color(0xFF4B5A58), math.max(3.5, cell * 0.8), const Color(0xFF0B1714));
    }
    final bell = g.bell;
    if (bell != null && seen(bell.x, bell.y)) {
      dot(bell.x.toDouble(), bell.y.toDouble(), const Color(0xFFFFD36A), math.max(3.5, cell * 0.9), const Color(0xFF7A4F12));
    }
    // The archer: a soft halo, then a bright marker with a dark rim.
    final px = ox + (g.player.x + 0.5) * cell;
    final py = oy + (g.player.y - 0.2) * cell;
    canvas.drawCircle(Offset(px, py), math.max(7, cell * 1.8), Paint()..color = const Color(0x47FFE7AD));
    dot(g.player.x, g.player.y - 0.7, const Color(0xFFFFF6DC), math.max(4, cell * 0.95), const Color(0xFF0B1714));
  }

  @override
  bool shouldRepaint(_MapPainter old) => true;
}

// ---------------------------------------------------------------------------
// Wardrobe

class WardrobePanel extends StatefulWidget {
  const WardrobePanel({super.key, required this.engine, required this.art, required this.onClose});
  final SkyrootEngine engine;
  final ArtLibrary art;
  final VoidCallback onClose;

  @override
  State<WardrobePanel> createState() => _WardrobePanelState();
}

class _WardrobePanelState extends State<WardrobePanel> {
  late int _picked = widget.engine.progress.skin;

  @override
  Widget build(BuildContext context) {
    final p = widget.engine.progress;
    final sk = skins[_picked];
    final owned = p.skinOwned(_picked);
    final how = owned ? (p.skin == _picked ? 'Sedang dipakai' : 'Ketuk lagi untuk memakai') : 'Kalahkan ${bosses[_picked]?.name ?? ''} di ${areas[_picked].name}';
    return PanelShell(
      title: 'Lemari Skin',
      maxWidth: 520,
      onClose: widget.onClose,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.82,
              children: [
                for (var i = 0; i < skins.length; i++)
                  GestureDetector(
                    onTap: () {
                      if (_picked == i && p.skinOwned(i)) {
                        widget.engine.equipSkin(i);
                        widget.onClose();
                        return;
                      }
                      setState(() => _picked = i);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0x99081611),
                        border: Border.all(color: p.skin == i ? gold : (_picked == i ? mint : _panelEdgeSoft), width: p.skin == i || _picked == i ? 2 : 1),
                      ),
                      child: Opacity(
                        opacity: p.skinOwned(i) ? 1 : 0.4,
                        child: Column(children: [
                          Expanded(child: CustomPaint(size: Size.infinite, painter: _SkinIconPainter(widget.art, 'skin_$i'))),
                          Text(skins[i].name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.1)),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0x8C081611), borderRadius: BorderRadius.circular(12), border: Border.all(color: _panelEdgeSoft)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 3, children: [
                Text('$_picked. ${sk.name}', style: const TextStyle(color: goldHi, fontWeight: FontWeight.w800, fontSize: 15)),
                Text('${sk.perk}${_picked > 1 ? ' + semua buff sebelumnya' : ''}', style: const TextStyle(color: _muted, fontSize: 13, height: 1.35)),
                Text(how, style: const TextStyle(color: mint, fontSize: 12.5, fontStyle: FontStyle.italic)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkinIconPainter extends CustomPainter {
  _SkinIconPainter(this.art, this.frame);
  final ArtLibrary art;
  final String frame;

  @override
  void paint(Canvas canvas, Size size) {
    final sheet = art.sheets['SKIN_ICONS'];
    final f = sheet?.frames[frame];
    if (sheet == null || f == null) return;
    final c = f.content;
    final k = math.min(size.width / c.w, size.height / c.h);
    canvas.drawImageRect(
      sheet.img,
      Rect.fromLTWH(c.x, c.y, c.w, c.h),
      Rect.fromLTWH((size.width - c.w * k) / 2, (size.height - c.h * k) / 2, c.w * k, c.h * k),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_SkinIconPainter old) => false;
}
