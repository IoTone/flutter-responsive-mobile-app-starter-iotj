import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Meshmore SNS'**
  String get appName;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Socialrobot Network Service'**
  String get appSubtitle;

  /// No description provided for @tabDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get tabDashboard;

  /// No description provided for @tabChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get tabChat;

  /// No description provided for @tabNodes.
  ///
  /// In en, this message translates to:
  /// **'Nodes'**
  String get tabNodes;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @tabAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get tabAbout;

  /// No description provided for @dashboardPeersInRange.
  ///
  /// In en, this message translates to:
  /// **'PEERS IN RANGE'**
  String get dashboardPeersInRange;

  /// No description provided for @dashboardKnownCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{0 known} =1{1 known} other{{n} known}}'**
  String dashboardKnownCount(int n);

  /// No description provided for @dashboardRadio.
  ///
  /// In en, this message translates to:
  /// **'RADIO'**
  String get dashboardRadio;

  /// No description provided for @dashboardLocation.
  ///
  /// In en, this message translates to:
  /// **'LOCATION'**
  String get dashboardLocation;

  /// No description provided for @dashboardBattery.
  ///
  /// In en, this message translates to:
  /// **'BATTERY'**
  String get dashboardBattery;

  /// No description provided for @dashboardRecent.
  ///
  /// In en, this message translates to:
  /// **'RECENT'**
  String get dashboardRecent;

  /// No description provided for @dashboardNoActivity.
  ///
  /// In en, this message translates to:
  /// **'— no activity —'**
  String get dashboardNoActivity;

  /// No description provided for @dashboardAwaitingDevice.
  ///
  /// In en, this message translates to:
  /// **'— awaiting device —'**
  String get dashboardAwaitingDevice;

  /// No description provided for @dashboardAwaitingDeviceLocation.
  ///
  /// In en, this message translates to:
  /// **'— awaiting device location —'**
  String get dashboardAwaitingDeviceLocation;

  /// No description provided for @dashboardUnnamed.
  ///
  /// In en, this message translates to:
  /// **'(unnamed)'**
  String get dashboardUnnamed;

  /// No description provided for @dashboardRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get dashboardRenameTitle;

  /// No description provided for @dashboardLocationNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set — neither device nor phone fix yet'**
  String get dashboardLocationNotSet;

  /// No description provided for @dashboardLocationConfigure.
  ///
  /// In en, this message translates to:
  /// **'CONFIGURE'**
  String get dashboardLocationConfigure;

  /// No description provided for @dashboardLocationSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'source · {source}'**
  String dashboardLocationSourceLabel(String source);

  /// No description provided for @statusLinked.
  ///
  /// In en, this message translates to:
  /// **'LINKED · NO ALERTS'**
  String get statusLinked;

  /// No description provided for @statusSyncing.
  ///
  /// In en, this message translates to:
  /// **'SYNCING…'**
  String get statusSyncing;

  /// No description provided for @statusSyncingLong.
  ///
  /// In en, this message translates to:
  /// **'SYNCING…'**
  String get statusSyncingLong;

  /// No description provided for @statusHandshaking.
  ///
  /// In en, this message translates to:
  /// **'SYNCING…'**
  String get statusHandshaking;

  /// No description provided for @statusReconnecting.
  ///
  /// In en, this message translates to:
  /// **'RECONNECTING…'**
  String get statusReconnecting;

  /// No description provided for @statusLinkLost.
  ///
  /// In en, this message translates to:
  /// **'LINK LOST'**
  String get statusLinkLost;

  /// No description provided for @statusOffline.
  ///
  /// In en, this message translates to:
  /// **'OFFLINE'**
  String get statusOffline;

  /// No description provided for @statusConnecting.
  ///
  /// In en, this message translates to:
  /// **'CONNECTING…'**
  String get statusConnecting;

  /// No description provided for @actionConnect.
  ///
  /// In en, this message translates to:
  /// **'CONNECT'**
  String get actionConnect;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get actionRetry;

  /// No description provided for @dashboardDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get dashboardDevice;

  /// No description provided for @deviceMgrTitle.
  ///
  /// In en, this message translates to:
  /// **'DEVICE'**
  String get deviceMgrTitle;

  /// No description provided for @deviceMgrNoPair.
  ///
  /// In en, this message translates to:
  /// **'No device paired'**
  String get deviceMgrNoPair;

  /// No description provided for @deviceMgrStateConnected.
  ///
  /// In en, this message translates to:
  /// **'CONNECTED'**
  String get deviceMgrStateConnected;

  /// No description provided for @deviceMgrStateConnecting.
  ///
  /// In en, this message translates to:
  /// **'CONNECTING…'**
  String get deviceMgrStateConnecting;

  /// No description provided for @deviceMgrStateReconnecting.
  ///
  /// In en, this message translates to:
  /// **'RECONNECTING…'**
  String get deviceMgrStateReconnecting;

  /// No description provided for @deviceMgrStateDisconnected.
  ///
  /// In en, this message translates to:
  /// **'DISCONNECTED'**
  String get deviceMgrStateDisconnected;

  /// No description provided for @deviceMgrStateFailed.
  ///
  /// In en, this message translates to:
  /// **'FAILED'**
  String get deviceMgrStateFailed;

  /// No description provided for @deviceMgrDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get deviceMgrDisconnect;

  /// No description provided for @deviceMgrReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get deviceMgrReconnect;

  /// No description provided for @deviceMgrForget.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get deviceMgrForget;

  /// No description provided for @deviceMgrPick.
  ///
  /// In en, this message translates to:
  /// **'PICK A DEVICE'**
  String get deviceMgrPick;

  /// No description provided for @deviceMgrScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get deviceMgrScan;

  /// No description provided for @deviceMgrStopScan.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get deviceMgrStopScan;

  /// No description provided for @deviceMgrScanHint.
  ///
  /// In en, this message translates to:
  /// **'Tap Scan to look for nearby MeshCore devices. When two are in range, pick the one you want.'**
  String get deviceMgrScanHint;

  /// No description provided for @deviceMgrScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {message}'**
  String deviceMgrScanFailed(String message);

  /// No description provided for @deviceMgrRecent.
  ///
  /// In en, this message translates to:
  /// **'RECENTLY PAIRED'**
  String get deviceMgrRecent;

  /// No description provided for @deviceMgrAgoNever.
  ///
  /// In en, this message translates to:
  /// **'never'**
  String get deviceMgrAgoNever;

  /// No description provided for @deviceMgrAgoNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get deviceMgrAgoNow;

  /// No description provided for @deviceMgrAgoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min ago'**
  String deviceMgrAgoMinutes(int n);

  /// No description provided for @deviceMgrAgoHours.
  ///
  /// In en, this message translates to:
  /// **'{n} h ago'**
  String deviceMgrAgoHours(int n);

  /// No description provided for @deviceMgrAgoDays.
  ///
  /// In en, this message translates to:
  /// **'{n} d ago'**
  String deviceMgrAgoDays(int n);

  /// No description provided for @settingsHeading.
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get settingsHeading;

  /// No description provided for @settingsConnection.
  ///
  /// In en, this message translates to:
  /// **'CONNECTION'**
  String get settingsConnection;

  /// No description provided for @settingsConnectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-reconnect (M7 backoff) · forget device'**
  String get settingsConnectionSubtitle;

  /// No description provided for @settingsBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Stay connected in background'**
  String get settingsBackgroundTitle;

  /// No description provided for @settingsBackgroundOn.
  ///
  /// In en, this message translates to:
  /// **'Android: a persistent notification keeps the radio linked so messages arrive while backgrounded'**
  String get settingsBackgroundOn;

  /// No description provided for @settingsBackgroundOff.
  ///
  /// In en, this message translates to:
  /// **'Messages still arrive when you reopen the app (radio buffers them); no background notification'**
  String get settingsBackgroundOff;

  /// No description provided for @settingsTelemetryPoll.
  ///
  /// In en, this message translates to:
  /// **'Gather node telemetry'**
  String get settingsTelemetryPoll;

  /// No description provided for @settingsTelemetryPollOn.
  ///
  /// In en, this message translates to:
  /// **'Politely polls contacts for temperature / altitude (a little OTA airtime)'**
  String get settingsTelemetryPollOn;

  /// No description provided for @settingsTelemetryPollOff.
  ///
  /// In en, this message translates to:
  /// **'No telemetry requests sent; query a node manually from its detail'**
  String get settingsTelemetryPollOff;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageJapanese.
  ///
  /// In en, this message translates to:
  /// **'日本語'**
  String get settingsLanguageJapanese;

  /// No description provided for @settingsSpeech.
  ///
  /// In en, this message translates to:
  /// **'SPEECH (R5)'**
  String get settingsSpeech;

  /// No description provided for @settingsSpeechOn.
  ///
  /// In en, this message translates to:
  /// **'Text-to-speech ON · per-channel toggle in Chat'**
  String get settingsSpeechOn;

  /// No description provided for @settingsSpeechOff.
  ///
  /// In en, this message translates to:
  /// **'Text-to-speech OFF (default) · reads channel messages'**
  String get settingsSpeechOff;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'NOTIFICATIONS'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Critical → system notification + vibrate'**
  String get settingsNotificationsSubtitle;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'DATA / ABOUT'**
  String get settingsData;

  /// No description provided for @settingsDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export diagnostics · logs · About · Terms'**
  String get settingsDataSubtitle;

  /// No description provided for @settingsPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get settingsPermissions;

  /// No description provided for @settingsPermissionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open the OS settings page for this app — flip Bluetooth / Notifications on or off here.'**
  String get settingsPermissionsSubtitle;

  /// No description provided for @settingsShowIntro.
  ///
  /// In en, this message translates to:
  /// **'Show intro again on next launch'**
  String get settingsShowIntro;

  /// No description provided for @settingsShowIntroEnabled.
  ///
  /// In en, this message translates to:
  /// **'Wipes the first-run flag so the permissions intro shows again — useful when you\'re testing the flow'**
  String get settingsShowIntroEnabled;

  /// No description provided for @settingsShowIntroDisabled.
  ///
  /// In en, this message translates to:
  /// **'Intro is currently scheduled for next launch'**
  String get settingsShowIntroDisabled;

  /// No description provided for @aboutCopyright.
  ///
  /// In en, this message translates to:
  /// **'Copyright (c) 2026 IoTone, Inc.'**
  String get aboutCopyright;

  /// No description provided for @aboutSubtitleEn.
  ///
  /// In en, this message translates to:
  /// **'(Socialrobot Network Service)'**
  String get aboutSubtitleEn;

  /// No description provided for @aboutSubtitleJa.
  ///
  /// In en, this message translates to:
  /// **'(ソーシャルロボット・ネットワークサービス)'**
  String get aboutSubtitleJa;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'A MeshCore companion client.'**
  String get aboutDescription;

  /// No description provided for @aboutLicense.
  ///
  /// In en, this message translates to:
  /// **'Licensed under the MIT (X11) License.'**
  String get aboutLicense;

  /// No description provided for @aboutMadeWith.
  ///
  /// In en, this message translates to:
  /// **'Made with ♥ in Fukuoka, Japan'**
  String get aboutMadeWith;

  /// No description provided for @aboutTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions — wired in U5.'**
  String get aboutTerms;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'v{version}'**
  String aboutVersion(String version);

  /// No description provided for @personalizationHeading.
  ///
  /// In en, this message translates to:
  /// **'Profile & personalization'**
  String get personalizationHeading;

  /// No description provided for @personalizationThemePreset.
  ///
  /// In en, this message translates to:
  /// **'THEME PRESET'**
  String get personalizationThemePreset;

  /// No description provided for @personalizationType.
  ///
  /// In en, this message translates to:
  /// **'TYPE'**
  String get personalizationType;

  /// No description provided for @personalizationFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get personalizationFontSize;

  /// No description provided for @personalizationAccessibility.
  ///
  /// In en, this message translates to:
  /// **'ACCESSIBILITY (R13)'**
  String get personalizationAccessibility;

  /// No description provided for @personalizationHighContrast.
  ///
  /// In en, this message translates to:
  /// **'High contrast'**
  String get personalizationHighContrast;

  /// No description provided for @personalizationHighContrastSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Force the SEELE high-contrast palette'**
  String get personalizationHighContrastSubtitle;

  /// No description provided for @personalizationHighContrastHint.
  ///
  /// In en, this message translates to:
  /// **'High contrast is on — the SEELE high-contrast palette is forced regardless of your preset pick. Turn off High contrast below to use another theme.'**
  String get personalizationHighContrastHint;

  /// No description provided for @personalizationReduceMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduce motion'**
  String get personalizationReduceMotion;

  /// No description provided for @personalizationVisualHapticOnly.
  ///
  /// In en, this message translates to:
  /// **'Visual + haptic only'**
  String get personalizationVisualHapticOnly;

  /// No description provided for @personalizationVisualHapticOnlySubtitle.
  ///
  /// In en, this message translates to:
  /// **'No information by sound; turns audio off'**
  String get personalizationVisualHapticOnlySubtitle;

  /// No description provided for @personalizationAudioAlerts.
  ///
  /// In en, this message translates to:
  /// **'AUDIO ALERTS (R12)'**
  String get personalizationAudioAlerts;

  /// No description provided for @personalizationAudioMaster.
  ///
  /// In en, this message translates to:
  /// **'Audio alerts'**
  String get personalizationAudioMaster;

  /// No description provided for @personalizationAudioMasterDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled by \"visual + haptic only\"'**
  String get personalizationAudioMasterDisabled;

  /// No description provided for @personalizationAudioMasterEnabled.
  ///
  /// In en, this message translates to:
  /// **'Off by default; augmentation only'**
  String get personalizationAudioMasterEnabled;

  /// No description provided for @firstRunHeader.
  ///
  /// In en, this message translates to:
  /// **'MESHMORE · WELCOME'**
  String get firstRunHeader;

  /// No description provided for @firstRunTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick heads-up on what we\'ll ask for'**
  String get firstRunTitle;

  /// No description provided for @firstRunBleTitle.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get firstRunBleTitle;

  /// No description provided for @firstRunBleBody.
  ///
  /// In en, this message translates to:
  /// **'To pair with your MeshCore radio and exchange messages over the local mesh. Required to send / receive over the air.'**
  String get firstRunBleBody;

  /// No description provided for @firstRunNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get firstRunNotificationsTitle;

  /// No description provided for @firstRunNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'Asked only if you turn on \"Stay connected in background\" later in App settings. Skipped today so you\'re not interrupted twice.'**
  String get firstRunNotificationsBody;

  /// No description provided for @firstRunOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline is fine'**
  String get firstRunOfflineTitle;

  /// No description provided for @firstRunOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'If you skip Bluetooth, the app still works — browse message history, configure channels, read diagnostics. Just no live mesh traffic until you grant Bluetooth.'**
  String get firstRunOfflineBody;

  /// No description provided for @firstRunGrant.
  ///
  /// In en, this message translates to:
  /// **'Grant Bluetooth & continue'**
  String get firstRunGrant;

  /// No description provided for @firstRunSkip.
  ///
  /// In en, this message translates to:
  /// **'Continue offline (skip permissions)'**
  String get firstRunSkip;

  /// No description provided for @firstRunDeniedTransient.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth wasn\'t granted — you can continue offline or open OS settings to change your mind.'**
  String get firstRunDeniedTransient;

  /// No description provided for @firstRunDeniedPermanent.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth was permanently denied — open OS settings to grant it. You can still use the app offline.'**
  String get firstRunDeniedPermanent;

  /// No description provided for @firstRunOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open OS settings'**
  String get firstRunOpenSettings;

  /// No description provided for @dashboardPaired.
  ///
  /// In en, this message translates to:
  /// **'paired: {name}'**
  String dashboardPaired(String name);

  /// No description provided for @dashboardCharging.
  ///
  /// In en, this message translates to:
  /// **'CHARGING'**
  String get dashboardCharging;

  /// No description provided for @dashboardBatteryReadout.
  ///
  /// In en, this message translates to:
  /// **'{volts}V · ~{percent}%'**
  String dashboardBatteryReadout(String volts, int percent);

  /// No description provided for @dashboardBatteryLeft.
  ///
  /// In en, this message translates to:
  /// **'~{time} left'**
  String dashboardBatteryLeft(String time);

  /// No description provided for @nodesScanArea.
  ///
  /// In en, this message translates to:
  /// **'Scan area'**
  String get nodesScanArea;

  /// No description provided for @nodesScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get nodesScanning;

  /// No description provided for @nodesAdvertise.
  ///
  /// In en, this message translates to:
  /// **'Advertise'**
  String get nodesAdvertise;

  /// No description provided for @nodesSyncContacts.
  ///
  /// In en, this message translates to:
  /// **'Sync contacts'**
  String get nodesSyncContacts;

  /// No description provided for @nodesHyperlocalGridTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hyperlocal grid (R18)'**
  String get nodesHyperlocalGridTooltip;

  /// No description provided for @nodesFloodAdvert.
  ///
  /// In en, this message translates to:
  /// **'Flood advert'**
  String get nodesFloodAdvert;

  /// No description provided for @nodesFloodAdvertBody.
  ///
  /// In en, this message translates to:
  /// **'Whole mesh — neighbours + repeaters. Best for discovery.'**
  String get nodesFloodAdvertBody;

  /// No description provided for @nodesZeroHopAdvert.
  ///
  /// In en, this message translates to:
  /// **'Zero-hop advert'**
  String get nodesZeroHopAdvert;

  /// No description provided for @nodesZeroHopAdvertBody.
  ///
  /// In en, this message translates to:
  /// **'Direct neighbours only — not rebroadcast. Quieter on a busy mesh.'**
  String get nodesZeroHopAdvertBody;

  /// No description provided for @nodesFloodAdvertSent.
  ///
  /// In en, this message translates to:
  /// **'Flood advert sent — propagates across the whole mesh (neighbours + repeaters). The other node must Advertise too before it appears here.'**
  String get nodesFloodAdvertSent;

  /// No description provided for @nodesZeroHopAdvertSent.
  ///
  /// In en, this message translates to:
  /// **'Zero-hop advert sent — direct neighbours only, not rebroadcast by repeaters.'**
  String get nodesZeroHopAdvertSent;

  /// No description provided for @nodesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, shortId, or pubkey…'**
  String get nodesSearchHint;

  /// No description provided for @nodesFilterStarred.
  ///
  /// In en, this message translates to:
  /// **'Starred'**
  String get nodesFilterStarred;

  /// No description provided for @nodesFilterInRange.
  ///
  /// In en, this message translates to:
  /// **'In range'**
  String get nodesFilterInRange;

  /// No description provided for @nodesFilterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get nodesFilterClear;

  /// No description provided for @nodesFilterLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen · {label}'**
  String nodesFilterLastSeen(String label);

  /// No description provided for @nodesFilterWithin.
  ///
  /// In en, this message translates to:
  /// **'Within · {label}'**
  String nodesFilterWithin(String label);

  /// No description provided for @nodesAgeAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get nodesAgeAny;

  /// No description provided for @nodesAgeHour.
  ///
  /// In en, this message translates to:
  /// **'Last hour'**
  String get nodesAgeHour;

  /// No description provided for @nodesAge24h.
  ///
  /// In en, this message translates to:
  /// **'Last 24 h'**
  String get nodesAge24h;

  /// No description provided for @nodesAge7d.
  ///
  /// In en, this message translates to:
  /// **'Last 7 d'**
  String get nodesAge7d;

  /// No description provided for @nodesDistAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get nodesDistAny;

  /// No description provided for @nodesDist100m.
  ///
  /// In en, this message translates to:
  /// **'≤ 100 m'**
  String get nodesDist100m;

  /// No description provided for @nodesDist500m.
  ///
  /// In en, this message translates to:
  /// **'≤ 500 m'**
  String get nodesDist500m;

  /// No description provided for @nodesDist5km.
  ///
  /// In en, this message translates to:
  /// **'≤ 5 km'**
  String get nodesDist5km;

  /// No description provided for @nodesDist25km.
  ///
  /// In en, this message translates to:
  /// **'≤ 25 km'**
  String get nodesDist25km;

  /// No description provided for @nodesStatusReady.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total} in fabric · {inRange} in range · {favs, plural, =0{0 contacts} =1{1 contact} other{{favs} contacts}}'**
  String nodesStatusReady(int shown, int total, int inRange, int favs);

  /// No description provided for @nodesStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Not connected — Settings → Diagnostics & connect'**
  String get nodesStatusOffline;

  /// No description provided for @nodesInRangeBadge.
  ///
  /// In en, this message translates to:
  /// **'IN RANGE'**
  String get nodesInRangeBadge;

  /// No description provided for @nodesFarBadge.
  ///
  /// In en, this message translates to:
  /// **'FAR'**
  String get nodesFarBadge;

  /// No description provided for @nodesEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No nodes match this filter.\n\nTap Clear to widen, or change the chip cutoffs above.'**
  String get nodesEmptyFiltered;

  /// No description provided for @nodesEmptyReady.
  ///
  /// In en, this message translates to:
  /// **'No nodes yet.\n\nDiscovery is advert-driven: a node shows up only when its advert is heard. Chatting on Public does NOT make a node appear.\n\nAsk the other node to Advertise / Share (or tap \"Advertise\" here so it can find you), then \"Scan area\".\n\nThis view shows the mesh \"fabric\" (what you\'ve seen). Star a node to mark it as a contact.'**
  String get nodesEmptyReady;

  /// No description provided for @nodesEmptyOffline.
  ///
  /// In en, this message translates to:
  /// **'Connect a radio to discover nearby nodes.'**
  String get nodesEmptyOffline;

  /// No description provided for @nodesFavTooltip.
  ///
  /// In en, this message translates to:
  /// **'Favourite as contact'**
  String get nodesFavTooltip;

  /// No description provided for @nodesUnfavTooltip.
  ///
  /// In en, this message translates to:
  /// **'Unfavourite (remove from contacts)'**
  String get nodesUnfavTooltip;

  /// No description provided for @gridTitle.
  ///
  /// In en, this message translates to:
  /// **'Hyperlocal grid'**
  String get gridTitle;

  /// No description provided for @gridShowLegend.
  ///
  /// In en, this message translates to:
  /// **'Show legend'**
  String get gridShowLegend;

  /// No description provided for @gridHideLegend.
  ///
  /// In en, this message translates to:
  /// **'Hide legend'**
  String get gridHideLegend;

  /// No description provided for @gridPlayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Play (refresh every interval)'**
  String get gridPlayTooltip;

  /// No description provided for @gridPauseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pause updates'**
  String get gridPauseTooltip;

  /// No description provided for @gridIntervalTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh interval (when playing)'**
  String get gridIntervalTooltip;

  /// No description provided for @gridRange.
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get gridRange;

  /// No description provided for @gridRangeRoom.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get gridRangeRoom;

  /// No description provided for @gridRangeHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get gridRangeHome;

  /// No description provided for @gridRangeBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get gridRangeBlock;

  /// No description provided for @gridRangeNeighborhood.
  ///
  /// In en, this message translates to:
  /// **'Neighborhood'**
  String get gridRangeNeighborhood;

  /// No description provided for @gridRangeArea.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get gridRangeArea;

  /// No description provided for @gridRangeWide.
  ///
  /// In en, this message translates to:
  /// **'Wide'**
  String get gridRangeWide;

  /// No description provided for @gridRangeCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get gridRangeCity;

  /// No description provided for @gridRangeRegion.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get gridRangeRegion;

  /// No description provided for @gridLegend.
  ///
  /// In en, this message translates to:
  /// **'LEGEND'**
  String get gridLegend;

  /// No description provided for @gridLegendRings.
  ///
  /// In en, this message translates to:
  /// **'Three concentric rings = distance bands. With GPS on both ends, the outer ring is the **Range** scale above (~{value} right now). Without GPS, rings are RSSI bands (near / mid / far).'**
  String gridLegendRings(String value);

  /// No description provided for @gridLegendSelf.
  ///
  /// In en, this message translates to:
  /// **'Centre marker = you. Cross-hair = N-S / E-W guide.'**
  String get gridLegendSelf;

  /// No description provided for @gridLegendDot.
  ///
  /// In en, this message translates to:
  /// **'Dot = a fabric node we\'ve heard. Brightness = recency (full = just now, fades to 0 over 24 h then disappears).'**
  String get gridLegendDot;

  /// No description provided for @gridLegendKnown.
  ///
  /// In en, this message translates to:
  /// **'Pulse (slow growing halo) = a known node — we have had a direct attributable exchange (DM) with them.'**
  String get gridLegendKnown;

  /// No description provided for @gridLegendFavourite.
  ///
  /// In en, this message translates to:
  /// **'Rapid blink in alt-colour = a favourited contact.'**
  String get gridLegendFavourite;

  /// No description provided for @gridLegendRipple.
  ///
  /// In en, this message translates to:
  /// **'Centre-out ripple = an anonymous channel message (the protocol doesn\'t attribute channel msgs to a sender).'**
  String get gridLegendRipple;

  /// No description provided for @gridLegendTap.
  ///
  /// In en, this message translates to:
  /// **'Tap a node to see details + Message / Favourite.'**
  String get gridLegendTap;

  /// No description provided for @gridLegendHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading wedge / HDG line = the direction the phone\'s top edge is pointing relative to MAGNETIC north (not true north, not GPS travel direction). Comes from the phone\'s compass sensor.'**
  String get gridLegendHeading;

  /// No description provided for @gridLegendCalibration.
  ///
  /// In en, this message translates to:
  /// **'Calibration: if the arrow seems wrong, hold the phone level and wave it in a figure-8 motion several times. The OS handles compass calibration; the app only displays sensor accuracy (a \'Calibrate\' hint appears when accuracy is poor).'**
  String get gridLegendCalibration;

  /// No description provided for @gridViewRadial.
  ///
  /// In en, this message translates to:
  /// **'Radial'**
  String get gridViewRadial;

  /// No description provided for @gridViewGlobe.
  ///
  /// In en, this message translates to:
  /// **'Globe'**
  String get gridViewGlobe;

  /// No description provided for @gridViewEqualGrid.
  ///
  /// In en, this message translates to:
  /// **'Equal grid'**
  String get gridViewEqualGrid;

  /// No description provided for @gridViewStreetMap.
  ///
  /// In en, this message translates to:
  /// **'Street map'**
  String get gridViewStreetMap;

  /// No description provided for @gridViewPicker.
  ///
  /// In en, this message translates to:
  /// **'Switch map view'**
  String get gridViewPicker;

  /// No description provided for @gridViewRadialShort.
  ///
  /// In en, this message translates to:
  /// **'RADAR'**
  String get gridViewRadialShort;

  /// No description provided for @gridViewGlobeShort.
  ///
  /// In en, this message translates to:
  /// **'GLOBE'**
  String get gridViewGlobeShort;

  /// No description provided for @gridViewEqualGridShort.
  ///
  /// In en, this message translates to:
  /// **'CELLS'**
  String get gridViewEqualGridShort;

  /// No description provided for @gridViewStreetMapShort.
  ///
  /// In en, this message translates to:
  /// **'ROADS'**
  String get gridViewStreetMapShort;

  /// No description provided for @gridViewFabric.
  ///
  /// In en, this message translates to:
  /// **'Fabric survey'**
  String get gridViewFabric;

  /// No description provided for @gridViewFabricShort.
  ///
  /// In en, this message translates to:
  /// **'MESH'**
  String get gridViewFabricShort;

  /// No description provided for @gridViewElevation.
  ///
  /// In en, this message translates to:
  /// **'Fujiさん'**
  String get gridViewElevation;

  /// No description provided for @gridViewElevationShort.
  ///
  /// In en, this message translates to:
  /// **'FUJI'**
  String get gridViewElevationShort;

  /// No description provided for @fujiLegendTitle.
  ///
  /// In en, this message translates to:
  /// **'FUJIさん'**
  String get fujiLegendTitle;

  /// No description provided for @fujiLegendDesc.
  ///
  /// In en, this message translates to:
  /// **'Altitude survey. Heights on a √-scaled axis against famous landmarks. Your device\'s altitude comes from device GPS telemetry or the phone fix.'**
  String get fujiLegendDesc;

  /// No description provided for @fujiLegendMe.
  ///
  /// In en, this message translates to:
  /// **'Dashed line = you. At your altitude, or pinned to the ground with ALT? until it resolves.'**
  String get fujiLegendMe;

  /// No description provided for @fujiLegendRefs.
  ///
  /// In en, this message translates to:
  /// **'Silhouettes = real-world references (person → Mt Fuji) for scale.'**
  String get fujiLegendRefs;

  /// No description provided for @fujiLegendPeers.
  ///
  /// In en, this message translates to:
  /// **'Dots = peers, plotted at their telemetry altitude once queried.'**
  String get fujiLegendPeers;

  /// No description provided for @fujiLegendUnknown.
  ///
  /// In en, this message translates to:
  /// **'Striped band along the ground = peers with no altitude yet.'**
  String get fujiLegendUnknown;

  /// No description provided for @fujiLegendAutoQuery.
  ///
  /// In en, this message translates to:
  /// **'The AUTO-QUERY box pulls peer altitudes slowly; tap it to restart.'**
  String get fujiLegendAutoQuery;

  /// No description provided for @elevationProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'MESHMORE :: FUJIさん'**
  String get elevationProfileTitle;

  /// No description provided for @elevationProfileAltLabel.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get elevationProfileAltLabel;

  /// No description provided for @elevationProfileMeLabel.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get elevationProfileMeLabel;

  /// No description provided for @elevationProfileUnknownLabel.
  ///
  /// In en, this message translates to:
  /// **'altitude unknown'**
  String get elevationProfileUnknownLabel;

  /// No description provided for @elevationProfilePeers.
  ///
  /// In en, this message translates to:
  /// **'{n} peers tracked'**
  String elevationProfilePeers(int n);

  /// No description provided for @elevationRefPerson.
  ///
  /// In en, this message translates to:
  /// **'Human'**
  String get elevationRefPerson;

  /// No description provided for @elevationRefHouse.
  ///
  /// In en, this message translates to:
  /// **'House'**
  String get elevationRefHouse;

  /// No description provided for @elevationRefRedwood.
  ///
  /// In en, this message translates to:
  /// **'Redwood'**
  String get elevationRefRedwood;

  /// No description provided for @elevationRefEmpireState.
  ///
  /// In en, this message translates to:
  /// **'Empire State'**
  String get elevationRefEmpireState;

  /// No description provided for @elevationRefBurj.
  ///
  /// In en, this message translates to:
  /// **'Burj Khalifa'**
  String get elevationRefBurj;

  /// No description provided for @elevationRefMtFuji.
  ///
  /// In en, this message translates to:
  /// **'Mt Fuji'**
  String get elevationRefMtFuji;

  /// No description provided for @fabricCoverageCount.
  ///
  /// In en, this message translates to:
  /// **'MESH SURVEY · {n} CELLS'**
  String fabricCoverageCount(int n);

  /// No description provided for @fabricResetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset coverage'**
  String get fabricResetTooltip;

  /// No description provided for @fabricResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset mesh-coverage survey?'**
  String get fabricResetTitle;

  /// No description provided for @fabricResetBody.
  ///
  /// In en, this message translates to:
  /// **'Drops every recorded cell. New observations will start filling the map again as you move and the mesh reports nearby nodes.'**
  String get fabricResetBody;

  /// No description provided for @fabricResetApply.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get fabricResetApply;

  /// No description provided for @streetMapRecenter.
  ///
  /// In en, this message translates to:
  /// **'Re-centre on me'**
  String get streetMapRecenter;

  /// No description provided for @streetMapTopoLayer.
  ///
  /// In en, this message translates to:
  /// **'Switch to topographical map'**
  String get streetMapTopoLayer;

  /// No description provided for @streetMapStandardLayer.
  ///
  /// In en, this message translates to:
  /// **'Switch to street map'**
  String get streetMapStandardLayer;

  /// No description provided for @mapHideTiles.
  ///
  /// In en, this message translates to:
  /// **'Hide map tiles'**
  String get mapHideTiles;

  /// No description provided for @mapShowTiles.
  ///
  /// In en, this message translates to:
  /// **'Show map tiles'**
  String get mapShowTiles;

  /// No description provided for @deviceRegionLoadedOffline.
  ///
  /// In en, this message translates to:
  /// **'{label} loaded — Apply when a device is connected.'**
  String deviceRegionLoadedOffline(String label);

  /// No description provided for @equalGridAwaitingFix.
  ///
  /// In en, this message translates to:
  /// **'Equal-grid view needs your own location — waiting for a GPS fix (phone or device).'**
  String get equalGridAwaitingFix;

  /// No description provided for @equalGridCellSize.
  ///
  /// In en, this message translates to:
  /// **'CELL {size}'**
  String equalGridCellSize(String size);

  /// No description provided for @equalGridZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in (tighter cells)'**
  String get equalGridZoomIn;

  /// No description provided for @equalGridZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out (wider cells)'**
  String get equalGridZoomOut;

  /// No description provided for @equalGridShowStats.
  ///
  /// In en, this message translates to:
  /// **'Show targeting panel'**
  String get equalGridShowStats;

  /// No description provided for @equalGridHideStats.
  ///
  /// In en, this message translates to:
  /// **'Hide targeting panel'**
  String get equalGridHideStats;

  /// No description provided for @globeFooter.
  ///
  /// In en, this message translates to:
  /// **'Showing {n} peers with known location'**
  String globeFooter(int n);

  /// No description provided for @globeOverlayArcs.
  ///
  /// In en, this message translates to:
  /// **'arcs'**
  String get globeOverlayArcs;

  /// No description provided for @globeOverlayRegion.
  ///
  /// In en, this message translates to:
  /// **'region'**
  String get globeOverlayRegion;

  /// No description provided for @globeOverlayLabels.
  ///
  /// In en, this message translates to:
  /// **'labels'**
  String get globeOverlayLabels;

  /// No description provided for @globeZoom.
  ///
  /// In en, this message translates to:
  /// **'ZOOM'**
  String get globeZoom;

  /// No description provided for @globeAltitude.
  ///
  /// In en, this message translates to:
  /// **'ALT'**
  String get globeAltitude;

  /// No description provided for @globePaused.
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get globePaused;

  /// No description provided for @voiceOfflineBadge.
  ///
  /// In en, this message translates to:
  /// **'OFFLINE'**
  String get voiceOfflineBadge;

  /// No description provided for @dashboardLocationRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh location from device'**
  String get dashboardLocationRefresh;

  /// No description provided for @dashboardLocationAltitude.
  ///
  /// In en, this message translates to:
  /// **'alt {meters} m'**
  String dashboardLocationAltitude(int meters);

  /// No description provided for @deviceLocReportsAwaiting.
  ///
  /// In en, this message translates to:
  /// **'Device reports: (awaiting)'**
  String get deviceLocReportsAwaiting;

  /// No description provided for @deviceLocReportsNone.
  ///
  /// In en, this message translates to:
  /// **'Device reports: no GPS fix (0, 0)'**
  String get deviceLocReportsNone;

  /// No description provided for @deviceLocReportsValue.
  ///
  /// In en, this message translates to:
  /// **'Device reports: {lat}, {lon}'**
  String deviceLocReportsValue(String lat, String lon);

  /// No description provided for @deviceLocUnsaved.
  ///
  /// In en, this message translates to:
  /// **'✱ unsaved'**
  String get deviceLocUnsaved;

  /// No description provided for @deviceGpsModule.
  ///
  /// In en, this message translates to:
  /// **'ON-BOARD GPS MODULE'**
  String get deviceGpsModule;

  /// No description provided for @deviceGpsEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable on-board GPS'**
  String get deviceGpsEnable;

  /// No description provided for @deviceGpsEnabledHint.
  ///
  /// In en, this message translates to:
  /// **'Device firmware polls its GPS chip and updates location automatically.'**
  String get deviceGpsEnabledHint;

  /// No description provided for @deviceGpsDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'Off — the device never reads its GPS chip; advertised location stays whatever was last written.'**
  String get deviceGpsDisabledHint;

  /// No description provided for @deviceGpsUnknown.
  ///
  /// In en, this message translates to:
  /// **'Waiting for device…'**
  String get deviceGpsUnknown;

  /// No description provided for @deviceGpsInterval.
  ///
  /// In en, this message translates to:
  /// **'GPS update interval'**
  String get deviceGpsInterval;

  /// No description provided for @deviceGpsIntervalOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get deviceGpsIntervalOff;

  /// No description provided for @deviceGpsIntervalSec.
  ///
  /// In en, this message translates to:
  /// **'Every {n} s'**
  String deviceGpsIntervalSec(int n);

  /// No description provided for @deviceGpsIntervalMin.
  ///
  /// In en, this message translates to:
  /// **'Every {n} min'**
  String deviceGpsIntervalMin(int n);

  /// No description provided for @deviceGpsIntervalHour.
  ///
  /// In en, this message translates to:
  /// **'Every {n} h'**
  String deviceGpsIntervalHour(int n);

  /// No description provided for @deviceGpsIntervalFixedByFirmware.
  ///
  /// In en, this message translates to:
  /// **'Polling cadence is fixed by this firmware build (the sensors module doesn\'t expose `gps_interval`).'**
  String get deviceGpsIntervalFixedByFirmware;

  /// No description provided for @locTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-publish location'**
  String get locTitle;

  /// No description provided for @locTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Periodic + on-movement phone-GPS push to the device'**
  String get locTileSubtitle;

  /// No description provided for @locHelp.
  ///
  /// In en, this message translates to:
  /// **'Phone-side workaround for stale device GPS. When enabled, the app periodically (and/or on movement) reads phone GPS and writes it to the device via SET_ADVERT_LATLON + a zero-hop self-advert.'**
  String get locHelp;

  /// No description provided for @locMaster.
  ///
  /// In en, this message translates to:
  /// **'Auto-publish'**
  String get locMaster;

  /// No description provided for @locMasterOn.
  ///
  /// In en, this message translates to:
  /// **'On — using phone GPS'**
  String get locMasterOn;

  /// No description provided for @locMasterOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get locMasterOff;

  /// No description provided for @locInterval.
  ///
  /// In en, this message translates to:
  /// **'Periodic interval'**
  String get locInterval;

  /// No description provided for @locMovement.
  ///
  /// In en, this message translates to:
  /// **'Smart broadcast (on movement)'**
  String get locMovement;

  /// No description provided for @locOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get locOff;

  /// No description provided for @locIntervalMin.
  ///
  /// In en, this message translates to:
  /// **'Every {n} min'**
  String locIntervalMin(int n);

  /// No description provided for @locIntervalHour.
  ///
  /// In en, this message translates to:
  /// **'Every {n} h'**
  String locIntervalHour(int n);

  /// No description provided for @locMovementM.
  ///
  /// In en, this message translates to:
  /// **'{m} m'**
  String locMovementM(int m);

  /// No description provided for @locMovementKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String locMovementKm(int km);

  /// No description provided for @locPublishNow.
  ///
  /// In en, this message translates to:
  /// **'Publish now'**
  String get locPublishNow;

  /// No description provided for @locPublishNowSub.
  ///
  /// In en, this message translates to:
  /// **'One-shot manual push to verify the loop.'**
  String get locPublishNowSub;

  /// No description provided for @locLastPublished.
  ///
  /// In en, this message translates to:
  /// **'Last: {lat}, {lon}  ·  {time}  ·  {trigger}'**
  String locLastPublished(String lat, String lon, String time, String trigger);

  /// No description provided for @locBatteryHint.
  ///
  /// In en, this message translates to:
  /// **'Smart-broadcast streams GPS (~10 mA continuous). Periodic-only is cheaper. Combine both for responsiveness; pick smart-broadcast alone if battery matters.'**
  String get locBatteryHint;

  /// No description provided for @gridEmpty.
  ///
  /// In en, this message translates to:
  /// **'No fabric in range yet.\n\nNodes appear here as their adverts are heard. Star a node in Nodes to mark it as a contact (rapid blink). Nodes we DM with become known (pulse).'**
  String get gridEmpty;

  /// No description provided for @gridStatusReady.
  ///
  /// In en, this message translates to:
  /// **'{visible} in fabric · {known} known · {favs, plural, =0{0 contacts} =1{1 contact} other{{favs} contacts}} · {playState}'**
  String gridStatusReady(int visible, int known, int favs, String playState);

  /// No description provided for @gridStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Not connected — Settings → Diagnostics & connect'**
  String get gridStatusOffline;

  /// No description provided for @gridPlayStatePaused.
  ///
  /// In en, this message translates to:
  /// **'paused'**
  String get gridPlayStatePaused;

  /// No description provided for @gridPlayStateLive.
  ///
  /// In en, this message translates to:
  /// **'live ({interval})'**
  String gridPlayStateLive(String interval);

  /// No description provided for @gridFooter.
  ///
  /// In en, this message translates to:
  /// **'Outer ring ≈ {label} ({value}) · tap a node for details · info icon for the legend'**
  String gridFooter(String label, String value);

  /// No description provided for @gridHeading.
  ///
  /// In en, this message translates to:
  /// **'HDG {deg}° {cardinal}'**
  String gridHeading(int deg, String cardinal);

  /// No description provided for @gridHeadingCalibrate.
  ///
  /// In en, this message translates to:
  /// **'Compass needs calibration — wave the phone in a figure 8.'**
  String get gridHeadingCalibrate;

  /// No description provided for @gridOrientNorthUp.
  ///
  /// In en, this message translates to:
  /// **'North-up'**
  String get gridOrientNorthUp;

  /// No description provided for @gridOrientHeadingUp.
  ///
  /// In en, this message translates to:
  /// **'Heading-up'**
  String get gridOrientHeadingUp;

  /// No description provided for @gridHeadingHud.
  ///
  /// In en, this message translates to:
  /// **'HEADING'**
  String get gridHeadingHud;

  /// No description provided for @voiceSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice (TTS quality)'**
  String get voiceSettingsTitle;

  /// No description provided for @voiceSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Off until you turn on SPEECH in App settings. Rate / pitch / voice take effect on the next utterance.'**
  String get voiceSettingsHint;

  /// No description provided for @voiceRate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get voiceRate;

  /// No description provided for @voicePitch.
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get voicePitch;

  /// No description provided for @voicePicker.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voicePicker;

  /// No description provided for @voicePickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No voices reported by the platform engine — using the system default.'**
  String get voicePickerEmpty;

  /// No description provided for @voicePickerOnlyMyLanguage.
  ///
  /// In en, this message translates to:
  /// **'Only show my language'**
  String get voicePickerOnlyMyLanguage;

  /// No description provided for @voicePickerOnlyMyLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Limits the list to voices matching the phone\'s current language ({lang}). Turn off to see every voice the OS reports.'**
  String voicePickerOnlyMyLanguageHint(String lang);

  /// No description provided for @voicePickerFilteredCount.
  ///
  /// In en, this message translates to:
  /// **'{n} · {lang}'**
  String voicePickerFilteredCount(int n, String lang);

  /// No description provided for @voicePickerAllCount.
  ///
  /// In en, this message translates to:
  /// **'{n} · ALL'**
  String voicePickerAllCount(int n);

  /// No description provided for @voicePickerNoMatchForLanguage.
  ///
  /// In en, this message translates to:
  /// **'No voices installed for {lang}. Turn off the filter above to see other languages, or install a {lang} voice in your OS settings.'**
  String voicePickerNoMatchForLanguage(String lang);

  /// No description provided for @voicePickerSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get voicePickerSystem;

  /// No description provided for @voicePreview.
  ///
  /// In en, this message translates to:
  /// **'Try a phrase'**
  String get voicePreview;

  /// No description provided for @voicePreviewPhrase.
  ///
  /// In en, this message translates to:
  /// **'This is a Meshmore SNS voice preview.'**
  String get voicePreviewPhrase;

  /// No description provided for @voicePreviewDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'Turn on SPEECH in App settings to audition a phrase.'**
  String get voicePreviewDisabledHint;

  /// No description provided for @settingsHubDevice.
  ///
  /// In en, this message translates to:
  /// **'Device configuration'**
  String get settingsHubDevice;

  /// No description provided for @settingsHubDeviceSub.
  ///
  /// In en, this message translates to:
  /// **'Meshcore radio & device (R7)'**
  String get settingsHubDeviceSub;

  /// No description provided for @settingsHubApp.
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get settingsHubApp;

  /// No description provided for @settingsHubAppSub.
  ///
  /// In en, this message translates to:
  /// **'Connection, language, speech, data'**
  String get settingsHubAppSub;

  /// No description provided for @settingsHubProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile & personalization'**
  String get settingsHubProfile;

  /// No description provided for @settingsHubProfileSub.
  ///
  /// In en, this message translates to:
  /// **'Theme, font size, audio, accessibility'**
  String get settingsHubProfileSub;

  /// No description provided for @settingsHubChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get settingsHubChannels;

  /// No description provided for @settingsHubChannelsSub.
  ///
  /// In en, this message translates to:
  /// **'Slots · name + PSK · #hashtag · active'**
  String get settingsHubChannelsSub;

  /// No description provided for @settingsHubDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics & connect'**
  String get settingsHubDiagnostics;

  /// No description provided for @settingsHubDiagnosticsSub.
  ///
  /// In en, this message translates to:
  /// **'Connect a radio · frame log · M6 capture'**
  String get settingsHubDiagnosticsSub;

  /// No description provided for @bootHeader.
  ///
  /// In en, this message translates to:
  /// **'MESHMORE  /  SYNCHRONIZING'**
  String get bootHeader;

  /// No description provided for @bootConnecting.
  ///
  /// In en, this message translates to:
  /// **'CONNECTING TO RADIO…'**
  String get bootConnecting;

  /// No description provided for @bootHandshaking.
  ///
  /// In en, this message translates to:
  /// **'HANDSHAKING…'**
  String get bootHandshaking;

  /// No description provided for @bootSyncing.
  ///
  /// In en, this message translates to:
  /// **'SYNCING DEVICE STATE…'**
  String get bootSyncing;

  /// No description provided for @bootReady.
  ///
  /// In en, this message translates to:
  /// **'MESH ONLINE'**
  String get bootReady;

  /// No description provided for @bootOffline.
  ///
  /// In en, this message translates to:
  /// **'OFFLINE — Settings → Diagnostics & connect'**
  String get bootOffline;

  /// No description provided for @bootSkip.
  ///
  /// In en, this message translates to:
  /// **'SKIP'**
  String get bootSkip;

  /// No description provided for @bootRetry.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get bootRetry;

  /// No description provided for @bootSubtitle.
  ///
  /// In en, this message translates to:
  /// **'WAIT  /  進行中'**
  String get bootSubtitle;

  /// No description provided for @eventAdvert.
  ///
  /// In en, this message translates to:
  /// **'advert · {name}'**
  String eventAdvert(String name);

  /// No description provided for @eventChannelMsg.
  ///
  /// In en, this message translates to:
  /// **'ch{channel} · \"{text}\"'**
  String eventChannelMsg(String channel, String text);

  /// No description provided for @eventDm.
  ///
  /// In en, this message translates to:
  /// **'dm · \"{text}\"'**
  String eventDm(String text);

  /// No description provided for @eventContact.
  ///
  /// In en, this message translates to:
  /// **'contact · {name}'**
  String eventContact(String name);

  /// No description provided for @eventBattery.
  ///
  /// In en, this message translates to:
  /// **'battery {volts}V'**
  String eventBattery(String volts);

  /// No description provided for @eventDeviceError.
  ///
  /// In en, this message translates to:
  /// **'device error (code {code})'**
  String eventDeviceError(String code);

  /// No description provided for @eventDeviceClockSynced.
  ///
  /// In en, this message translates to:
  /// **'device clock in sync'**
  String get eventDeviceClockSynced;

  /// No description provided for @eventDeviceClockSkew.
  ///
  /// In en, this message translates to:
  /// **'device clock read (offset {seconds}s)'**
  String eventDeviceClockSkew(String seconds);

  /// No description provided for @eventMsgSent.
  ///
  /// In en, this message translates to:
  /// **'msg sent (ack {ack})'**
  String eventMsgSent(String ack);

  /// No description provided for @eventDeviceInfo.
  ///
  /// In en, this message translates to:
  /// **'device {version}'**
  String eventDeviceInfo(String version);

  /// No description provided for @eventSelfInfo.
  ///
  /// In en, this message translates to:
  /// **'self-info · {name}'**
  String eventSelfInfo(String name);

  /// No description provided for @eventQueuedWaiting.
  ///
  /// In en, this message translates to:
  /// **'queued items waiting'**
  String get eventQueuedWaiting;

  /// No description provided for @eventQueuedWaitingN.
  ///
  /// In en, this message translates to:
  /// **'queued items waiting ({count})'**
  String eventQueuedWaitingN(String count);

  /// No description provided for @chatChannelHeader.
  ///
  /// In en, this message translates to:
  /// **'CHANNEL · {name}'**
  String chatChannelHeader(String name);

  /// No description provided for @chatManageChannels.
  ///
  /// In en, this message translates to:
  /// **'Manage channels'**
  String get chatManageChannels;

  /// No description provided for @chatTtsDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'Enable TTS in App settings'**
  String get chatTtsDisabledHint;

  /// No description provided for @chatTtsMuted.
  ///
  /// In en, this message translates to:
  /// **'TTS muted for this channel'**
  String get chatTtsMuted;

  /// No description provided for @chatTtsActive.
  ///
  /// In en, this message translates to:
  /// **'TTS reading this channel'**
  String get chatTtsActive;

  /// No description provided for @chatHideChannels.
  ///
  /// In en, this message translates to:
  /// **'Hide channels'**
  String get chatHideChannels;

  /// No description provided for @chatShowChannels.
  ///
  /// In en, this message translates to:
  /// **'Show channels'**
  String get chatShowChannels;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'— no messages on this channel —'**
  String get chatEmpty;

  /// No description provided for @chatJumpToNewest.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new} other{{count} new}}'**
  String chatJumpToNewest(int count);

  /// No description provided for @chatComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Message {channel}'**
  String chatComposerHint(String channel);

  /// No description provided for @chatComposerOffline.
  ///
  /// In en, this message translates to:
  /// **'Connect a radio to send'**
  String get chatComposerOffline;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatMessageActions.
  ///
  /// In en, this message translates to:
  /// **'Message actions'**
  String get chatMessageActions;

  /// No description provided for @dmTitle.
  ///
  /// In en, this message translates to:
  /// **'DM · {peer}'**
  String dmTitle(String peer);

  /// No description provided for @dmPubkeyLabel.
  ///
  /// In en, this message translates to:
  /// **'pubkey · {hex}'**
  String dmPubkeyLabel(String hex);

  /// No description provided for @dmEmpty.
  ///
  /// In en, this message translates to:
  /// **'— no messages yet —'**
  String get dmEmpty;

  /// No description provided for @dmOpenPeerDetail.
  ///
  /// In en, this message translates to:
  /// **'Peer details'**
  String get dmOpenPeerDetail;

  /// No description provided for @dmPeerNotInFabric.
  ///
  /// In en, this message translates to:
  /// **'This peer hasn\'t shown up on the mesh yet (no advert heard).'**
  String get dmPeerNotInFabric;

  /// No description provided for @dmComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Message {peer}'**
  String dmComposerHint(String peer);

  /// No description provided for @dmSend.
  ///
  /// In en, this message translates to:
  /// **'Send DM'**
  String get dmSend;

  /// No description provided for @actionReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get actionReply;

  /// No description provided for @actionReplySub.
  ///
  /// In en, this message translates to:
  /// **'Quote this message in your reply'**
  String get actionReplySub;

  /// No description provided for @actionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get actionCopy;

  /// No description provided for @actionCopySub.
  ///
  /// In en, this message translates to:
  /// **'Copy the message text to the clipboard'**
  String get actionCopySub;

  /// No description provided for @actionDeleteLocal.
  ///
  /// In en, this message translates to:
  /// **'Delete locally'**
  String get actionDeleteLocal;

  /// No description provided for @actionDeleteLocalSub.
  ///
  /// In en, this message translates to:
  /// **'Removes this row from your history only — over-the-air messages cannot be recalled.'**
  String get actionDeleteLocalSub;

  /// No description provided for @actionCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get actionCopied;

  /// No description provided for @actionDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this message locally?'**
  String get actionDeleteConfirmTitle;

  /// No description provided for @actionDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the row from your local history. MeshCore has no recall — the recipient still has it.'**
  String get actionDeleteConfirmBody;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @nodeDetailSelf.
  ///
  /// In en, this message translates to:
  /// **'This is your own node — no Message / Favourite.'**
  String get nodeDetailSelf;

  /// No description provided for @nodeDetailRecentDms.
  ///
  /// In en, this message translates to:
  /// **'RECENT DMS'**
  String get nodeDetailRecentDms;

  /// No description provided for @nodeDetailMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get nodeDetailMessage;

  /// No description provided for @nodeDetailFavourite.
  ///
  /// In en, this message translates to:
  /// **'Favourite'**
  String get nodeDetailFavourite;

  /// No description provided for @nodeDetailContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get nodeDetailContact;

  /// No description provided for @nodeDetailShowOnMap.
  ///
  /// In en, this message translates to:
  /// **'Show on geocoded map'**
  String get nodeDetailShowOnMap;

  /// No description provided for @nodeDetailShowOnMapSnack.
  ///
  /// In en, this message translates to:
  /// **'Reverse-geocoded map (R25) is on the roadmap.'**
  String get nodeDetailShowOnMapSnack;

  /// No description provided for @nodeDetailShowOnMapFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the maps app.'**
  String get nodeDetailShowOnMapFailed;

  /// No description provided for @nodeDetailCopyPubkey.
  ///
  /// In en, this message translates to:
  /// **'Copy full pubkey'**
  String get nodeDetailCopyPubkey;

  /// No description provided for @nodeDetailPubkeyCopied.
  ///
  /// In en, this message translates to:
  /// **'Pubkey copied'**
  String get nodeDetailPubkeyCopied;

  /// No description provided for @nodeDetailTags.
  ///
  /// In en, this message translates to:
  /// **'TAGS'**
  String get nodeDetailTags;

  /// No description provided for @nodeDetailAddTag.
  ///
  /// In en, this message translates to:
  /// **'tag'**
  String get nodeDetailAddTag;

  /// No description provided for @nodeDetailAddTagTitle.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get nodeDetailAddTagTitle;

  /// No description provided for @nodeDetailAddTagHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. repeater, work, ham-club'**
  String get nodeDetailAddTagHint;

  /// No description provided for @nodeDetailAddTagSuggestions.
  ///
  /// In en, this message translates to:
  /// **'RECENTLY USED'**
  String get nodeDetailAddTagSuggestions;

  /// No description provided for @nodeDetailAddTagApply.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get nodeDetailAddTagApply;

  /// No description provided for @nodeDetailInRange.
  ///
  /// In en, this message translates to:
  /// **'IN RANGE'**
  String get nodeDetailInRange;

  /// No description provided for @nodeDetailKnown.
  ///
  /// In en, this message translates to:
  /// **'KNOWN'**
  String get nodeDetailKnown;

  /// No description provided for @nodeDetailContactBadge.
  ///
  /// In en, this message translates to:
  /// **'CONTACT'**
  String get nodeDetailContactBadge;

  /// No description provided for @nodeDetailShortIdKv.
  ///
  /// In en, this message translates to:
  /// **'shortId'**
  String get nodeDetailShortIdKv;

  /// No description provided for @nodeDetailPubkeyKv.
  ///
  /// In en, this message translates to:
  /// **'pubkey'**
  String get nodeDetailPubkeyKv;

  /// No description provided for @nodeDetailSignalKv.
  ///
  /// In en, this message translates to:
  /// **'signal'**
  String get nodeDetailSignalKv;

  /// No description provided for @nodeDetailLastHeardKv.
  ///
  /// In en, this message translates to:
  /// **'last heard'**
  String get nodeDetailLastHeardKv;

  /// No description provided for @nodeDetailDistanceKv.
  ///
  /// In en, this message translates to:
  /// **'distance'**
  String get nodeDetailDistanceKv;

  /// No description provided for @nodeDetailLatLonKv.
  ///
  /// In en, this message translates to:
  /// **'lat / lon'**
  String get nodeDetailLatLonKv;

  /// No description provided for @gridViewTree.
  ///
  /// In en, this message translates to:
  /// **'Mesh tree'**
  String get gridViewTree;

  /// No description provided for @gridViewTreeShort.
  ///
  /// In en, this message translates to:
  /// **'TREE'**
  String get gridViewTreeShort;

  /// No description provided for @gridViewSnsCells.
  ///
  /// In en, this message translates to:
  /// **'SNS cells (heat)'**
  String get gridViewSnsCells;

  /// No description provided for @gridViewSnsCellsShort.
  ///
  /// In en, this message translates to:
  /// **'SNS'**
  String get gridViewSnsCellsShort;

  /// No description provided for @gridViewWeather.
  ///
  /// In en, this message translates to:
  /// **'Weather (environment)'**
  String get gridViewWeather;

  /// No description provided for @gridViewWeatherShort.
  ///
  /// In en, this message translates to:
  /// **'WX'**
  String get gridViewWeatherShort;

  /// No description provided for @weatherSelf.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get weatherSelf;

  /// No description provided for @weatherEmpty.
  ///
  /// In en, this message translates to:
  /// **'No nodes are reporting environment data yet.\nReadings appear as sensor-equipped nodes are polled — enable \"Gather node telemetry\" in App settings.'**
  String get weatherEmpty;

  /// No description provided for @weatherSelfNoTelemetry.
  ///
  /// In en, this message translates to:
  /// **'This device hasn\'t returned telemetry yet. Make sure you\'re connected, then reopen this view.'**
  String get weatherSelfNoTelemetry;

  /// No description provided for @weatherSelfNoEnv.
  ///
  /// In en, this message translates to:
  /// **'This device\'s telemetry carries no environment sensor.\nIt reported: {types}.\n(A BME280 needs the MeshCore sensor firmware / environment telemetry enabled.)'**
  String weatherSelfNoEnv(String types);

  /// No description provided for @weatherReporting.
  ///
  /// In en, this message translates to:
  /// **'{count} reporting'**
  String weatherReporting(int count);

  /// No description provided for @weatherMin.
  ///
  /// In en, this message translates to:
  /// **'MIN'**
  String get weatherMin;

  /// No description provided for @weatherAvg.
  ///
  /// In en, this message translates to:
  /// **'AVG'**
  String get weatherAvg;

  /// No description provided for @weatherMax.
  ///
  /// In en, this message translates to:
  /// **'MAX'**
  String get weatherMax;

  /// No description provided for @weatherAgoSeconds.
  ///
  /// In en, this message translates to:
  /// **'{s}s ago'**
  String weatherAgoSeconds(int s);

  /// No description provided for @weatherAgoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{m}m ago'**
  String weatherAgoMinutes(int m);

  /// No description provided for @weatherAgoHours.
  ///
  /// In en, this message translates to:
  /// **'{h}h ago'**
  String weatherAgoHours(int h);

  /// No description provided for @snsCellsAwaitingFix.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a location fix — the heat map centres on you.'**
  String get snsCellsAwaitingFix;

  /// No description provided for @snsCellsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get snsCellsClear;

  /// No description provided for @snsCellsStatus.
  ///
  /// In en, this message translates to:
  /// **'{active} cells · {hot} hot'**
  String snsCellsStatus(int active, int hot);

  /// No description provided for @snsCellsLegendTitle.
  ///
  /// In en, this message translates to:
  /// **'SNS CELLS'**
  String get snsCellsLegendTitle;

  /// No description provided for @snsCellsLegendDesc.
  ///
  /// In en, this message translates to:
  /// **'A live social-activity heat map. Each observed message warms its cell; cells cool over a one-hour horizon.'**
  String get snsCellsLegendDesc;

  /// No description provided for @snsCellsLegendHot.
  ///
  /// In en, this message translates to:
  /// **'Bright red = busy (≈5+ messages in the last minute).'**
  String get snsCellsLegendHot;

  /// No description provided for @snsCellsLegendCool.
  ///
  /// In en, this message translates to:
  /// **'Fading to white = quieting down; gone after ~1 h idle.'**
  String get snsCellsLegendCool;

  /// No description provided for @snsCellsLegendToast.
  ///
  /// In en, this message translates to:
  /// **'New messages flash as a toast near their source, then vanish.'**
  String get snsCellsLegendToast;

  /// No description provided for @snsCellsLegendChannel.
  ///
  /// In en, this message translates to:
  /// **'Channel messages carry the sender\'s name — they warm the sender\'s cell when we know their location, otherwise your own cell (the receive point).'**
  String get snsCellsLegendChannel;

  /// No description provided for @snsCellsLegendDecay.
  ///
  /// In en, this message translates to:
  /// **'Only the last hour is tracked; nothing is stored.'**
  String get snsCellsLegendDecay;

  /// No description provided for @meshTreeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Waiting for contact sync — the tree is built from each contact\'s outPath.'**
  String get meshTreeEmpty;

  /// No description provided for @meshTreeHopsDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get meshTreeHopsDirect;

  /// No description provided for @meshTreeHopsAll.
  ///
  /// In en, this message translates to:
  /// **'≤6 / All'**
  String get meshTreeHopsAll;

  /// No description provided for @meshTreeHopsFlood.
  ///
  /// In en, this message translates to:
  /// **'Flood / All'**
  String get meshTreeHopsFlood;

  /// No description provided for @meshTreeHopsN.
  ///
  /// In en, this message translates to:
  /// **'≤{n} hops'**
  String meshTreeHopsN(int n);

  /// No description provided for @meshTreeRecenter.
  ///
  /// In en, this message translates to:
  /// **'Recenter'**
  String get meshTreeRecenter;

  /// No description provided for @meshTreeLegendTitle.
  ///
  /// In en, this message translates to:
  /// **'MESH TREE'**
  String get meshTreeLegendTitle;

  /// No description provided for @meshTreeLegendDesc.
  ///
  /// In en, this message translates to:
  /// **'A directed graph of how the radio reaches each contact. Edges come from Contact.outPath — the exact repeater chain the device uses to send.'**
  String get meshTreeLegendDesc;

  /// No description provided for @meshTreeLegendSelf.
  ///
  /// In en, this message translates to:
  /// **'You — pinned at the centre.'**
  String get meshTreeLegendSelf;

  /// No description provided for @meshTreeLegendRepeater.
  ///
  /// In en, this message translates to:
  /// **'Square = repeater. Mast-mounted infra, hub colour. Peers fan out through these.'**
  String get meshTreeLegendRepeater;

  /// No description provided for @meshTreeLegendRoom.
  ///
  /// In en, this message translates to:
  /// **'Diamond = room server. Server-class node hosting named rooms.'**
  String get meshTreeLegendRoom;

  /// No description provided for @meshTreeLegendChat.
  ///
  /// In en, this message translates to:
  /// **'Circle = chat node. Peer you can DM.'**
  String get meshTreeLegendChat;

  /// No description provided for @meshTreeLegendSensor.
  ///
  /// In en, this message translates to:
  /// **'Small circle (dim) = sensor. Narrow-purpose node.'**
  String get meshTreeLegendSensor;

  /// No description provided for @meshTreeLegendFlood.
  ///
  /// In en, this message translates to:
  /// **'Dashed edge to you = flood-routed contact. Reachable, but with no fixed path.'**
  String get meshTreeLegendFlood;

  /// No description provided for @meshTreeLegendFloat.
  ///
  /// In en, this message translates to:
  /// **'Floating (no edges) — heard via advert only; route unknown.'**
  String get meshTreeLegendFloat;

  /// No description provided for @meshTreeLegendArrow.
  ///
  /// In en, this message translates to:
  /// **'Arrows point away from us, toward the destination peer.'**
  String get meshTreeLegendArrow;

  /// No description provided for @meshTreeLegendInteract.
  ///
  /// In en, this message translates to:
  /// **'Pinch to zoom, drag to pan, tap a node for details. Use Recenter to reset.'**
  String get meshTreeLegendInteract;

  /// No description provided for @fabricLegendTitle.
  ///
  /// In en, this message translates to:
  /// **'FABRIC SURVEY'**
  String get fabricLegendTitle;

  /// No description provided for @fabricLegendDesc.
  ///
  /// In en, this message translates to:
  /// **'A persistent record of where the mesh has been observed. Each rectangle is a small geographic cell (~220 m × 220 m) the device logged on contact with this location.'**
  String get fabricLegendDesc;

  /// No description provided for @fabricLegendCell.
  ///
  /// In en, this message translates to:
  /// **'Filled cell — the mesh reached here at some point.'**
  String get fabricLegendCell;

  /// No description provided for @fabricLegendRecency.
  ///
  /// In en, this message translates to:
  /// **'Brighter fill = more recent. Tiers: < 1 h, < 24 h, < 7 d, older.'**
  String get fabricLegendRecency;

  /// No description provided for @fabricLegendMarker.
  ///
  /// In en, this message translates to:
  /// **'Tertiary-coloured pins mark peers in the current set. Tap one for details.'**
  String get fabricLegendMarker;

  /// No description provided for @fabricLegendSelf.
  ///
  /// In en, this message translates to:
  /// **'The primary-coloured pin is you.'**
  String get fabricLegendSelf;

  /// No description provided for @fabricLegendReset.
  ///
  /// In en, this message translates to:
  /// **'Reset the survey from the overflow menu when you move to a new area.'**
  String get fabricLegendReset;

  /// No description provided for @nodeDetailHopsKv.
  ///
  /// In en, this message translates to:
  /// **'hops'**
  String get nodeDetailHopsKv;

  /// No description provided for @nodeDetailHopsDirect.
  ///
  /// In en, this message translates to:
  /// **'direct (0 hops)'**
  String get nodeDetailHopsDirect;

  /// No description provided for @nodeDetailHopsViaRepeaters.
  ///
  /// In en, this message translates to:
  /// **'{n} via repeater(s)'**
  String nodeDetailHopsViaRepeaters(int n);

  /// No description provided for @nodeDetailHopsUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get nodeDetailHopsUnknown;

  /// No description provided for @nodeDetailHopsFlood.
  ///
  /// In en, this message translates to:
  /// **'Flood'**
  String get nodeDetailHopsFlood;

  /// No description provided for @nodeDetailAltitudeKv.
  ///
  /// In en, this message translates to:
  /// **'altitude'**
  String get nodeDetailAltitudeKv;

  /// No description provided for @nodeDetailAltitudeMeters.
  ///
  /// In en, this message translates to:
  /// **'{m} m'**
  String nodeDetailAltitudeMeters(String m);

  /// No description provided for @nodeDetailAltitudeUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get nodeDetailAltitudeUnknown;

  /// No description provided for @nodeDetailTempKv.
  ///
  /// In en, this message translates to:
  /// **'temperature'**
  String get nodeDetailTempKv;

  /// No description provided for @nodeDetailTempValue.
  ///
  /// In en, this message translates to:
  /// **'{c} °C'**
  String nodeDetailTempValue(String c);

  /// No description provided for @nodeDetailHumidityKv.
  ///
  /// In en, this message translates to:
  /// **'humidity'**
  String get nodeDetailHumidityKv;

  /// No description provided for @nodeDetailHumidityValue.
  ///
  /// In en, this message translates to:
  /// **'{p}%'**
  String nodeDetailHumidityValue(String p);

  /// No description provided for @nodeDetailPressureKv.
  ///
  /// In en, this message translates to:
  /// **'pressure'**
  String get nodeDetailPressureKv;

  /// No description provided for @nodeDetailPressureValue.
  ///
  /// In en, this message translates to:
  /// **'{hpa} hPa'**
  String nodeDetailPressureValue(String hpa);

  /// No description provided for @nodeDetailQueryTelemetry.
  ///
  /// In en, this message translates to:
  /// **'Query telemetry'**
  String get nodeDetailQueryTelemetry;

  /// No description provided for @nodeDetailRefreshTelemetry.
  ///
  /// In en, this message translates to:
  /// **'Refresh telemetry'**
  String get nodeDetailRefreshTelemetry;

  /// No description provided for @nodeDetailTelemetryQuerying.
  ///
  /// In en, this message translates to:
  /// **'querying peer over the air…'**
  String get nodeDetailTelemetryQuerying;

  /// No description provided for @nodeDetailTelemetryNotContact.
  ///
  /// In en, this message translates to:
  /// **'Not a synced contact — telemetry can\'t be requested. Add this node as a contact on the device first.'**
  String get nodeDetailTelemetryNotContact;

  /// No description provided for @nodeDetailTelemetryAge.
  ///
  /// In en, this message translates to:
  /// **'telemetry from {age}'**
  String nodeDetailTelemetryAge(String age);

  /// No description provided for @nodeDetailAgoSeconds.
  ///
  /// In en, this message translates to:
  /// **'{n}s ago'**
  String nodeDetailAgoSeconds(int n);

  /// No description provided for @nodeDetailAgoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min ago'**
  String nodeDetailAgoMinutes(int n);

  /// No description provided for @nodeDetailAgoHours.
  ///
  /// In en, this message translates to:
  /// **'{n} h ago'**
  String nodeDetailAgoHours(int n);

  /// No description provided for @nodeDetailAgoDays.
  ///
  /// In en, this message translates to:
  /// **'{n} d ago'**
  String nodeDetailAgoDays(int n);

  /// No description provided for @channelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get channelsTitle;

  /// No description provided for @channelsHelp.
  ///
  /// In en, this message translates to:
  /// **'A channel = slot + name + 16-byte key. Public (slot 0) is the shared default. For a private group, set the SAME name & PSK in the same slot on every node.'**
  String get channelsHelp;

  /// No description provided for @channelsOfflineHint.
  ///
  /// In en, this message translates to:
  /// **'Connect a radio (Diagnostics) to edit channels.'**
  String get channelsOfflineHint;

  /// No description provided for @channelsEmpty.
  ///
  /// In en, this message translates to:
  /// **'— empty —'**
  String get channelsEmpty;

  /// No description provided for @channelsSlotLabel.
  ///
  /// In en, this message translates to:
  /// **'slot {idx}'**
  String channelsSlotLabel(int idx);

  /// No description provided for @channelsSlotActive.
  ///
  /// In en, this message translates to:
  /// **'slot {idx} · ACTIVE'**
  String channelsSlotActive(int idx);

  /// No description provided for @channelsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get channelsEdit;

  /// No description provided for @channelsSet.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get channelsSet;

  /// No description provided for @channelsSetSnack.
  ///
  /// In en, this message translates to:
  /// **'Channel {idx} set to \"{name}\" — every node needs the same name & PSK here'**
  String channelsSetSnack(int idx, String name);

  /// No description provided for @channelsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Channel slot {idx}'**
  String channelsDialogTitle(int idx);

  /// No description provided for @channelsName.
  ///
  /// In en, this message translates to:
  /// **'Channel name'**
  String get channelsName;

  /// No description provided for @channelsKeySource.
  ///
  /// In en, this message translates to:
  /// **'Key source'**
  String get channelsKeySource;

  /// No description provided for @channelsKeyPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get channelsKeyPublic;

  /// No description provided for @channelsKeyHashtag.
  ///
  /// In en, this message translates to:
  /// **'#tag'**
  String get channelsKeyHashtag;

  /// No description provided for @channelsKeyHex.
  ///
  /// In en, this message translates to:
  /// **'Hex'**
  String get channelsKeyHex;

  /// No description provided for @channelsKeyPublicBody.
  ///
  /// In en, this message translates to:
  /// **'Uses the well-known Public channel key.'**
  String get channelsKeyPublicBody;

  /// No description provided for @channelsKeyHashtagHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. #mygroup'**
  String get channelsKeyHashtagHint;

  /// No description provided for @channelsKeyHashtagHelper.
  ///
  /// In en, this message translates to:
  /// **'Key derived from the tag (sha256)'**
  String get channelsKeyHashtagHelper;

  /// No description provided for @channelsKeyHexHint.
  ///
  /// In en, this message translates to:
  /// **'32 hex chars (16 bytes)'**
  String get channelsKeyHexHint;

  /// No description provided for @channelsErrorTag.
  ///
  /// In en, this message translates to:
  /// **'Enter a #hashtag'**
  String get channelsErrorTag;

  /// No description provided for @channelsErrorHex.
  ///
  /// In en, this message translates to:
  /// **'PSK must be 32 hex chars (16 bytes)'**
  String get channelsErrorHex;

  /// No description provided for @channelsErrorName.
  ///
  /// In en, this message translates to:
  /// **'Enter a channel name'**
  String get channelsErrorName;

  /// No description provided for @channelsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get channelsCancel;

  /// No description provided for @channelsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get channelsSave;

  /// No description provided for @channelsHelpEncryption.
  ///
  /// In en, this message translates to:
  /// **'Slot 0 (Public) uses a well-known key — everyone with the firmware can read it. Other slots are AES-128 encrypted with the 16-byte PSK you set; only nodes with the same PSK can decrypt.'**
  String get channelsHelpEncryption;

  /// No description provided for @channelsHexGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate random PSK'**
  String get channelsHexGenerate;

  /// No description provided for @channelsHexCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get channelsHexCopy;

  /// No description provided for @channelsHexCopied.
  ///
  /// In en, this message translates to:
  /// **'PSK copied to clipboard'**
  String get channelsHexCopied;

  /// No description provided for @channelsTagWeakShort.
  ///
  /// In en, this message translates to:
  /// **'Short tags are guessable. Use 12+ chars or unusual phrasing.'**
  String get channelsTagWeakShort;

  /// No description provided for @channelsTagWeakCommon.
  ///
  /// In en, this message translates to:
  /// **'Common words are guessable — an attacker can grind tags. Use unusual phrasing.'**
  String get channelsTagWeakCommon;

  /// No description provided for @channelsSlot0WarnTitle.
  ///
  /// In en, this message translates to:
  /// **'Overwriting the Public channel?'**
  String get channelsSlot0WarnTitle;

  /// No description provided for @channelsSlot0WarnBody.
  ///
  /// In en, this message translates to:
  /// **'Slot 0 is the well-known Public channel. Writing a private PSK here means you\'ll only be able to talk to nodes that use this exact key in slot 0 — you\'ll lose the shared Public channel. Proceed?'**
  String get channelsSlot0WarnBody;

  /// No description provided for @channelsSlot0WarnContinue.
  ///
  /// In en, this message translates to:
  /// **'Overwrite slot 0'**
  String get channelsSlot0WarnContinue;

  /// No description provided for @channelsSlot0WarnCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get channelsSlot0WarnCancel;

  /// No description provided for @channelsCurrentKey.
  ///
  /// In en, this message translates to:
  /// **'Current key'**
  String get channelsCurrentKey;

  /// No description provided for @channelsRevealKey.
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get channelsRevealKey;

  /// No description provided for @channelsHideKey.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get channelsHideKey;

  /// No description provided for @channelsCurrentKeyUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not loaded yet — open then close this dialog after the device has synced.'**
  String get channelsCurrentKeyUnknown;

  /// No description provided for @channelsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear slot'**
  String get channelsClear;

  /// No description provided for @channelsClearConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear slot {idx}?'**
  String channelsClearConfirmTitle(int idx);

  /// No description provided for @channelsClearConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'MeshCore has no protocol-level \"clear\" — this slot will be overwritten back to the well-known Public defaults (name + key). Other nodes will need to do the same to talk on it again.'**
  String get channelsClearConfirmBody;

  /// No description provided for @channelsClearConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get channelsClearConfirmAction;

  /// No description provided for @channelsClearSnack.
  ///
  /// In en, this message translates to:
  /// **'Slot {idx} cleared (reset to Public defaults)'**
  String channelsClearSnack(int idx);

  /// No description provided for @channelsDefaultBadge.
  ///
  /// In en, this message translates to:
  /// **'DEFAULT'**
  String get channelsDefaultBadge;

  /// No description provided for @channelsSetDefaultTooltip.
  ///
  /// In en, this message translates to:
  /// **'Set as default channel on launch'**
  String get channelsSetDefaultTooltip;

  /// No description provided for @channelsClearDefaultTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear default channel preference'**
  String get channelsClearDefaultTooltip;

  /// No description provided for @channelsSetDefaultSnack.
  ///
  /// In en, this message translates to:
  /// **'Slot {idx} is now the launch default'**
  String channelsSetDefaultSnack(int idx);

  /// No description provided for @channelsClearedDefaultSnack.
  ///
  /// In en, this message translates to:
  /// **'Launch default cleared'**
  String get channelsClearedDefaultSnack;

  /// No description provided for @channelsKeyShake.
  ///
  /// In en, this message translates to:
  /// **'Shake'**
  String get channelsKeyShake;

  /// No description provided for @channelsShakeTitle.
  ///
  /// In en, this message translates to:
  /// **'Shake to roll dice'**
  String get channelsShakeTitle;

  /// No description provided for @channelsShakeBody.
  ///
  /// In en, this message translates to:
  /// **'Shake your phone — each accepted motion sample feeds the hash. Stop once the ring fills.'**
  String get channelsShakeBody;

  /// No description provided for @channelsShakeProgress.
  ///
  /// In en, this message translates to:
  /// **'{accepted} of {target} samples · {pct}%'**
  String channelsShakeProgress(int accepted, int target, int pct);

  /// No description provided for @channelsShakeReroll.
  ///
  /// In en, this message translates to:
  /// **'Reroll'**
  String get channelsShakeReroll;

  /// No description provided for @channelsShakeUse.
  ///
  /// In en, this message translates to:
  /// **'Use this key'**
  String get channelsShakeUse;

  /// No description provided for @channelsShakeTapFallback.
  ///
  /// In en, this message translates to:
  /// **'Tap to roll (reduceMotion is on — uses Random.secure instead)'**
  String get channelsShakeTapFallback;

  /// No description provided for @channelsShareQr.
  ///
  /// In en, this message translates to:
  /// **'Share via QR'**
  String get channelsShareQr;

  /// No description provided for @channelsQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Share channel {idx}'**
  String channelsQrTitle(int idx);

  /// No description provided for @channelsQrBody.
  ///
  /// In en, this message translates to:
  /// **'Scan with a Meshmore device or any QR reader. Anyone with this code can join the channel — share only with trusted peers.'**
  String get channelsQrBody;

  /// No description provided for @channelsQrPayload.
  ///
  /// In en, this message translates to:
  /// **'Payload (also copy-friendly)'**
  String get channelsQrPayload;

  /// No description provided for @channelsQrClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get channelsQrClose;

  /// No description provided for @deviceConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Device configuration'**
  String get deviceConfigTitle;

  /// No description provided for @deviceRegionBand.
  ///
  /// In en, this message translates to:
  /// **'REGION / BAND'**
  String get deviceRegionBand;

  /// No description provided for @deviceRegionCurrent.
  ///
  /// In en, this message translates to:
  /// **'CURRENTLY APPLIED'**
  String get deviceRegionCurrent;

  /// No description provided for @deviceRegionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Waiting for device…'**
  String get deviceRegionUnknown;

  /// No description provided for @deviceRegionCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom (no preset match)'**
  String get deviceRegionCustom;

  /// No description provided for @deviceRegionSuggestFromLocation.
  ///
  /// In en, this message translates to:
  /// **'Suggest from my location'**
  String get deviceRegionSuggestFromLocation;

  /// No description provided for @deviceRegionSuggestTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply suggested region?'**
  String get deviceRegionSuggestTitle;

  /// No description provided for @deviceRegionSuggestBody.
  ///
  /// In en, this message translates to:
  /// **'Based on your phone GPS ({lat}, {lon}), the matching preset is {label}. Verify this is legal where you are before applying — particularly outside the country you set up in.'**
  String deviceRegionSuggestBody(String lat, String lon, String label);

  /// No description provided for @deviceRegionSuggestApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get deviceRegionSuggestApply;

  /// No description provided for @deviceRegionSuggestNoFix.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get a GPS fix — try outdoors with location permission granted.'**
  String get deviceRegionSuggestNoFix;

  /// No description provided for @deviceRegionSuggestNoMatch.
  ///
  /// In en, this message translates to:
  /// **'Your location doesn\'t match any shipped country preset — pick one manually.'**
  String get deviceRegionSuggestNoMatch;

  /// No description provided for @deviceRegionAppliedToast.
  ///
  /// In en, this message translates to:
  /// **'{label} applied — make sure every node in your mesh uses the same preset.'**
  String deviceRegionAppliedToast(String label);

  /// No description provided for @deviceRegionDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Operating points are community-curated, not regulatory guarantees. Pick the preset legal where you are and use the SAME tuple on every node. The Japan (ARIB STD-T108) preset is a community proposal that hasn\'t been broadly field-validated — please confirm it is legal and works on your hardware before relying on it.'**
  String get deviceRegionDisclaimer;

  /// No description provided for @presetUsCanada.
  ///
  /// In en, this message translates to:
  /// **'USA / Canada'**
  String get presetUsCanada;

  /// No description provided for @presetUsArizona.
  ///
  /// In en, this message translates to:
  /// **'USA — Arizona'**
  String get presetUsArizona;

  /// No description provided for @presetJpAribT108.
  ///
  /// In en, this message translates to:
  /// **'Japan (ARIB STD-T108)'**
  String get presetJpAribT108;

  /// No description provided for @presetEuUkLong.
  ///
  /// In en, this message translates to:
  /// **'EU / UK (Long Range)'**
  String get presetEuUkLong;

  /// No description provided for @presetEuUkMedium.
  ///
  /// In en, this message translates to:
  /// **'EU / UK (Medium Range)'**
  String get presetEuUkMedium;

  /// No description provided for @presetEuUkNarrow.
  ///
  /// In en, this message translates to:
  /// **'EU / UK (Narrow)'**
  String get presetEuUkNarrow;

  /// No description provided for @presetCh.
  ///
  /// In en, this message translates to:
  /// **'Switzerland'**
  String get presetCh;

  /// No description provided for @presetCz.
  ///
  /// In en, this message translates to:
  /// **'Czech Republic'**
  String get presetCz;

  /// No description provided for @presetPt869.
  ///
  /// In en, this message translates to:
  /// **'Portugal (869 MHz)'**
  String get presetPt869;

  /// No description provided for @presetAu.
  ///
  /// In en, this message translates to:
  /// **'Australia'**
  String get presetAu;

  /// No description provided for @presetAuNarrow.
  ///
  /// In en, this message translates to:
  /// **'Australia (Narrow)'**
  String get presetAuNarrow;

  /// No description provided for @presetAuSaWaQld.
  ///
  /// In en, this message translates to:
  /// **'Australia (SA / WA / QLD)'**
  String get presetAuSaWaQld;

  /// No description provided for @presetNz.
  ///
  /// In en, this message translates to:
  /// **'New Zealand'**
  String get presetNz;

  /// No description provided for @presetVn.
  ///
  /// In en, this message translates to:
  /// **'Vietnam'**
  String get presetVn;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @deviceRadioParams.
  ///
  /// In en, this message translates to:
  /// **'RADIO PARAMS'**
  String get deviceRadioParams;

  /// No description provided for @deviceIdentityAdvert.
  ///
  /// In en, this message translates to:
  /// **'IDENTITY / ADVERT'**
  String get deviceIdentityAdvert;

  /// No description provided for @deviceChannelsSection.
  ///
  /// In en, this message translates to:
  /// **'CHANNELS'**
  String get deviceChannelsSection;

  /// No description provided for @deviceOtherParamsSection.
  ///
  /// In en, this message translates to:
  /// **'OTHER PARAMS'**
  String get deviceOtherParamsSection;

  /// No description provided for @deviceDeviceSection.
  ///
  /// In en, this message translates to:
  /// **'DEVICE'**
  String get deviceDeviceSection;

  /// No description provided for @deviceFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency (MHz)'**
  String get deviceFrequency;

  /// No description provided for @deviceBandwidth.
  ///
  /// In en, this message translates to:
  /// **'Bandwidth (kHz)'**
  String get deviceBandwidth;

  /// No description provided for @deviceSpreadingFactor.
  ///
  /// In en, this message translates to:
  /// **'Spreading factor (5–12)'**
  String get deviceSpreadingFactor;

  /// No description provided for @deviceCodingRate.
  ///
  /// In en, this message translates to:
  /// **'Coding rate (5–8)'**
  String get deviceCodingRate;

  /// No description provided for @deviceTxPower.
  ///
  /// In en, this message translates to:
  /// **'TX power (dBm)'**
  String get deviceTxPower;

  /// No description provided for @deviceLoadFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Load from device'**
  String get deviceLoadFromDevice;

  /// No description provided for @deviceApplyRadio.
  ///
  /// In en, this message translates to:
  /// **'Apply radio params'**
  String get deviceApplyRadio;

  /// No description provided for @deviceConnectFirst.
  ///
  /// In en, this message translates to:
  /// **'Connect a radio first (Diagnostics & connect).'**
  String get deviceConnectFirst;

  /// No description provided for @deviceAdvertName.
  ///
  /// In en, this message translates to:
  /// **'Advert name'**
  String get deviceAdvertName;

  /// No description provided for @deviceSetName.
  ///
  /// In en, this message translates to:
  /// **'Set name'**
  String get deviceSetName;

  /// No description provided for @deviceAdvertLatitude.
  ///
  /// In en, this message translates to:
  /// **'Advert latitude (°)'**
  String get deviceAdvertLatitude;

  /// No description provided for @deviceAdvertLongitude.
  ///
  /// In en, this message translates to:
  /// **'Advert longitude (°)'**
  String get deviceAdvertLongitude;

  /// No description provided for @deviceUsePhoneLocation.
  ///
  /// In en, this message translates to:
  /// **'Use phone location'**
  String get deviceUsePhoneLocation;

  /// No description provided for @deviceReadDeviceLocation.
  ///
  /// In en, this message translates to:
  /// **'Read device location'**
  String get deviceReadDeviceLocation;

  /// No description provided for @deviceSetAdvertLocation.
  ///
  /// In en, this message translates to:
  /// **'Set advert location'**
  String get deviceSetAdvertLocation;

  /// No description provided for @deviceAdvertSource.
  ///
  /// In en, this message translates to:
  /// **'Advert location source'**
  String get deviceAdvertSource;

  /// No description provided for @deviceAdvertSourceNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get deviceAdvertSourceNone;

  /// No description provided for @deviceAdvertSourcePinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get deviceAdvertSourcePinned;

  /// No description provided for @deviceAdvertSourceGps.
  ///
  /// In en, this message translates to:
  /// **'Device GPS'**
  String get deviceAdvertSourceGps;

  /// No description provided for @deviceToastNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a node name'**
  String get deviceToastNameEmpty;

  /// No description provided for @deviceToastNameSet.
  ///
  /// In en, this message translates to:
  /// **'Name updated — re-advertising to neighbours'**
  String get deviceToastNameSet;

  /// No description provided for @deviceToastSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Send failed: {error}'**
  String deviceToastSendFailed(String error);

  /// No description provided for @deviceToastNoDeviceYet.
  ///
  /// In en, this message translates to:
  /// **'Device hasn\'t reported yet — try once linked'**
  String get deviceToastNoDeviceYet;

  /// No description provided for @deviceToastNoGpsYet.
  ///
  /// In en, this message translates to:
  /// **'Device has no location yet (no GPS fix)'**
  String get deviceToastNoGpsYet;

  /// No description provided for @deviceToastLoadedDeviceLoc.
  ///
  /// In en, this message translates to:
  /// **'Loaded device location · tap Set advert location to broadcast'**
  String get deviceToastLoadedDeviceLoc;

  /// No description provided for @deviceToastGettingPhoneFix.
  ///
  /// In en, this message translates to:
  /// **'Getting phone GPS fix…'**
  String get deviceToastGettingPhoneFix;

  /// No description provided for @deviceToastPhoneFixFailed.
  ///
  /// In en, this message translates to:
  /// **'Phone GPS fix failed (services off or timeout)'**
  String get deviceToastPhoneFixFailed;

  /// No description provided for @deviceToastNoFixReturned.
  ///
  /// In en, this message translates to:
  /// **'No fix returned'**
  String get deviceToastNoFixReturned;

  /// No description provided for @deviceToastGotPhoneLoc.
  ///
  /// In en, this message translates to:
  /// **'Got phone location · tap Set advert location to broadcast'**
  String get deviceToastGotPhoneLoc;

  /// No description provided for @deviceToastInvalidLatLon.
  ///
  /// In en, this message translates to:
  /// **'Enter valid lat (−90..90) and lon (−180..180)'**
  String get deviceToastInvalidLatLon;

  /// No description provided for @deviceToastAdvertLocSet.
  ///
  /// In en, this message translates to:
  /// **'Advert location set'**
  String get deviceToastAdvertLocSet;

  /// No description provided for @deviceToastInvalidRadio.
  ///
  /// In en, this message translates to:
  /// **'Enter valid numbers for freq/BW/SF/CR'**
  String get deviceToastInvalidRadio;

  /// No description provided for @deviceToastRadioSent.
  ///
  /// In en, this message translates to:
  /// **'Radio params sent — restart/observe the device to confirm'**
  String get deviceToastRadioSent;

  /// No description provided for @deviceLocPermDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission needed for a phone GPS fix.'**
  String get deviceLocPermDenied;

  /// No description provided for @deviceLocPermDeniedPerm.
  ///
  /// In en, this message translates to:
  /// **'Location permission permanently denied — open OS settings to grant it.'**
  String get deviceLocPermDeniedPerm;

  /// No description provided for @deviceOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get deviceOpenSettings;

  /// No description provided for @diagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics & connect'**
  String get diagnosticsTitle;

  /// No description provided for @diagnosticsState.
  ///
  /// In en, this message translates to:
  /// **'STATE'**
  String get diagnosticsState;

  /// No description provided for @diagnosticsSends.
  ///
  /// In en, this message translates to:
  /// **'SENDS'**
  String get diagnosticsSends;

  /// No description provided for @diagnosticsChannelTail.
  ///
  /// In en, this message translates to:
  /// **'CHANNEL-TAIL ORACLE'**
  String get diagnosticsChannelTail;

  /// No description provided for @diagnosticsCapture.
  ///
  /// In en, this message translates to:
  /// **'CAPTURE / EXPORT'**
  String get diagnosticsCapture;

  /// No description provided for @diagnosticsRawFrameLog.
  ///
  /// In en, this message translates to:
  /// **'RAW FRAME LOG (newest first)'**
  String get diagnosticsRawFrameLog;

  /// No description provided for @diagnosticsConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get diagnosticsConnect;

  /// No description provided for @diagnosticsDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get diagnosticsDisconnect;

  /// No description provided for @diagnosticsForget.
  ///
  /// In en, this message translates to:
  /// **'Forget device'**
  String get diagnosticsForget;

  /// No description provided for @diagnosticsCopyLog.
  ///
  /// In en, this message translates to:
  /// **'Copy log'**
  String get diagnosticsCopyLog;

  /// No description provided for @otherManualAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Manual-add contacts'**
  String get otherManualAddTitle;

  /// No description provided for @otherManualAddSubOn.
  ///
  /// In en, this message translates to:
  /// **'You add heard nodes as contacts on demand.'**
  String get otherManualAddSubOn;

  /// No description provided for @otherManualAddSubOff.
  ///
  /// In en, this message translates to:
  /// **'Heard nodes auto-promote to contacts.'**
  String get otherManualAddSubOff;

  /// No description provided for @otherTelemetryLabel.
  ///
  /// In en, this message translates to:
  /// **'Telemetry mode (raw byte)'**
  String get otherTelemetryLabel;

  /// No description provided for @otherTelemetryHelper.
  ///
  /// In en, this message translates to:
  /// **'0 = off · semantics are firmware-defined.'**
  String get otherTelemetryHelper;

  /// No description provided for @otherMultiAcksLabel.
  ///
  /// In en, this message translates to:
  /// **'Multi-acks (0–3)'**
  String get otherMultiAcksLabel;

  /// No description provided for @otherMultiAcksHelper.
  ///
  /// In en, this message translates to:
  /// **'0 = single ack (default). Higher = wait for N extra acks before considering a send confirmed.'**
  String get otherMultiAcksHelper;

  /// No description provided for @otherApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get otherApply;

  /// No description provided for @otherSentSnack.
  ///
  /// In en, this message translates to:
  /// **'OTHER PARAMS sent — device-side write may take a moment.'**
  String get otherSentSnack;

  /// No description provided for @otherAwaitingDevice.
  ///
  /// In en, this message translates to:
  /// **'— awaiting device —'**
  String get otherAwaitingDevice;

  /// No description provided for @batteryTitle.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get batteryTitle;

  /// No description provided for @batteryConfigSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Charge, drain rate, and time-to-empty estimate'**
  String get batteryConfigSubtitle;

  /// No description provided for @batteryAwaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a battery reading from the device…'**
  String get batteryAwaiting;

  /// No description provided for @batteryReset.
  ///
  /// In en, this message translates to:
  /// **'Reset history'**
  String get batteryReset;

  /// No description provided for @batteryResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear all stored battery history? The runtime estimate will rebuild as new readings arrive.'**
  String get batteryResetConfirm;

  /// No description provided for @batteryVoltageLabel.
  ///
  /// In en, this message translates to:
  /// **'VOLTAGE'**
  String get batteryVoltageLabel;

  /// No description provided for @batteryCharging.
  ///
  /// In en, this message translates to:
  /// **'Charging'**
  String get batteryCharging;

  /// No description provided for @batteryChargingNote.
  ///
  /// In en, this message translates to:
  /// **'Charging — runtime estimate paused.'**
  String get batteryChargingNote;

  /// No description provided for @batteryTimeToEmpty.
  ///
  /// In en, this message translates to:
  /// **'TIME TO EMPTY'**
  String get batteryTimeToEmpty;

  /// No description provided for @batteryEstimating.
  ///
  /// In en, this message translates to:
  /// **'Gathering drain data — an estimate appears after a few minutes of discharge.'**
  String get batteryEstimating;

  /// No description provided for @batteryDrainRate.
  ///
  /// In en, this message translates to:
  /// **'Drain rate'**
  String get batteryDrainRate;

  /// No description provided for @batteryBasis.
  ///
  /// In en, this message translates to:
  /// **'Basis'**
  String get batteryBasis;

  /// No description provided for @batteryBasisObserved.
  ///
  /// In en, this message translates to:
  /// **'measured over {span} of discharge'**
  String batteryBasisObserved(String span);

  /// No description provided for @batteryBasisRated.
  ///
  /// In en, this message translates to:
  /// **'nameplate (capacity ÷ typical draw)'**
  String get batteryBasisRated;

  /// No description provided for @batteryConfidence.
  ///
  /// In en, this message translates to:
  /// **'confidence'**
  String get batteryConfidence;

  /// No description provided for @batteryConfHigh.
  ///
  /// In en, this message translates to:
  /// **'high'**
  String get batteryConfHigh;

  /// No description provided for @batteryConfMedium.
  ///
  /// In en, this message translates to:
  /// **'medium'**
  String get batteryConfMedium;

  /// No description provided for @batteryConfLow.
  ///
  /// In en, this message translates to:
  /// **'low'**
  String get batteryConfLow;

  /// No description provided for @batteryMethodObserved.
  ///
  /// In en, this message translates to:
  /// **'Measured discharge'**
  String get batteryMethodObserved;

  /// No description provided for @batteryMethodRated.
  ///
  /// In en, this message translates to:
  /// **'Rated estimate'**
  String get batteryMethodRated;

  /// No description provided for @batteryMethodNone.
  ///
  /// In en, this message translates to:
  /// **'Gathering data'**
  String get batteryMethodNone;

  /// No description provided for @batterySpecTitle.
  ///
  /// In en, this message translates to:
  /// **'DEVICE MODEL'**
  String get batterySpecTitle;

  /// No description provided for @batterySpecGeneric.
  ///
  /// In en, this message translates to:
  /// **'Unknown hardware — using a generic single-cell Li-ion model. The estimate relies on observed drain (no nameplate capacity to cross-check).'**
  String get batterySpecGeneric;

  /// No description provided for @batterySpecCapacity.
  ///
  /// In en, this message translates to:
  /// **'Capacity: {mah} mAh'**
  String batterySpecCapacity(int mah);

  /// No description provided for @batterySpecCapacityUnknown.
  ///
  /// In en, this message translates to:
  /// **'Capacity: user-supplied (unknown)'**
  String get batterySpecCapacityUnknown;

  /// No description provided for @batterySpecDraw.
  ///
  /// In en, this message translates to:
  /// **'Typical draw: ~{ma} mA (radio receiving)'**
  String batterySpecDraw(int ma);

  /// No description provided for @batteryHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'VOLTAGE HISTORY'**
  String get batteryHistoryTitle;

  /// No description provided for @batteryHistorySpan.
  ///
  /// In en, this message translates to:
  /// **'{span} · {count} samples'**
  String batteryHistorySpan(String span, int count);

  /// No description provided for @batteryDurDH.
  ///
  /// In en, this message translates to:
  /// **'{days}d {hours}h'**
  String batteryDurDH(int days, int hours);

  /// No description provided for @batteryDurHM.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {mins}m'**
  String batteryDurHM(int hours, int mins);

  /// No description provided for @batteryDurM.
  ///
  /// In en, this message translates to:
  /// **'{mins}m'**
  String batteryDurM(int mins);

  /// No description provided for @deliverySending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get deliverySending;

  /// No description provided for @deliverySent.
  ///
  /// In en, this message translates to:
  /// **'Sent into the mesh'**
  String get deliverySent;

  /// No description provided for @deliveryDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered (recipient acknowledged)'**
  String get deliveryDelivered;

  /// No description provided for @deliveryFailed.
  ///
  /// In en, this message translates to:
  /// **'Not delivered — no acknowledgement or send failed'**
  String get deliveryFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
