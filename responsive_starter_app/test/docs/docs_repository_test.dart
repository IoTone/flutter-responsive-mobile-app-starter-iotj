// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshmore_sns_app/docs/doc_section.dart';
import 'package:meshmore_sns_app/docs/docs_repository.dart';

/// Asset bundle that serves canned strings for the docs assets.
class _FakeBundle extends AssetBundle {
  _FakeBundle(this.contents);
  final Map<String, String> contents;

  @override
  Future<ByteData> load(String key) => throw UnimplementedError();

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final String? v = contents[key];
    if (v == null) throw Exception('no asset $key');
    return v;
  }
}

void main() {
  const String protoAsset = 'assets/docs/protocol.md';
  const String fwAsset = 'assets/docs/firmware.md';

  late _FakeBundle bundle;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    bundle = _FakeBundle(<String, String>{
      protoAsset: '# Protocol\nbundled',
      fwAsset: '# Firmware\nbundled',
      'assets/docs/app.md': '# App\nbundled',
    });
  });

  group('DocSpec.remoteUrls', () {
    test('firmware tries the version tag first, then main', () {
      final List<Uri> urls = DocSpec.of(DocSection.firmware)
          .remoteUrls(firmwareVersion: 'v1.7.0');
      expect(urls.length, 2);
      expect(urls.first.toString(), contains('/v1.7.0/README.md'));
      expect(urls.last.toString(), contains('/main/README.md'));
    });

    test('firmware with no version falls back to main only', () {
      final List<Uri> urls =
          DocSpec.of(DocSection.firmware).remoteUrls(firmwareVersion: null);
      expect(urls.length, 1);
      expect(urls.single.toString(), contains('/main/README.md'));
    });

    test('app section has no remote source', () {
      expect(DocSpec.of(DocSection.app).remoteUrls(), isEmpty);
    });
  });

  group('load', () {
    test('returns the bundled snapshot when nothing is cached', () async {
      final DocsRepository repo =
          DocsRepository(bundle: bundle, fetcher: (_) async => null);
      final DocContent c = await repo.load(DocSection.protocol);
      expect(c.origin, DocOrigin.bundled);
      expect(c.markdown, contains('bundled'));
      expect(c.fetchedAt, isNull);
    });

    test('prefers the cached copy once one exists', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'mm.docs.protocol.text': '# Protocol\nCACHED',
        'mm.docs.protocol.at': '2026-06-03T00:00:00.000',
        'mm.docs.protocol.url': 'https://example/proto.md',
      });
      final DocsRepository repo =
          DocsRepository(bundle: bundle, fetcher: (_) async => null);
      final DocContent c = await repo.load(DocSection.protocol);
      expect(c.origin, DocOrigin.cached);
      expect(c.markdown, contains('CACHED'));
      expect(c.sourceUrl, 'https://example/proto.md');
    });
  });

  group('refresh', () {
    test('caches upstream when it differs from what we hold', () async {
      final DocsRepository repo = DocsRepository(
          bundle: bundle, fetcher: (_) async => '# Protocol\nNEWER');
      final DateTime when = DateTime(2026, 6, 3, 12);
      final DocContent? updated =
          await repo.refresh(DocSection.protocol, now: when);
      expect(updated, isNotNull);
      expect(updated!.origin, DocOrigin.cached);
      expect(updated.markdown, contains('NEWER'));
      expect(updated.fetchedAt, when);

      // The next load now serves the cached copy.
      final DocContent reloaded = await repo.load(DocSection.protocol);
      expect(reloaded.origin, DocOrigin.cached);
      expect(reloaded.markdown, contains('NEWER'));
    });

    test('no-op when upstream matches the current copy', () async {
      final DocsRepository repo = DocsRepository(
          bundle: bundle, fetcher: (_) async => '# Protocol\nbundled');
      final DocContent? updated = await repo.refresh(DocSection.protocol);
      expect(updated, isNull);
    });

    test('no-op (offline) when the fetch fails', () async {
      final DocsRepository repo =
          DocsRepository(bundle: bundle, fetcher: (_) async => null);
      expect(await repo.refresh(DocSection.protocol), isNull);
    });

    test('app section never hits the network', () async {
      bool fetched = false;
      final DocsRepository repo = DocsRepository(
          bundle: bundle,
          fetcher: (_) async {
            fetched = true;
            return '# App\nremote';
          });
      expect(await repo.refresh(DocSection.app), isNull);
      expect(fetched, isFalse);
    });

    test('falls through to the next URL when the first returns null',
        () async {
      final List<Uri> seen = <Uri>[];
      final DocsRepository repo = DocsRepository(
        bundle: bundle,
        fetcher: (Uri url) async {
          seen.add(url);
          return url.toString().contains('/main/') ? '# Firmware\nMAIN' : null;
        },
      );
      final DocContent? updated = await repo.refresh(
        DocSection.firmware,
        firmwareVersion: 'v1.7.0',
      );
      expect(updated, isNotNull);
      expect(updated!.markdown, contains('MAIN'));
      expect(updated.sourceUrl, contains('/main/README.md'));
      // The tag URL was attempted first.
      expect(seen.first.toString(), contains('/v1.7.0/'));
    });
  });

  test('clearCache reverts load to the bundled snapshot', () async {
    final DocsRepository repo = DocsRepository(
        bundle: bundle, fetcher: (_) async => '# Protocol\nNEWER');
    await repo.refresh(DocSection.protocol);
    expect((await repo.load(DocSection.protocol)).origin, DocOrigin.cached);
    await repo.clearCache(DocSection.protocol);
    expect((await repo.load(DocSection.protocol)).origin, DocOrigin.bundled);
  });
}
