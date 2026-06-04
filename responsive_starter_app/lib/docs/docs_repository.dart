// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'doc_section.dart';

/// Fetches the text at [url], or null on any failure (offline, 404,
/// timeout). Injectable so the repository is testable without network.
typedef DocFetcher = Future<String?> Function(Uri url);

/// R53 — loads documentation for the Docs reader.
///
/// **Offline-first:** [load] always returns immediately from the cached
/// copy if present, otherwise the baked-in bundled snapshot — it never
/// touches the network. [refresh] is the opportunistic part: it pulls
/// the upstream copy, and if it differs from what we hold, caches it so
/// the next [load] serves the newer text. A failed refresh is a no-op
/// (the reader keeps showing what it had).
class DocsRepository {
  DocsRepository({DocFetcher? fetcher, AssetBundle? bundle})
      : _fetch = fetcher ?? _httpGet,
        _bundle = bundle ?? rootBundle;

  final DocFetcher _fetch;
  final AssetBundle _bundle;

  /// Load the section's current best copy: cached if we have one, else
  /// the bundled snapshot. Never hits the network.
  Future<DocContent> load(DocSection section) async {
    final DocSpec spec = DocSpec.of(section);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? cached = prefs.getString('${spec.prefsKey}.text');
    if (cached != null && cached.isNotEmpty) {
      return DocContent(
        section: section,
        markdown: cached,
        origin: DocOrigin.cached,
        fetchedAt: DateTime.tryParse(
            prefs.getString('${spec.prefsKey}.at') ?? ''),
        sourceUrl: prefs.getString('${spec.prefsKey}.url'),
      );
    }
    final String bundled = await _bundle.loadString(spec.assetPath);
    return DocContent(
      section: section,
      markdown: bundled,
      origin: DocOrigin.bundled,
    );
  }

  /// Opportunistically fetch the upstream copy. Returns the freshly
  /// cached [DocContent] if something newer was pulled, or null if the
  /// section has no remote, the fetch failed, or the text is unchanged
  /// from what we already hold.
  Future<DocContent?> refresh(
    DocSection section, {
    String? firmwareVersion,
    DateTime? now,
  }) async {
    final DocSpec spec = DocSpec.of(section);
    final List<Uri> urls = spec.remoteUrls(firmwareVersion: firmwareVersion);
    if (urls.isEmpty) return null;

    String? fetched;
    Uri? from;
    for (final Uri url in urls) {
      final String? text = await _fetch(url);
      if (text != null && text.trim().isNotEmpty) {
        fetched = text;
        from = url;
        break;
      }
    }
    if (fetched == null || from == null) return null;

    // Compare against whatever we'd currently serve to avoid a pointless
    // write + "updated" signal when upstream hasn't changed.
    final DocContent current = await load(section);
    if (_normalise(fetched) == _normalise(current.markdown)) return null;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final DateTime stamp = now ?? DateTime.now();
    await prefs.setString('${spec.prefsKey}.text', fetched);
    await prefs.setString('${spec.prefsKey}.at', stamp.toIso8601String());
    await prefs.setString('${spec.prefsKey}.url', from.toString());
    return DocContent(
      section: section,
      markdown: fetched,
      origin: DocOrigin.cached,
      fetchedAt: stamp,
      sourceUrl: from.toString(),
    );
  }

  /// Drop the cached copy for a section, reverting [load] to the
  /// bundled snapshot.
  Future<void> clearCache(DocSection section) async {
    final DocSpec spec = DocSpec.of(section);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('${spec.prefsKey}.text');
    await prefs.remove('${spec.prefsKey}.at');
    await prefs.remove('${spec.prefsKey}.url');
  }

  static String _normalise(String s) => s.replaceAll('\r\n', '\n').trim();

  /// Default network fetcher: a plain GET over dart:io with a short
  /// timeout. Returns null on any non-200 / error so callers treat the
  /// device as simply offline.
  static Future<String?> _httpGet(Uri url) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final HttpClientRequest req = await client.getUrl(url);
      final HttpClientResponse resp = await req.close();
      if (resp.statusCode != 200) return null;
      return await resp.transform(utf8.decoder).join();
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
