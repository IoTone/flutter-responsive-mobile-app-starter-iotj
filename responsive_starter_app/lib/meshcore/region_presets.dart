// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT

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
  // ARIB STD-T108 ch.32 (923.2 MHz centre), 125 kHz, SF10. LBT
  // (listen-before-talk) is mandated and is enforced by the
  // device firmware — NOT by this app. The 13 dBm TX is the
  // ceiling for ARIB 920 MHz 1 mW EIRP-class operation.
  RegionPreset(
    id: 'jp_arib_t108',
    label: 'Japan (ARIB STD-T108)',
    frequencyMhz: 923.2,
    bandwidthKhz: 125,
    spreadingFactor: 10,
    codingRate: 5,
    txPowerDbm: 13,
    note: '920 MHz · LBT ≥5 ms · ≤13 dBm',
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
