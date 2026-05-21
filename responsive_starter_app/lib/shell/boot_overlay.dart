// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../meshcore/meshcore_connection.dart';
import '../meshcore/meshcore_controller.dart';

/// Boot-time busy overlay (R8 polish). On a cold launch the
/// BLE auto-connect → APP_START → SELF_INFO → drain chain typically
/// takes 3–8 s, during which the Dashboard renders blank-ish and
/// feels unresponsive. The overlay covers that gap with a branded
/// NERV-style "synchronising" screen that:
///
/// - Shows only on the first reach to `ready` (this session). Once
///   the controller reaches `ready` we fade out and never show
///   again — later disconnects/reconnects use the regular status
///   slab, not the overlay.
/// - Stops its own animations during the fade so widget-test
///   `pumpAndSettle` actually settles.
/// - **Always** uses the NERV palette regardless of the user's
///   chosen preset; this is a brand moment.
/// - Honours `Skip` so anyone in an offline session isn't blocked.
class BootOverlay extends StatefulWidget {
  const BootOverlay({super.key, required this.child});

  /// The shell content rendered behind the overlay.
  final Widget child;

  @override
  State<BootOverlay> createState() => _BootOverlayState();
}

class _BootOverlayState extends State<BootOverlay>
    with TickerProviderStateMixin {
  static const Color _bg = Color(0xFF0A0E1A);
  static const Color _bgDeep = Color(0xFF000000);
  static const Color _accent = Color(0xFFFF7A00); // NERV orange
  static const Color _alt = Color(0xFF9CFF00); // NERV ok-green
  static const Color _fg = Color(0xFFE6ECF5);

  /// Live AnimationController, repeats while overlay is visible.
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1.0, // start visible
  );

  /// True once we've finished the dismiss animation. From then on
  /// the overlay's Builder returns the child directly with zero
  /// overhead — and the Stack stops layering anything above.
  bool _dismissed = false;

  /// True once the user tapped SKIP (latches; we don't re-show on
  /// later reconnects in the same session anyway, but this is the
  /// signal "they actively asked me to leave").
  bool _skipped = false;

  @override
  void dispose() {
    _spin.dispose();
    _fade.dispose();
    super.dispose();
  }

  Future<void> _beginFadeOut() async {
    if (_dismissed) return;
    _spin.stop();
    await _fade.animateTo(0, curve: Curves.easeOut);
    if (mounted) setState(() => _dismissed = true);
  }

  void _onSkip() {
    setState(() => _skipped = true);
    _beginFadeOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return widget.child;

    final MeshcoreController mc = context.watch<MeshcoreController>();
    final bool ready = mc.state == MeshcoreConnectionState.ready;

    // "Nothing in flight": disconnected, not attempting a connect,
    // and no paired device → there is no boot work to wait for, so
    // the overlay is just covering empty UI. Dismiss now. This also
    // makes the offline-first launch path (no radio paired yet) read
    // as a normal Dashboard from the first frame.
    final bool quiescent =
        mc.state == MeshcoreConnectionState.disconnected &&
            !mc.isConnecting &&
            !mc.hasPairedDevice;

    if ((ready || quiescent) &&
        !_skipped &&
        _fade.value > 0 &&
        !_fade.isAnimating) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _beginFadeOut());
    }

    final AppLocalizations l = AppLocalizations.of(context);
    final String status = switch (mc.state) {
      MeshcoreConnectionState.ready => l.bootReady,
      MeshcoreConnectionState.handshaking => l.bootHandshaking,
      MeshcoreConnectionState.reconnecting => l.bootHandshaking,
      MeshcoreConnectionState.failed => l.bootOffline,
      MeshcoreConnectionState.disconnected => mc.isConnecting
          ? l.bootConnecting
          : l.bootOffline,
    };

    return Stack(
      children: <Widget>[
        widget.child,
        IgnorePointer(
          ignoring: _dismissed || _fade.value == 0,
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _fade,
              curve: Curves.easeInOut,
            ),
            child: _BootSurface(
              spin: _spin,
              accent: _accent,
              alt: _alt,
              fg: _fg,
              bg: _bg,
              bgDeep: _bgDeep,
              header: l.bootHeader,
              subtitle: l.bootSubtitle,
              status: status,
              skipLabel: l.bootSkip,
              onSkip: _onSkip,
            ),
          ),
        ),
      ],
    );
  }
}

class _BootSurface extends StatelessWidget {
  const _BootSurface({
    required this.spin,
    required this.accent,
    required this.alt,
    required this.fg,
    required this.bg,
    required this.bgDeep,
    required this.header,
    required this.subtitle,
    required this.status,
    required this.skipLabel,
    required this.onSkip,
  });

  final AnimationController spin;
  final Color accent;
  final Color alt;
  final Color fg;
  final Color bg;
  final Color bgDeep;
  final String header;
  final String subtitle;
  final String status;
  final String skipLabel;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgDeep,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[bg, bgDeep],
            ),
          ),
          child: Stack(
            children: <Widget>[
              // Corner brackets (NERV-style frame).
              Positioned.fill(
                child: CustomPaint(
                  painter: _CornerBracketsPainter(accent),
                ),
              ),
              // Top header strip.
              Positioned(
                top: 24,
                left: 24,
                right: 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(header,
                        style: TextStyle(
                            color: accent,
                            fontFamily: 'monospace',
                            fontSize: 11,
                            letterSpacing: 4)),
                    Text(subtitle,
                        style: TextStyle(
                            color: alt,
                            fontFamily: 'monospace',
                            fontSize: 11,
                            letterSpacing: 4)),
                  ],
                ),
              ),
              // Centre spinner.
              Center(
                child: AnimatedBuilder(
                  animation: spin,
                  builder: (BuildContext _, Widget? __) {
                    return CustomPaint(
                      size: const Size(240, 240),
                      painter: _NervSpinnerPainter(
                        accent: accent,
                        alt: alt,
                        t: spin.value,
                      ),
                    );
                  },
                ),
              ),
              // Status text below centre.
              Positioned(
                left: 0,
                right: 0,
                bottom: 96,
                child: Center(
                  child: Text(
                    status,
                    style: TextStyle(
                        color: fg,
                        fontFamily: 'monospace',
                        fontSize: 14,
                        letterSpacing: 3),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              // Skip in bottom-right.
              Positioned(
                right: 16,
                bottom: 16,
                child: TextButton(
                  onPressed: onSkip,
                  child: Text(skipLabel,
                      style: TextStyle(
                          color: alt,
                          fontFamily: 'monospace',
                          fontSize: 12,
                          letterSpacing: 3)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Four small "L" brackets in each corner — the NERV frame look.
class _CornerBracketsPainter extends CustomPainter {
  _CornerBracketsPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: .85);
    const double arm = 28;
    const double inset = 14;
    // TL
    canvas.drawPath(
      Path()
        ..moveTo(inset, inset + arm)
        ..lineTo(inset, inset)
        ..lineTo(inset + arm, inset),
      p,
    );
    // TR
    canvas.drawPath(
      Path()
        ..moveTo(size.width - inset - arm, inset)
        ..lineTo(size.width - inset, inset)
        ..lineTo(size.width - inset, inset + arm),
      p,
    );
    // BR
    canvas.drawPath(
      Path()
        ..moveTo(size.width - inset, size.height - inset - arm)
        ..lineTo(size.width - inset, size.height - inset)
        ..lineTo(size.width - inset - arm, size.height - inset),
      p,
    );
    // BL
    canvas.drawPath(
      Path()
        ..moveTo(inset + arm, size.height - inset)
        ..lineTo(inset, size.height - inset)
        ..lineTo(inset, size.height - inset - arm),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter old) =>
      old.color != color;
}

/// Centre spinner — concentric rotating chevrons + a steady hex
/// outline + an alt-colour pulse at 12 o'clock. Deliberately
/// hand-drawn to evoke NERV/EVA HUDs without using copyrighted
/// assets.
class _NervSpinnerPainter extends CustomPainter {
  _NervSpinnerPainter({
    required this.accent,
    required this.alt,
    required this.t,
  });
  final Color accent;
  final Color alt;
  final double t; // 0..1 repeating

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = math.min(size.width, size.height) / 2 - 4;

    // Static hex outline.
    final Path hex = Path();
    for (int i = 0; i < 6; i++) {
      final double a = i * math.pi / 3 + math.pi / 6;
      final Offset p =
          c + Offset(r * math.cos(a), r * math.sin(a));
      if (i == 0) {
        hex.moveTo(p.dx, p.dy);
      } else {
        hex.lineTo(p.dx, p.dy);
      }
    }
    hex.close();
    canvas.drawPath(
      hex,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: .55),
    );

    // Rotating chevron ring (clockwise, full revolution = 4 s).
    final double angle = t * 2 * math.pi;
    for (int i = 0; i < 8; i++) {
      final double a = angle + i * math.pi / 4;
      final double inset = i.isEven ? r - 12 : r - 22;
      final Offset cTip =
          c + Offset(inset * math.cos(a), inset * math.sin(a));
      final Offset cWingA = c +
          Offset(
            (inset - 8) * math.cos(a + 0.18),
            (inset - 8) * math.sin(a + 0.18),
          );
      final Offset cWingB = c +
          Offset(
            (inset - 8) * math.cos(a - 0.18),
            (inset - 8) * math.sin(a - 0.18),
          );
      final Paint pp = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color =
            accent.withValues(alpha: i.isEven ? 0.85 : 0.35);
      canvas.drawPath(
        Path()
          ..moveTo(cWingA.dx, cWingA.dy)
          ..lineTo(cTip.dx, cTip.dy)
          ..lineTo(cWingB.dx, cWingB.dy),
        pp,
      );
    }

    // Inner crosshair + dot.
    final Paint cross = Paint()
      ..color = accent.withValues(alpha: .9)
      ..strokeWidth = 1.4;
    canvas.drawLine(c.translate(-12, 0), c.translate(12, 0), cross);
    canvas.drawLine(c.translate(0, -12), c.translate(0, 12), cross);
    canvas.drawCircle(c, 4, Paint()..color = accent);

    // Alt-colour 12-o'clock pulse — green dot that breathes.
    final double pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
    canvas.drawCircle(
      c.translate(0, -r),
      4 + 2 * pulse,
      Paint()..color = alt.withValues(alpha: 0.55 + 0.45 * pulse),
    );
  }

  @override
  bool shouldRepaint(covariant _NervSpinnerPainter old) =>
      old.t != t;
}
