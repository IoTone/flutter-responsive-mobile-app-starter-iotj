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
}
