// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Keeps the app process alive in the background so the existing
/// main-isolate BLE link + reconnect + SYNC-drain keep running while
/// screen-locked (R17 / U8). The companion protocol has no history
/// fetch, so an overflowed device buffer = lost messages; on Android
/// only a **foreground service** prevents Doze from killing the
/// process during a long lock.
///
/// All plugin usage is isolated here: the rest of the app depends on
/// this interface, the default is a no-op (iOS / tests / unsupported),
/// and the Android impl only acts on Android. The persistent
/// notification is the accepted cost (user-decided 2026-05-19).
abstract class BackgroundKeepalive {
  Future<void> start();
  Future<void> stop();
  Future<bool> get isRunning;
}

/// Default everywhere except a real Android device.
class NoopBackgroundKeepalive implements BackgroundKeepalive {
  const NoopBackgroundKeepalive();
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<bool> get isRunning async => false;
}

/// Selects the Android foreground-service impl on Android, else no-op.
/// In `flutter test` `defaultTargetPlatform` is android, so also gate
/// on it NOT being a test build by requiring a real platform dispatcher
/// — simplest: callers in tests inject their own fake; production wires
/// this factory. Kept conservative so a native misconfig can't break
/// other platforms or the core app.
BackgroundKeepalive createBackgroundKeepalive() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return ForegroundServiceKeepalive();
  }
  return const NoopBackgroundKeepalive();
}

/// Top-level entry point the OS calls for the service isolate. The
/// handler is intentionally minimal: its only job is to *exist* so
/// the foreground service runs and keeps the process alive — the BLE
/// connection and SYNC-drain stay in the main isolate.
@pragma('vm:entry-point')
void backgroundKeepaliveCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepaliveHandler());
}

class _KeepaliveHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override
  void onRepeatEvent(DateTime timestamp) {}
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

/// Android foreground service via `flutter_foreground_task`
/// (`connectedDevice` type — keeps a BLE peripheral connection alive
/// for polling/sync; avoids the Android-15 dataSync timeout). Native
/// behaviour is **unverified in this environment** — requires
/// on-device testing + a clean Android rebuild.
class ForegroundServiceKeepalive implements BackgroundKeepalive {
  bool _inited = false;

  void _ensureInit() {
    if (_inited) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'mm_keepalive',
        channelName: 'Mesh link',
        channelDescription:
            'Keeps the MeshCore radio connected so messages are '
            'received while the app is in the background.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    _inited = true;
  }

  @override
  Future<void> start() async {
    _ensureInit();
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceId: 4403,
      notificationTitle: 'Meshmore SNS',
      notificationText: 'Keeping the mesh radio connected',
      callback: backgroundKeepaliveCallback,
    );
  }

  @override
  Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  @override
  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;
}
