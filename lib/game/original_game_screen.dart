import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Runs the original platformer and its local assets inside Android's WebView.
///
/// The WebView fills the whole screen (immersive); the safe-area insets are
/// forwarded to the page so the HUD and touch controls avoid notches, rounded
/// corners and the gesture bar while the world art still reaches the edges.
class OriginalGameScreen extends StatefulWidget {
  const OriginalGameScreen({
    super.key,
    required this.stage,
    required this.skin,
    this.lightMode = true,
  });
  final int stage;
  final int skin;
  final bool lightMode;

  @override
  State<OriginalGameScreen> createState() => _OriginalGameScreenState();
}

class _OriginalGameScreenState extends State<OriginalGameScreen>
    with WidgetsBindingObserver {
  MethodChannel? _channel;
  EdgeInsets? _sentInsets;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _channel?.invokeMethod<void>(
      state == AppLifecycleState.resumed ? 'resume' : 'pause',
    );
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel?.setMethodCallHandler(null);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  static Map<String, double> _insetArgs(EdgeInsets insets) => {
    'safeTop': insets.top,
    'safeRight': insets.right,
    'safeBottom': insets.bottom,
    'safeLeft': insets.left,
  };

  void _sendInsets(EdgeInsets insets) {
    if (_channel == null || insets == _sentInsets) return;
    _sentInsets = insets;
    _channel!.invokeMethod<void>('insets', _insetArgs(insets));
  }

  @override
  Widget build(BuildContext context) {
    // viewPadding keeps cutout/gesture-bar space even while bars are hidden.
    final insets = MediaQuery.viewPaddingOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendInsets(insets));
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final channel = _channel;
        if (channel == null) {
          Navigator.of(context).pop();
        } else {
          channel.invokeMethod<void>('back');
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xff0b1714),
        body: AndroidView(
          viewType: 'skyroot/original-game',
          creationParamsCodec: const StandardMessageCodec(),
          creationParams: {
            'stage': widget.stage,
            'skin': widget.skin,
            'lightMode': widget.lightMode,
            ..._insetArgs(insets),
          },
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
          onPlatformViewCreated: (id) {
            _sentInsets = insets;
            _channel = MethodChannel('skyroot/game/$id')
              ..setMethodCallHandler((call) async {
                if (call.method == 'home' && mounted) {
                  Navigator.of(context).pop();
                }
              });
            if (mounted) _sendInsets(MediaQuery.viewPaddingOf(context));
          },
        ),
      ),
    );
  }
}
