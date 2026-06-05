// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/mm_skin.dart';
import 'mm_shape.dart';

/// A framed surface panel whose edge treatment (sharp / rounded /
/// chamfered) comes from the active skin. The NERV concept renders this
/// as a chamfered HUD panel; SEELE as a plain sharp slab.
class MmPanel extends StatelessWidget {
  const MmPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.fill,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final MmSkin skin = context.skin;
    final OutlinedBorder border = mmShapeBorder(
      skin.shape,
      side: BorderSide(
          color: skin.color.line, width: skin.shape.borderWidth),
    );
    return Container(
      decoration:
          ShapeDecoration(color: fill ?? skin.color.surface, shape: border),
      padding: padding,
      child: child,
    );
  }
}

/// A section header — a tracked, optionally uppercase label. Loud
/// concepts (NERV) extend it with a diagonal **hazard-stripe** bar;
/// calm ones (SEELE) render just the label.
class MmSectionHeader extends StatelessWidget {
  const MmSectionHeader(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final MmSkin skin = context.skin;
    final Widget labelWidget = Text(
      skin.type.upperHeadings ? label.toUpperCase() : label,
      style: TextStyle(
        fontFamily: skin.type.headingFamily ?? skin.type.monoFamily,
        color: skin.color.fgMuted,
        fontSize: 11,
        letterSpacing: skin.type.headingTracking,
        fontWeight: FontWeight.w700,
      ),
    );
    return Row(
      children: <Widget>[
        labelWidget,
        if (skin.ornament.warningStripes) ...<Widget>[
          const SizedBox(width: 10),
          Expanded(
            child: CustomPaint(
              painter: _HazardStripes(skin.color.accent, skin.color.line),
              child: const SizedBox(height: 9),
            ),
          ),
          const SizedBox(width: 8),
        ] else
          const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _HazardStripes extends CustomPainter {
  _HazardStripes(this.stripe, this.gap);
  final Color stripe;
  final Color gap;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = gap.withValues(alpha: .4));
    final Paint p = Paint()..color = stripe.withValues(alpha: .55);
    const double w = 6, step = 12;
    for (double x = -size.height; x < size.width; x += step) {
      final Path path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + size.height, 0)
        ..lineTo(x + size.height + w, 0)
        ..lineTo(x + w, size.height)
        ..close();
      canvas.save();
      canvas.clipRect(Offset.zero & size);
      canvas.drawPath(path, p);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_HazardStripes old) =>
      old.stripe != stripe || old.gap != gap;
}

/// A labelled telemetry readout — `LABEL value` in the skin's mono
/// face. The workhorse for HUD-style data lines.
class MmReadout extends StatelessWidget {
  const MmReadout({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Color? valueColor;

  /// Render the value larger (a hero figure within a panel).
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final MmSkin skin = context.skin;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          skin.type.upperHeadings ? label.toUpperCase() : label,
          style: TextStyle(
            fontFamily: skin.type.monoFamily,
            color: skin.color.fgMuted,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: skin.type.monoFamily,
              color: valueColor ?? skin.color.fg,
              fontSize: emphasize ? 18 : 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              fontFeatures: skin.type.slashedZero
                  ? const <FontFeature>[FontFeature.slashedZero()]
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// A list row whose container reskins with the active skin: loud
/// concepts (NERV, chamfer/ornament) render each row as a framed
/// **panel card**; calm ones (SEELE) render a flat row with a hairline
/// rule — same content, different identity, no per-screen fork. Drop-in
/// for `ListTile` (leading / title / subtitle / trailing / onTap).
class MmListRow extends StatelessWidget {
  const MmListRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final MmSkin skin = context.skin;
    final Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (leading != null)
          Padding(padding: const EdgeInsets.only(right: 12), child: leading!),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DefaultTextStyle.merge(
                style: TextStyle(color: skin.color.fg),
                child: title,
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: subtitle!,
                ),
            ],
          ),
        ),
        if (trailing != null)
          Padding(padding: const EdgeInsets.only(left: 8), child: trailing!),
      ],
    );

    final bool card =
        skin.shape.corner != MmCorner.sharp || skin.ornament.any;
    if (card) {
      return MmPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: InkWell(onTap: onTap, child: content),
      );
    }
    // Calm/flat: a plain tappable row with a bottom hairline.
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: skin.color.line)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: content,
        ),
      ),
    );
  }
}

/// A small status pill (app-bar / header chip) — dot + tracked label,
/// inverting to the alert colour when [alert].
class MmStatusPill extends StatelessWidget {
  const MmStatusPill(this.label, {super.key, this.alert = false});

  final String label;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final MmSkin skin = context.skin;
    final Color fg = alert ? skin.color.alert : skin.color.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: ShapeDecoration(
        shape: mmShapeBorder(
          MmShape(
              corner: skin.shape.corner == MmCorner.chamfer
                  ? MmCorner.chamfer
                  : MmCorner.rounded,
              cornerSize: math.min(skin.shape.cornerSize, 6),
              borderWidth: 1),
          side: BorderSide(color: fg.withValues(alpha: .5)),
        ),
      ),
      child: Text(
        skin.type.upperHeadings ? label.toUpperCase() : label,
        style: TextStyle(
          fontFamily: skin.type.monoFamily,
          color: fg,
          fontSize: 10,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
