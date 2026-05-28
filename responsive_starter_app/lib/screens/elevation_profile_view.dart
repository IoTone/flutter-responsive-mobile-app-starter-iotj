// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../meshcore/discovered_node.dart';
import '../meshcore/meshcore_controller.dart';

/// R45 — exploratory altitude-profile view. **Not** meant to be
/// useful (most peers plot in the "?" band until each one's
/// telemetry has been queried). Meant to be *interesting*: a NERV-
/// style targeting HUD with iconic real-world references drawn at
/// their true heights and our node pinned at the altitude reported
/// by the paired device's GPS (via the CMD_SEND_TELEMETRY_REQ /
/// 0x8B path, populated automatically on every ready transition).
/// Phone-GPS altitude is used only as a last-resort fallback.
///
/// Reference set (handpicked for an order-of-magnitude spread):
///   - Person ........... 1.7 m
///   - House ............. 10 m
///   - Redwood .......... 115 m
///   - Empire State ..... 381 m
///   - Burj Khalifa ..... 828 m
///   - Mt Fuji ........ 3 776 m
///
/// Altitude axis is square-root scaled so the small references stay
/// readable instead of collapsing onto the ground line.
class ElevationProfileView extends StatefulWidget {
  const ElevationProfileView({
    super.key,
    this.filteredNodes,
  });

  final List<DiscoveredNode>? filteredNodes;

  @override
  State<ElevationProfileView> createState() =>
      _ElevationProfileViewState();
}

class _ElevationProfileViewState extends State<ElevationProfileView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  /// R45+1 — while the view is open, we passively walk through the
  /// peer list and ask the device for each one's telemetry, one
  /// every [_queryInterval]. Rate-limited so a fleet of N peers
  /// takes ~5N seconds to fully populate, which keeps OTA airtime
  /// well below the channel's saturation point.
  ///
  /// The controller dedupes against its own cache + inflight set —
  /// repeated requestPeerTelemetry calls for the same peer are
  /// cheap no-ops when fresh telemetry already exists.
  Timer? _autoQueryTimer;
  static const Duration _queryInterval = Duration(seconds: 5);

  /// Stop hammering a peer after this many sends with no response.
  /// Each send costs 1 OTA packet from us + 1 from them per hop; the
  /// 3rd unanswered attempt is a strong signal the peer's telemetry
  /// mode is off and no future attempt this session will help.
  static const int _maxAttemptsPerPeer = 3;

  /// Cap on hop count we'll auto-query. Direct (0) and 1-hop peers
  /// are always queried. 2-hop only when distance is known and
  /// reasonable. 3+ hops never auto-queried.
  static const int _maxHopsAlways = 1;
  static const int _maxHopsWithDistance = 2;
  static const double _maxDistanceMeters = 100000; // 100 km

  // Observability counters — purely for the status chip. The
  // *authoritative* attempt-per-peer cap lives on the controller
  // (`MeshcoreController.telemetryAttemptsFor`) so it persists
  // when the user swaps view modes and returns to the elevation
  // view. These two local ints just label what this view-instance
  // has done since mount.
  int _ticksWithNoEligible = 0;
  String? _lastTargetName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Fire one immediately so the first peer doesn't have to wait
      // the full 5 s; then periodic from there.
      _stepAutoQuery();
      _autoQueryTimer = Timer.periodic(_queryInterval, (_) {
        _stepAutoQuery();
      });
    });
  }

  @override
  void dispose() {
    _autoQueryTimer?.cancel();
    _scan.dispose();
    super.dispose();
  }

  /// Tier a peer for the auto-query loop:
  /// - 0  → direct neighbour (always)
  /// - 1  → 1-hop (always)
  /// - 2  → 2-hop AND distance known and < 100 km
  /// - -1 → skip (too far, too many hops, or no path info)
  int _tierFor(DiscoveredNode n, MeshcoreController mc) {
    final List<int>? hops = n.outPathHashes;
    if (hops == null) return -1; // no path info → don't auto-query
    final int hopCount = hops.length;
    if (hopCount == 0) return 0;
    if (hopCount <= _maxHopsAlways) return 1;
    if (hopCount <= _maxHopsWithDistance && n.hasLocation) {
      final double? d =
          mc.distanceMetersTo(n.latitude!, n.longitude!);
      if (d != null && d < _maxDistanceMeters) return 2;
    }
    return -1;
  }

  void _stepAutoQuery() {
    if (!mounted) return;
    final MeshcoreController mc = context.read<MeshcoreController>();
    if (!mc.isReady) {
      debugPrint('[elev.auto] skip — not ready');
      return;
    }
    final List<DiscoveredNode> source =
        widget.filteredNodes ?? mc.nodes;
    // Eligibility: no altitude resolved, not currently in flight,
    // controller-side attempt count below the cap (persistent
    // across view re-mounts), AND falls into one of the three
    // query tiers.
    final List<DiscoveredNode> eligible = <DiscoveredNode>[
      for (final DiscoveredNode n in source)
        if (n.pubKeyHex != mc.ownPubKeyHex &&
            n.altitudeMeters == null &&
            mc.telemetryFor(n.pubKeyHex)?.altitudeMeters == null &&
            !mc.isQueryingTelemetry(n.pubKeyHex) &&
            mc.telemetryAttemptsFor(n.pubKeyHex) <
                _maxAttemptsPerPeer &&
            _tierFor(n, mc) >= 0)
          n,
    ];
    if (eligible.isEmpty) {
      _ticksWithNoEligible++;
      debugPrint('[elev.auto] no eligible peers '
          '(${source.length} visible, '
          'tick $_ticksWithNoEligible)');
      if (mounted) setState(() {}); // refresh status chip
      return;
    }
    // Sort by (tier asc, lastHeard desc) — lowest tier (cheapest
    // OTA) first; within the same tier, the recently-heard peer
    // goes first since they're likeliest to respond.
    eligible.sort((DiscoveredNode a, DiscoveredNode b) {
      final int t = _tierFor(a, mc).compareTo(_tierFor(b, mc));
      if (t != 0) return t;
      return b.lastHeardUnix.compareTo(a.lastHeardUnix);
    });
    final DiscoveredNode target = eligible.first;
    final int tier = _tierFor(target, mc);
    _lastTargetName =
        target.name.isEmpty ? target.shortId : target.name;
    final int attemptBefore =
        mc.telemetryAttemptsFor(target.pubKeyHex);
    debugPrint('[elev.auto] sending telemetry req → ${target.name} '
        '(tier $tier · hops ${target.hopCount ?? "?"} · '
        'attempt ${attemptBefore + 1}/$_maxAttemptsPerPeer) — '
        'session total ${mc.telemetrySendCount + 1}');
    unawaited(mc.requestPeerTelemetry(
      target.pubKeyHex,
      maxAttempts: _maxAttemptsPerPeer,
    ));
    if (mounted) setState(() {}); // refresh status chip
  }

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final AppLocalizations l = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;

    final List<DiscoveredNode> source =
        widget.filteredNodes ?? mc.nodes;
    // No more hasLocation filter — altitude can come from telemetry
    // independent of an advert lat/lon, so a peer without GPS in its
    // advert can still plot vertically if telemetry told us its
    // altitude. The x-position is just a stagger, not a real
    // coordinate, so this is honest.
    final List<DiscoveredNode> peers = <DiscoveredNode>[
      for (final DiscoveredNode n in source)
        if (n.pubKeyHex != mc.ownPubKeyHex) n,
    ];

    // R45+1 — merge altitude from telemetry cache as a fallback to
    // the (always-null) advert field. When firmware eventually ships
    // an advert altitude slot, n.altitudeMeters takes priority; until
    // then this is the only way peers get above the ground band.
    final Map<String, double> peerAlt = <String, double>{};
    for (final DiscoveredNode n in peers) {
      final double? resolved = n.altitudeMeters ??
          mc.telemetryFor(n.pubKeyHex)?.altitudeMeters;
      if (resolved != null) peerAlt[n.pubKeyHex] = resolved;
    }

    final double? selfAlt = mc.ownLocation?.altitudeMeters;

    // Status counters for the observability chip. All sourced from
    // the controller now so the counts persist across view re-mounts
    // (you don't go back to "queries: 0" after swapping to another
    // grid mode and back).
    final int resolvedCount = peerAlt.length;
    final int inflightCount = peers
        .where((DiscoveredNode n) =>
            mc.isQueryingTelemetry(n.pubKeyHex))
        .length;
    final int totalQueries = mc.telemetrySendCount;
    final int gaveUpCount = peers
        .where((DiscoveredNode n) =>
            mc.telemetryAttemptsFor(n.pubKeyHex) >=
                _maxAttemptsPerPeer &&
            mc.telemetryFor(n.pubKeyHex)?.altitudeMeters == null)
        .length;
    final int skippedCount = peers
        .where((DiscoveredNode n) =>
            n.altitudeMeters == null &&
            mc.telemetryFor(n.pubKeyHex)?.altitudeMeters == null &&
            _tierFor(n, mc) < 0)
        .length;

    return Stack(
      children: <Widget>[
        AnimatedBuilder(
          animation: _scan,
          builder: (BuildContext _, Widget? __) {
            // CustomPaint without a child collapses to Size.zero,
            // leaving only the parent Scaffold's banner visible.
            // SizedBox.expand gives it the body's full constraints
            // so the painter has somewhere to draw.
            return SizedBox.expand(
              child: CustomPaint(
                painter: _ElevationProfilePainter(
                  selfAltMeters: selfAlt,
                  peers: peers,
                  peerAltOverrides: peerAlt,
                  knownPubKeys: mc.known,
                  favPubKeys: mc.favorites,
                  accent: cs.primary,
                  accentDim: cs.primary.withValues(alpha: .40),
                  accentFaint: cs.primary.withValues(alpha: .18),
                  warn: cs.tertiary,
                  fg: cs.onSurface,
                  bg: cs.surface,
                  scanT: _scan.value,
                  header: l.elevationProfileTitle,
                  altLabel: l.elevationProfileAltLabel,
                  meLabel: l.elevationProfileMeLabel,
                  unknownLabel: l.elevationProfileUnknownLabel,
                  peerCountLabel:
                      l.elevationProfilePeers(peers.length),
                  referenceLabels: <_RefId, String>{
                    _RefId.person: l.elevationRefPerson,
                    _RefId.house: l.elevationRefHouse,
                    _RefId.redwood: l.elevationRefRedwood,
                    _RefId.empireState: l.elevationRefEmpireState,
                    _RefId.burj: l.elevationRefBurj,
                    _RefId.mtFuji: l.elevationRefMtFuji,
                  },
                ),
              ),
            );
          },
        ),
        // Observability chip — makes the auto-query loop visible so
        // we can tell whether queries are firing, in flight, and/or
        // getting responses. If queries climb but resolved stays at
        // 0, peers aren't answering (likely their telemetry mode is
        // off, or our device hasn't synced contacts for them).
        Positioned(
          left: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: .85),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: cs.outline.withValues(alpha: .55)),
            ),
            child: DefaultTextStyle(
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 10,
                fontFamily: 'monospace',
                letterSpacing: 1,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('AUTO-QUERY'),
                  const SizedBox(height: 2),
                  Text('queries: $totalQueries · '
                      'in-flight: $inflightCount'),
                  Text('resolved: $resolvedCount / ${peers.length}'),
                  Text('skip: $skippedCount · gave-up: $gaveUpCount'),
                  if (_lastTargetName != null)
                    Text('last: $_lastTargetName',
                        overflow: TextOverflow.ellipsis),
                  // If we've sent several queries but seen no
                  // resolutions, the peer side almost certainly isn't
                  // responding — most common cause is peer's
                  // telemetry mode being off (CMD_SET_OTHER_PARAMS
                  // packs a byte where the low bits gate which
                  // sensors are exposed).
                  if (totalQueries >= 3 && resolvedCount == 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'no responses — peer telem mode\noff?',
                        style: TextStyle(
                            color: cs.tertiary, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Identifier for each reference object so the painter and the l10n
/// labels stay in sync without parallel-array gymnastics.
enum _RefId { person, house, redwood, empireState, burj, mtFuji }

class _Ref {
  const _Ref(this.id, this.altMeters, this.draw);
  final _RefId id;
  final double altMeters;
  final void Function(
      Canvas c, Offset baseCentre, double pxPerMeter, Color stroke,
      Color fill) draw;
}

/// All references, sorted bottom → top by altitude.
const List<_Ref> _references = <_Ref>[
  _Ref(_RefId.person, 1.7, _drawPerson),
  _Ref(_RefId.house, 10.0, _drawHouse),
  _Ref(_RefId.redwood, 115.0, _drawRedwood),
  _Ref(_RefId.empireState, 381.0, _drawEmpireState),
  _Ref(_RefId.burj, 828.0, _drawBurj),
  _Ref(_RefId.mtFuji, 3776.0, _drawMtFuji),
];

/// Square-root scale: alt → y-offset from the ground line.
/// Keeps the dynamic range honest enough that 10 m feels much
/// bigger than 1 m, while 4 km doesn't take up the whole canvas.
double _altToYOffset(double altMeters, double pxPerSqrtMeter) {
  if (altMeters <= 0) return 0;
  return math.sqrt(altMeters) * pxPerSqrtMeter;
}

class _ElevationProfilePainter extends CustomPainter {
  _ElevationProfilePainter({
    required this.selfAltMeters,
    required this.peers,
    required this.peerAltOverrides,
    required this.knownPubKeys,
    required this.favPubKeys,
    required this.accent,
    required this.accentDim,
    required this.accentFaint,
    required this.warn,
    required this.fg,
    required this.bg,
    required this.scanT,
    required this.header,
    required this.altLabel,
    required this.meLabel,
    required this.unknownLabel,
    required this.peerCountLabel,
    required this.referenceLabels,
  });

  final double? selfAltMeters;
  final List<DiscoveredNode> peers;

  /// R45+1 — resolved altitude per peer (keyed by pubKeyHex). Falls
  /// back through advert → telemetry cache → null in the caller; the
  /// painter just reads this map. Peers absent from the map land in
  /// the unknown band along the ground.
  final Map<String, double> peerAltOverrides;

  final Set<String> knownPubKeys;
  final Set<String> favPubKeys;
  final Color accent;
  final Color accentDim;
  final Color accentFaint;
  final Color warn;
  final Color fg;
  final Color bg;

  /// 0..1 cycling — drives the scan-line sweep.
  final double scanT;

  final String header;
  final String altLabel;
  final String meLabel;
  final String unknownLabel;
  final String peerCountLabel;
  final Map<_RefId, String> referenceLabels;

  /// Max altitude shown on the axis — slightly above Mt Fuji.
  static const double _altMax = 4500.0;

  /// Ticks at decadal-ish stops. The painter draws each as a dashed
  /// horizontal line + numeric label on the axis strip.
  static const List<double> _ticks = <double>[
    0, 10, 50, 100, 500, 1000, 2000, 3000, 4000
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Layout — vertical strip on the right is the altitude axis;
    // everything else is the canvas where the references stand on
    // the ground line.
    const double axisWidth = 72.0;
    const double topPad = 64.0;
    const double bottomPad = 32.0;
    final double groundY = size.height - bottomPad;
    final double topY = topPad;
    final double availableY = groundY - topY;

    // pxPerSqrtMeter: 0 m at ground line, sqrt(_altMax) m at topY.
    final double pxPerSqrtMeter =
        availableY / math.sqrt(_altMax);
    final Rect canvasRect =
        Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(canvasRect, Paint()..color = bg);

    _drawHudFrame(canvas, size);
    _drawHeader(canvas, size);
    _drawAxis(canvas, size, axisWidth, groundY, topY, pxPerSqrtMeter);

    // Reference silhouettes — laid out across the working area.
    final double workW = size.width - axisWidth - 16.0;
    final int n = _references.length;
    // Distribute evenly; leave breathing room at both ends.
    for (int i = 0; i < n; i++) {
      final _Ref r = _references[i];
      final double cx = 24 + ((i + 0.5) / n) * (workW - 24);
      final Offset base = Offset(cx, groundY);
      r.draw(canvas, base, pxPerSqrtMeter, accent, accentFaint);
      _labelReference(canvas, base, r, pxPerSqrtMeter);
    }

    // Ground line (horizon).
    final Paint groundLine = Paint()
      ..color = accent
      ..strokeWidth = 1.5;
    canvas.drawLine(
        Offset(0, groundY), Offset(size.width - axisWidth, groundY),
        groundLine);

    // Self pin: horizontal line at our altitude, marker chip on
    // the left edge.
    if (selfAltMeters != null) {
      final double y = groundY -
          _altToYOffset(selfAltMeters!.clamp(0.0, _altMax), pxPerSqrtMeter);
      final Paint mePaint = Paint()
        ..color = warn
        ..strokeWidth = 2.0;
      _dashedLine(canvas, Offset(0, y),
          Offset(size.width - axisWidth, y), mePaint, dash: 6, gap: 5);
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: '${meLabel.toUpperCase()} '
              '${selfAltMeters!.toStringAsFixed(0)}m',
          style: TextStyle(
              color: warn,
              fontSize: 10,
              letterSpacing: 1,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final Rect chip = Rect.fromLTWH(
          6, y - tp.height / 2 - 3, tp.width + 12, tp.height + 6);
      canvas.drawRect(chip, Paint()..color = bg);
      canvas.drawRect(
          chip,
          Paint()
            ..color = warn
            ..style = PaintingStyle.stroke);
      tp.paint(canvas, Offset(chip.left + 6, chip.top + 3));
      // Bullseye dot on the right end of the dashed line.
      final Offset endP =
          Offset(size.width - axisWidth - 4, y);
      canvas.drawCircle(endP, 5.0, Paint()..color = warn);
      canvas.drawCircle(endP, 2.0, Paint()..color = bg);
    }

    // Scan line — a single bright horizontal pixel-line sweeping
    // from ground to top, looping. Pure flourish.
    final double scanY = groundY - (groundY - topY) * scanT;
    canvas.drawLine(
        Offset(0, scanY),
        Offset(size.width - axisWidth, scanY),
        Paint()
          ..color = accent.withValues(alpha: 0.22)
          ..strokeWidth = 1.0);

    // Unknown-altitude band along the ground line where peers
    // without altitude plot. Stripe pattern says "this is a holding
    // area, not actual measurement".
    _drawUnknownBand(canvas, size, axisWidth, groundY);

    // Peer markers. Altitude resolution order, in the caller:
    // advert field → telemetry cache → null. Peers absent from
    // peerAltOverrides land in the unknown band; peers present
    // plot at their resolved height.
    int unknownCount = 0;
    for (int i = 0; i < peers.length; i++) {
      final DiscoveredNode n = peers[i];
      final double? alt = peerAltOverrides[n.pubKeyHex];
      if (alt == null) {
        // Stagger horizontally in the unknown band, top-right of
        // the workspace, so multiple peers don't stack.
        final double x = (size.width - axisWidth) -
            16 -
            (unknownCount * 14.0) % (size.width - axisWidth - 32);
        final double y = groundY + 12.0;
        _drawPeerMarker(canvas, Offset(x, y), n, isUnknownAlt: true);
        unknownCount++;
      } else {
        final double y = groundY -
            _altToYOffset(alt.clamp(0.0, _altMax), pxPerSqrtMeter);
        final double x = 40 +
            ((i * 53) % ((size.width - axisWidth - 80).toInt()))
                .toDouble();
        _drawPeerMarker(canvas, Offset(x, y), n, isUnknownAlt: false);
      }
    }

    // Status strip at the bottom — peer count + unknown count.
    final TextPainter status = TextPainter(
      text: TextSpan(
        text: '$peerCountLabel  ·  '
            '$unknownCount $unknownLabel',
        style: TextStyle(
            color: accentDim,
            fontSize: 9,
            letterSpacing: 2,
            fontFamily: 'monospace'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    status.paint(canvas, Offset(12, size.height - 18));
  }

  void _drawHudFrame(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = accentFaint
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
        Rect.fromLTRB(4, 4, size.width - 4, size.height - 4), p);
    // Corner brackets.
    const double len = 14.0;
    final Paint c = Paint()
      ..color = accent
      ..strokeWidth = 1.4;
    void corner(Offset o, double dx, double dy) {
      canvas.drawLine(o, o.translate(len * dx, 0), c);
      canvas.drawLine(o, o.translate(0, len * dy), c);
    }
    corner(const Offset(8, 8), 1, 1);
    corner(Offset(size.width - 8, 8), -1, 1);
    corner(Offset(8, size.height - 8), 1, -1);
    corner(Offset(size.width - 8, size.height - 8), -1, -1);
  }

  void _drawHeader(Canvas canvas, Size size) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: '[ $header ]',
        style: TextStyle(
            color: accent,
            fontSize: 11,
            letterSpacing: 3,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(20, 18));
    // Hash slash decorations to the right of the header.
    final Paint h = Paint()
      ..color = accentDim
      ..strokeWidth = 1.0;
    final double startX = 20 + tp.width + 12;
    for (double x = startX; x < size.width - 20; x += 6) {
      canvas.drawLine(Offset(x, 20), Offset(x + 4, 28), h);
    }
  }

  void _drawAxis(Canvas canvas, Size size, double axisWidth,
      double groundY, double topY, double pxPerSqrtMeter) {
    final double xAxis = size.width - axisWidth;
    final Paint axisLine = Paint()
      ..color = accent
      ..strokeWidth = 1.0;
    canvas.drawLine(
        Offset(xAxis, topY - 6), Offset(xAxis, groundY + 6), axisLine);

    // Axis title.
    final TextPainter title = TextPainter(
      text: TextSpan(
        text: altLabel.toUpperCase(),
        style: TextStyle(
            color: accentDim,
            fontSize: 9,
            letterSpacing: 2,
            fontFamily: 'monospace'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    title.paint(canvas, Offset(xAxis + 10, topY - 22));

    // Tick marks + labels.
    for (final double a in _ticks) {
      final double y = groundY - _altToYOffset(a, pxPerSqrtMeter);
      // Short tick + dashed extension into the workspace for the
      // top of the scale.
      canvas.drawLine(
          Offset(xAxis - 4, y), Offset(xAxis + 4, y), axisLine);
      _dashedLine(
          canvas,
          Offset(0, y),
          Offset(xAxis - 6, y),
          Paint()
            ..color = accentFaint
            ..strokeWidth = 1.0,
          dash: 4,
          gap: 6);
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: a < 1000 ? '${a.round()} m' : '${(a / 1000).toStringAsFixed(1)} km',
          style: TextStyle(
              color: accent,
              fontSize: 9,
              letterSpacing: 1,
              fontFamily: 'monospace'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(xAxis + 8, y - tp.height / 2));
    }
  }

  void _labelReference(
      Canvas canvas, Offset base, _Ref r, double pxPerSqrtMeter) {
    final double topY = base.dy - _altToYOffset(r.altMeters, pxPerSqrtMeter);
    final String name = referenceLabels[r.id] ?? r.id.name;
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: '$name · ${r.altMeters < 1000
            ? '${r.altMeters.round()}m'
            : '${(r.altMeters / 1000).toStringAsFixed(1)}km'}',
        style: TextStyle(
            color: accent,
            fontSize: 9,
            letterSpacing: 1,
            fontFamily: 'monospace'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // Position above the silhouette tip.
    final Offset at = Offset(base.dx - tp.width / 2, topY - tp.height - 4);
    canvas.drawRect(
        Rect.fromLTWH(at.dx - 3, at.dy - 1, tp.width + 6, tp.height + 2),
        Paint()..color = bg.withValues(alpha: .85));
    tp.paint(canvas, at);
  }

  void _drawUnknownBand(Canvas canvas, Size size, double axisWidth,
      double groundY) {
    final double bandTop = groundY + 4;
    final double bandBottom = groundY + 22;
    final Rect r =
        Rect.fromLTRB(0, bandTop, size.width - axisWidth, bandBottom);
    final Paint stripe = Paint()
      ..color = accentDim
      ..strokeWidth = 0.8;
    // Diagonal hash fill.
    canvas.save();
    canvas.clipRect(r);
    for (double x = -bandBottom; x < size.width - axisWidth; x += 6) {
      canvas.drawLine(Offset(x, bandTop),
          Offset(x + (bandBottom - bandTop), bandBottom), stripe);
    }
    canvas.restore();
    canvas.drawRect(
        r,
        Paint()
          ..color = accentDim
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke);
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: '/ ${unknownLabel.toUpperCase()}',
        style: TextStyle(
            color: accentDim,
            fontSize: 8,
            letterSpacing: 2,
            fontFamily: 'monospace'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(6, bandTop + 4));
  }

  void _drawPeerMarker(Canvas canvas, Offset at, DiscoveredNode n,
      {required bool isUnknownAlt}) {
    final Color base = n.type == 2 ? accent : warn;
    final Paint fill = Paint()..color = base;
    if (n.type == 2) {
      // Repeater = triangle.
      const double s = 5.0;
      final Path p = Path()
        ..moveTo(at.dx, at.dy - s)
        ..lineTo(at.dx - s, at.dy + s)
        ..lineTo(at.dx + s, at.dy + s)
        ..close();
      canvas.drawPath(p, fill);
    } else {
      canvas.drawCircle(at, 4.0, fill);
    }
    // Faint vertical "rope" from the marker to the ground for
    // known-altitude peers, so the height-above-horizon reads.
    if (!isUnknownAlt) {
      final Paint rope = Paint()
        ..color = base.withValues(alpha: .3)
        ..strokeWidth = 1.0;
      canvas.drawLine(at, Offset(at.dx, at.dy + 200), rope);
    }
    // Star pip for favourite, dot for known.
    if (favPubKeys.contains(n.pubKeyHex)) {
      canvas.drawCircle(at + const Offset(0, -8), 1.6,
          Paint()..color = warn);
    } else if (knownPubKeys.contains(n.pubKeyHex)) {
      canvas.drawCircle(
          at + const Offset(0, -8),
          1.6,
          Paint()
            ..color = accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8);
    }
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint,
      {double dash = 4, double gap = 4}) {
    final double dx = b.dx - a.dx;
    final double dy = b.dy - a.dy;
    final double len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return;
    final double ux = dx / len;
    final double uy = dy / len;
    double t = 0;
    while (t < len) {
      final double t2 = math.min(t + dash, len);
      canvas.drawLine(Offset(a.dx + ux * t, a.dy + uy * t),
          Offset(a.dx + ux * t2, a.dy + uy * t2), paint);
      t += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _ElevationProfilePainter old) =>
      selfAltMeters != old.selfAltMeters ||
      peers != old.peers ||
      knownPubKeys != old.knownPubKeys ||
      favPubKeys != old.favPubKeys ||
      scanT != old.scanT;
}

// ---------- Reference silhouettes ----------------------------------

void _drawPerson(Canvas c, Offset base, double pxPerSqrtMeter,
    Color stroke, Color fill) {
  final double h = math.sqrt(1.7) * pxPerSqrtMeter;
  // Person is tiny at this scale — draw a stylised stick figure.
  final double cx = base.dx;
  final double top = base.dy - h;
  final Paint p = Paint()
    ..color = stroke
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;
  // Head.
  c.drawCircle(Offset(cx, top + 3), 2.5, p);
  // Body.
  c.drawLine(Offset(cx, top + 6), Offset(cx, base.dy), p);
  // Arms.
  c.drawLine(
      Offset(cx - 4, base.dy - h * 0.55),
      Offset(cx + 4, base.dy - h * 0.55),
      p);
  // Legs.
  c.drawLine(Offset(cx, base.dy), Offset(cx - 3, base.dy + 0.1), p);
}

void _drawHouse(Canvas c, Offset base, double pxPerSqrtMeter,
    Color stroke, Color fill) {
  final double h = math.sqrt(10.0) * pxPerSqrtMeter;
  final double w = h * 1.1;
  final Paint outline = Paint()
    ..color = stroke
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;
  final Paint f = Paint()..color = fill;
  final Rect body =
      Rect.fromLTWH(base.dx - w / 2, base.dy - h * 0.65, w, h * 0.65);
  c.drawRect(body, f);
  c.drawRect(body, outline);
  // Peaked roof.
  final Path roof = Path()
    ..moveTo(base.dx - w / 2 - 2, base.dy - h * 0.65)
    ..lineTo(base.dx, base.dy - h)
    ..lineTo(base.dx + w / 2 + 2, base.dy - h * 0.65)
    ..close();
  c.drawPath(roof, f);
  c.drawPath(roof, outline);
  // Door.
  final Rect door = Rect.fromLTWH(
      base.dx - w * 0.10, base.dy - h * 0.3, w * 0.20, h * 0.30);
  c.drawRect(door, outline);
}

void _drawRedwood(Canvas c, Offset base, double pxPerSqrtMeter,
    Color stroke, Color fill) {
  final double h = math.sqrt(115.0) * pxPerSqrtMeter;
  final double w = h * 0.18;
  final Paint outline = Paint()
    ..color = stroke
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;
  final Paint f = Paint()..color = fill;
  // Trunk.
  final Rect trunk = Rect.fromLTWH(
      base.dx - w * 0.15, base.dy - h * 0.30, w * 0.30, h * 0.30);
  c.drawRect(trunk, f);
  c.drawRect(trunk, outline);
  // Conical canopy — two stacked triangles for a redwood vibe.
  final Path canopy = Path()
    ..moveTo(base.dx - w, base.dy - h * 0.30)
    ..lineTo(base.dx + w, base.dy - h * 0.30)
    ..lineTo(base.dx + w * 0.6, base.dy - h * 0.55)
    ..lineTo(base.dx - w * 0.6, base.dy - h * 0.55)
    ..close();
  c.drawPath(canopy, f);
  c.drawPath(canopy, outline);
  final Path canopy2 = Path()
    ..moveTo(base.dx - w * 0.7, base.dy - h * 0.55)
    ..lineTo(base.dx + w * 0.7, base.dy - h * 0.55)
    ..lineTo(base.dx, base.dy - h)
    ..close();
  c.drawPath(canopy2, f);
  c.drawPath(canopy2, outline);
}

void _drawEmpireState(Canvas c, Offset base, double pxPerSqrtMeter,
    Color stroke, Color fill) {
  final double h = math.sqrt(381.0) * pxPerSqrtMeter;
  final double baseW = h * 0.45;
  final Paint outline = Paint()
    ..color = stroke
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;
  final Paint f = Paint()..color = fill;
  // Stepped silhouette: three rectangles narrowing upward, plus a
  // spire on top.
  void step(double cx, double bottomY, double topY, double width) {
    final Rect r = Rect.fromLTWH(
        cx - width / 2, topY, width, bottomY - topY);
    c.drawRect(r, f);
    c.drawRect(r, outline);
  }
  step(base.dx, base.dy, base.dy - h * 0.55, baseW);
  step(base.dx, base.dy - h * 0.55, base.dy - h * 0.80, baseW * 0.70);
  step(base.dx, base.dy - h * 0.80, base.dy - h * 0.92, baseW * 0.45);
  // Spire.
  c.drawLine(Offset(base.dx, base.dy - h * 0.92),
      Offset(base.dx, base.dy - h), outline);
}

void _drawBurj(Canvas c, Offset base, double pxPerSqrtMeter,
    Color stroke, Color fill) {
  final double h = math.sqrt(828.0) * pxPerSqrtMeter;
  final double w = h * 0.18;
  final Paint outline = Paint()
    ..color = stroke
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;
  final Paint f = Paint()..color = fill;
  // Tapering trunk.
  final Path body = Path()
    ..moveTo(base.dx - w / 2, base.dy)
    ..lineTo(base.dx + w / 2, base.dy)
    ..lineTo(base.dx + w * 0.18, base.dy - h * 0.80)
    ..lineTo(base.dx - w * 0.18, base.dy - h * 0.80)
    ..close();
  c.drawPath(body, f);
  c.drawPath(body, outline);
  // Pointy spire.
  c.drawLine(Offset(base.dx, base.dy - h * 0.80),
      Offset(base.dx, base.dy - h), outline);
}

void _drawMtFuji(Canvas c, Offset base, double pxPerSqrtMeter,
    Color stroke, Color fill) {
  final double h = math.sqrt(3776.0) * pxPerSqrtMeter;
  final double w = h * 1.3;
  final Paint outline = Paint()
    ..color = stroke
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;
  final Paint f = Paint()..color = fill;
  // Symmetric volcano cone.
  final Path body = Path()
    ..moveTo(base.dx - w / 2, base.dy)
    ..lineTo(base.dx - w * 0.10, base.dy - h * 0.95)
    ..lineTo(base.dx + w * 0.10, base.dy - h * 0.95)
    ..lineTo(base.dx + w / 2, base.dy)
    ..close();
  c.drawPath(body, f);
  c.drawPath(body, outline);
  // Snowcap.
  final Path cap = Path()
    ..moveTo(base.dx - w * 0.15, base.dy - h * 0.85)
    ..lineTo(base.dx - w * 0.10, base.dy - h * 0.95)
    ..lineTo(base.dx + w * 0.10, base.dy - h * 0.95)
    ..lineTo(base.dx + w * 0.15, base.dy - h * 0.85)
    ..close();
  c.drawPath(cap, Paint()..color = stroke.withValues(alpha: .25));
  c.drawPath(cap, outline);
}
