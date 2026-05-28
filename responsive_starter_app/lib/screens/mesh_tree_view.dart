// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:meshcore/meshcore.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../meshcore/discovered_node.dart';
import '../meshcore/mesh_graph.dart';
import '../meshcore/meshcore_controller.dart';
import '../util/force_layout.dart';
import 'node_detail_sheet.dart';

/// R50 — directed mesh topology tree, force-directed layout. The
/// data comes straight from `Contact.outPath` (the route the device
/// uses to reach each peer); the layout uses spring physics so
/// shared repeaters naturally become hubs.
///
/// Compared to the globe view this is *topology, not geography* —
/// peers without GPS still get a place (their connectivity does the
/// work). Compared to the radial view this is *connectivity, not
/// recency* — every edge in the picture is a confirmed route.
class MeshTreeView extends StatefulWidget {
  const MeshTreeView({
    super.key,
    this.filteredNodes,
    this.frozen = false,
  });

  /// Optional pre-filtered list (e.g. the parent screen applied
  /// favourites-only). When null the controller's full node list
  /// drives the graph.
  final List<DiscoveredNode>? filteredNodes;

  /// Pause the force simulation. The current frame keeps rendering.
  final bool frozen;

  @override
  State<MeshTreeView> createState() => _MeshTreeViewState();
}

class _MeshTreeViewState extends State<MeshTreeView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final Map<String, NodePosition> _positions = <String, NodePosition>{};
  final TransformationController _transform = TransformationController();
  ForceLayout? _layout;
  int _lastGraphSignature = 0;
  Size _lastSize = Size.zero;

  /// Max hop depth shown. 0 = direct neighbours only, 6 = everything
  /// (including advert-only floaters). Default 2 — direct + 1- + 2-hop.
  int _maxHops = 2;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick)..start();
  }

  void _onTick(Duration _) {
    if (widget.frozen) return;
    if (_layout == null) return;
    _layout!.step();
    // Touch state so CustomPaint repaints with the new positions.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _recenter() {
    // Animate-feel via a quick interpolation isn't worth the
    // complexity here — the snap to identity is fine and matches the
    // visual model ("reset view").
    _transform.value = Matrix4.identity();
  }

  /// Rebuild the simulation when the graph's node-set changes. We
  /// hash node ids cheaply so a transient lat/lon update doesn't
  /// invalidate the layout (re-randomising positions every frame
  /// would never settle).
  void _ensureLayout(MeshGraph g, Size size) {
    int sig = 17;
    for (final MeshGraphNode n in g.nodes) {
      sig = (sig * 31 + n.id.hashCode) & 0x7fffffff;
    }
    final bool sizeChanged = (_lastSize.width - size.width).abs() > 8 ||
        (_lastSize.height - size.height).abs() > 8;
    if (sig == _lastGraphSignature && _layout != null && !sizeChanged) {
      return;
    }
    _lastGraphSignature = sig;
    _lastSize = size;

    final double cx = size.width / 2;
    final double cy = size.height / 2;
    // Seed positions on a circle around the centre so the initial
    // burst of repulsion has somewhere to push toward. Self is
    // pinned dead centre — every other node settles around it.
    final math.Random rnd = math.Random(sig);
    final double r0 = math.min(size.width, size.height) * 0.30;
    final Map<String, NodePosition> next = <String, NodePosition>{};
    int i = 0;
    for (final MeshGraphNode n in g.nodes) {
      if (n.isSelf) {
        next[n.id] = NodePosition(x: cx, y: cy, pinned: true);
      } else {
        // Reuse the prior position if we already have one — keeps
        // the layout stable when a peer's name/type updates.
        final NodePosition? prev = _positions[n.id];
        if (prev != null) {
          next[n.id] = prev;
        } else {
          final double angle = 2 * math.pi * i / math.max(1, g.nodes.length);
          final double jitter =
              (rnd.nextDouble() - 0.5) * r0 * 0.4;
          next[n.id] = NodePosition(
            x: cx + (r0 + jitter) * math.cos(angle),
            y: cy + (r0 + jitter) * math.sin(angle),
          );
        }
      }
      i++;
    }
    _positions
      ..clear()
      ..addAll(next);

    _layout = ForceLayout(
      positions: _positions,
      edges: <(String, String)>[
        for (final MeshGraphEdge e in g.edges) (e.fromId, e.toId),
      ],
      centerX: cx,
      centerY: cy,
      // Keep every node inside the viewport — floaters (disconnected
      // advert-only peers) would otherwise be pushed off-screen by
      // repulsion and look like they vanished at higher hop settings.
      bounds: (w: size.width, h: size.height),
    );
  }

  void _maybeShowDetail(MeshcoreController mc, Offset tap) {
    // Hit-test by finding the closest node within ~24 px.
    String? hitId;
    double bestD2 = 24 * 24.0;
    _positions.forEach((String id, NodePosition p) {
      final double dx = p.x - tap.dx;
      final double dy = p.y - tap.dy;
      final double d2 = dx * dx + dy * dy;
      if (d2 < bestD2) {
        bestD2 = d2;
        hitId = id;
      }
    });
    if (hitId == null || hitId == 'self') return;
    DiscoveredNode? node;
    for (final DiscoveredNode n in mc.nodes) {
      if (n.pubKeyHex == hitId) {
        node = n;
        break;
      }
    }
    if (node == null) return;
    final DiscoveredNode peer = node;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext _) => NodeDetailSheet(
        node: peer,
        distanceMeters: peer.hasLocation
            ? mc.distanceMetersTo(peer.latitude!, peer.longitude!)
            : null,
        isFavourite: mc.favorites.contains(peer.pubKeyHex),
        isKnown: mc.known.contains(peer.pubKeyHex),
        onToggleFavourite: () => mc.toggleFavorite(peer.pubKeyHex),
        proximity: mc.proximityFor(peer),
        recentDms: mc.dmHistoryFor(peer.pubKeyHex),
        tags: mc.tagsFor(peer.pubKeyHex),
        tagSuggestions: mc.allTags,
        onAddTag: (String t) => mc.addTagTo(peer.pubKeyHex, t),
        onRemoveTag: (String t) => mc.removeTagFrom(peer.pubKeyHex, t),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppLocalizations l = AppLocalizations.of(context);

    final MeshGraph graph = MeshGraph.fromController(
      mc,
      filteredNodes: widget.filteredNodes,
      maxHops: _maxHops,
    );

    return LayoutBuilder(
      builder: (BuildContext _, BoxConstraints c) {
        final Size size = Size(c.maxWidth, c.maxHeight);
        _ensureLayout(graph, size);
        return Stack(
          children: <Widget>[
            // InteractiveViewer handles pinch-zoom + two-finger pan +
            // mouse-wheel zoom. The canvas inside is laid out at the
            // viewport size; the viewer transforms it. Gestures
            // delivered to children land in the *unscaled* coordinate
            // space, so hit-testing against _positions still works
            // without manual matrix math.
            //
            // boundaryMargin huge so you can pan a long way before
            // hitting an edge — the layout drifts outward when the
            // mesh grows large.
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: 0.3,
                maxScale: 4.0,
                boundaryMargin: const EdgeInsets.all(1200),
                child: GestureDetector(
                  onTapUp: (TapUpDetails d) =>
                      _maybeShowDetail(mc, d.localPosition),
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: CustomPaint(
                      painter: _MeshTreePainter(
                        graph: graph,
                        positions: _positions,
                        knownPubKeys: mc.known,
                        favPubKeys: mc.favorites,
                        accent: cs.primary,
                        accentDim: cs.primary.withValues(alpha: .35),
                        hub: cs.tertiary,
                        edge: cs.primary.withValues(alpha: .55),
                        edgeFloat: cs.outline.withValues(alpha: .35),
                        label: cs.onSurface,
                        bg: cs.surface,
                        emptyMsg: graph.nodes.length <= 1
                            ? l.meshTreeEmpty
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Recenter overlay — listens to the transformation
            // controller so it appears only when the user has zoomed
            // or panned away from the default view. Identity matrix
            // means already centred → nothing to do, button hidden.
            Positioned(
              right: 12,
              bottom: 12,
              child: AnimatedBuilder(
                animation: _transform,
                builder: (BuildContext _, Widget? __) {
                  final bool atIdentity =
                      _transform.value.isIdentity();
                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: atIdentity ? 0.0 : 1.0,
                    child: IgnorePointer(
                      ignoring: atIdentity,
                      child: FilledButton.tonalIcon(
                        icon: const Icon(
                            Icons.center_focus_strong, size: 16),
                        label: Text(l.meshTreeRecenter),
                        onPressed: _recenter,
                      ),
                    ),
                  );
                },
              ),
            ),
            // Hop-depth slider — trims the tree to peers within
            // N hops. 0 = Direct, 6 = All (incl. advert-only
            // floaters). Default 2.
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _HopSlider(
                value: _maxHops,
                label: _hopLabel(_maxHops, l),
                cs: cs,
                onChanged: (int v) {
                  if (v != _maxHops) setState(() => _maxHops = v);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _hopLabel(int hops, AppLocalizations l) {
    if (hops <= 0) return l.meshTreeHopsDirect;
    if (hops >= 6) return l.meshTreeHopsAll;
    return l.meshTreeHopsN(hops);
  }
}

/// Compact hop-depth slider for the tree view. 0..6 with a label
/// chip showing the current setting.
class _HopSlider extends StatelessWidget {
  const _HopSlider({
    required this.value,
    required this.label,
    required this.cs,
    required this.onChanged,
  });
  final int value;
  final String label;
  final ColorScheme cs;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outline.withValues(alpha: .55)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.account_tree, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 11,
                fontFamily: 'monospace',
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 6,
              divisions: 6,
              onChanged: (double v) => onChanged(v.round()),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeshTreePainter extends CustomPainter {
  _MeshTreePainter({
    required this.graph,
    required this.positions,
    required this.knownPubKeys,
    required this.favPubKeys,
    required this.accent,
    required this.accentDim,
    required this.hub,
    required this.edge,
    required this.edgeFloat,
    required this.label,
    required this.bg,
    this.emptyMsg,
  });

  final MeshGraph graph;
  final Map<String, NodePosition> positions;
  final Set<String> knownPubKeys;
  final Set<String> favPubKeys;
  final Color accent;
  final Color accentDim;
  final Color hub;
  final Color edge;
  final Color edgeFloat;
  final Color label;
  final Color bg;
  final String? emptyMsg;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    if (emptyMsg != null) {
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: emptyMsg!,
          style: TextStyle(color: edgeFloat, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: size.width * 0.7);
      tp.paint(canvas,
          Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
      return;
    }

    // Edges first so node circles sit on top.
    final Paint edgePaint = Paint()
      ..color = edge
      ..strokeWidth = 1.2;
    for (final MeshGraphEdge e in graph.edges) {
      final NodePosition? a = positions[e.fromId];
      final NodePosition? b = positions[e.toId];
      if (a == null || b == null) continue;
      canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), edgePaint);
      _drawArrow(canvas, Offset(a.x, a.y), Offset(b.x, b.y), edgePaint);
    }

    // Nodes.
    for (final MeshGraphNode n in graph.nodes) {
      final NodePosition? p = positions[n.id];
      if (p == null) continue;
      final Offset c = Offset(p.x, p.y);
      final _NodeStyle style = _styleFor(n);
      // Halo for known / favourites — same circle for any glyph
      // shape so the affinity cue stays consistent.
      if (favPubKeys.contains(n.id)) {
        canvas.drawCircle(
            c,
            style.radius + 5,
            Paint()
              ..color = style.colour.withValues(alpha: .25)
              ..style = PaintingStyle.fill);
      } else if (knownPubKeys.contains(n.id)) {
        canvas.drawCircle(
            c,
            style.radius + 3,
            Paint()
              ..color = style.colour.withValues(alpha: .18)
              ..style = PaintingStyle.fill);
      }
      // Body + outline, shape-aware.
      final Paint fillBg = Paint()..color = bg;
      final Paint strokeBody = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = n.isSelf ? 2.4 : 1.5
        ..color = style.colour;
      _drawShape(canvas, c, style.radius, style.shape, fillBg);
      _drawShape(canvas, c, style.radius, style.shape, strokeBody);
      // Centre dot for self.
      if (n.isSelf) {
        canvas.drawCircle(c, 3.0, Paint()..color = style.colour);
      }
      // Label.
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: n.label,
          style: TextStyle(
            color: label,
            fontSize: 10,
            fontFamily: 'monospace',
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 120);
      tp.paint(canvas,
          Offset(c.dx - tp.width / 2, c.dy + style.radius + 2));
    }
  }

  /// Draw the node glyph at [centre] with half-extent [r] using
  /// [paint]. The shape encodes the node's role so the topology is
  /// readable at a glance without leaning on colour alone:
  ///
  /// - **circle** — chat / sensor / self (endpoints + ego)
  /// - **square** — repeater (mast-mounted, infra)
  /// - **diamond** — room server (server-class infra)
  void _drawShape(
      Canvas canvas, Offset centre, double r, _NodeShape shape, Paint paint) {
    switch (shape) {
      case _NodeShape.circle:
        canvas.drawCircle(centre, r, paint);
      case _NodeShape.square:
        final Rect rect =
            Rect.fromCenter(center: centre, width: r * 2, height: r * 2);
        canvas.drawRect(rect, paint);
      case _NodeShape.diamond:
        final Path p = Path()
          ..moveTo(centre.dx, centre.dy - r)
          ..lineTo(centre.dx + r, centre.dy)
          ..lineTo(centre.dx, centre.dy + r)
          ..lineTo(centre.dx - r, centre.dy)
          ..close();
        canvas.drawPath(p, paint);
    }
  }

  _NodeStyle _styleFor(MeshGraphNode n) {
    if (n.isSelf) {
      return _NodeStyle(
          colour: accent, radius: 10, shape: _NodeShape.circle);
    }
    return switch (n.type) {
      kAdvTypeRepeater => _NodeStyle(
          colour: hub, radius: 10, shape: _NodeShape.square),
      kAdvTypeRoom => _NodeStyle(
          colour: hub, radius: 9, shape: _NodeShape.diamond),
      kAdvTypeSensor => _NodeStyle(
          colour: accentDim, radius: 5, shape: _NodeShape.circle),
      _ => _NodeStyle(
          colour: accent, radius: 6, shape: _NodeShape.circle),
    };
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    // Place arrowhead just before the `to` node so it doesn't get
    // hidden under the node circle.
    final double dx = to.dx - from.dx;
    final double dy = to.dy - from.dy;
    final double d = math.sqrt(dx * dx + dy * dy);
    if (d < 24) return; // too short to bother
    final double ux = dx / d;
    final double uy = dy / d;
    final double backoff = 12;
    final Offset tip =
        Offset(to.dx - ux * backoff, to.dy - uy * backoff);
    const double arrowSize = 6;
    final Offset left = Offset(
      tip.dx - ux * arrowSize - uy * arrowSize * 0.6,
      tip.dy - uy * arrowSize + ux * arrowSize * 0.6,
    );
    final Offset right = Offset(
      tip.dx - ux * arrowSize + uy * arrowSize * 0.6,
      tip.dy - uy * arrowSize - ux * arrowSize * 0.6,
    );
    canvas.drawLine(tip, left, paint);
    canvas.drawLine(tip, right, paint);
  }

  @override
  bool shouldRepaint(covariant _MeshTreePainter old) => true;
}

/// Glyph shape per node role. Circle = endpoint, square = repeater
/// infra, diamond = room server.
enum _NodeShape { circle, square, diamond }

class _NodeStyle {
  const _NodeStyle({
    required this.colour,
    required this.radius,
    required this.shape,
  });
  final Color colour;
  final double radius;
  final _NodeShape shape;
}
