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
  String get tabDocs => 'ドキュメント';

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
  String get dashNervLink => 'リンク';

  @override
  String get dashNervNode => 'ノード';

  @override
  String get dashNervRegion => '地域';

  @override
  String get dashNervMesh => 'メッシュ';

  @override
  String get dashNervKnown => '既知';

  @override
  String get dashNervEvents => 'イベント';

  @override
  String get dashHyperRadar => 'ノードレーダー';

  @override
  String get dashHyperEmpty => 'ノードを探索中…';

  @override
  String get dashHyperPeers => 'ピア';

  @override
  String get dashHyperNear => '近';

  @override
  String get dashHyperFar => '遠';

  @override
  String get dashAgHudSignal => 'シグナル';

  @override
  String get dashAgHudTraffic => 'ch トラフィック';

  @override
  String get dashDrPopLink => 'リンク';

  @override
  String get dashReconNoContacts => '範囲内に連絡先なし';

  @override
  String dashAgHudOfKnown(String count) {
    return '既知 $count 中';
  }

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
  String get dashboardUnnamed => '(名前なし)';

  @override
  String get dashboardRenameTitle => 'デバイス名';

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
  String get dashboardDevice => 'デバイス';

  @override
  String get deviceMgrTitle => 'デバイス';

  @override
  String get deviceMgrNoPair => 'デバイス未ペアリング';

  @override
  String get deviceMgrStateConnected => '接続中';

  @override
  String get deviceMgrStateConnecting => '接続中…';

  @override
  String get deviceMgrStateReconnecting => '再接続中…';

  @override
  String get deviceMgrStateDisconnected => '切断';

  @override
  String get deviceMgrStateFailed => '失敗';

  @override
  String get deviceMgrDisconnect => '切断';

  @override
  String get deviceMgrReconnect => '再接続';

  @override
  String get deviceMgrForget => 'ペアリング解除';

  @override
  String get deviceMgrPick => 'デバイスを選択';

  @override
  String get deviceMgrScan => 'スキャン';

  @override
  String get deviceMgrStopScan => '停止';

  @override
  String get deviceMgrScanHint =>
      '「スキャン」をタップして近くの MeshCore デバイスを探します。2 台以上ある場合はリストから選んでください。';

  @override
  String deviceMgrScanFailed(String message) {
    return 'スキャン失敗: $message';
  }

  @override
  String get deviceMgrRecent => '最近のペアリング';

  @override
  String get deviceMgrAgoNever => '未使用';

  @override
  String get deviceMgrAgoNow => 'たった今';

  @override
  String deviceMgrAgoMinutes(int n) {
    return '$n 分前';
  }

  @override
  String deviceMgrAgoHours(int n) {
    return '$n 時間前';
  }

  @override
  String deviceMgrAgoDays(int n) {
    return '$n 日前';
  }

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
  String get settingsTelemetryPoll => 'ノードのテレメトリを収集';

  @override
  String get settingsTelemetryPollOn => 'コンタクトに温度・標高を控えめに問い合わせ (少量の電波使用)';

  @override
  String get settingsTelemetryPollOff => 'テレメトリ要求は送信しません; 各ノードの詳細から手動で取得';

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
  String get aboutLicensesButton => 'オープンソースライセンスと権利表示';

  @override
  String get aboutAttributions =>
      'MeshCore ドキュメント（MIT）、GeoNames 都市データ（CC-BY 4.0）、Natural Earth（パブリックドメイン）、OpenStreetMap 地図データ（ODbL）、Saira・JetBrains Mono フォント（OFL）を含みます。';

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
  String get personalizationAudioMasterEnabled => '既定で ON; 補助としてのみ';

  @override
  String get dashboardAudioMute => 'アラート音をミュート';

  @override
  String get dashboardAudioUnmute => 'アラート音のミュート解除';

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
  String dashboardBatteryLeft(String time) {
    return '残り約$time';
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
  String get nodesFarBadge => '遠距離';

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
  String get gridRangeCity => '市';

  @override
  String get gridRangeRegion => '地域';

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
  String get gridViewEqualGrid => '等分グリッド';

  @override
  String get gridViewStreetMap => 'ストリートマップ';

  @override
  String get gridViewPicker => 'マップ表示を切替';

  @override
  String get gridViewRadialShort => 'レーダー';

  @override
  String get gridViewGlobeShort => 'グローブ';

  @override
  String get gridViewEqualGridShort => 'セル';

  @override
  String get gridViewStreetMapShort => 'ロード';

  @override
  String get gridViewFabric => 'ファブリック調査';

  @override
  String get gridViewFabricShort => 'メッシュ';

  @override
  String get gridViewElevation => 'Fujiさん';

  @override
  String get gridViewElevationShort => '富士';

  @override
  String get fujiLegendTitle => 'Fujiさん';

  @override
  String get fujiLegendDesc =>
      '標高測量。√スケール軸で有名な建造物と高さを比較。自分の標高はデバイスGPSテレメトリまたは電話の位置情報から取得。';

  @override
  String get fujiLegendMe => '破線 = あなた。標高が判明していればその位置に、未取得なら地面に「ALT?」表示。';

  @override
  String get fujiLegendRefs => 'シルエット = 実世界の基準（人 → 富士山）でスケール感を示す。';

  @override
  String get fujiLegendPeers => '点 = ピア。問い合わせ後にテレメトリ標高でプロット。';

  @override
  String get fujiLegendUnknown => '地面沿いの縞帯 = まだ標高不明のピア。';

  @override
  String get fujiLegendAutoQuery => 'AUTO-QUERY ボックスがピア標高を順次取得。タップで再起動。';

  @override
  String get elevationProfileTitle => 'MESHMORE :: Fujiさん';

  @override
  String get elevationProfileAltLabel => '高度';

  @override
  String get elevationProfileMeLabel => '現在地';

  @override
  String get elevationProfileUnknownLabel => '高度不明';

  @override
  String elevationProfilePeers(int n) {
    return '$n 個のノード';
  }

  @override
  String get elevationRefPerson => '人間';

  @override
  String get elevationRefHouse => '家';

  @override
  String get elevationRefRedwood => 'セコイア';

  @override
  String get elevationRefEmpireState => 'エンパイア';

  @override
  String get elevationRefBurj => 'ブルジュ';

  @override
  String get elevationRefMtFuji => '富士山';

  @override
  String fabricCoverageCount(int n) {
    return 'メッシュ調査 · $n セル';
  }

  @override
  String get fabricResetTooltip => '調査結果をリセット';

  @override
  String get fabricResetTitle => 'メッシュ調査結果をリセットしますか？';

  @override
  String get fabricResetBody =>
      '記録済みのセルをすべて削除します。移動と近隣ノードの観測に応じて新しい記録が再び埋まっていきます。';

  @override
  String get fabricResetApply => 'リセット';

  @override
  String get streetMapRecenter => '現在地に戻す';

  @override
  String get streetMapTopoLayer => '地形図に切り替え';

  @override
  String get streetMapStandardLayer => '標準地図に切り替え';

  @override
  String get mapHideTiles => '地図タイルを非表示';

  @override
  String get mapShowTiles => '地図タイルを表示';

  @override
  String deviceRegionLoadedOffline(String label) {
    return '$label を読み込みました — デバイス接続時に「適用」してください。';
  }

  @override
  String get equalGridAwaitingFix =>
      '等分グリッド表示には自分の位置が必要です — GPS 取得待ち（スマートフォンまたはデバイス）。';

  @override
  String equalGridCellSize(String size) {
    return 'セル $size';
  }

  @override
  String get equalGridZoomIn => 'ズームイン（セルを狭く）';

  @override
  String get equalGridZoomOut => 'ズームアウト（セルを広く）';

  @override
  String get equalGridShowStats => 'ターゲティングパネルを表示';

  @override
  String get equalGridHideStats => 'ターゲティングパネルを非表示';

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
  String get gridOrientNorthUp => '北を上';

  @override
  String get gridOrientHeadingUp => '進行方向を上';

  @override
  String get gridHeadingHud => '方位';

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
  String get voicePickerOnlyMyLanguage => '現在の言語のみ表示';

  @override
  String voicePickerOnlyMyLanguageHint(String lang) {
    return 'スマートフォンの現在の言語（$lang）に一致する音声のみを表示します。オフにするとOSが報告する全音声を表示します。';
  }

  @override
  String voicePickerFilteredCount(int n, String lang) {
    return '$n 件 · $lang';
  }

  @override
  String voicePickerAllCount(int n) {
    return '$n 件 · すべて';
  }

  @override
  String voicePickerNoMatchForLanguage(String lang) {
    return '$lang の音声がインストールされていません。上のフィルターをオフにして他言語を表示するか、OS の設定から $lang の音声を追加してください。';
  }

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
  String chatJumpToNewest(int count) {
    return '新着 $count 件';
  }

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
  String get dmOpenPeerDetail => '相手の詳細';

  @override
  String get dmPeerNotInFabric => 'この相手はまだメッシュ上で確認されていません（アドバート未受信）。';

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
  String get nodeDetailShareTelemetryTitle => 'この連絡先と自分のテレメトリを共有';

  @override
  String get nodeDetailShareTelemetryHelp =>
      'テレメトリモードが「連絡先」のとき、この連絡先が選択したテレメトリを取得できるようにします。基本がオフだと何も共有されません。';

  @override
  String get nodeDetailRecentDms => '最近の DM';

  @override
  String get nodeDetailMessage => 'メッセージ';

  @override
  String get nodeIdentityTitle => '連絡先のキーが変更されました';

  @override
  String nodeIdentityBody(String name, int count) {
    return '「$name」は新しいキーで稼働中です — 相手の端末で削除・再追加された可能性があります。お気に入り・タグ・保存済みメッセージ $count 件を現在のキーに移動しますか？';
  }

  @override
  String nodeIdentityOldKey(String shortId) {
    return '旧キー …$shortId';
  }

  @override
  String get nodeIdentityAction => '現在のキーに移動';

  @override
  String nodeIdentityMoved(String name) {
    return 'データを「$name」の現在のキーに移動しました';
  }

  @override
  String get nodeIdentityLinkAction => 'キーが変わった？ 別のノードにリンク';

  @override
  String get nodeIdentityLinkTitle => '変更されたキーをリンク';

  @override
  String get nodeIdentityLinkHelp =>
      '新しいキーで稼働している同じ連絡先のノードを選んでください。お気に入り・タグ・メッセージが現在のキーに移動し、古いキーは廃止されます。';

  @override
  String get nodeIdentityLinkEmpty =>
      'リンクできる他のノードがありません — スキャンするか新しいキーのアドバートを待ってください。';

  @override
  String get nodeIdentityLinkSearchHint => '名前またはキーで絞り込み';

  @override
  String get nodeIdentityLinkNoMatch => '一致するノードがありません — 検索をクリアすると全件表示します。';

  @override
  String nodeIdentityLinkConfirm(String from, String to) {
    return 'お気に入り・タグ・メッセージを「$from」から「$to」へ移動し、古いキーを廃止しますか？';
  }

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
  String get nodeDetailTags => 'タグ';

  @override
  String get nodeDetailAddTag => 'タグ';

  @override
  String get nodeDetailAddTagTitle => 'タグを追加';

  @override
  String get nodeDetailAddTagHint => '例: リピーター、職場、アマチュア無線クラブ';

  @override
  String get nodeDetailAddTagSuggestions => '最近使ったタグ';

  @override
  String get nodeDetailAddTagApply => '追加';

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
  String get gridViewTree => 'メッシュツリー';

  @override
  String get gridViewTreeShort => 'ツリー';

  @override
  String get gridViewSnsCells => 'SNS セル（ヒート）';

  @override
  String get gridViewSnsCellsShort => 'SNS';

  @override
  String get gridViewWeather => '気象（環境）';

  @override
  String get gridViewWeatherShort => 'WX';

  @override
  String get weatherSelf => 'このデバイス';

  @override
  String get weatherEmpty =>
      '環境データを報告しているノードはまだありません。\nセンサー搭載ノードが照会されると表示されます — アプリ設定で「ノードのテレメトリを収集」を有効にしてください。';

  @override
  String get weatherSelfNoTelemetry =>
      'このデバイスはまだテレメトリを返していません。接続を確認してから、この画面を開き直してください。';

  @override
  String weatherSelfNoEnv(String types) {
    return 'このデバイスのファームウェアは環境テレメトリに対応していません。\n報告内容: $types。\nセンサー（例: T1000-E の BME280）には MeshCore センサーファームウェアが必要です。標準ビルドはバッテリー／GPS のみを送信し、環境モードを設定してもデバイス側でオフに戻されます。これはアプリの設定ではなくデバイス側の制限です。';
  }

  @override
  String weatherReporting(int count) {
    return '$count 件が報告中';
  }

  @override
  String get docsHubTitle => 'ドキュメント';

  @override
  String get docsHubSubtitle =>
      'MeshCore プロトコル、デバイスのファームウェア、本アプリの解説をオフラインで読めます。オンライン時に GitHub から最新版を取得します。';

  @override
  String get docsHubFooter =>
      'ドキュメントはオフライン閲覧用に端末にキャッシュされます。項目を開いて ↻ で最新版を取得。出典: meshcore-dev/MeshCore。';

  @override
  String get docsProtocolTitle => 'プロトコル';

  @override
  String get docsProtocolSub => 'MeshCore コンパニオン無線プロトコル — フレーム、オペコード、フロー。';

  @override
  String get docsFirmwareTitle => 'ファームウェア';

  @override
  String get docsFirmwareSub => 'MeshCore ファームウェア概要（README）。';

  @override
  String docsFirmwareSubVersion(String version) {
    return 'MeshCore ファームウェア — $version に対応。';
  }

  @override
  String get docsAppTitle => 'アプリ';

  @override
  String get docsAppSub => 'Meshmore SNS の仕組みとメッシュの活用方法。';

  @override
  String get docsRefresh => 'GitHub から更新';

  @override
  String get docsUpdated => '最新版に更新しました';

  @override
  String get docsUpToDate => 'すでに最新です';

  @override
  String get docsOriginBundled => '同梱スナップショット';

  @override
  String docsOriginUpdated(String when) {
    return '更新: $when';
  }

  @override
  String docsFirmwareForVersion(String version) {
    return 'デバイス $version';
  }

  @override
  String get docsFirmwareNoDevice => 'デバイス未接続';

  @override
  String get docsAgoJustNow => 'たった今';

  @override
  String docsAgoMinutes(int n) {
    return '$n分前';
  }

  @override
  String docsAgoHours(int n) {
    return '$n時間前';
  }

  @override
  String docsAgoDays(int n) {
    return '$n日前';
  }

  @override
  String get weatherMin => '最低';

  @override
  String get weatherAvg => '平均';

  @override
  String get weatherMax => '最高';

  @override
  String weatherAgoSeconds(int s) {
    return '$s秒前';
  }

  @override
  String weatherAgoMinutes(int m) {
    return '$m分前';
  }

  @override
  String weatherAgoHours(int h) {
    return '$h時間前';
  }

  @override
  String get snsCellsAwaitingFix => '位置情報を待機中 — ヒートマップは自分を中心に表示されます。';

  @override
  String get snsCellsClear => 'クリア';

  @override
  String snsCellsStatus(int active, int hot) {
    return '$active セル · $hot ホット';
  }

  @override
  String snsPlacesButton(int count) {
    return '場所 ($count)';
  }

  @override
  String get snsPlacesTitle => '推定された場所（過去1時間）';

  @override
  String get snsPlacesEmpty => '現在、推定された場所はありません。';

  @override
  String get snsPlacesDismiss => '場所ではない — 削除';

  @override
  String get snsFrameMetro => 'メトロ · 約20 km';

  @override
  String get snsFrameRegion => '地域 · 約300 km';

  @override
  String get snsFrameMesh => 'メッシュ · 全体';

  @override
  String get snsCellsLegendTitle => 'SNS セル';

  @override
  String get snsCellsLegendDesc =>
      'ライブのソーシャル活動ヒートマップ。観測したメッセージごとにセルが温まり、1時間の地平で冷えていきます。';

  @override
  String get snsCellsLegendHot => '明るい赤 = 活発（直近1分で約5件以上）。';

  @override
  String get snsCellsLegendCool => '白へ退色 = 沈静化。約1時間無活動で消滅。';

  @override
  String get snsCellsLegendToast => '新着メッセージは発信元付近にトーストで点滅し、消えます。';

  @override
  String get snsCellsLegendChannel =>
      'チャンネルメッセージは送信者名を含みます — 送信者の位置が分かればそのセルを、分からなければ自分のセル（受信地点）を温めます。';

  @override
  String get snsCellsLegendInferred =>
      '破線の ◇ マーカーは会話（「〜から」など）から推定した場所で、おおよその位置に表示されます。チャンネルごとに設定で切替できます。';

  @override
  String get snsCellsLegendDecay => '直近1時間のみ追跡。保存はされません。';

  @override
  String get meshTreeEmpty => 'コンタクト同期を待機中 — ツリーは各コンタクトの outPath から構築されます。';

  @override
  String get meshTreeHopsDirect => '直接';

  @override
  String get meshTreeHopsAll => '≤6 / 全て';

  @override
  String get meshTreeHopsFlood => 'フラッド / 全て';

  @override
  String meshTreeHopsN(int n) {
    return '≤$n ホップ';
  }

  @override
  String get meshTreeRecenter => '中央に戻す';

  @override
  String get meshTreeLegendTitle => 'メッシュツリー';

  @override
  String get meshTreeLegendDesc =>
      '無線がどの経路で各コンタクトに到達するかの有向グラフ。エッジは Contact.outPath — デバイスが送信に使う正確なリピーター連鎖。';

  @override
  String get meshTreeLegendSelf => 'あなた — 中央に固定。';

  @override
  String get meshTreeLegendRepeater =>
      '四角 = リピーター。マスト設置インフラ、ハブ色。ピアはこれらを経由して広がる。';

  @override
  String get meshTreeLegendRoom => 'ひし形 = ルームサーバ。名前付きルームをホストするサーバ級ノード。';

  @override
  String get meshTreeLegendChat => '円 = チャットノード。DM 可能なピア。';

  @override
  String get meshTreeLegendSensor => '小さい円（暗）= センサー。特定用途のノード。';

  @override
  String get meshTreeLegendFlood =>
      '破線で自分とつながる = フラッドルーティングのコンタクト。到達可能だが固定経路なし。';

  @override
  String get meshTreeLegendFloat => '浮遊（エッジなし）— advert のみで受信、経路不明。';

  @override
  String get meshTreeLegendArrow => '矢印は自分から目的ピアへ向かう。';

  @override
  String get meshTreeLegendInteract =>
      'ピンチで拡大縮小、ドラッグで移動、ノードをタップで詳細。「中央に戻す」でリセット。';

  @override
  String get fabricLegendTitle => 'ファブリックサーベイ';

  @override
  String get fabricLegendDesc =>
      'メッシュが観測された場所の永続的な記録。各長方形は小さな地理セル（約 220 m × 220 m）で、デバイスがこの位置と接続したときにログ。';

  @override
  String get fabricLegendCell => '塗りつぶしセル — ここで一度はメッシュが届いた。';

  @override
  String get fabricLegendRecency =>
      '明るい塗り = より新しい。階層 — 1時間以内、24時間以内、7日以内、それ以上。';

  @override
  String get fabricLegendMarker => '第三色のピンは現在のセット内のピア。タップで詳細。';

  @override
  String get fabricLegendSelf => '原色のピンはあなた。';

  @override
  String get fabricLegendReset => '新しい地域に移動するときは、オーバーフローメニューからサーベイをリセット。';

  @override
  String get nodeDetailHopsKv => 'ホップ数';

  @override
  String get nodeDetailHopsDirect => '直接 (0 ホップ)';

  @override
  String nodeDetailHopsViaRepeaters(int n) {
    return '$n 経由リピーター';
  }

  @override
  String get nodeDetailHopsUnknown => '不明';

  @override
  String get nodeDetailHopsFlood => 'フラッド';

  @override
  String get nodeDetailAltitudeKv => '標高';

  @override
  String nodeDetailAltitudeMeters(String m) {
    return '$m m';
  }

  @override
  String get nodeDetailAltitudeUnknown => '不明';

  @override
  String get nodeDetailTempKv => '温度';

  @override
  String nodeDetailTempValue(String c) {
    return '$c °C';
  }

  @override
  String get nodeDetailHumidityKv => '湿度';

  @override
  String nodeDetailHumidityValue(String p) {
    return '$p%';
  }

  @override
  String get nodeDetailPressureKv => '気圧';

  @override
  String nodeDetailPressureValue(String hpa) {
    return '$hpa hPa';
  }

  @override
  String get nodeDetailQueryTelemetry => 'テレメトリを取得';

  @override
  String get nodeDetailRefreshTelemetry => 'テレメトリを更新';

  @override
  String get nodeDetailTelemetryQuerying => '電波経由でピアに問い合わせ中…';

  @override
  String get nodeDetailTelemetryNotContact =>
      '同期済みコンタクトではありません — テレメトリは要求できません。まずデバイスにこのノードをコンタクトとして追加してください。';

  @override
  String nodeDetailTelemetryAge(String age) {
    return '$age前のテレメトリ';
  }

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
  String get channelsInferPlaces => 'メッセージから場所を推定';

  @override
  String get channelsInferPlacesSub => 'このチャンネルの会話から地名を抽出し、SNS グリッドに表示します。';

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
  String get deviceToastNameSet => '名前を更新 — 隣接ノードへ再アドバート中';

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
  String get otherTelemetryModeTitle => 'テレメトリ共有 — 各種類を誰が要求できるか';

  @override
  String get otherTelemetryBase => '基本';

  @override
  String get otherTelemetryLoc => '位置';

  @override
  String get otherTelemetryEnv => '環境';

  @override
  String get otherTelemetryDeny => 'オフ';

  @override
  String get otherTelemetryFlags => '連絡先';

  @override
  String get otherTelemetryAll => '全員';

  @override
  String get otherTelemetryModeHelp =>
      'このデバイスの各種テレメトリを誰が要求できるかを設定します — 基本=バッテリー、位置=GPS、環境=温度/湿度/気圧。オフ=すべて拒否、連絡先=連絡先のみ（フラグに従う）、全員=任意のノード。これは共有の許可設定であり、センサーの有無とは無関係です（環境センサーがなければ「全員」でも何も送信しません）。';

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

  @override
  String get batteryTitle => 'バッテリー';

  @override
  String get batteryConfigSubtitle => '充電量・消費レート・残り時間の推定';

  @override
  String get batteryAwaiting => 'デバイスからのバッテリー値を待機中…';

  @override
  String get batteryReset => '履歴をリセット';

  @override
  String get batteryResetConfirm =>
      '保存済みのバッテリー履歴をすべて消去しますか？新しい値が届くと推定は再構築されます。';

  @override
  String get batteryVoltageLabel => '電圧';

  @override
  String get batteryCharging => '充電中';

  @override
  String get batteryChargingNote => '充電中 — 残り時間の推定は一時停止しています。';

  @override
  String get batteryTimeToEmpty => '残り時間';

  @override
  String get batteryEstimating => '消費データを収集中 — 数分間の放電後に推定値が表示されます。';

  @override
  String get batteryDrainRate => '消費レート';

  @override
  String get batteryBasis => '根拠';

  @override
  String batteryBasisObserved(String span) {
    return '$span の放電実測に基づく';
  }

  @override
  String get batteryBasisRated => '定格 (容量 ÷ 標準消費電流)';

  @override
  String get batteryConfidence => '信頼度';

  @override
  String get batteryConfHigh => '高';

  @override
  String get batteryConfMedium => '中';

  @override
  String get batteryConfLow => '低';

  @override
  String get batteryMethodObserved => '放電実測';

  @override
  String get batteryMethodRated => '定格推定';

  @override
  String get batteryMethodNone => 'データ収集中';

  @override
  String get batterySpecTitle => 'デバイスモデル';

  @override
  String get batterySpecGeneric =>
      '不明なハードウェア — 汎用の単セル Li-ion モデルを使用します。定格容量での照合ができないため、推定は実測消費に依存します。';

  @override
  String batterySpecCapacity(int mah) {
    return '容量: $mah mAh';
  }

  @override
  String get batterySpecCapacityUnknown => '容量: ユーザー供給 (不明)';

  @override
  String batterySpecDraw(int ma) {
    return '標準消費: 約 $ma mA (受信時)';
  }

  @override
  String get batteryHistoryTitle => '電圧履歴';

  @override
  String batteryHistorySpan(String span, int count) {
    return '$span · $count サンプル';
  }

  @override
  String batteryDurDH(int days, int hours) {
    return '$days日 $hours時間';
  }

  @override
  String batteryDurHM(int hours, int mins) {
    return '$hours時間 $mins分';
  }

  @override
  String batteryDurM(int mins) {
    return '$mins分';
  }

  @override
  String get deliverySending => '送信中…';

  @override
  String get deliverySent => 'メッシュへ送信済み';

  @override
  String get deliveryDelivered => '配信完了 (受信側が確認)';

  @override
  String get deliveryFailed => '未配信 — 確認応答なし、または送信失敗';
}
