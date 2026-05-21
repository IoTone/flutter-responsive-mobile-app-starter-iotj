// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Meshmore SNS';

  @override
  String get appSubtitle => 'Socialrobot Network Service';

  @override
  String get tabDashboard => 'Dashboard';

  @override
  String get tabChat => 'Chat';

  @override
  String get tabNodes => 'Nodes';

  @override
  String get tabSettings => 'Settings';

  @override
  String get tabAbout => 'About';

  @override
  String get dashboardPeersInRange => 'PEERS IN RANGE';

  @override
  String dashboardKnownCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n known',
      one: '1 known',
      zero: '0 known',
    );
    return '$_temp0';
  }

  @override
  String get dashboardRadio => 'RADIO';

  @override
  String get dashboardLocation => 'LOCATION';

  @override
  String get dashboardBattery => 'BATTERY';

  @override
  String get dashboardRecent => 'RECENT';

  @override
  String get dashboardNoActivity => '— no activity —';

  @override
  String get dashboardAwaitingDevice => '— awaiting device —';

  @override
  String get dashboardAwaitingDeviceLocation => '— awaiting device location —';

  @override
  String get dashboardLocationNotSet =>
      'Not set — neither device nor phone fix yet';

  @override
  String get dashboardLocationConfigure => 'CONFIGURE';

  @override
  String dashboardLocationSourceLabel(String source) {
    return 'source · $source';
  }

  @override
  String get statusLinked => 'LINKED · NO ALERTS';

  @override
  String get statusSyncing => 'SYNCING…';

  @override
  String get statusSyncingLong => 'SYNCING…';

  @override
  String get statusHandshaking => 'SYNCING…';

  @override
  String get statusReconnecting => 'RECONNECTING…';

  @override
  String get statusLinkLost => 'LINK LOST';

  @override
  String get statusOffline => 'OFFLINE';

  @override
  String get statusConnecting => 'CONNECTING…';

  @override
  String get actionConnect => 'CONNECT';

  @override
  String get actionRetry => 'RETRY';

  @override
  String get settingsHeading => 'App settings';

  @override
  String get settingsConnection => 'CONNECTION';

  @override
  String get settingsConnectionSubtitle =>
      'Auto-reconnect (M7 backoff) · forget device';

  @override
  String get settingsBackgroundTitle => 'Stay connected in background';

  @override
  String get settingsBackgroundOn =>
      'Android: a persistent notification keeps the radio linked so messages arrive while backgrounded';

  @override
  String get settingsBackgroundOff =>
      'Messages still arrive when you reopen the app (radio buffers them); no background notification';

  @override
  String get settingsLanguage => 'LANGUAGE';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageJapanese => '日本語';

  @override
  String get settingsSpeech => 'SPEECH (R5)';

  @override
  String get settingsSpeechOn =>
      'Text-to-speech ON · per-channel toggle in Chat';

  @override
  String get settingsSpeechOff =>
      'Text-to-speech OFF (default) · reads channel messages';

  @override
  String get settingsNotifications => 'NOTIFICATIONS';

  @override
  String get settingsNotificationsSubtitle =>
      'Critical → system notification + vibrate';

  @override
  String get settingsData => 'DATA / ABOUT';

  @override
  String get settingsDataSubtitle =>
      'Export diagnostics · logs · About · Terms';

  @override
  String get settingsPermissions => 'Permissions';

  @override
  String get settingsPermissionsSubtitle =>
      'Open the OS settings page for this app — flip Bluetooth / Notifications on or off here.';

  @override
  String get settingsShowIntro => 'Show intro again on next launch';

  @override
  String get settingsShowIntroEnabled =>
      'Wipes the first-run flag so the permissions intro shows again — useful when you\'re testing the flow';

  @override
  String get settingsShowIntroDisabled =>
      'Intro is currently scheduled for next launch';

  @override
  String get aboutCopyright => 'Copyright (c) 2026 IoTone, Inc.';

  @override
  String get aboutSubtitleEn => '(Socialrobot Network Service)';

  @override
  String get aboutSubtitleJa => '(ソーシャルロボット・ネットワークサービス)';

  @override
  String get aboutDescription => 'A MeshCore companion client.';

  @override
  String get aboutLicense => 'Licensed under the MIT (X11) License.';

  @override
  String get aboutMadeWith => 'Made with ♥ in Fukuoka, Japan';

  @override
  String get aboutTerms => 'Terms & Conditions — wired in U5.';

  @override
  String aboutVersion(String version) {
    return 'v$version';
  }

  @override
  String get personalizationHeading => 'Profile & personalization';

  @override
  String get personalizationThemePreset => 'THEME PRESET';

  @override
  String get personalizationType => 'TYPE';

  @override
  String get personalizationFontSize => 'Font size';

  @override
  String get personalizationAccessibility => 'ACCESSIBILITY (R13)';

  @override
  String get personalizationHighContrast => 'High contrast';

  @override
  String get personalizationHighContrastSubtitle =>
      'Force the SEELE high-contrast palette';

  @override
  String get personalizationHighContrastHint =>
      'High contrast is on — the SEELE high-contrast palette is forced regardless of your preset pick. Turn off High contrast below to use another theme.';

  @override
  String get personalizationReduceMotion => 'Reduce motion';

  @override
  String get personalizationVisualHapticOnly => 'Visual + haptic only';

  @override
  String get personalizationVisualHapticOnlySubtitle =>
      'No information by sound; turns audio off';

  @override
  String get personalizationAudioAlerts => 'AUDIO ALERTS (R12)';

  @override
  String get personalizationAudioMaster => 'Audio alerts';

  @override
  String get personalizationAudioMasterDisabled =>
      'Disabled by \"visual + haptic only\"';

  @override
  String get personalizationAudioMasterEnabled =>
      'Off by default; augmentation only';

  @override
  String get firstRunHeader => 'MESHMORE · WELCOME';

  @override
  String get firstRunTitle => 'Quick heads-up on what we\'ll ask for';

  @override
  String get firstRunBleTitle => 'Bluetooth';

  @override
  String get firstRunBleBody =>
      'To pair with your MeshCore radio and exchange messages over the local mesh. Required to send / receive over the air.';

  @override
  String get firstRunNotificationsTitle => 'Notifications';

  @override
  String get firstRunNotificationsBody =>
      'Asked only if you turn on \"Stay connected in background\" later in App settings. Skipped today so you\'re not interrupted twice.';

  @override
  String get firstRunOfflineTitle => 'Offline is fine';

  @override
  String get firstRunOfflineBody =>
      'If you skip Bluetooth, the app still works — browse message history, configure channels, read diagnostics. Just no live mesh traffic until you grant Bluetooth.';

  @override
  String get firstRunGrant => 'Grant Bluetooth & continue';

  @override
  String get firstRunSkip => 'Continue offline (skip permissions)';

  @override
  String get firstRunDeniedTransient =>
      'Bluetooth wasn\'t granted — you can continue offline or open OS settings to change your mind.';

  @override
  String get firstRunDeniedPermanent =>
      'Bluetooth was permanently denied — open OS settings to grant it. You can still use the app offline.';

  @override
  String get firstRunOpenSettings => 'Open OS settings';

  @override
  String dashboardPaired(String name) {
    return 'paired: $name';
  }

  @override
  String get dashboardCharging => 'CHARGING';

  @override
  String dashboardBatteryReadout(String volts, int percent) {
    return '${volts}V · ~$percent%';
  }

  @override
  String get nodesScanArea => 'Scan area';

  @override
  String get nodesScanning => 'Scanning…';

  @override
  String get nodesAdvertise => 'Advertise';

  @override
  String get nodesSyncContacts => 'Sync contacts';

  @override
  String get nodesHyperlocalGridTooltip => 'Hyperlocal grid (R18)';

  @override
  String get nodesFloodAdvert => 'Flood advert';

  @override
  String get nodesFloodAdvertBody =>
      'Whole mesh — neighbours + repeaters. Best for discovery.';

  @override
  String get nodesZeroHopAdvert => 'Zero-hop advert';

  @override
  String get nodesZeroHopAdvertBody =>
      'Direct neighbours only — not rebroadcast. Quieter on a busy mesh.';

  @override
  String get nodesFloodAdvertSent =>
      'Flood advert sent — propagates across the whole mesh (neighbours + repeaters). The other node must Advertise too before it appears here.';

  @override
  String get nodesZeroHopAdvertSent =>
      'Zero-hop advert sent — direct neighbours only, not rebroadcast by repeaters.';

  @override
  String get nodesSearchHint => 'Search by name, shortId, or pubkey…';

  @override
  String get nodesFilterStarred => 'Starred';

  @override
  String get nodesFilterInRange => 'In range';

  @override
  String get nodesFilterClear => 'Clear';

  @override
  String nodesFilterLastSeen(String label) {
    return 'Last seen · $label';
  }

  @override
  String nodesFilterWithin(String label) {
    return 'Within · $label';
  }

  @override
  String get nodesAgeAny => 'Any';

  @override
  String get nodesAgeHour => 'Last hour';

  @override
  String get nodesAge24h => 'Last 24 h';

  @override
  String get nodesAge7d => 'Last 7 d';

  @override
  String get nodesDistAny => 'Any';

  @override
  String get nodesDist100m => '≤ 100 m';

  @override
  String get nodesDist500m => '≤ 500 m';

  @override
  String get nodesDist5km => '≤ 5 km';

  @override
  String get nodesDist25km => '≤ 25 km';

  @override
  String nodesStatusReady(int shown, int total, int inRange, int favs) {
    String _temp0 = intl.Intl.pluralLogic(
      favs,
      locale: localeName,
      other: '$favs contacts',
      one: '1 contact',
      zero: '0 contacts',
    );
    return '$shown of $total in fabric · $inRange in range · $_temp0';
  }

  @override
  String get nodesStatusOffline =>
      'Not connected — Settings → Diagnostics & connect';

  @override
  String get nodesInRangeBadge => 'IN RANGE';

  @override
  String get nodesEmptyFiltered =>
      'No nodes match this filter.\n\nTap Clear to widen, or change the chip cutoffs above.';

  @override
  String get nodesEmptyReady =>
      'No nodes yet.\n\nDiscovery is advert-driven: a node shows up only when its advert is heard. Chatting on Public does NOT make a node appear.\n\nAsk the other node to Advertise / Share (or tap \"Advertise\" here so it can find you), then \"Scan area\".\n\nThis view shows the mesh \"fabric\" (what you\'ve seen). Star a node to mark it as a contact.';

  @override
  String get nodesEmptyOffline => 'Connect a radio to discover nearby nodes.';

  @override
  String get nodesFavTooltip => 'Favourite as contact';

  @override
  String get nodesUnfavTooltip => 'Unfavourite (remove from contacts)';

  @override
  String get gridTitle => 'Hyperlocal grid';

  @override
  String get gridShowLegend => 'Show legend';

  @override
  String get gridHideLegend => 'Hide legend';

  @override
  String get gridPlayTooltip => 'Play (refresh every interval)';

  @override
  String get gridPauseTooltip => 'Pause updates';

  @override
  String get gridIntervalTooltip => 'Refresh interval (when playing)';

  @override
  String get gridRange => 'Range';

  @override
  String get gridRangeRoom => 'Room';

  @override
  String get gridRangeHome => 'Home';

  @override
  String get gridRangeBlock => 'Block';

  @override
  String get gridRangeNeighborhood => 'Neighborhood';

  @override
  String get gridRangeArea => 'Area';

  @override
  String get gridRangeWide => 'Wide';

  @override
  String get gridLegend => 'LEGEND';

  @override
  String gridLegendRings(String value) {
    return 'Three concentric rings = distance bands. With GPS on both ends, the outer ring is the **Range** scale above (~$value right now). Without GPS, rings are RSSI bands (near / mid / far).';
  }

  @override
  String get gridLegendSelf =>
      'Centre marker = you. Cross-hair = N-S / E-W guide.';

  @override
  String get gridLegendDot =>
      'Dot = a fabric node we\'ve heard. Brightness = recency (full = just now, fades to 0 over 24 h then disappears).';

  @override
  String get gridLegendKnown =>
      'Pulse (slow growing halo) = a known node — we have had a direct attributable exchange (DM) with them.';

  @override
  String get gridLegendFavourite =>
      'Rapid blink in alt-colour = a favourited contact.';

  @override
  String get gridLegendRipple =>
      'Centre-out ripple = an anonymous channel message (the protocol doesn\'t attribute channel msgs to a sender).';

  @override
  String get gridLegendTap =>
      'Tap a node to see details + Message / Favourite.';

  @override
  String get gridEmpty =>
      'No fabric in range yet.\n\nNodes appear here as their adverts are heard. Star a node in Nodes to mark it as a contact (rapid blink). Nodes we DM with become known (pulse).';

  @override
  String gridStatusReady(int visible, int known, int favs, String playState) {
    String _temp0 = intl.Intl.pluralLogic(
      favs,
      locale: localeName,
      other: '$favs contacts',
      one: '1 contact',
      zero: '0 contacts',
    );
    return '$visible in fabric · $known known · $_temp0 · $playState';
  }

  @override
  String get gridStatusOffline =>
      'Not connected — Settings → Diagnostics & connect';

  @override
  String get gridPlayStatePaused => 'paused';

  @override
  String gridPlayStateLive(String interval) {
    return 'live ($interval)';
  }

  @override
  String gridFooter(String label, String value) {
    return 'Outer ring ≈ $label ($value) · tap a node for details · info icon for the legend';
  }
}
