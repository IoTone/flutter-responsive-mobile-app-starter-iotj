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
  String get dashboardUnnamed => '(unnamed)';

  @override
  String get dashboardRenameTitle => 'Device name';

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
  String get dashboardDevice => 'Device';

  @override
  String get deviceMgrTitle => 'DEVICE';

  @override
  String get deviceMgrNoPair => 'No device paired';

  @override
  String get deviceMgrStateConnected => 'CONNECTED';

  @override
  String get deviceMgrStateConnecting => 'CONNECTING…';

  @override
  String get deviceMgrStateReconnecting => 'RECONNECTING…';

  @override
  String get deviceMgrStateDisconnected => 'DISCONNECTED';

  @override
  String get deviceMgrStateFailed => 'FAILED';

  @override
  String get deviceMgrDisconnect => 'Disconnect';

  @override
  String get deviceMgrReconnect => 'Reconnect';

  @override
  String get deviceMgrForget => 'Forget';

  @override
  String get deviceMgrPick => 'PICK A DEVICE';

  @override
  String get deviceMgrScan => 'Scan';

  @override
  String get deviceMgrStopScan => 'Stop';

  @override
  String get deviceMgrScanHint =>
      'Tap Scan to look for nearby MeshCore devices. When two are in range, pick the one you want.';

  @override
  String deviceMgrScanFailed(String message) {
    return 'Scan failed: $message';
  }

  @override
  String get deviceMgrRecent => 'RECENTLY PAIRED';

  @override
  String get deviceMgrAgoNever => 'never';

  @override
  String get deviceMgrAgoNow => 'just now';

  @override
  String deviceMgrAgoMinutes(int n) {
    return '$n min ago';
  }

  @override
  String deviceMgrAgoHours(int n) {
    return '$n h ago';
  }

  @override
  String deviceMgrAgoDays(int n) {
    return '$n d ago';
  }

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
  String dashboardBatteryLeft(String time) {
    return '~$time left';
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
  String get nodesFarBadge => 'FAR';

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
  String get gridLegendHeading =>
      'Heading wedge / HDG line = the direction the phone\'s top edge is pointing relative to MAGNETIC north (not true north, not GPS travel direction). Comes from the phone\'s compass sensor.';

  @override
  String get gridLegendCalibration =>
      'Calibration: if the arrow seems wrong, hold the phone level and wave it in a figure-8 motion several times. The OS handles compass calibration; the app only displays sensor accuracy (a \'Calibrate\' hint appears when accuracy is poor).';

  @override
  String get gridViewRadial => 'Radial';

  @override
  String get gridViewGlobe => 'Globe';

  @override
  String get gridViewEqualGrid => 'Equal grid';

  @override
  String get gridViewStreetMap => 'Street map';

  @override
  String get gridViewPicker => 'Switch map view';

  @override
  String get gridViewRadialShort => 'RADAR';

  @override
  String get gridViewGlobeShort => 'GLOBE';

  @override
  String get gridViewEqualGridShort => 'CELLS';

  @override
  String get gridViewStreetMapShort => 'ROADS';

  @override
  String get gridViewFabric => 'Fabric survey';

  @override
  String get gridViewFabricShort => 'MESH';

  @override
  String get gridViewElevation => 'Fujiさん';

  @override
  String get gridViewElevationShort => 'FUJI';

  @override
  String get fujiLegendTitle => 'FUJIさん';

  @override
  String get fujiLegendDesc =>
      'Altitude survey. Heights on a √-scaled axis against famous landmarks. Your device\'s altitude comes from device GPS telemetry or the phone fix.';

  @override
  String get fujiLegendMe =>
      'Dashed line = you. At your altitude, or pinned to the ground with ALT? until it resolves.';

  @override
  String get fujiLegendRefs =>
      'Silhouettes = real-world references (person → Mt Fuji) for scale.';

  @override
  String get fujiLegendPeers =>
      'Dots = peers, plotted at their telemetry altitude once queried.';

  @override
  String get fujiLegendUnknown =>
      'Striped band along the ground = peers with no altitude yet.';

  @override
  String get fujiLegendAutoQuery =>
      'The AUTO-QUERY box pulls peer altitudes slowly; tap it to restart.';

  @override
  String get elevationProfileTitle => 'MESHMORE :: FUJIさん';

  @override
  String get elevationProfileAltLabel => 'Altitude';

  @override
  String get elevationProfileMeLabel => 'Me';

  @override
  String get elevationProfileUnknownLabel => 'altitude unknown';

  @override
  String elevationProfilePeers(int n) {
    return '$n peers tracked';
  }

  @override
  String get elevationRefPerson => 'Human';

  @override
  String get elevationRefHouse => 'House';

  @override
  String get elevationRefRedwood => 'Redwood';

  @override
  String get elevationRefEmpireState => 'Empire State';

  @override
  String get elevationRefBurj => 'Burj Khalifa';

  @override
  String get elevationRefMtFuji => 'Mt Fuji';

  @override
  String fabricCoverageCount(int n) {
    return 'MESH SURVEY · $n CELLS';
  }

  @override
  String get fabricResetTooltip => 'Reset coverage';

  @override
  String get fabricResetTitle => 'Reset mesh-coverage survey?';

  @override
  String get fabricResetBody =>
      'Drops every recorded cell. New observations will start filling the map again as you move and the mesh reports nearby nodes.';

  @override
  String get fabricResetApply => 'Reset';

  @override
  String get streetMapRecenter => 'Re-centre on me';

  @override
  String get streetMapTopoLayer => 'Switch to topographical map';

  @override
  String get streetMapStandardLayer => 'Switch to street map';

  @override
  String get mapHideTiles => 'Hide map tiles';

  @override
  String get mapShowTiles => 'Show map tiles';

  @override
  String deviceRegionLoadedOffline(String label) {
    return '$label loaded — Apply when a device is connected.';
  }

  @override
  String get equalGridAwaitingFix =>
      'Equal-grid view needs your own location — waiting for a GPS fix (phone or device).';

  @override
  String equalGridCellSize(String size) {
    return 'CELL $size';
  }

  @override
  String get equalGridZoomIn => 'Zoom in (tighter cells)';

  @override
  String get equalGridZoomOut => 'Zoom out (wider cells)';

  @override
  String get equalGridShowStats => 'Show targeting panel';

  @override
  String get equalGridHideStats => 'Hide targeting panel';

  @override
  String globeFooter(int n) {
    return 'Showing $n peers with known location';
  }

  @override
  String get globeOverlayArcs => 'arcs';

  @override
  String get globeOverlayRegion => 'region';

  @override
  String get globeOverlayLabels => 'labels';

  @override
  String get globeZoom => 'ZOOM';

  @override
  String get globeAltitude => 'ALT';

  @override
  String get globePaused => 'PAUSED';

  @override
  String get voiceOfflineBadge => 'OFFLINE';

  @override
  String get dashboardLocationRefresh => 'Refresh location from device';

  @override
  String dashboardLocationAltitude(int meters) {
    return 'alt $meters m';
  }

  @override
  String get deviceLocReportsAwaiting => 'Device reports: (awaiting)';

  @override
  String get deviceLocReportsNone => 'Device reports: no GPS fix (0, 0)';

  @override
  String deviceLocReportsValue(String lat, String lon) {
    return 'Device reports: $lat, $lon';
  }

  @override
  String get deviceLocUnsaved => '✱ unsaved';

  @override
  String get deviceGpsModule => 'ON-BOARD GPS MODULE';

  @override
  String get deviceGpsEnable => 'Enable on-board GPS';

  @override
  String get deviceGpsEnabledHint =>
      'Device firmware polls its GPS chip and updates location automatically.';

  @override
  String get deviceGpsDisabledHint =>
      'Off — the device never reads its GPS chip; advertised location stays whatever was last written.';

  @override
  String get deviceGpsUnknown => 'Waiting for device…';

  @override
  String get deviceGpsInterval => 'GPS update interval';

  @override
  String get deviceGpsIntervalOff => 'Off';

  @override
  String deviceGpsIntervalSec(int n) {
    return 'Every $n s';
  }

  @override
  String deviceGpsIntervalMin(int n) {
    return 'Every $n min';
  }

  @override
  String deviceGpsIntervalHour(int n) {
    return 'Every $n h';
  }

  @override
  String get deviceGpsIntervalFixedByFirmware =>
      'Polling cadence is fixed by this firmware build (the sensors module doesn\'t expose `gps_interval`).';

  @override
  String get locTitle => 'Auto-publish location';

  @override
  String get locTileSubtitle =>
      'Periodic + on-movement phone-GPS push to the device';

  @override
  String get locHelp =>
      'Phone-side workaround for stale device GPS. When enabled, the app periodically (and/or on movement) reads phone GPS and writes it to the device via SET_ADVERT_LATLON + a zero-hop self-advert.';

  @override
  String get locMaster => 'Auto-publish';

  @override
  String get locMasterOn => 'On — using phone GPS';

  @override
  String get locMasterOff => 'Off';

  @override
  String get locInterval => 'Periodic interval';

  @override
  String get locMovement => 'Smart broadcast (on movement)';

  @override
  String get locOff => 'Off';

  @override
  String locIntervalMin(int n) {
    return 'Every $n min';
  }

  @override
  String locIntervalHour(int n) {
    return 'Every $n h';
  }

  @override
  String locMovementM(int m) {
    return '$m m';
  }

  @override
  String locMovementKm(int km) {
    return '$km km';
  }

  @override
  String get locPublishNow => 'Publish now';

  @override
  String get locPublishNowSub => 'One-shot manual push to verify the loop.';

  @override
  String locLastPublished(String lat, String lon, String time, String trigger) {
    return 'Last: $lat, $lon  ·  $time  ·  $trigger';
  }

  @override
  String get locBatteryHint =>
      'Smart-broadcast streams GPS (~10 mA continuous). Periodic-only is cheaper. Combine both for responsiveness; pick smart-broadcast alone if battery matters.';

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

  @override
  String gridHeading(int deg, String cardinal) {
    return 'HDG $deg° $cardinal';
  }

  @override
  String get gridHeadingCalibrate =>
      'Compass needs calibration — wave the phone in a figure 8.';

  @override
  String get voiceSettingsTitle => 'Voice (TTS quality)';

  @override
  String get voiceSettingsHint =>
      'Off until you turn on SPEECH in App settings. Rate / pitch / voice take effect on the next utterance.';

  @override
  String get voiceRate => 'Rate';

  @override
  String get voicePitch => 'Pitch';

  @override
  String get voicePicker => 'Voice';

  @override
  String get voicePickerEmpty =>
      'No voices reported by the platform engine — using the system default.';

  @override
  String get voicePickerOnlyMyLanguage => 'Only show my language';

  @override
  String voicePickerOnlyMyLanguageHint(String lang) {
    return 'Limits the list to voices matching the phone\'s current language ($lang). Turn off to see every voice the OS reports.';
  }

  @override
  String voicePickerFilteredCount(int n, String lang) {
    return '$n · $lang';
  }

  @override
  String voicePickerAllCount(int n) {
    return '$n · ALL';
  }

  @override
  String voicePickerNoMatchForLanguage(String lang) {
    return 'No voices installed for $lang. Turn off the filter above to see other languages, or install a $lang voice in your OS settings.';
  }

  @override
  String get voicePickerSystem => 'System default';

  @override
  String get voicePreview => 'Try a phrase';

  @override
  String get voicePreviewPhrase => 'This is a Meshmore SNS voice preview.';

  @override
  String get voicePreviewDisabledHint =>
      'Turn on SPEECH in App settings to audition a phrase.';

  @override
  String get settingsHubDevice => 'Device configuration';

  @override
  String get settingsHubDeviceSub => 'Meshcore radio & device (R7)';

  @override
  String get settingsHubApp => 'App settings';

  @override
  String get settingsHubAppSub => 'Connection, language, speech, data';

  @override
  String get settingsHubProfile => 'Profile & personalization';

  @override
  String get settingsHubProfileSub => 'Theme, font size, audio, accessibility';

  @override
  String get settingsHubChannels => 'Channels';

  @override
  String get settingsHubChannelsSub => 'Slots · name + PSK · #hashtag · active';

  @override
  String get settingsHubDiagnostics => 'Diagnostics & connect';

  @override
  String get settingsHubDiagnosticsSub =>
      'Connect a radio · frame log · M6 capture';

  @override
  String get bootHeader => 'MESHMORE  /  SYNCHRONIZING';

  @override
  String get bootConnecting => 'CONNECTING TO RADIO…';

  @override
  String get bootHandshaking => 'HANDSHAKING…';

  @override
  String get bootSyncing => 'SYNCING DEVICE STATE…';

  @override
  String get bootReady => 'MESH ONLINE';

  @override
  String get bootOffline => 'OFFLINE — Settings → Diagnostics & connect';

  @override
  String get bootSkip => 'SKIP';

  @override
  String get bootRetry => 'RETRY';

  @override
  String get bootSubtitle => 'WAIT  /  進行中';

  @override
  String eventAdvert(String name) {
    return 'advert · $name';
  }

  @override
  String eventChannelMsg(String channel, String text) {
    return 'ch$channel · \"$text\"';
  }

  @override
  String eventDm(String text) {
    return 'dm · \"$text\"';
  }

  @override
  String eventContact(String name) {
    return 'contact · $name';
  }

  @override
  String eventBattery(String volts) {
    return 'battery ${volts}V';
  }

  @override
  String eventDeviceError(String code) {
    return 'device error (code $code)';
  }

  @override
  String get eventDeviceClockSynced => 'device clock in sync';

  @override
  String eventDeviceClockSkew(String seconds) {
    return 'device clock read (offset ${seconds}s)';
  }

  @override
  String eventMsgSent(String ack) {
    return 'msg sent (ack $ack)';
  }

  @override
  String eventDeviceInfo(String version) {
    return 'device $version';
  }

  @override
  String eventSelfInfo(String name) {
    return 'self-info · $name';
  }

  @override
  String get eventQueuedWaiting => 'queued items waiting';

  @override
  String eventQueuedWaitingN(String count) {
    return 'queued items waiting ($count)';
  }

  @override
  String chatChannelHeader(String name) {
    return 'CHANNEL · $name';
  }

  @override
  String get chatManageChannels => 'Manage channels';

  @override
  String get chatTtsDisabledHint => 'Enable TTS in App settings';

  @override
  String get chatTtsMuted => 'TTS muted for this channel';

  @override
  String get chatTtsActive => 'TTS reading this channel';

  @override
  String get chatHideChannels => 'Hide channels';

  @override
  String get chatShowChannels => 'Show channels';

  @override
  String get chatEmpty => '— no messages on this channel —';

  @override
  String chatJumpToNewest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new',
      one: '1 new',
    );
    return '$_temp0';
  }

  @override
  String chatComposerHint(String channel) {
    return 'Message $channel';
  }

  @override
  String get chatComposerOffline => 'Connect a radio to send';

  @override
  String get chatSend => 'Send';

  @override
  String get chatMessageActions => 'Message actions';

  @override
  String dmTitle(String peer) {
    return 'DM · $peer';
  }

  @override
  String dmPubkeyLabel(String hex) {
    return 'pubkey · $hex';
  }

  @override
  String get dmEmpty => '— no messages yet —';

  @override
  String get dmOpenPeerDetail => 'Peer details';

  @override
  String get dmPeerNotInFabric =>
      'This peer hasn\'t shown up on the mesh yet (no advert heard).';

  @override
  String dmComposerHint(String peer) {
    return 'Message $peer';
  }

  @override
  String get dmSend => 'Send DM';

  @override
  String get actionReply => 'Reply';

  @override
  String get actionReplySub => 'Quote this message in your reply';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionCopySub => 'Copy the message text to the clipboard';

  @override
  String get actionDeleteLocal => 'Delete locally';

  @override
  String get actionDeleteLocalSub =>
      'Removes this row from your history only — over-the-air messages cannot be recalled.';

  @override
  String get actionCopied => 'Copied to clipboard';

  @override
  String get actionDeleteConfirmTitle => 'Delete this message locally?';

  @override
  String get actionDeleteConfirmBody =>
      'This removes the row from your local history. MeshCore has no recall — the recipient still has it.';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get nodeDetailSelf =>
      'This is your own node — no Message / Favourite.';

  @override
  String get nodeDetailRecentDms => 'RECENT DMS';

  @override
  String get nodeDetailMessage => 'Message';

  @override
  String get nodeDetailFavourite => 'Favourite';

  @override
  String get nodeDetailContact => 'Contact';

  @override
  String get nodeDetailShowOnMap => 'Show on geocoded map';

  @override
  String get nodeDetailShowOnMapSnack =>
      'Reverse-geocoded map (R25) is on the roadmap.';

  @override
  String get nodeDetailShowOnMapFailed => 'Couldn\'t open the maps app.';

  @override
  String get nodeDetailCopyPubkey => 'Copy full pubkey';

  @override
  String get nodeDetailPubkeyCopied => 'Pubkey copied';

  @override
  String get nodeDetailTags => 'TAGS';

  @override
  String get nodeDetailAddTag => 'tag';

  @override
  String get nodeDetailAddTagTitle => 'Add tag';

  @override
  String get nodeDetailAddTagHint => 'e.g. repeater, work, ham-club';

  @override
  String get nodeDetailAddTagSuggestions => 'RECENTLY USED';

  @override
  String get nodeDetailAddTagApply => 'Add';

  @override
  String get nodeDetailInRange => 'IN RANGE';

  @override
  String get nodeDetailKnown => 'KNOWN';

  @override
  String get nodeDetailContactBadge => 'CONTACT';

  @override
  String get nodeDetailShortIdKv => 'shortId';

  @override
  String get nodeDetailPubkeyKv => 'pubkey';

  @override
  String get nodeDetailSignalKv => 'signal';

  @override
  String get nodeDetailLastHeardKv => 'last heard';

  @override
  String get nodeDetailDistanceKv => 'distance';

  @override
  String get nodeDetailLatLonKv => 'lat / lon';

  @override
  String get gridViewTree => 'Mesh tree';

  @override
  String get gridViewTreeShort => 'TREE';

  @override
  String get gridViewSnsCells => 'SNS cells (heat)';

  @override
  String get gridViewSnsCellsShort => 'SNS';

  @override
  String get snsCellsAwaitingFix =>
      'Waiting for a location fix — the heat map centres on you.';

  @override
  String get snsCellsClear => 'Clear';

  @override
  String snsCellsStatus(int active, int hot) {
    return '$active cells · $hot hot';
  }

  @override
  String get snsCellsLegendTitle => 'SNS CELLS';

  @override
  String get snsCellsLegendDesc =>
      'A live social-activity heat map. Each observed message warms its cell; cells cool over a one-hour horizon.';

  @override
  String get snsCellsLegendHot =>
      'Bright red = busy (≈5+ messages in the last minute).';

  @override
  String get snsCellsLegendCool =>
      'Fading to white = quieting down; gone after ~1 h idle.';

  @override
  String get snsCellsLegendToast =>
      'New messages flash as a toast near their source, then vanish.';

  @override
  String get snsCellsLegendChannel =>
      'Channel messages carry the sender\'s name — they warm the sender\'s cell when we know their location, otherwise your own cell (the receive point).';

  @override
  String get snsCellsLegendDecay =>
      'Only the last hour is tracked; nothing is stored.';

  @override
  String get meshTreeEmpty =>
      'Waiting for contact sync — the tree is built from each contact\'s outPath.';

  @override
  String get meshTreeHopsDirect => 'Direct';

  @override
  String get meshTreeHopsAll => '≤6 / All';

  @override
  String get meshTreeHopsFlood => 'Flood / All';

  @override
  String meshTreeHopsN(int n) {
    return '≤$n hops';
  }

  @override
  String get meshTreeRecenter => 'Recenter';

  @override
  String get meshTreeLegendTitle => 'MESH TREE';

  @override
  String get meshTreeLegendDesc =>
      'A directed graph of how the radio reaches each contact. Edges come from Contact.outPath — the exact repeater chain the device uses to send.';

  @override
  String get meshTreeLegendSelf => 'You — pinned at the centre.';

  @override
  String get meshTreeLegendRepeater =>
      'Square = repeater. Mast-mounted infra, hub colour. Peers fan out through these.';

  @override
  String get meshTreeLegendRoom =>
      'Diamond = room server. Server-class node hosting named rooms.';

  @override
  String get meshTreeLegendChat => 'Circle = chat node. Peer you can DM.';

  @override
  String get meshTreeLegendSensor =>
      'Small circle (dim) = sensor. Narrow-purpose node.';

  @override
  String get meshTreeLegendFlood =>
      'Dashed edge to you = flood-routed contact. Reachable, but with no fixed path.';

  @override
  String get meshTreeLegendFloat =>
      'Floating (no edges) — heard via advert only; route unknown.';

  @override
  String get meshTreeLegendArrow =>
      'Arrows point away from us, toward the destination peer.';

  @override
  String get meshTreeLegendInteract =>
      'Pinch to zoom, drag to pan, tap a node for details. Use Recenter to reset.';

  @override
  String get fabricLegendTitle => 'FABRIC SURVEY';

  @override
  String get fabricLegendDesc =>
      'A persistent record of where the mesh has been observed. Each rectangle is a small geographic cell (~220 m × 220 m) the device logged on contact with this location.';

  @override
  String get fabricLegendCell =>
      'Filled cell — the mesh reached here at some point.';

  @override
  String get fabricLegendRecency =>
      'Brighter fill = more recent. Tiers: < 1 h, < 24 h, < 7 d, older.';

  @override
  String get fabricLegendMarker =>
      'Tertiary-coloured pins mark peers in the current set. Tap one for details.';

  @override
  String get fabricLegendSelf => 'The primary-coloured pin is you.';

  @override
  String get fabricLegendReset =>
      'Reset the survey from the overflow menu when you move to a new area.';

  @override
  String get nodeDetailHopsKv => 'hops';

  @override
  String get nodeDetailHopsDirect => 'direct (0 hops)';

  @override
  String nodeDetailHopsViaRepeaters(int n) {
    return '$n via repeater(s)';
  }

  @override
  String get nodeDetailHopsUnknown => 'unknown';

  @override
  String get nodeDetailHopsFlood => 'Flood';

  @override
  String get nodeDetailAltitudeKv => 'altitude';

  @override
  String nodeDetailAltitudeMeters(String m) {
    return '$m m';
  }

  @override
  String get nodeDetailAltitudeUnknown => 'unknown';

  @override
  String get nodeDetailQueryTelemetry => 'Query telemetry';

  @override
  String get nodeDetailRefreshTelemetry => 'Refresh telemetry';

  @override
  String get nodeDetailTelemetryQuerying => 'querying peer over the air…';

  @override
  String get nodeDetailTelemetryNotContact =>
      'Not a synced contact — telemetry can\'t be requested. Add this node as a contact on the device first.';

  @override
  String nodeDetailTelemetryAge(String age) {
    return 'telemetry from $age';
  }

  @override
  String nodeDetailAgoSeconds(int n) {
    return '${n}s ago';
  }

  @override
  String nodeDetailAgoMinutes(int n) {
    return '$n min ago';
  }

  @override
  String nodeDetailAgoHours(int n) {
    return '$n h ago';
  }

  @override
  String nodeDetailAgoDays(int n) {
    return '$n d ago';
  }

  @override
  String get channelsTitle => 'Channels';

  @override
  String get channelsHelp =>
      'A channel = slot + name + 16-byte key. Public (slot 0) is the shared default. For a private group, set the SAME name & PSK in the same slot on every node.';

  @override
  String get channelsOfflineHint =>
      'Connect a radio (Diagnostics) to edit channels.';

  @override
  String get channelsEmpty => '— empty —';

  @override
  String channelsSlotLabel(int idx) {
    return 'slot $idx';
  }

  @override
  String channelsSlotActive(int idx) {
    return 'slot $idx · ACTIVE';
  }

  @override
  String get channelsEdit => 'Edit';

  @override
  String get channelsSet => 'Set';

  @override
  String channelsSetSnack(int idx, String name) {
    return 'Channel $idx set to \"$name\" — every node needs the same name & PSK here';
  }

  @override
  String channelsDialogTitle(int idx) {
    return 'Channel slot $idx';
  }

  @override
  String get channelsName => 'Channel name';

  @override
  String get channelsKeySource => 'Key source';

  @override
  String get channelsKeyPublic => 'Public';

  @override
  String get channelsKeyHashtag => '#tag';

  @override
  String get channelsKeyHex => 'Hex';

  @override
  String get channelsKeyPublicBody => 'Uses the well-known Public channel key.';

  @override
  String get channelsKeyHashtagHint => 'e.g. #mygroup';

  @override
  String get channelsKeyHashtagHelper => 'Key derived from the tag (sha256)';

  @override
  String get channelsKeyHexHint => '32 hex chars (16 bytes)';

  @override
  String get channelsErrorTag => 'Enter a #hashtag';

  @override
  String get channelsErrorHex => 'PSK must be 32 hex chars (16 bytes)';

  @override
  String get channelsErrorName => 'Enter a channel name';

  @override
  String get channelsCancel => 'Cancel';

  @override
  String get channelsSave => 'Save';

  @override
  String get channelsHelpEncryption =>
      'Slot 0 (Public) uses a well-known key — everyone with the firmware can read it. Other slots are AES-128 encrypted with the 16-byte PSK you set; only nodes with the same PSK can decrypt.';

  @override
  String get channelsHexGenerate => 'Generate random PSK';

  @override
  String get channelsHexCopy => 'Copy';

  @override
  String get channelsHexCopied => 'PSK copied to clipboard';

  @override
  String get channelsTagWeakShort =>
      'Short tags are guessable. Use 12+ chars or unusual phrasing.';

  @override
  String get channelsTagWeakCommon =>
      'Common words are guessable — an attacker can grind tags. Use unusual phrasing.';

  @override
  String get channelsSlot0WarnTitle => 'Overwriting the Public channel?';

  @override
  String get channelsSlot0WarnBody =>
      'Slot 0 is the well-known Public channel. Writing a private PSK here means you\'ll only be able to talk to nodes that use this exact key in slot 0 — you\'ll lose the shared Public channel. Proceed?';

  @override
  String get channelsSlot0WarnContinue => 'Overwrite slot 0';

  @override
  String get channelsSlot0WarnCancel => 'Cancel';

  @override
  String get channelsCurrentKey => 'Current key';

  @override
  String get channelsRevealKey => 'Reveal';

  @override
  String get channelsHideKey => 'Hide';

  @override
  String get channelsCurrentKeyUnknown =>
      'Not loaded yet — open then close this dialog after the device has synced.';

  @override
  String get channelsClear => 'Clear slot';

  @override
  String channelsClearConfirmTitle(int idx) {
    return 'Clear slot $idx?';
  }

  @override
  String get channelsClearConfirmBody =>
      'MeshCore has no protocol-level \"clear\" — this slot will be overwritten back to the well-known Public defaults (name + key). Other nodes will need to do the same to talk on it again.';

  @override
  String get channelsClearConfirmAction => 'Clear';

  @override
  String channelsClearSnack(int idx) {
    return 'Slot $idx cleared (reset to Public defaults)';
  }

  @override
  String get channelsDefaultBadge => 'DEFAULT';

  @override
  String get channelsSetDefaultTooltip => 'Set as default channel on launch';

  @override
  String get channelsClearDefaultTooltip => 'Clear default channel preference';

  @override
  String channelsSetDefaultSnack(int idx) {
    return 'Slot $idx is now the launch default';
  }

  @override
  String get channelsClearedDefaultSnack => 'Launch default cleared';

  @override
  String get channelsKeyShake => 'Shake';

  @override
  String get channelsShakeTitle => 'Shake to roll dice';

  @override
  String get channelsShakeBody =>
      'Shake your phone — each accepted motion sample feeds the hash. Stop once the ring fills.';

  @override
  String channelsShakeProgress(int accepted, int target, int pct) {
    return '$accepted of $target samples · $pct%';
  }

  @override
  String get channelsShakeReroll => 'Reroll';

  @override
  String get channelsShakeUse => 'Use this key';

  @override
  String get channelsShakeTapFallback =>
      'Tap to roll (reduceMotion is on — uses Random.secure instead)';

  @override
  String get channelsShareQr => 'Share via QR';

  @override
  String channelsQrTitle(int idx) {
    return 'Share channel $idx';
  }

  @override
  String get channelsQrBody =>
      'Scan with a Meshmore device or any QR reader. Anyone with this code can join the channel — share only with trusted peers.';

  @override
  String get channelsQrPayload => 'Payload (also copy-friendly)';

  @override
  String get channelsQrClose => 'Close';

  @override
  String get deviceConfigTitle => 'Device configuration';

  @override
  String get deviceRegionBand => 'REGION / BAND';

  @override
  String get deviceRegionCurrent => 'CURRENTLY APPLIED';

  @override
  String get deviceRegionUnknown => 'Waiting for device…';

  @override
  String get deviceRegionCustom => 'Custom (no preset match)';

  @override
  String get deviceRegionSuggestFromLocation => 'Suggest from my location';

  @override
  String get deviceRegionSuggestTitle => 'Apply suggested region?';

  @override
  String deviceRegionSuggestBody(String lat, String lon, String label) {
    return 'Based on your phone GPS ($lat, $lon), the matching preset is $label. Verify this is legal where you are before applying — particularly outside the country you set up in.';
  }

  @override
  String get deviceRegionSuggestApply => 'Apply';

  @override
  String get deviceRegionSuggestNoFix =>
      'Couldn\'t get a GPS fix — try outdoors with location permission granted.';

  @override
  String get deviceRegionSuggestNoMatch =>
      'Your location doesn\'t match any shipped country preset — pick one manually.';

  @override
  String deviceRegionAppliedToast(String label) {
    return '$label applied — make sure every node in your mesh uses the same preset.';
  }

  @override
  String get deviceRegionDisclaimer =>
      'Operating points are community-curated, not regulatory guarantees. Pick the preset legal where you are and use the SAME tuple on every node. The Japan (ARIB STD-T108) preset is a community proposal that hasn\'t been broadly field-validated — please confirm it is legal and works on your hardware before relying on it.';

  @override
  String get presetUsCanada => 'USA / Canada';

  @override
  String get presetUsArizona => 'USA — Arizona';

  @override
  String get presetJpAribT108 => 'Japan (ARIB STD-T108)';

  @override
  String get presetEuUkLong => 'EU / UK (Long Range)';

  @override
  String get presetEuUkMedium => 'EU / UK (Medium Range)';

  @override
  String get presetEuUkNarrow => 'EU / UK (Narrow)';

  @override
  String get presetCh => 'Switzerland';

  @override
  String get presetCz => 'Czech Republic';

  @override
  String get presetPt869 => 'Portugal (869 MHz)';

  @override
  String get presetAu => 'Australia';

  @override
  String get presetAuNarrow => 'Australia (Narrow)';

  @override
  String get presetAuSaWaQld => 'Australia (SA / WA / QLD)';

  @override
  String get presetNz => 'New Zealand';

  @override
  String get presetVn => 'Vietnam';

  @override
  String get cancel => 'Cancel';

  @override
  String get deviceRadioParams => 'RADIO PARAMS';

  @override
  String get deviceIdentityAdvert => 'IDENTITY / ADVERT';

  @override
  String get deviceChannelsSection => 'CHANNELS';

  @override
  String get deviceOtherParamsSection => 'OTHER PARAMS';

  @override
  String get deviceDeviceSection => 'DEVICE';

  @override
  String get deviceFrequency => 'Frequency (MHz)';

  @override
  String get deviceBandwidth => 'Bandwidth (kHz)';

  @override
  String get deviceSpreadingFactor => 'Spreading factor (5–12)';

  @override
  String get deviceCodingRate => 'Coding rate (5–8)';

  @override
  String get deviceTxPower => 'TX power (dBm)';

  @override
  String get deviceLoadFromDevice => 'Load from device';

  @override
  String get deviceApplyRadio => 'Apply radio params';

  @override
  String get deviceConnectFirst =>
      'Connect a radio first (Diagnostics & connect).';

  @override
  String get deviceAdvertName => 'Advert name';

  @override
  String get deviceSetName => 'Set name';

  @override
  String get deviceAdvertLatitude => 'Advert latitude (°)';

  @override
  String get deviceAdvertLongitude => 'Advert longitude (°)';

  @override
  String get deviceUsePhoneLocation => 'Use phone location';

  @override
  String get deviceReadDeviceLocation => 'Read device location';

  @override
  String get deviceSetAdvertLocation => 'Set advert location';

  @override
  String get deviceAdvertSource => 'Advert location source';

  @override
  String get deviceAdvertSourceNone => 'None';

  @override
  String get deviceAdvertSourcePinned => 'Pinned';

  @override
  String get deviceAdvertSourceGps => 'Device GPS';

  @override
  String get deviceToastNameEmpty => 'Enter a node name';

  @override
  String get deviceToastNameSet =>
      'Name updated — re-advertising to neighbours';

  @override
  String deviceToastSendFailed(String error) {
    return 'Send failed: $error';
  }

  @override
  String get deviceToastNoDeviceYet =>
      'Device hasn\'t reported yet — try once linked';

  @override
  String get deviceToastNoGpsYet => 'Device has no location yet (no GPS fix)';

  @override
  String get deviceToastLoadedDeviceLoc =>
      'Loaded device location · tap Set advert location to broadcast';

  @override
  String get deviceToastGettingPhoneFix => 'Getting phone GPS fix…';

  @override
  String get deviceToastPhoneFixFailed =>
      'Phone GPS fix failed (services off or timeout)';

  @override
  String get deviceToastNoFixReturned => 'No fix returned';

  @override
  String get deviceToastGotPhoneLoc =>
      'Got phone location · tap Set advert location to broadcast';

  @override
  String get deviceToastInvalidLatLon =>
      'Enter valid lat (−90..90) and lon (−180..180)';

  @override
  String get deviceToastAdvertLocSet => 'Advert location set';

  @override
  String get deviceToastInvalidRadio => 'Enter valid numbers for freq/BW/SF/CR';

  @override
  String get deviceToastRadioSent =>
      'Radio params sent — restart/observe the device to confirm';

  @override
  String get deviceLocPermDenied =>
      'Location permission needed for a phone GPS fix.';

  @override
  String get deviceLocPermDeniedPerm =>
      'Location permission permanently denied — open OS settings to grant it.';

  @override
  String get deviceOpenSettings => 'Open settings';

  @override
  String get diagnosticsTitle => 'Diagnostics & connect';

  @override
  String get diagnosticsState => 'STATE';

  @override
  String get diagnosticsSends => 'SENDS';

  @override
  String get diagnosticsChannelTail => 'CHANNEL-TAIL ORACLE';

  @override
  String get diagnosticsCapture => 'CAPTURE / EXPORT';

  @override
  String get diagnosticsRawFrameLog => 'RAW FRAME LOG (newest first)';

  @override
  String get diagnosticsConnect => 'Connect';

  @override
  String get diagnosticsDisconnect => 'Disconnect';

  @override
  String get diagnosticsForget => 'Forget device';

  @override
  String get diagnosticsCopyLog => 'Copy log';

  @override
  String get otherManualAddTitle => 'Manual-add contacts';

  @override
  String get otherManualAddSubOn =>
      'You add heard nodes as contacts on demand.';

  @override
  String get otherManualAddSubOff => 'Heard nodes auto-promote to contacts.';

  @override
  String get otherTelemetryLabel => 'Telemetry mode (raw byte)';

  @override
  String get otherTelemetryHelper =>
      '0 = off · semantics are firmware-defined.';

  @override
  String get otherMultiAcksLabel => 'Multi-acks (0–3)';

  @override
  String get otherMultiAcksHelper =>
      '0 = single ack (default). Higher = wait for N extra acks before considering a send confirmed.';

  @override
  String get otherApply => 'Apply';

  @override
  String get otherSentSnack =>
      'OTHER PARAMS sent — device-side write may take a moment.';

  @override
  String get otherAwaitingDevice => '— awaiting device —';

  @override
  String get batteryTitle => 'Battery';

  @override
  String get batteryConfigSubtitle =>
      'Charge, drain rate, and time-to-empty estimate';

  @override
  String get batteryAwaiting =>
      'Waiting for a battery reading from the device…';

  @override
  String get batteryReset => 'Reset history';

  @override
  String get batteryResetConfirm =>
      'Clear all stored battery history? The runtime estimate will rebuild as new readings arrive.';

  @override
  String get batteryVoltageLabel => 'VOLTAGE';

  @override
  String get batteryCharging => 'Charging';

  @override
  String get batteryChargingNote => 'Charging — runtime estimate paused.';

  @override
  String get batteryTimeToEmpty => 'TIME TO EMPTY';

  @override
  String get batteryEstimating =>
      'Gathering drain data — an estimate appears after a few minutes of discharge.';

  @override
  String get batteryDrainRate => 'Drain rate';

  @override
  String get batteryBasis => 'Basis';

  @override
  String batteryBasisObserved(String span) {
    return 'measured over $span of discharge';
  }

  @override
  String get batteryBasisRated => 'nameplate (capacity ÷ typical draw)';

  @override
  String get batteryConfidence => 'confidence';

  @override
  String get batteryConfHigh => 'high';

  @override
  String get batteryConfMedium => 'medium';

  @override
  String get batteryConfLow => 'low';

  @override
  String get batteryMethodObserved => 'Measured discharge';

  @override
  String get batteryMethodRated => 'Rated estimate';

  @override
  String get batteryMethodNone => 'Gathering data';

  @override
  String get batterySpecTitle => 'DEVICE MODEL';

  @override
  String get batterySpecGeneric =>
      'Unknown hardware — using a generic single-cell Li-ion model. The estimate relies on observed drain (no nameplate capacity to cross-check).';

  @override
  String batterySpecCapacity(int mah) {
    return 'Capacity: $mah mAh';
  }

  @override
  String get batterySpecCapacityUnknown => 'Capacity: user-supplied (unknown)';

  @override
  String batterySpecDraw(int ma) {
    return 'Typical draw: ~$ma mA (radio receiving)';
  }

  @override
  String get batteryHistoryTitle => 'VOLTAGE HISTORY';

  @override
  String batteryHistorySpan(String span, int count) {
    return '$span · $count samples';
  }

  @override
  String batteryDurDH(int days, int hours) {
    return '${days}d ${hours}h';
  }

  @override
  String batteryDurHM(int hours, int mins) {
    return '${hours}h ${mins}m';
  }

  @override
  String batteryDurM(int mins) {
    return '${mins}m';
  }

  @override
  String get deliverySending => 'Sending…';

  @override
  String get deliverySent => 'Sent into the mesh';

  @override
  String get deliveryDelivered => 'Delivered (recipient acknowledged)';

  @override
  String get deliveryFailed =>
      'Not delivered — no acknowledgement or send failed';
}
