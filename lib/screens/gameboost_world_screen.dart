import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class GameBoostWorldScreen extends StatefulWidget {
  const GameBoostWorldScreen({super.key});

  @override
  State<GameBoostWorldScreen> createState() => _GameBoostWorldScreenState();
}

class _GameBoostWorldScreenState extends State<GameBoostWorldScreen> {
  Offset _direction = Offset.zero;
  double _theta = 0; // yatay açı (derece)
  double _phi = 80; // dikey açı (derece)
  double _radius = 8; // kamera mesafesi (metre)

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _handleDirectionChanged(Offset value) {
    setState(() {
      _direction = value;
      const double orbitSpeed = 2.0;
      _theta += value.dx * orbitSpeed;
      _phi = (_phi - value.dy * orbitSpeed).clamp(25, 85);
    });
  }

  String get _cameraOrbitString {
    final t = _theta.toStringAsFixed(1);
    final p = _phi.toStringAsFixed(1);
    final r = _radius.toStringAsFixed(1);
    return '${t}deg ${p}deg ${r}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050509),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF020617),
                      Color(0xFF0F172A),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: ModelViewer(
                  src: 'openworldmap.glb',
                  alt: 'GameBoost açık dünya haritası',
                  autoRotate: false,
                  cameraControls: true,
                  disableZoom: false,
                  autoPlay: true,
                  ar: false,
                  cameraOrbit: _cameraOrbitString,
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              left: 24,
              bottom: 32,
              child: _Joystick(
                onChanged: _handleDirectionChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Joystick extends StatefulWidget {
  final ValueChanged<Offset> onChanged;

  const _Joystick({required this.onChanged});

  @override
  State<_Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<_Joystick> {
  Offset _delta = Offset.zero;

  static const double _size = 120;
  static const double _knobSize = 60;

  void _updateFromLocalPosition(Offset localPosition) {
    const double radius = _size / 2;
    const double knobRadius = _knobSize / 2;
    final center = const Offset(radius, radius);
    final raw = localPosition - center;
    final maxDistance = radius - knobRadius;

    Offset clamped = raw;
    final distance = raw.distance;
    if (distance > maxDistance && distance > 0) {
      clamped = raw / distance * maxDistance;
    }

    final normalized = Offset(
      (clamped.dx / maxDistance).clamp(-1.0, 1.0),
      (clamped.dy / maxDistance).clamp(-1.0, 1.0),
    );

    setState(() {
      _delta = normalized;
    });

    widget.onChanged(Offset(normalized.dx, normalized.dy));
  }

  void _reset() {
    setState(() {
      _delta = Offset.zero;
    });
    widget.onChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        _updateFromLocalPosition(details.localPosition);
      },
      onPanUpdate: (details) {
        _updateFromLocalPosition(details.localPosition);
      },
      onPanEnd: (_) {
        _reset();
      },
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white12,
                border: Border.all(color: Colors.white24, width: 2),
              ),
            ),
            Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white30,
                ),
              ),
            ),
            Positioned(
              left: _size / 2 - _knobSize / 2 + _delta.dx * (_size / 2 - _knobSize / 2),
              top: _size / 2 - _knobSize / 2 + _delta.dy * (_size / 2 - _knobSize / 2),
              child: Container(
                width: _knobSize,
                height: _knobSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2563EB),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.6),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
