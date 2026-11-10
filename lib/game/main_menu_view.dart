import 'package:flutter/material.dart';
import 'skin_preview.dart';

const _gold = Color(0xffefcb80);
const _goldHi = Color(0xffffe7ad);
const _goldDeep = Color(0xffc8903a);
const _mint = Color(0xff8ed9bb);
const _ink = Color(0xff06140f);
const _panel = Color(0xd9102822);
const _edge = Color(0x55efcb80);
const _muted = Color(0xffa9c2b6);

/// Menu art comes from the existing world backdrops and portrait atlas.
class MainMenuView extends StatelessWidget {
  const MainMenuView({
    super.key,
    required this.areas,
    required this.skinNames,
    required this.themes,
    required this.stage,
    required this.skin,
    required this.progress,
    required this.hasSave,
    required this.onArea,
    required this.onSkin,
    required this.onPlay,
    required this.onReset,
    required this.lightMode,
    required this.onLightMode,
    required this.unlocked,
    required this.rich,
    required this.onUnlockAll,
  });
  final int unlocked;
  final bool rich;
  final VoidCallback onUnlockAll;
  final List<String> areas, skinNames;
  final List<(String, String)> themes;
  final int stage, skin, progress;
  final bool hasSave;
  final bool lightMode;
  final ValueChanged<bool> onLightMode;
  final ValueChanged<int> onArea, onSkin;
  final VoidCallback onPlay, onReset;

  void _help(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: const Color(0xff10261f),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      side: BorderSide(color: _edge),
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cara bermain',
              style: TextStyle(
                fontSize: 25,
                color: _gold,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            for (final item in [
              (
                Icons.open_with_rounded,
                'Bergerak & memanjat',
                'Dekati sulur hijau, lalu tahan joystick kiri ke atas. Jika ujung sulur menggantung, lompat sambil menahan joystick ke atas. Geser ke bawah untuk turun.',
              ),
              (
                Icons.north_rounded,
                'Lompat & lepas sulur',
                'Tahan tombol lompat (hijau) untuk lompatan tinggi. Saat memanjat, lompat sambil mengarah ke kiri atau kanan untuk pindah ke platform.',
              ),
              (
                Icons.near_me_outlined,
                'Bidik & tembak',
                'Tahan tombol busur (emas), geser untuk membidik, lalu lepas. Dash dan panah pijakan tersedia setelah relik didapat atau saat memilih wilayah lanjutan.',
              ),
              (
                Icons.pause_rounded,
                'Jeda',
                'Tombol jeda di kanan atas atau tombol Kembali ponsel membuka menu jeda: lanjut, checkpoint, suara, dan menu utama.',
              ),
            ])
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0x66061410),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x2aefcb80)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _IconBubble(item.$1),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$2,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: _goldHi,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.$3,
                            style: const TextStyle(color: _muted, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff12291f),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: _edge),
        ),
        icon: const Icon(Icons.warning_amber_rounded, color: _gold, size: 36),
        title: const Text('Reset progres?', style: TextStyle(color: _goldHi)),
        content: const Text(
          'Checkpoint, rahasia, dan boss yang sudah dikalahkan akan dihapus. Tindakan ini tidak bisa dibatalkan.',
          style: TextStyle(color: _muted, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: _mint),
            child: const Text('BATAL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffc9553f),
              foregroundColor: Colors.white,
            ),
            child: const Text('YA, RESET'),
          ),
        ],
      ),
    );
    if (ok == true) onReset();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _ink,
    body: Stack(
      fit: StackFit.expand,
      children: [
        // Full-bleed backdrop of the selected world, fading under the menu.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          child: Image.asset(
            themes[stage].$2,
            key: ValueKey(stage),
            gaplessPlayback: true,
            fit: BoxFit.cover,
            cacheWidth: 720,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xb306140f), Color(0xe606140f), _ink],
              stops: [0, .45, .8],
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(context),
                    const SizedBox(height: 18),
                    _hero(),
                    const SizedBox(height: 18),
                    _PlayButton(
                      label: hasSave
                          ? 'LANJUTKAN PETUALANGAN'
                          : 'MULAI PETUALANGAN',
                      onPressed: onPlay,
                    ),
                    const SizedBox(height: 10),
                    _richButton(),
                    const SizedBox(height: 14),
                    _progressCard(),
                    const SizedBox(height: 26),
                    const _SectionTitle(
                      'Jelajahi dunia',
                      '11 wilayah',
                      Icons.public_rounded,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 136,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        itemCount: areas.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) => _ChoiceCard(
                          title: areas[index],
                          tag: (index + 1).toString().padLeft(2, '0'),
                          selected: stage == index,
                          locked: index > unlocked,
                          onTap: () => onArea(index),
                          child: Image.asset(
                            themes[index].$2,
                            fit: BoxFit.cover,
                            cacheWidth: 360,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle(
                      'Pilih pemanah',
                      '11 skin',
                      Icons.shield_moon_outlined,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 136,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        itemCount: skinNames.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) => _ChoiceCard(
                          title: skinNames[index],
                          selected: skin == index,
                          locked: !rich && index > unlocked,
                          onTap: () => onSkin(index),
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment(0, -.2),
                                radius: .8,
                                colors: [Color(0xff2c5546), Color(0xff11271f)],
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 30),
                              child: SkinPreview(index: index),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    _settingsCard(context),
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _confirmReset(context),
                        icon: const Icon(Icons.restart_alt_rounded, size: 16),
                        label: const Text(
                          'RESET PROGRESS',
                          style: TextStyle(fontSize: 11, letterSpacing: 1.2),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xffd98a78),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _header(BuildContext context) => Row(
    children: [
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x55efcb80), blurRadius: 18),
          ],
        ),
        child: Image.asset(
          'assets/images/logo.png',
          width: 60,
          height: 60,
          cacheWidth: 180,
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                colors: [_goldHi, _gold, _goldDeep],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ).createShader(rect),
              child: const Text(
                'SKYROOT',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: Colors.white,
                  height: 1.05,
                ),
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'THE LAST ARCHER',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 3,
                color: _mint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      _RoundIconButton(
        icon: Icons.help_outline_rounded,
        tooltip: 'Cara bermain',
        onTap: () => _help(context),
      ),
    ],
  );

  Widget _hero() => Container(
    height: 268,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: _edge, width: 1.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x99000000),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: Image.asset(
              themes[stage].$2,
              key: ValueKey(stage),
              gaplessPlayback: true,
              fit: BoxFit.cover,
              cacheWidth: 1080,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00071b15),
                  Color(0x33071b15),
                  Color(0xf0071b15),
                ],
                stops: [0, .45, 1],
              ),
            ),
          ),
          // Soft glow behind the portrait.
          const Positioned(
            right: -30,
            bottom: -40,
            width: 230,
            height: 230,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x66efcb80), Color(0x00efcb80)],
                ),
              ),
            ),
          ),
          Positioned(
            right: -4,
            bottom: 0,
            width: 158,
            height: 186,
            child: RepaintBoundary(child: SkinPreview(index: skin)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Badge(
                  'WILAYAH ${(stage + 1).toString().padLeft(2, '0')} / 11',
                ),
                const Spacer(),
                FractionallySizedBox(
                  widthFactor: .66,
                  child: Text(
                    areas[stage],
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 1.06,
                      color: _goldHi,
                      shadows: [
                        Shadow(blurRadius: 14, color: Colors.black),
                        Shadow(offset: Offset(0, 2), color: Colors.black54),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xb3081b16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x558ed9bb)),
                  ),
                  child: Text(
                    'Pemanah · ${skinNames[skin]}',
                    style: const TextStyle(
                      color: _mint,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _progressCard() => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x2aefcb80)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            const Icon(Icons.eco_rounded, size: 18, color: _mint),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                rich ? 'Semua wilayah & skin terbuka' : 'Terbuka ${unlocked + 1}/11 wilayah & skin',
                style: TextStyle(color: _mint, fontSize: 12),
              ),
            ),
            Text(
              'Progres $progress%',
              style: const TextStyle(
                color: _goldHi,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress / 100,
            minHeight: 6,
            backgroundColor: const Color(0xff203b30),
            color: _gold,
          ),
        ),
      ],
    ),
  );

  Widget _richButton() => Material(
    color: _panel,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: rich ? null : onUnlockAll,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _edge, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.monetization_on_rounded, color: _goldHi, size: 24),
            const SizedBox(width: 8),
            Text(
              rich ? '999+' : '0',
              style: const TextStyle(color: _goldHi, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                rich ? 'Koin tak terbatas · semua terbuka' : 'DAPATKAN 999+ KOIN & BUKA SEMUA',
                style: TextStyle(
                  color: rich ? _mint : _gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
            ),
            Icon(rich ? Icons.all_inclusive_rounded : Icons.lock_open_rounded, color: _mint, size: 20),
          ],
        ),
      ),
    ),
  );

  // A Material (not a decorated Container) so the ListTiles can paint ink on it.
  Widget _settingsCard(BuildContext context) => Material(
    color: _panel,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0x2aefcb80)),
    ),
    child: Column(
      children: [
        ListTile(
          onTap: () => _help(context),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          leading: const _IconBubble(Icons.sports_esports_outlined),
          title: const Text(
            'Cara memanjat & kontrol lainnya',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: _mint),
        ),
        const Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: Color(0x22efcb80),
        ),
        SwitchListTile.adaptive(
          value: lightMode,
          onChanged: onLightMode,
          activeThumbColor: _gold,
          secondary: const _IconBubble(Icons.bolt_rounded),
          title: const Text(
            'Mode ringan',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            lightMode
                ? 'Hemat baterai & lancar di HP lama'
                : 'Ketajaman gambar penuh',
            style: const TextStyle(fontSize: 11, color: _muted),
          ),
        ),
      ],
    ),
  );
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Container(
    height: 62,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_goldHi, _gold, _goldDeep],
        stops: [0, .45, 1],
      ),
      border: Border.all(color: const Color(0xfffff3d1), width: 1.5),
      boxShadow: const [
        BoxShadow(color: Color(0x66efcb80), blurRadius: 22, spreadRadius: -2),
        BoxShadow(color: Color(0xff6b4512), offset: Offset(0, 4)),
      ],
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        splashColor: const Color(0x33ffffff),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xff1d2f20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: _goldHi,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xff1d2a16),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: .8,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: _panel,
      shape: const CircleBorder(side: BorderSide(color: _edge, width: 1.5)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, color: _gold, size: 24),
        ),
      ),
    ),
  );
}

class _IconBubble extends StatelessWidget {
  const _IconBubble(this.icon);
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xff1b3a2f),
      border: Border.all(color: const Color(0x448ed9bb)),
    ),
    child: Icon(icon, color: _mint, size: 20),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xcc081b16),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _edge),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: _gold,
        fontSize: 10,
        letterSpacing: 1.6,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.count, this.icon);
  final String title, count;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 4,
        height: 20,
        decoration: BoxDecoration(
          color: _gold,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Icon(icon, size: 20, color: _gold),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Color(0xfff1f4ea),
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x331b3a2f),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x338ed9bb)),
        ),
        child: Text(
          '$count  →',
          style: const TextStyle(fontSize: 11, color: _mint),
        ),
      ),
    ],
  );
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.selected,
    required this.onTap,
    required this.child,
    this.tag,
    this.locked = false,
  });
  final bool locked;
  final String title;
  final String? tag;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 118,
        margin: EdgeInsets.symmetric(vertical: selected ? 0 : 5),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xff19372b),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _gold : const Color(0xff2b4a3b),
            width: selected ? 2.2 : 1,
          ),
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x66efcb80), blurRadius: 16)]
              : const [BoxShadow(color: Color(0x66000000), blurRadius: 8)],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(child: child),
            if (locked)
              const ColoredBox(
                color: Color(0xb3061410),
                child: Center(child: Icon(Icons.lock_rounded, color: _gold, size: 30)),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: selected
                        ? const [Color(0xe63a2e10), Color(0xf2241c08)]
                        : const [Color(0xcc081b16), Color(0xf2081b16)],
                  ),
                ),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? _goldHi : const Color(0xffdeeadc),
                  ),
                ),
              ),
            ),
            if (tag != null)
              Positioned(
                top: 7,
                left: 7,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xcc081b16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag!,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: _mint,
                      letterSpacing: .8,
                    ),
                  ),
                ),
              ),
            if (selected)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.check_circle, color: _gold, size: 20),
              ),
          ],
        ),
      ),
    ),
  );
}
