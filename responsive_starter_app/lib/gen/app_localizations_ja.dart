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
  String get gridLegendHeading =>
      '方位ウェッジ・HDG 表示 = スマートフォン上端が**磁北**を基準に向いている方向（真北でも GPS 進行方向でもなく、スマートフォンの方位センサーが示す方位）。';

  @override
  String get gridLegendCalibration =>
      'キャリブレーション: 矢印がずれている場合、スマートフォンを水平に持って数回 8 の字に動かしてください。コンパスのキャリブレーションは OS が行い、アプリは精度のみ表示します（精度が悪いと「Calibrate」ヒントが出ます）。';

  @override
  String get gridViewRadial => 'ラジアル';

  @override
  String get gridViewGlobe => 'グローブ';

  @override
  String globeFooter(int n) {
    return '位置情報のある $n 件のピアを表示';
  }

  @override
  String get globeOverlayArcs => 'アーク';

  @override
  String get globeOverlayRegion => '地域';

  @override
  String get globeOverlayLabels => 'ラベル';

  @override
  String get globeZoom => 'ズーム';

  @override
  String get globeAltitude => '高度';

  @override
  String get globePaused => '一時停止';

  @override
  String get voiceOfflineBadge => 'オフライン';

  @override
  String get dashboardLocationRefresh => 'デバイスから位置を更新';

  @override
  String dashboardLocationAltitude(int meters) {
    return '高度 $meters m';
  }

  @override
  String get deviceLocReportsAwaiting => 'デバイス報告値: (待機中)';

  @override
  String get deviceLocReportsNone => 'デバイス報告値: GPS 未取得 (0, 0)';

  @override
  String deviceLocReportsValue(String lat, String lon) {
    return 'デバイス報告値: $lat, $lon';
  }

  @override
  String get deviceLocUnsaved => '✱ 未保存';

  @override
  String get deviceGpsModule => 'オンボード GPS モジュール';

  @override
  String get deviceGpsEnable => 'オンボード GPS を有効化';

  @override
  String get deviceGpsEnabledHint =>
      'デバイスファームウェアが GPS チップを定期的に読み取り、位置を自動更新します。';

  @override
  String get deviceGpsDisabledHint =>
      'オフ — デバイスは GPS を一切読み取らず、配信される位置は最後に書き込まれた値のままです。';

  @override
  String get deviceGpsUnknown => 'デバイス応答待ち…';

  @override
  String get deviceGpsInterval => 'GPS 更新間隔';

  @override
  String get deviceGpsIntervalOff => 'オフ';

  @override
  String deviceGpsIntervalSec(int n) {
    return '$n 秒ごと';
  }

  @override
  String deviceGpsIntervalMin(int n) {
    return '$n 分ごと';
  }

  @override
  String deviceGpsIntervalHour(int n) {
    return '$n 時間ごと';
  }

  @override
  String get deviceGpsIntervalFixedByFirmware =>
      'このファームウェアビルドでは GPS 更新間隔がハードコードされており、変更できません（sensors モジュールが `gps_interval` を公開していないため）。';

  @override
  String get locTitle => '位置の自動公開';

  @override
  String get locTileSubtitle => '定期 + 移動検知でスマートフォン GPS をデバイスに反映';

  @override
  String get locHelp =>
      'デバイス GPS が古いままの場合のスマートフォン側ワークアラウンド。有効時、定期・移動検知のいずれかで取得した GPS を SET_ADVERT_LATLON + ゼロホップ アドバートでデバイスに書き込みます。';

  @override
  String get locMaster => '自動公開';

  @override
  String get locMasterOn => 'オン — スマートフォン GPS 使用中';

  @override
  String get locMasterOff => 'オフ';

  @override
  String get locInterval => '定期間隔';

  @override
  String get locMovement => 'スマートブロードキャスト (移動検知)';

  @override
  String get locOff => 'オフ';

  @override
  String locIntervalMin(int n) {
    return '$n 分ごと';
  }

  @override
  String locIntervalHour(int n) {
    return '$n 時間ごと';
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
  String get locPublishNow => '今すぐ公開';

  @override
  String get locPublishNowSub => 'ループ動作の確認用に手動で 1 回送信。';

  @override
  String locLastPublished(String lat, String lon, String time, String trigger) {
    return '最終: $lat, $lon  ·  $time  ·  $trigger';
  }

  @override
  String get locBatteryHint =>
      'スマートブロードキャストは GPS を継続使用 (約 10 mA)。定期のみは省電力。両方有効で応答性最大、バッテリー優先ならスマートブロードキャストのみ推奨。';

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
  String gridHeading(int deg, String cardinal) {
    return '方位 $deg° $cardinal';
  }

  @override
  String get gridHeadingCalibrate => 'コンパス要校正 — スマートフォンを 8 の字に振ってください。';

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

  @override
  String chatChannelHeader(String name) {
    return 'チャンネル · $name';
  }

  @override
  String get chatManageChannels => 'チャンネル管理';

  @override
  String get chatTtsDisabledHint => 'アプリ設定で TTS を有効化';

  @override
  String get chatTtsMuted => 'このチャンネルの TTS をミュート中';

  @override
  String get chatTtsActive => 'このチャンネルを TTS で読み上げ中';

  @override
  String get chatHideChannels => 'チャンネルを隠す';

  @override
  String get chatShowChannels => 'チャンネルを表示';

  @override
  String get chatEmpty => '— このチャンネルにメッセージはありません —';

  @override
  String chatComposerHint(String channel) {
    return '$channel へメッセージ';
  }

  @override
  String get chatComposerOffline => '送信するにはラジオに接続';

  @override
  String get chatSend => '送信';

  @override
  String get chatMessageActions => 'メッセージ操作';

  @override
  String dmTitle(String peer) {
    return 'DM · $peer';
  }

  @override
  String dmPubkeyLabel(String hex) {
    return '公開鍵 · $hex';
  }

  @override
  String get dmEmpty => '— メッセージはまだありません —';

  @override
  String dmComposerHint(String peer) {
    return '$peer へメッセージ';
  }

  @override
  String get dmSend => 'DM 送信';

  @override
  String get actionReply => '返信';

  @override
  String get actionReplySub => 'このメッセージを引用して返信';

  @override
  String get actionCopy => 'コピー';

  @override
  String get actionCopySub => 'メッセージ本文をクリップボードにコピー';

  @override
  String get actionDeleteLocal => 'ローカル削除';

  @override
  String get actionDeleteLocalSub => '履歴からこの行のみ削除 — OTA 送信済みのメッセージは取り消せません。';

  @override
  String get actionCopied => 'クリップボードにコピーしました';

  @override
  String get actionDeleteConfirmTitle => 'このメッセージをローカルから削除しますか?';

  @override
  String get actionDeleteConfirmBody =>
      'ローカル履歴からこの行を削除します。MeshCore に取り消しはなく、受信者側には残ります。';

  @override
  String get actionCancel => 'キャンセル';

  @override
  String get actionDelete => '削除';

  @override
  String get nodeDetailSelf => 'これはあなた自身のノードです — メッセージ / お気に入りは利用不可。';

  @override
  String get nodeDetailRecentDms => '最近の DM';

  @override
  String get nodeDetailMessage => 'メッセージ';

  @override
  String get nodeDetailFavourite => 'お気に入り';

  @override
  String get nodeDetailContact => 'コンタクト';

  @override
  String get nodeDetailShowOnMap => '地図上に表示';

  @override
  String get nodeDetailShowOnMapSnack => 'リバースジオコード地図 (R25) は今後対応予定です。';

  @override
  String get nodeDetailShowOnMapFailed => 'マップアプリを開けませんでした。';

  @override
  String get nodeDetailCopyPubkey => '公開鍵をコピー';

  @override
  String get nodeDetailPubkeyCopied => '公開鍵をコピーしました';

  @override
  String get nodeDetailInRange => '範囲内';

  @override
  String get nodeDetailKnown => '既知';

  @override
  String get nodeDetailContactBadge => 'コンタクト';

  @override
  String get nodeDetailShortIdKv => 'shortId';

  @override
  String get nodeDetailPubkeyKv => '公開鍵';

  @override
  String get nodeDetailSignalKv => '信号';

  @override
  String get nodeDetailLastHeardKv => '最終受信';

  @override
  String get nodeDetailDistanceKv => '距離';

  @override
  String get nodeDetailLatLonKv => '緯度 / 経度';

  @override
  String nodeDetailAgoSeconds(int n) {
    return '$n秒前';
  }

  @override
  String nodeDetailAgoMinutes(int n) {
    return '$n分前';
  }

  @override
  String nodeDetailAgoHours(int n) {
    return '$n時間前';
  }

  @override
  String nodeDetailAgoDays(int n) {
    return '$n日前';
  }

  @override
  String get channelsTitle => 'チャンネル';

  @override
  String get channelsHelp =>
      'チャンネル = スロット + 名前 + 16 バイト鍵。Public (スロット 0) は共有の既定。プライベートグループは全ノードで同じスロットに同じ名前 & PSK を設定してください。';

  @override
  String get channelsOfflineHint => 'チャンネルを編集するにはラジオを接続 (診断)。';

  @override
  String get channelsEmpty => '— 未設定 —';

  @override
  String channelsSlotLabel(int idx) {
    return 'スロット $idx';
  }

  @override
  String channelsSlotActive(int idx) {
    return 'スロット $idx · 有効';
  }

  @override
  String get channelsEdit => '編集';

  @override
  String get channelsSet => '設定';

  @override
  String channelsSetSnack(int idx, String name) {
    return 'チャンネル $idx を「$name」に設定 — 全ノードで同じ名前 & PSK が必要';
  }

  @override
  String channelsDialogTitle(int idx) {
    return 'チャンネルスロット $idx';
  }

  @override
  String get channelsName => 'チャンネル名';

  @override
  String get channelsKeySource => '鍵ソース';

  @override
  String get channelsKeyPublic => 'Public';

  @override
  String get channelsKeyHashtag => '#タグ';

  @override
  String get channelsKeyHex => 'Hex';

  @override
  String get channelsKeyPublicBody => '公開チャンネル既定鍵を使用。';

  @override
  String get channelsKeyHashtagHint => '例: #mygroup';

  @override
  String get channelsKeyHashtagHelper => 'タグから鍵を導出 (sha256)';

  @override
  String get channelsKeyHexHint => '16 進 32 文字 (16 バイト)';

  @override
  String get channelsErrorTag => '#ハッシュタグを入力してください';

  @override
  String get channelsErrorHex => 'PSK は 16 進 32 文字 (16 バイト) で入力してください';

  @override
  String get channelsErrorName => 'チャンネル名を入力してください';

  @override
  String get channelsCancel => 'キャンセル';

  @override
  String get channelsSave => '保存';

  @override
  String get channelsHelpEncryption =>
      'スロット 0 (Public) は既知の鍵を使用 — ファームウェアを持つ全員が読めます。他のスロットは設定した 16 バイト PSK で AES-128 暗号化。同じ PSK を持つノードのみ復号できます。';

  @override
  String get channelsHexGenerate => 'PSK をランダム生成';

  @override
  String get channelsHexCopy => 'コピー';

  @override
  String get channelsHexCopied => 'PSK をクリップボードにコピー';

  @override
  String get channelsTagWeakShort => '短いタグは推測されやすい。12 文字以上または独自の表現を使用してください。';

  @override
  String get channelsTagWeakCommon =>
      '一般的な単語は推測されやすい — 攻撃者にタグ総当りを許します。独自の表現を使用してください。';

  @override
  String get channelsSlot0WarnTitle => 'Public チャンネルを上書きしますか?';

  @override
  String get channelsSlot0WarnBody =>
      'スロット 0 は既知の Public チャンネルです。ここにプライベート PSK を書き込むと、同じ鍵を持つノードとしか通話できなくなり、共通の Public チャンネルを失います。続行しますか?';

  @override
  String get channelsSlot0WarnContinue => 'スロット 0 を上書き';

  @override
  String get channelsSlot0WarnCancel => 'キャンセル';

  @override
  String get channelsCurrentKey => '現在の鍵';

  @override
  String get channelsRevealKey => '表示';

  @override
  String get channelsHideKey => '隠す';

  @override
  String get channelsCurrentKeyUnknown => '未取得 — デバイス同期後にダイアログを開き直してください。';

  @override
  String get channelsClear => 'スロットをクリア';

  @override
  String channelsClearConfirmTitle(int idx) {
    return 'スロット $idx をクリアしますか?';
  }

  @override
  String get channelsClearConfirmBody =>
      'MeshCore にはプロトコルレベルの「クリア」がありません — このスロットは Public 既定値 (名前 + 鍵) に上書きされます。他ノードも同様の操作が必要です。';

  @override
  String get channelsClearConfirmAction => 'クリア';

  @override
  String channelsClearSnack(int idx) {
    return 'スロット $idx をクリア (Public 既定値にリセット)';
  }

  @override
  String get channelsDefaultBadge => '既定';

  @override
  String get channelsSetDefaultTooltip => '起動時の既定チャンネルに設定';

  @override
  String get channelsClearDefaultTooltip => '既定チャンネル設定を解除';

  @override
  String channelsSetDefaultSnack(int idx) {
    return 'スロット $idx を起動時の既定に設定';
  }

  @override
  String get channelsClearedDefaultSnack => '起動時の既定を解除しました';

  @override
  String get channelsKeyShake => '振る';

  @override
  String get channelsShakeTitle => 'シェイクでダイスロール';

  @override
  String get channelsShakeBody =>
      'スマートフォンを振ってください — 検出された動きサンプルがハッシュに加算されます。リングが満たされたら停止。';

  @override
  String channelsShakeProgress(int accepted, int target, int pct) {
    return '$accepted / $target サンプル · $pct%';
  }

  @override
  String get channelsShakeReroll => '再ロール';

  @override
  String get channelsShakeUse => 'この鍵を使用';

  @override
  String get channelsShakeTapFallback =>
      'タップでロール (reduceMotion 有効 — Random.secure を使用)';

  @override
  String get channelsShareQr => 'QR で共有';

  @override
  String channelsQrTitle(int idx) {
    return 'チャンネル $idx を共有';
  }

  @override
  String get channelsQrBody =>
      'Meshmore デバイス、または任意の QR リーダーでスキャン。このコードを持つ人はチャンネルに参加できます — 信頼できる相手のみと共有してください。';

  @override
  String get channelsQrPayload => 'ペイロード (コピー用)';

  @override
  String get channelsQrClose => '閉じる';

  @override
  String get deviceConfigTitle => 'デバイス設定';

  @override
  String get deviceRegionBand => 'リージョン / バンド';

  @override
  String get deviceRegionCurrent => '現在の設定';

  @override
  String get deviceRegionUnknown => 'デバイス応答待ち…';

  @override
  String get deviceRegionCustom => 'カスタム（プリセット非該当）';

  @override
  String get deviceRegionSuggestFromLocation => '現在地から自動選択';

  @override
  String get deviceRegionSuggestTitle => '推奨リージョンを適用しますか？';

  @override
  String deviceRegionSuggestBody(String lat, String lon, String label) {
    return 'スマートフォンの GPS（$lat, $lon）に基づくと、該当するプリセットは「$label」です。国境付近では誤判定する可能性があるため、適用前に現地の法令に適合するか必ず確認してください。';
  }

  @override
  String get deviceRegionSuggestApply => '適用';

  @override
  String get deviceRegionSuggestNoFix =>
      'GPS の取得に失敗しました — 屋外で位置情報の許可を確認してから再試行してください。';

  @override
  String get deviceRegionSuggestNoMatch => '現在地が出荷時プリセットの対象外です — 手動で選択してください。';

  @override
  String deviceRegionAppliedToast(String label) {
    return '$label を適用しました。メッシュ内の全ノードで同じプリセットを使用してください。';
  }

  @override
  String get deviceRegionDisclaimer =>
      'プリセット値はコミュニティで合意された運用例であり、法令適合を保証するものではありません。利用地で合法なプリセットを選び、メッシュ内の全ノードで同じ値を使用してください。日本（ARIB STD-T108）のプリセットはコミュニティ提案で、広範な実機検証は完了していません。実運用前に、法令適合性と動作をご自身のハードウェアで必ず確認してください。';

  @override
  String get presetUsCanada => '米国 / カナダ';

  @override
  String get presetUsArizona => '米国 — アリゾナ';

  @override
  String get presetJpAribT108 => '日本（ARIB STD-T108）';

  @override
  String get presetEuUkLong => 'EU / UK（長距離）';

  @override
  String get presetEuUkMedium => 'EU / UK（中距離）';

  @override
  String get presetEuUkNarrow => 'EU / UK（狭帯域）';

  @override
  String get presetCh => 'スイス';

  @override
  String get presetCz => 'チェコ';

  @override
  String get presetPt869 => 'ポルトガル（869 MHz）';

  @override
  String get presetAu => 'オーストラリア';

  @override
  String get presetAuNarrow => 'オーストラリア（狭帯域）';

  @override
  String get presetAuSaWaQld => 'オーストラリア（SA / WA / QLD）';

  @override
  String get presetNz => 'ニュージーランド';

  @override
  String get presetVn => 'ベトナム';

  @override
  String get cancel => 'キャンセル';

  @override
  String get deviceRadioParams => 'ラジオパラメータ';

  @override
  String get deviceIdentityAdvert => 'アイデンティティ / アドバート';

  @override
  String get deviceChannelsSection => 'チャンネル';

  @override
  String get deviceOtherParamsSection => 'その他のパラメータ';

  @override
  String get deviceDeviceSection => 'デバイス';

  @override
  String get deviceFrequency => '周波数 (MHz)';

  @override
  String get deviceBandwidth => '帯域幅 (kHz)';

  @override
  String get deviceSpreadingFactor => '拡散率 (5–12)';

  @override
  String get deviceCodingRate => '符号化率 (5–8)';

  @override
  String get deviceTxPower => '送信電力 (dBm)';

  @override
  String get deviceLoadFromDevice => 'デバイスから読込';

  @override
  String get deviceApplyRadio => 'ラジオパラメータを適用';

  @override
  String get deviceConnectFirst => 'まずラジオに接続してください (診断 & 接続)。';

  @override
  String get deviceAdvertName => 'アドバート名';

  @override
  String get deviceSetName => '名前を設定';

  @override
  String get deviceAdvertLatitude => 'アドバート緯度 (°)';

  @override
  String get deviceAdvertLongitude => 'アドバート経度 (°)';

  @override
  String get deviceUsePhoneLocation => 'スマートフォンの位置を使用';

  @override
  String get deviceReadDeviceLocation => 'デバイスの位置を読込';

  @override
  String get deviceSetAdvertLocation => 'アドバート位置を設定';

  @override
  String get deviceAdvertSource => 'アドバート位置ソース';

  @override
  String get deviceAdvertSourceNone => 'なし';

  @override
  String get deviceAdvertSourcePinned => 'ピン留め';

  @override
  String get deviceAdvertSourceGps => 'デバイス GPS';

  @override
  String get deviceToastNameEmpty => 'ノード名を入力してください';

  @override
  String get deviceToastNameSet => '名前を設定 — 隣接ノードに反映するため再アドバートを実行';

  @override
  String deviceToastSendFailed(String error) {
    return '送信失敗: $error';
  }

  @override
  String get deviceToastNoDeviceYet => 'デバイス未応答 — 接続後に再試行';

  @override
  String get deviceToastNoGpsYet => 'デバイスにまだ位置情報がありません (GPS 未取得)';

  @override
  String get deviceToastLoadedDeviceLoc =>
      'デバイス位置を読込 · ブロードキャストするには「アドバート位置を設定」をタップ';

  @override
  String get deviceToastGettingPhoneFix => 'スマートフォン GPS を取得中…';

  @override
  String get deviceToastPhoneFixFailed => 'スマートフォン GPS の取得失敗 (サービス無効またはタイムアウト)';

  @override
  String get deviceToastNoFixReturned => '位置情報が返されませんでした';

  @override
  String get deviceToastGotPhoneLoc =>
      'スマートフォン位置を取得 · ブロードキャストするには「アドバート位置を設定」をタップ';

  @override
  String get deviceToastInvalidLatLon => '有効な緯度 (−90..90) と経度 (−180..180) を入力';

  @override
  String get deviceToastAdvertLocSet => 'アドバート位置を設定しました';

  @override
  String get deviceToastInvalidRadio => 'freq/BW/SF/CR に有効な数値を入力';

  @override
  String get deviceToastRadioSent => 'ラジオパラメータを送信 — デバイスを再起動 / 観測して確認';

  @override
  String get deviceLocPermDenied => 'スマートフォン GPS 取得には位置情報の許可が必要です。';

  @override
  String get deviceLocPermDeniedPerm => '位置情報が永続的に拒否されました — OS 設定で許可してください。';

  @override
  String get deviceOpenSettings => '設定を開く';

  @override
  String get diagnosticsTitle => '診断 & 接続';

  @override
  String get diagnosticsState => '状態';

  @override
  String get diagnosticsSends => '送信';

  @override
  String get diagnosticsChannelTail => 'チャンネルテール オラクル';

  @override
  String get diagnosticsCapture => 'キャプチャ / エクスポート';

  @override
  String get diagnosticsRawFrameLog => 'RAW フレームログ (新しい順)';

  @override
  String get diagnosticsConnect => '接続';

  @override
  String get diagnosticsDisconnect => '切断';

  @override
  String get diagnosticsForget => 'デバイスを解除';

  @override
  String get diagnosticsCopyLog => 'ログをコピー';

  @override
  String get otherManualAddTitle => 'コンタクトを手動追加';

  @override
  String get otherManualAddSubOn => '受信したノードは必要時に手動でコンタクトに追加します。';

  @override
  String get otherManualAddSubOff => '受信したノードは自動でコンタクトに昇格します。';

  @override
  String get otherTelemetryLabel => 'テレメトリモード (生バイト)';

  @override
  String get otherTelemetryHelper => '0 = オフ · 意味はファームウェアに依存します。';

  @override
  String get otherMultiAcksLabel => 'マルチ ACK (0–3)';

  @override
  String get otherMultiAcksHelper =>
      '0 = シングル ACK (既定)。値が大きいほど送信確定までに待つ追加 ACK 数。';

  @override
  String get otherApply => '適用';

  @override
  String get otherSentSnack => 'OTHER PARAMS を送信 — デバイス側の書込に時間がかかる場合があります。';

  @override
  String get otherAwaitingDevice => '— デバイス待機中 —';
}
