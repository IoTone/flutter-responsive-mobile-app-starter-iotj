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
