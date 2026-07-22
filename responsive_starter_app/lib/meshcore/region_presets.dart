// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import '../gen/app_localizations.dart';

/// R39 — LoRa region presets + geofence resolver.
///
/// Values are community-curated, mirrored from the canonical
/// MeshCore-companion preset table maintained at
/// github.com/zjs81/meshcore-open and gotnull/socialmesh (which both
/// import the same set the reference Liam Cottle / MeshCore-Web
/// companion uses). They are **not** regulatory guarantees — they
/// are the operating points the community has converged on within
/// each country's ISM band. The user remains responsible for
/// confirming legality where they are.
///
/// Why mirror rather than fetch: the app is offline-first
/// (mesh radio first, network second), so the presets are baked
/// into the binary. They evolve maybe once a year; bumping the app
/// is the right cadence.
class RegionPreset {
  const RegionPreset({
    required this.id,
    required this.label,
    required this.frequencyMhz,
    required this.bandwidthKhz,
    required this.spreadingFactor,
    required this.codingRate,
    required this.txPowerDbm,
    this.note,
  });

  /// Stable identifier used for shared_preferences persistence.
  /// Snake_case, never translated.
  final String id;

  /// User-visible label. Place names are NOT translated.
  final String label;

  final double frequencyMhz;
  final double bandwidthKhz;
  final int spreadingFactor;

  /// Coding rate denominator: 5 → 4/5, 6 → 4/6, 7 → 4/7, 8 → 4/8.
  final int codingRate;

  /// Recommended TX power in dBm. Firmware caps to the hardware /
  /// regulatory limit regardless.
  final int txPowerDbm;

  /// Optional one-line regulatory hint shown under the preset chip.
  final String? note;
}

const String kCustomPresetId = 'custom';

/// All shipped region presets, in roughly alphabetical-by-region
/// order. Selecting one prefills the radio params; matching
/// firmware values back to a preset uses [matchPresetByRadioParams].
const List<RegionPreset> kRegionPresets = <RegionPreset>[
  // --- North America ---
  RegionPreset(
    id: 'us_canada',
    label: 'USA / Canada',
    frequencyMhz: 910.525,
    bandwidthKhz: 62.5,
    spreadingFactor: 7,
    codingRate: 5,
    txPowerDbm: 22,
    note: 'FCC 902–928 MHz ISM · ≤30 dBm',
  ),
  RegionPreset(
    id: 'us_arizona',
    label: 'USA — Arizona',
    frequencyMhz: 908.205,
    bandwidthKhz: 62.5,
    spreadingFactor: 10,
    codingRate: 5,
    txPowerDbm: 20,
    note: 'AZ regional variant',
  ),
  // --- Japan ---
  // ARIB STD-T108 CH37 (923.2 MHz centre) — a valid 200 kHz unit
  // channel; our 125 kHz signal fits inside it. This is also the
  // LoRaWAN AS923-JP / Meshtastic-JP default region, so it aligns
  // with those ecosystems (NOT with the nascent MeshCore-JP
  // community proposal, which is 920.8 MHz / SF12 / CR 4/8 — see
  // MeshCore issues #2079 JP_STRICT and #2218 ARIB-LBT, both still
  // open mid-2026; the earlier #460 was parked without shipping a
  // preset, so MeshCore ships no canonical JP entry).
  //
  // Regulatory basis (license-free 特定小電力, verified 2026-07):
  //  - Power: ≤13 dBm (20 mW) conducted, referenced to a ≤3 dBi
  //    antenna (≈16 dBm EIRP ceiling). Higher gain → cut conducted.
  //  - LBT: carrier sense at −80 dBm; minimum sense 128 µs (the
  //    "5 ms" figure is the long-burst class boundary, not the
  //    floor). Mandated + enforced by the device FIRMWARE, not us.
  //  - Duty: CH33–38 (incl. CH37) cap TX at ≤360 s per rolling
  //    hour (~10%). A chatty mesh must respect this.
  //  - 技適: legal params do NOT make operation legal — the radio
  //    HARDWARE must be 技適-certified. Most grey-import LoRa boards
  //    are not. Surfaced in deviceRegionDisclaimer.
  RegionPreset(
    id: 'jp_arib_t108',
    label: 'Japan (ARIB STD-T108)',
    frequencyMhz: 923.2,
    bandwidthKhz: 125,
    spreadingFactor: 10,
    codingRate: 5,
    txPowerDbm: 13,
    note: '920 MHz CH37 · LBT required · ≤10%/h duty · ≤13 dBm',
  ),
  // MeshCore-JP community convention (proposal-stage, small user
  // base): 920.8 MHz = ARIB CH25, in the CH24–32 group which — in
  // long-sense LBT mode — carries no explicit hourly duty cap (unlike
  // CH33–38). SF12 / CR 4/8 is their deliberate max-range choice. This
  // is the tuple to pick to interoperate with other MeshCore-JP nodes;
  // it will NOT reach the ARIB-T108 default preset above. Same legal
  // basis (≤13 dBm conducted, mandatory firmware LBT, 技適 hardware).
  // Source: MeshCore issues #2079 / #2218 (@jirogit), open mid-2026.
  RegionPreset(
    id: 'jp_meshcore',
    label: 'Japan (MeshCore-JP)',
    frequencyMhz: 920.8,
    bandwidthKhz: 125,
    spreadingFactor: 12,
    codingRate: 8,
    txPowerDbm: 13,
    note: '920.8 MHz CH25 · LBT required · ≤13 dBm · MeshCore-JP',
  ),
  // --- EU / UK ---
  RegionPreset(
    id: 'eu_uk_long',
    label: 'EU / UK (Long Range)',
    frequencyMhz: 869.525,
    bandwidthKhz: 250,
    spreadingFactor: 11,
    codingRate: 5,
    txPowerDbm: 14,
    note: 'ERC 869.4–869.65 · ≤27 dBm',
  ),
  RegionPreset(
    id: 'eu_uk_medium',
    label: 'EU / UK (Medium Range)',
    frequencyMhz: 869.525,
    bandwidthKhz: 250,
    spreadingFactor: 10,
    codingRate: 5,
    txPowerDbm: 14,
  ),
  RegionPreset(
    id: 'eu_uk_narrow',
    label: 'EU / UK (Narrow)',
    frequencyMhz: 869.618,
    bandwidthKhz: 62.5,
    spreadingFactor: 8,
    codingRate: 5,
    txPowerDbm: 14,
  ),
  RegionPreset(
    id: 'ch',
    label: 'Switzerland',
    frequencyMhz: 869.618,
    bandwidthKhz: 62.5,
    spreadingFactor: 8,
    codingRate: 5,
    txPowerDbm: 14,
  ),
  RegionPreset(
    id: 'cz',
    label: 'Czech Republic',
    frequencyMhz: 869.432,
    bandwidthKhz: 62.5,
    spreadingFactor: 7,
    codingRate: 5,
    txPowerDbm: 14,
  ),
  RegionPreset(
    id: 'pt_869',
    label: 'Portugal (869 MHz)',
    frequencyMhz: 869.618,
    bandwidthKhz: 62.5,
    spreadingFactor: 7,
    codingRate: 5,
    txPowerDbm: 14,
  ),
  // --- Australia / NZ ---
  RegionPreset(
    id: 'au_default',
    label: 'Australia',
    frequencyMhz: 915.8,
    bandwidthKhz: 250,
    spreadingFactor: 10,
    codingRate: 5,
    txPowerDbm: 20,
  ),
  RegionPreset(
    id: 'au_narrow',
    label: 'Australia (Narrow)',
    frequencyMhz: 916.575,
    bandwidthKhz: 62.5,
    spreadingFactor: 7,
    codingRate: 5,
    txPowerDbm: 20,
  ),
  RegionPreset(
    id: 'au_sa_wa_qld',
    label: 'Australia (SA / WA / QLD)',
    frequencyMhz: 923.125,
    bandwidthKhz: 62.5,
    spreadingFactor: 8,
    codingRate: 5,
    txPowerDbm: 20,
  ),
  RegionPreset(
    id: 'nz_default',
    label: 'New Zealand',
    frequencyMhz: 917.375,
    bandwidthKhz: 250,
    spreadingFactor: 11,
    codingRate: 5,
    txPowerDbm: 20,
  ),
  // --- SE Asia ---
  RegionPreset(
    id: 'vn',
    label: 'Vietnam',
    frequencyMhz: 920.250,
    bandwidthKhz: 250,
    spreadingFactor: 11,
    codingRate: 5,
    txPowerDbm: 20,
  ),
];

/// Returns the preset whose four LoRa params match the live device
/// values. Bandwidth uses a 0.5 kHz tolerance and frequency uses a
/// 1 kHz tolerance to absorb float rounding from the wire format
/// (uint32 ÷ 1000). Returns null if no match → caller should treat
/// the current config as "Custom".
RegionPreset? matchPresetByRadioParams({
  required double frequencyMhz,
  required double bandwidthKhz,
  required int spreadingFactor,
  required int codingRate,
}) {
  for (final RegionPreset p in kRegionPresets) {
    if ((p.frequencyMhz - frequencyMhz).abs() > 0.001) continue;
    if ((p.bandwidthKhz - bandwidthKhz).abs() > 0.5) continue;
    if (p.spreadingFactor != spreadingFactor) continue;
    if (p.codingRate != codingRate) continue;
    return p;
  }
  return null;
}

/// Translate a preset id to a locale-appropriate label. Place names
/// don't strictly translate, but the Japanese locale (for example)
/// expects 米国/カナダ rather than "USA / Canada" in the chip text.
/// Falls back to the English [RegionPreset.label] when l10n has no
/// key for the id.
String localizedPresetLabel(AppLocalizations l, String presetId) {
  switch (presetId) {
    case 'us_canada':
      return l.presetUsCanada;
    case 'us_arizona':
      return l.presetUsArizona;
    case 'jp_arib_t108':
      return l.presetJpAribT108;
    case 'jp_meshcore':
      return l.presetJpMeshcore;
    case 'eu_uk_long':
      return l.presetEuUkLong;
    case 'eu_uk_medium':
      return l.presetEuUkMedium;
    case 'eu_uk_narrow':
      return l.presetEuUkNarrow;
    case 'ch':
      return l.presetCh;
    case 'cz':
      return l.presetCz;
    case 'pt_869':
      return l.presetPt869;
    case 'au_default':
      return l.presetAu;
    case 'au_narrow':
      return l.presetAuNarrow;
    case 'au_sa_wa_qld':
      return l.presetAuSaWaQld;
    case 'nz_default':
      return l.presetNz;
    case 'vn':
      return l.presetVn;
  }
  // Unknown id: return the English label so a freshly-added
  // preset doesn't render as empty.
  return presetById(presetId)?.label ?? presetId;
}

/// Lookup by id, or null if [id] is `'custom'` / unknown.
RegionPreset? presetById(String id) {
  for (final RegionPreset p in kRegionPresets) {
    if (p.id == id) return p;
  }
  return null;
}

/// Coarse country bounding box → preset id resolver, used by the
/// first-run wizard / "Suggest from my location" path. Boxes
/// deliberately overlap (e.g. Mexico inside the North America 902-928
/// ISM region uses the same `us_canada` preset, which is correct);
/// when multiple match, the **first** match in this table wins, so
/// narrower country-specific entries are listed before broader ones.
///
/// This is geofencing, not legal advice: a fix near a national
/// border may pick the neighbouring country's preset, so the UI
/// always shows the suggested label + asks the user to confirm.
List<({double latMin, double latMax, double lonMin, double lonMax,
       String presetId})> _kCountryBoxes() => const <
    ({
      double latMin,
      double latMax,
      double lonMin,
      double lonMax,
      String presetId
    })>[
  // Narrow regional preset BEFORE the broader US box.
  (
    latMin: 31.0,
    latMax: 37.0,
    lonMin: -115.0,
    lonMax: -109.0,
    presetId: 'us_arizona',
  ),
  // Continental USA + AK + HI (broad).
  (
    latMin: 18.0,
    latMax: 72.0,
    lonMin: -180.0,
    lonMax: -65.0,
    presetId: 'us_canada',
  ),
  // Canada — same 902-928 ISM band as the US.
  (
    latMin: 41.0,
    latMax: 84.0,
    lonMin: -141.0,
    lonMax: -52.0,
    presetId: 'us_canada',
  ),
  // Japan archipelago (Hokkaido down to Yaeyama; includes Okinawa).
  (
    latMin: 24.0,
    latMax: 46.0,
    lonMin: 122.0,
    lonMax: 146.0,
    presetId: 'jp_arib_t108',
  ),
  // Vietnam.
  (
    latMin: 8.0,
    latMax: 24.0,
    lonMin: 102.0,
    lonMax: 110.0,
    presetId: 'vn',
  ),
  // Australia — broad box; users west of ~129°E should pick the
  // SA/WA/QLD preset manually, but the default-narrow is also
  // legal.
  (
    latMin: -44.0,
    latMax: -10.0,
    lonMin: 112.0,
    lonMax: 154.0,
    presetId: 'au_default',
  ),
  // New Zealand main + Stewart.
  (
    latMin: -47.5,
    latMax: -34.0,
    lonMin: 165.0,
    lonMax: 179.5,
    presetId: 'nz_default',
  ),
  // EU country-specific overrides (BEFORE the broad EU box).
  (
    latMin: 36.9,
    latMax: 42.2,
    lonMin: -9.6,
    lonMax: -6.1,
    presetId: 'pt_869',
  ),
  (
    latMin: 45.8,
    latMax: 47.9,
    lonMin: 5.9,
    lonMax: 10.6,
    presetId: 'ch',
  ),
  (
    latMin: 48.5,
    latMax: 51.1,
    lonMin: 12.0,
    lonMax: 18.9,
    presetId: 'cz',
  ),
  // Broad EU / UK / EEA — 869 MHz long-range default.
  (
    latMin: 34.0,
    latMax: 71.5,
    lonMin: -11.0,
    lonMax: 32.0,
    presetId: 'eu_uk_long',
  ),
];

/// Geofence-based preset suggestion. Returns null when [lat]/[lon]
/// fall outside every shipped country box (e.g. ocean, polar, or a
/// country we don't yet have a preset for). Caller should fall
/// through to manual picker in that case.
RegionPreset? suggestPresetForLatLon(double lat, double lon) {
  for (final box in _kCountryBoxes()) {
    if (lat < box.latMin || lat > box.latMax) continue;
    if (lon < box.lonMin || lon > box.lonMax) continue;
    return presetById(box.presetId);
  }
  return null;
}
