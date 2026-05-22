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

  @override
  String dashboardPaired(String name) {
    return 'ペア済み: $name';
  }

  @override
  String get dashboardCharging => '充電中';

  @override
  String dashboardBatteryReadout(String volts, int percent) {
    return '${volts}V · 約$percent%';
  }

  @override
  String get nodesScanArea => '周辺をスキャン';

  @override
  String get nodesScanning => 'スキャン中…';

  @override
  String get nodesAdvertise => 'アドバート送信';

  @override
  String get nodesSyncContacts => 'コンタクト同期';

  @override
  String get nodesHyperlocalGridTooltip => 'ハイパーローカルグリッド (R18)';

  @override
  String get nodesFloodAdvert => 'フラッドアドバート';

  @override
  String get nodesFloodAdvertBody => 'メッシュ全体 — 隣接 + リピーター。発見に最適。';

  @override
  String get nodesZeroHopAdvert => 'ゼロホップアドバート';

  @override
  String get nodesZeroHopAdvertBody => '隣接のみ — 再ブロードキャストなし。混雑したメッシュ向け。';

  @override
  String get nodesFloodAdvertSent =>
      'フラッドアドバートを送信 — メッシュ全体に伝播 (隣接 + リピーター)。相手側でも Advertise を実行するまで表示されません。';

  @override
  String get nodesZeroHopAdvertSent =>
      'ゼロホップアドバートを送信 — 隣接のみ、リピーターは再ブロードキャストしません。';

  @override
  String get nodesSearchHint => '名前 / shortId / 公開鍵で検索…';

  @override
  String get nodesFilterStarred => 'お気に入り';

  @override
  String get nodesFilterInRange => '範囲内';

  @override
  String get nodesFilterClear => 'クリア';

  @override
  String nodesFilterLastSeen(String label) {
    return '最終受信 · $label';
  }

  @override
  String nodesFilterWithin(String label) {
    return '距離 · $label';
  }

  @override
  String get nodesAgeAny => '指定なし';

  @override
  String get nodesAgeHour => '1時間以内';

  @override
  String get nodesAge24h => '24時間以内';

  @override
  String get nodesAge7d => '7日以内';

  @override
  String get nodesDistAny => '指定なし';

  @override
  String get nodesDist100m => '100 m 以内';

  @override
  String get nodesDist500m => '500 m 以内';

  @override
  String get nodesDist5km => '5 km 以内';

  @override
  String get nodesDist25km => '25 km 以内';

  @override
  String nodesStatusReady(int shown, int total, int inRange, int favs) {
    return '$shown/$total件 表示 · $inRange件 範囲内 · $favs件 コンタクト';
  }

  @override
  String get nodesStatusOffline => '未接続 — 設定 → 診断で接続';

  @override
  String get nodesInRangeBadge => '範囲内';

  @override
  String get nodesEmptyFiltered =>
      '条件に一致するノードがありません。\n\n上の「クリア」で絞り込みを解除するか、各チップで条件を変更してください。';

  @override
  String get nodesEmptyReady =>
      'ノードがまだありません。\n\n発見はアドバート駆動で、アドバートを受信したノードのみここに表示されます。Public でのチャットは発見につながりません。\n\n相手にも Advertise を実行してもらう (またはこちらで「Advertise」をタップ) 後、「Scan area」を実行してください。\n\nこの画面はメッシュの「ファブリック」(これまでに見たもの) を示します。スターをタップするとコンタクトに登録できます。';

  @override
  String get nodesEmptyOffline => 'ラジオを接続して周辺ノードを発見してください。';

  @override
  String get nodesFavTooltip => 'コンタクトに登録';

  @override
  String get nodesUnfavTooltip => 'コンタクトから削除';

  @override
  String get gridTitle => 'ハイパーローカルグリッド';

  @override
  String get gridShowLegend => '凡例を表示';

  @override
  String get gridHideLegend => '凡例を非表示';

  @override
  String get gridPlayTooltip => '再生 (一定間隔で更新)';

  @override
  String get gridPauseTooltip => '一時停止';

  @override
  String get gridIntervalTooltip => '更新間隔 (再生時)';

  @override
  String get gridRange => '範囲';

  @override
  String get gridRangeRoom => '部屋';

  @override
  String get gridRangeHome => '家';

  @override
  String get gridRangeBlock => 'ブロック';

  @override
  String get gridRangeNeighborhood => '近隣';

  @override
  String get gridRangeArea => 'エリア';

  @override
  String get gridRangeWide => '広域';

  @override
  String get gridLegend => '凡例';

  @override
  String gridLegendRings(String value) {
    return '同心円 3 本 = 距離帯。両端に GPS がある場合、外側のリングは上の「範囲」スケール (現在 ~$value)。GPS がない場合は RSSI 帯 (近 / 中 / 遠)。';
  }

  @override
  String get gridLegendSelf => '中央 = 自分。十字 = 南北 / 東西の目安。';

  @override
  String get gridLegendDot =>
      'ドット = 受信したファブリックノード。明るさ = 新しさ (受信直後 = 最大、24時間で 0 に減衰し消滅)。';

  @override
  String get gridLegendKnown => 'パルス (緩やかに広がる輪) = 既知ノード — 直接やり取り (DM) があったノード。';

  @override
  String get gridLegendFavourite => '別色での速い点滅 = お気に入りのコンタクト。';

  @override
  String get gridLegendRipple => '中央からの波紋 = 匿名のチャネルメッセージ (プロトコル上、送信者を特定できません)。';

  @override
  String get gridLegendTap => 'ノードをタップで詳細 + メッセージ / お気に入り。';

  @override
  String get gridEmpty =>
      'まだ範囲内にファブリックがありません。\n\nアドバートを受信するとここに表示されます。Nodes 画面でスターをタップしてコンタクト登録 (速い点滅)。DM 交換したノードは既知になります (パルス)。';

  @override
  String gridStatusReady(int visible, int known, int favs, String playState) {
    return '$visible件 ファブリック · $known件 既知 · $favs件 コンタクト · $playState';
  }

  @override
  String get gridStatusOffline => '未接続 — 設定 → 診断で接続';

  @override
  String get gridPlayStatePaused => '一時停止中';

  @override
  String gridPlayStateLive(String interval) {
    return 'ライブ ($interval)';
  }

  @override
  String gridFooter(String label, String value) {
    return '外側リング ≈ $label ($value) · ノードをタップで詳細 · ⓘ で凡例';
  }

  @override
  String get voiceSettingsTitle => '音声 (TTS 品質)';

  @override
  String get voiceSettingsHint =>
      '「アプリ設定」で SPEECH を ON にするまで無効。レート / ピッチ / 音声は次の発話から適用されます。';

  @override
  String get voiceRate => '速度';

  @override
  String get voicePitch => 'ピッチ';

  @override
  String get voicePicker => '音声';

  @override
  String get voicePickerEmpty =>
      'プラットフォームエンジンから利用可能な音声が報告されていません — システム既定を使用します。';

  @override
  String get voicePickerSystem => 'システム既定';

  @override
  String get voicePreview => 'サンプル再生';

  @override
  String get voicePreviewPhrase => 'これは Meshmore SNS の音声プレビューです。';

  @override
  String get voicePreviewDisabledHint =>
      'プレビューを聴くには、アプリ設定で SPEECH を ON にしてください。';

  @override
  String get settingsHubDevice => 'デバイス設定';

  @override
  String get settingsHubDeviceSub => 'MeshCore ラジオ & デバイス (R7)';

  @override
  String get settingsHubApp => 'アプリ設定';

  @override
  String get settingsHubAppSub => '接続 · 言語 · 音声 · データ';

  @override
  String get settingsHubProfile => 'プロフィール & パーソナライズ';

  @override
  String get settingsHubProfileSub => 'テーマ · フォントサイズ · 音声 · アクセシビリティ';

  @override
  String get settingsHubChannels => 'チャンネル';

  @override
  String get settingsHubChannelsSub => 'スロット · 名前 + PSK · #ハッシュタグ · 有効';

  @override
  String get settingsHubDiagnostics => '診断 & 接続';

  @override
  String get settingsHubDiagnosticsSub => 'ラジオ接続 · フレームログ · M6 キャプチャ';

  @override
  String get bootHeader => 'MESHMORE  /  同期中';

  @override
  String get bootConnecting => 'ラジオに接続中…';

  @override
  String get bootHandshaking => 'ハンドシェイク中…';

  @override
  String get bootSyncing => 'デバイス状態を同期中…';

  @override
  String get bootReady => 'メッシュ オンライン';

  @override
  String get bootOffline => 'オフライン — 設定 → 診断 & 接続';

  @override
  String get bootSkip => 'スキップ';

  @override
  String get bootRetry => '再試行';

  @override
  String get bootSubtitle => '待機  /  WAIT';

  @override
  String eventAdvert(String name) {
    return 'アドバート · $name';
  }

  @override
  String eventChannelMsg(String channel, String text) {
    return 'ch$channel · 「$text」';
  }

  @override
  String eventDm(String text) {
    return 'DM · 「$text」';
  }

  @override
  String eventContact(String name) {
    return 'コンタクト · $name';
  }

  @override
  String eventBattery(String volts) {
    return 'バッテリー ${volts}V';
  }

  @override
  String eventDeviceError(String code) {
    return 'デバイスエラー (コード $code)';
  }

  @override
  String get eventDeviceClockSynced => 'デバイス時計 同期';

  @override
  String eventDeviceClockSkew(String seconds) {
    return 'デバイス時計 読取 (オフセット ${seconds}s)';
  }

  @override
  String eventMsgSent(String ack) {
    return 'メッセージ送信 (ack $ack)';
  }

  @override
  String eventDeviceInfo(String version) {
    return 'デバイス $version';
  }

  @override
  String eventSelfInfo(String name) {
    return 'セルフ情報 · $name';
  }

  @override
  String get eventQueuedWaiting => 'キュー待機中';

  @override
  String eventQueuedWaitingN(String count) {
    return 'キュー待機中 ($count)';
  }
}
