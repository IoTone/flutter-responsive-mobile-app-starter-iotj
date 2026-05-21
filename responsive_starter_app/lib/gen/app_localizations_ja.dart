// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'Meshmore SNS';

  @override
  String get appSubtitle => 'ソーシャルロボット・ネットワークサービス';

  @override
  String get tabDashboard => 'ダッシュボード';

  @override
  String get tabChat => 'チャット';

  @override
  String get tabNodes => 'ノード';

  @override
  String get tabSettings => '設定';

  @override
  String get tabAbout => 'アプリ情報';

  @override
  String get dashboardPeersInRange => '範囲内のピア';

  @override
  String dashboardKnownCount(int n) {
    return '$n件 既知';
  }

  @override
  String get dashboardRadio => 'ラジオ';

  @override
  String get dashboardLocation => '現在地';

  @override
  String get dashboardBattery => 'バッテリー';

  @override
  String get dashboardRecent => '最近のアクティビティ';

  @override
  String get dashboardNoActivity => '— アクティビティなし —';

  @override
  String get dashboardAwaitingDevice => '— デバイス待機中 —';

  @override
  String get dashboardAwaitingDeviceLocation => '— デバイス位置情報を待機中 —';

  @override
  String get dashboardLocationNotSet => '未設定 — デバイス・スマートフォンともに位置情報未取得';

  @override
  String get dashboardLocationConfigure => '設定';

  @override
  String dashboardLocationSourceLabel(String source) {
    return 'ソース · $source';
  }

  @override
  String get statusLinked => '接続中 · 通常';

  @override
  String get statusSyncing => '同期中…';

  @override
  String get statusSyncingLong => '同期中…';

  @override
  String get statusHandshaking => '同期中…';

  @override
  String get statusReconnecting => '再接続中…';

  @override
  String get statusLinkLost => '接続切断';

  @override
  String get statusOffline => 'オフライン';

  @override
  String get statusConnecting => '接続中…';

  @override
  String get actionConnect => '接続';

  @override
  String get actionRetry => '再試行';

  @override
  String get settingsHeading => 'アプリ設定';

  @override
  String get settingsConnection => '接続';

  @override
  String get settingsConnectionSubtitle => '自動再接続 (M7 バックオフ) · デバイス解除';

  @override
  String get settingsBackgroundTitle => 'バックグラウンドで接続を維持';

  @override
  String get settingsBackgroundOn =>
      'Android: 常駐通知でラジオ接続を維持し、バックグラウンド中もメッセージを受信';

  @override
  String get settingsBackgroundOff =>
      'アプリ再表示時にメッセージ受信 (ラジオがバッファ); バックグラウンド通知なし';

  @override
  String get settingsLanguage => '言語';

  @override
  String get settingsLanguageSystem => 'システム既定';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageJapanese => '日本語';

  @override
  String get settingsSpeech => '音声読み上げ (R5)';

  @override
  String get settingsSpeechOn => '音声読み上げ ON · チャネル別切替はチャット内';

  @override
  String get settingsSpeechOff => '音声読み上げ OFF (既定) · チャネルメッセージを読み上げ';

  @override
  String get settingsNotifications => '通知';

  @override
  String get settingsNotificationsSubtitle => '重要 → システム通知 + バイブレーション';

  @override
  String get settingsData => 'データ / アプリ情報';

  @override
  String get settingsDataSubtitle => '診断エクスポート · ログ · アプリ情報 · 利用規約';

  @override
  String get settingsPermissions => '権限';

  @override
  String get settingsPermissionsSubtitle =>
      'このアプリの OS 設定画面を開く — Bluetooth / 通知をオン・オフできます。';

  @override
  String get settingsShowIntro => '次回起動時に紹介を再表示';

  @override
  String get settingsShowIntroEnabled => '初回フラグを消去し権限紹介を再表示 — フロー検証時に便利';

  @override
  String get settingsShowIntroDisabled => '紹介は次回起動時に表示予定';

  @override
  String get aboutCopyright => 'Copyright (c) 2026 IoTone, Inc.';

  @override
  String get aboutSubtitleEn => '(Socialrobot Network Service)';

  @override
  String get aboutSubtitleJa => '(ソーシャルロボット・ネットワークサービス)';

  @override
  String get aboutDescription => 'MeshCore コンパニオンクライアント。';

  @override
  String get aboutLicense => 'MIT (X11) ライセンスで提供。';

  @override
  String get aboutMadeWith => '福岡から ♥ をこめて';

  @override
  String get aboutTerms => '利用規約 — U5 で配線予定。';

  @override
  String aboutVersion(String version) {
    return 'v$version';
  }

  @override
  String get personalizationHeading => 'プロフィール & パーソナライズ';

  @override
  String get personalizationThemePreset => 'テーマプリセット';

  @override
  String get personalizationType => '文字';

  @override
  String get personalizationFontSize => 'フォントサイズ';

  @override
  String get personalizationAccessibility => 'アクセシビリティ (R13)';

  @override
  String get personalizationHighContrast => 'ハイコントラスト';

  @override
  String get personalizationHighContrastSubtitle => 'SEELE ハイコントラストパレットを強制適用';

  @override
  String get personalizationHighContrastHint =>
      'ハイコントラストが ON のため、プリセットの選択に関わらず SEELE ハイコントラストパレットが強制されます。別テーマを使うには下の「ハイコントラスト」を OFF にしてください。';

  @override
  String get personalizationReduceMotion => 'モーションを減らす';

  @override
  String get personalizationVisualHapticOnly => '視覚 + 触覚のみ';

  @override
  String get personalizationVisualHapticOnlySubtitle => '音による情報提示なし; 音声をオフ';

  @override
  String get personalizationAudioAlerts => '音声アラート (R12)';

  @override
  String get personalizationAudioMaster => '音声アラート';

  @override
  String get personalizationAudioMasterDisabled => '「視覚 + 触覚のみ」により無効';

  @override
  String get personalizationAudioMasterEnabled => '既定で OFF; 補助としてのみ';

  @override
  String get firstRunHeader => 'MESHMORE · ようこそ';

  @override
  String get firstRunTitle => 'アプリが必要とする権限について';

  @override
  String get firstRunBleTitle => 'Bluetooth';

  @override
  String get firstRunBleBody =>
      'MeshCore ラジオとペアリングし、ローカルメッシュ越しにメッセージを送受信します。OTA 通信に必須です。';

  @override
  String get firstRunNotificationsTitle => '通知';

  @override
  String get firstRunNotificationsBody =>
      '後でアプリ設定の「バックグラウンドで接続を維持」を ON にした場合のみ求めます。今回はスキップし二度確認しません。';

  @override
  String get firstRunOfflineTitle => 'オフラインでも使えます';

  @override
  String get firstRunOfflineBody =>
      'Bluetooth をスキップしてもアプリは動作します — メッセージ履歴の閲覧、チャネル設定、診断などが可能。Bluetooth を許可するまでライブメッシュ通信のみ利用不可。';

  @override
  String get firstRunGrant => 'Bluetooth を許可して続行';

  @override
  String get firstRunSkip => 'オフラインで続行 (権限をスキップ)';

  @override
  String get firstRunDeniedTransient =>
      'Bluetooth が許可されませんでした — オフラインで続行するか、OS 設定で許可を変更できます。';

  @override
  String get firstRunDeniedPermanent =>
      'Bluetooth が永続的に拒否されました — OS 設定で許可してください。オフラインでも引き続き利用可能です。';

  @override
  String get firstRunOpenSettings => 'OS 設定を開く';
}
