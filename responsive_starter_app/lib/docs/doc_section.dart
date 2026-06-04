// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT

/// R53 — the three documentation sections surfaced under the Docs tab.
///
/// Each section has a baked-in offline snapshot (an asset) and, except
/// for [app] (which we self-author and ship), an upstream source on
/// GitHub that we refresh from opportunistically when online.
enum DocSection { protocol, firmware, app }

/// Where the markdown a reader is showing came from.
enum DocOrigin {
  /// The snapshot baked into the app bundle.
  bundled,

  /// A copy fetched from upstream and cached locally.
  cached,
}

/// Static metadata for a [DocSection]: its bundled asset and the
/// upstream URL(s) to try, newest-first, when refreshing.
class DocSpec {
  const DocSpec(this.section, this.assetPath);

  final DocSection section;
  final String assetPath;

  /// SharedPreferences key prefix for the cached copy.
  String get prefsKey => 'mm.docs.${section.name}';

  /// Upstream URLs to try in order when refreshing, newest-first.
  /// Empty = no remote (self-authored; ships with the app).
  ///
  /// For [DocSection.firmware] we try the README at the tag matching
  /// the connected device's firmware version first, then fall back to
  /// `main` so a refresh still lands if the tag doesn't exist.
  List<Uri> remoteUrls({String? firmwareVersion}) {
    switch (section) {
      case DocSection.protocol:
        return <Uri>[
          Uri.parse('https://raw.githubusercontent.com/wiki/'
              'meshcore-dev/MeshCore/Companion-Radio-Protocol.md'),
        ];
      case DocSection.firmware:
        final String? tag = _firmwareTag(firmwareVersion);
        return <Uri>[
          if (tag != null)
            Uri.parse('https://raw.githubusercontent.com/'
                'meshcore-dev/MeshCore/$tag/README.md'),
          Uri.parse('https://raw.githubusercontent.com/'
              'meshcore-dev/MeshCore/main/README.md'),
        ];
      case DocSection.app:
        return const <Uri>[];
    }
  }

  /// Normalise a device firmware version string into a plausible git
  /// tag (`v1.7.0`). Returns null if we can't extract a version.
  static String? _firmwareTag(String? version) {
    if (version == null) return null;
    final RegExpMatch? m =
        RegExp(r'(\d+\.\d+(?:\.\d+)?)').firstMatch(version);
    if (m == null) return null;
    return 'v${m.group(1)}';
  }

  static const Map<DocSection, DocSpec> all = <DocSection, DocSpec>{
    DocSection.protocol: DocSpec(DocSection.protocol, 'assets/docs/protocol.md'),
    DocSection.firmware: DocSpec(DocSection.firmware, 'assets/docs/firmware.md'),
    DocSection.app: DocSpec(DocSection.app, 'assets/docs/app.md'),
  };

  static DocSpec of(DocSection s) => all[s]!;
}

/// A loaded document: its markdown text plus provenance for the UI.
class DocContent {
  const DocContent({
    required this.section,
    required this.markdown,
    required this.origin,
    this.fetchedAt,
    this.sourceUrl,
  });

  final DocSection section;
  final String markdown;
  final DocOrigin origin;

  /// When the cached copy was fetched (null for [DocOrigin.bundled]).
  final DateTime? fetchedAt;

  /// The upstream URL the cached copy came from (null when bundled).
  final String? sourceUrl;
}
