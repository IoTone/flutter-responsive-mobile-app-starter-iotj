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
