// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

/// R53 — renders a Markdown string to widgets with the app's
/// "futuristic" treatment: a monospace family throughout, tracked
/// uppercase headings with accent rules, pill'd inline code, framed
/// code blocks, and accent links. We parse with the pure-Dart
/// `markdown` package and walk the AST ourselves so the styling stays
/// under our control (and stays offline — images degrade to alt text).
class MarkdownView extends StatefulWidget {
  const MarkdownView(this.data, {super.key});

  final String data;

  @override
  State<MarkdownView> createState() => _MarkdownViewState();
}

class _MarkdownViewState extends State<MarkdownView> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  static const String _mono = 'monospace';

  @override
  void dispose() {
    for (final TapGestureRecognizer r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final TapGestureRecognizer r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final md.Document doc = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    );
    final List<md.Node> nodes =
        doc.parseLines(const LineSplitter().convert(widget.data));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _blocks(context, nodes),
    );
  }

  // --- Block level ---------------------------------------------------

  List<Widget> _blocks(BuildContext context, List<md.Node> nodes) {
    final List<Widget> out = <Widget>[];
    for (final md.Node node in nodes) {
      final Widget? w = _block(context, node);
      if (w != null) out.add(w);
    }
    return out;
  }

  Widget? _block(BuildContext context, md.Node node) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    if (node is md.Text) {
      final String t = node.text.trim();
      if (t.isEmpty) return null;
      return _para(context, <md.Node>[node]);
    }
    if (node is! md.Element) return null;

    switch (node.tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return _heading(context, node, int.parse(node.tag.substring(1)));
      case 'p':
        return _para(context, node.children ?? const <md.Node>[]);
      case 'pre':
        return _codeBlock(context, node);
      case 'blockquote':
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(14, 2, 8, 2),
          decoration: BoxDecoration(
            border: Border(
                left: BorderSide(color: cs.primary.withValues(alpha: .7), width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _blocks(context, node.children ?? const <md.Node>[]),
          ),
        );
      case 'ul':
        return _list(context, node, ordered: false);
      case 'ol':
        return _list(context, node, ordered: true);
      case 'hr':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Container(height: 1, color: cs.primary.withValues(alpha: .4)),
        );
      case 'table':
        return _table(context, node);
      case 'img':
        return _para(context, <md.Node>[node]);
      default:
        final List<Widget> kids =
            _blocks(context, node.children ?? const <md.Node>[]);
        if (kids.isEmpty) return null;
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: kids);
    }
  }

  Widget _heading(BuildContext context, md.Element node, int level) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double size = switch (level) {
      1 => 22,
      2 => 18,
      3 => 15,
      _ => 13.5,
    };
    final Color color = level == 1 || level == 3 ? cs.primary : cs.onSurface;
    final TextStyle style = TextStyle(
      fontFamily: _mono,
      fontSize: size,
      height: 1.3,
      letterSpacing: level <= 2 ? 2.5 : 1.4,
      fontWeight: FontWeight.w700,
      color: color,
    );
    final Widget text = RichText(
      text: TextSpan(
        children: _inline(context, node.children ?? const <md.Node>[],
            base: style, upper: true),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(top: level <= 2 ? 18 : 12, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          text,
          if (level <= 2)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                height: level == 1 ? 2 : 1,
                color: cs.primary
                    .withValues(alpha: level == 1 ? .65 : .3),
              ),
            ),
        ],
      ),
    );
  }

  Widget _para(BuildContext context, List<md.Node> children) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextStyle base = TextStyle(
      fontFamily: _mono,
      fontSize: 14,
      height: 1.55,
      color: cs.onSurface,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(children: _inline(context, children, base: base)),
      ),
    );
  }

  Widget _codeBlock(BuildContext context, md.Element pre) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String code = pre.textContent.replaceAll(RegExp(r'\n$'), '');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outline.withValues(alpha: .4)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          code,
          style: TextStyle(
            fontFamily: _mono,
            fontSize: 12.5,
            height: 1.45,
            color: cs.onSurface.withValues(alpha: .92),
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, md.Element node,
      {required bool ordered}) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<md.Node> items = (node.children ?? const <md.Node>[])
        .whereType<md.Element>()
        .where((md.Element e) => e.tag == 'li')
        .toList();
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      final md.Element li = items[i] as md.Element;
      final String marker = ordered ? '${i + 1}.' : '▹';
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: ordered ? 26 : 18,
              child: Text(marker,
                  style: TextStyle(
                      fontFamily: _mono,
                      fontSize: 14,
                      height: 1.55,
                      color: cs.primary,
                      fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _liContent(context, li),
              ),
            ),
          ],
        ),
      ));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: rows),
    );
  }

  /// A list item may hold loose text + nested blocks (sub-lists). Render
  /// inline children as a paragraph and recurse into block children.
  List<Widget> _liContent(BuildContext context, md.Element li) {
    final List<md.Node> kids = li.children ?? const <md.Node>[];
    final List<md.Node> inline = <md.Node>[];
    final List<Widget> out = <Widget>[];
    void flush() {
      if (inline.isEmpty) return;
      final ColorScheme cs = Theme.of(context).colorScheme;
      out.add(RichText(
        text: TextSpan(
          children: _inline(context, List<md.Node>.of(inline),
              base: TextStyle(
                  fontFamily: _mono,
                  fontSize: 14,
                  height: 1.55,
                  color: cs.onSurface)),
        ),
      ));
      inline.clear();
    }

    for (final md.Node k in kids) {
      if (k is md.Element &&
          (k.tag == 'ul' ||
              k.tag == 'ol' ||
              k.tag == 'pre' ||
              k.tag == 'blockquote')) {
        flush();
        final Widget? w = _block(context, k);
        if (w != null) out.add(w);
      } else if (k is md.Element && k.tag == 'p') {
        inline.addAll(k.children ?? const <md.Node>[]);
        flush();
      } else {
        inline.add(k);
      }
    }
    flush();
    return out;
  }

  Widget _table(BuildContext context, md.Element table) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<TableRow> rows = <TableRow>[];
    for (final md.Node section in table.children ?? const <md.Node>[]) {
      if (section is! md.Element) continue;
      final bool head = section.tag == 'thead';
      for (final md.Node tr in section.children ?? const <md.Node>[]) {
        if (tr is! md.Element || tr.tag != 'tr') continue;
        final List<Widget> cells = <Widget>[];
        for (final md.Node cell in tr.children ?? const <md.Node>[]) {
          if (cell is! md.Element) continue;
          cells.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: RichText(
              text: TextSpan(
                children: _inline(
                    context, cell.children ?? const <md.Node>[],
                    base: TextStyle(
                      fontFamily: _mono,
                      fontSize: 12.5,
                      height: 1.4,
                      color: head ? cs.primary : cs.onSurface,
                      fontWeight:
                          head ? FontWeight.w700 : FontWeight.w400,
                    )),
              ),
            ),
          ));
        }
        rows.add(TableRow(
          decoration: head
              ? BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: .4))
              : null,
          children: cells,
        ));
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: cs.outline.withValues(alpha: .4)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder.symmetric(
              inside: BorderSide(color: cs.outline.withValues(alpha: .25)),
            ),
            children: rows,
          ),
        ),
      ),
    );
  }

  // --- Inline level --------------------------------------------------

  List<InlineSpan> _inline(BuildContext context, List<md.Node> nodes,
      {required TextStyle base, bool upper = false}) {
    final List<InlineSpan> spans = <InlineSpan>[];
    for (final md.Node node in nodes) {
      if (node is md.Text) {
        String t = node.text;
        if (upper) t = t.toUpperCase();
        spans.add(TextSpan(text: t, style: base));
        continue;
      }
      if (node is! md.Element) continue;
      final List<md.Node> kids = node.children ?? const <md.Node>[];
      switch (node.tag) {
        case 'strong':
          spans.addAll(_inline(context, kids,
              base: base.copyWith(fontWeight: FontWeight.w700), upper: upper));
          break;
        case 'em':
          spans.addAll(_inline(context, kids,
              base: base.copyWith(fontStyle: FontStyle.italic), upper: upper));
          break;
        case 'del':
          spans.addAll(_inline(context, kids,
              base: base.copyWith(decoration: TextDecoration.lineThrough),
              upper: upper));
          break;
        case 'code':
          final ColorScheme cs = Theme.of(context).colorScheme;
          spans.add(TextSpan(
            text: node.textContent,
            style: base.copyWith(
              fontFamily: _mono,
              color: cs.primary,
              backgroundColor: cs.surfaceContainerHighest.withValues(alpha: .6),
            ),
          ));
          break;
        case 'a':
          spans.add(_link(context, node, base));
          break;
        case 'br':
          spans.add(const TextSpan(text: '\n'));
          break;
        case 'img':
          final String alt = node.attributes['alt'] ?? 'image';
          spans.add(TextSpan(
            text: '🖼 $alt',
            style: base.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ));
          break;
        default:
          spans.addAll(_inline(context, kids, base: base, upper: upper));
      }
    }
    return spans;
  }

  InlineSpan _link(BuildContext context, md.Element node, TextStyle base) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String? href = node.attributes['href'];
    final TapGestureRecognizer recognizer = TapGestureRecognizer()
      ..onTap = () {
        if (href == null) return;
        final Uri? uri = Uri.tryParse(href);
        if (uri != null) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      };
    _recognizers.add(recognizer);
    return TextSpan(
      children: _inline(context, node.children ?? const <md.Node>[],
          base: base.copyWith(
            color: cs.primary,
            decoration: TextDecoration.underline,
            decorationColor: cs.primary.withValues(alpha: .6),
          )),
      recognizer: href == null ? null : recognizer,
    );
  }
}
