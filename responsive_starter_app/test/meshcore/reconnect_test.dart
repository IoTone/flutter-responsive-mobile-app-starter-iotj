import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_connection.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';
import 'package:meshmore_sns_app/meshcore/reconnect_policy.dart';

import 'fake_transport.dart';

Future<void> _pump([int n = 8]) async {
  for (int i = 0; i < n; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('ReconnectPolicy', () {
    test('full-jitter ceiling grows exponentially and caps', () {
      final ReconnectPolicy p = ReconnectPolicy(
        base: const Duration(seconds: 1),
        max: const Duration(seconds: 30),
        random: () => 1.0, // ceiling
      );
      expect(p.delayForAttempt(1), const Duration(seconds: 1));
      expect(p.delayForAttempt(2), const Duration(seconds: 2));
      expect(p.delayForAttempt(3), const Duration(seconds: 4));
      expect(p.delayForAttempt(4), const Duration(seconds: 8));
      expect(p.delayForAttempt(6), const Duration(seconds: 30)); // capped
      expect(p.delayForAttempt(20), const Duration(seconds: 30));
    });

    test('jitter floor is zero', () {
      final ReconnectPolicy p = ReconnectPolicy(random: () => 0.0);
      expect(p.delayForAttempt(5), Duration.zero);
    });

    test('shouldRetry respects maxAttempts; 0 = forever', () {
      final ReconnectPolicy p = ReconnectPolicy(maxAttempts: 3);
      expect(p.shouldRetry(3), isTrue);
      expect(p.shouldRetry(4), isFalse);
      final ReconnectPolicy forever = ReconnectPolicy(maxAttempts: 0);
      expect(forever.shouldRetry(9999), isTrue);
    });
  });

  group('MeshcoreController auto-reconnect', () {
    test('retries with backoff then recovers; attempt resets', () async {
      final List<Duration> delays = <Duration>[];
      int calls = 0;
      late FakeMeshcoreTransport okFake;
      final MeshcoreController ctrl = MeshcoreController(
        connection: MeshcoreConnection(
            handshakeTimeout: const Duration(seconds: 5)),
        reconnectPolicy: ReconnectPolicy(
          base: const Duration(milliseconds: 10),
          max: const Duration(milliseconds: 100),
          random: () => 1.0,
          maxAttempts: 10,
        ),
        reconnectDelay: (Duration d) async => delays.add(d),
        transportFactory: () async {
          calls++;
          if (calls <= 2) throw StateError('boom $calls');
          okFake = FakeMeshcoreTransport(connected: true);
          return okFake;
        },
      );

      await ctrl.connect();
      await _pump();
      okFake.emit(selfInfoFrame());
      await _pump();

      expect(ctrl.isReady, isTrue);
      expect(calls, 3); // initial + 2 retries
      expect(delays.take(2).toList(),
          <Duration>[const Duration(milliseconds: 10),
              const Duration(milliseconds: 20)]);
      expect(ctrl.reconnectAttempt, 0); // reset on ready
      ctrl.dispose();
    });

    test('gives up after maxAttempts', () async {
      int calls = 0;
      final MeshcoreController ctrl = MeshcoreController(
        reconnectPolicy: ReconnectPolicy(
          base: const Duration(milliseconds: 1),
          random: () => 1.0,
          maxAttempts: 3,
        ),
        reconnectDelay: (Duration d) async {},
        transportFactory: () async {
          calls++;
          throw StateError('always fails');
        },
      );

      await ctrl.connect();
      await _pump(20);

      expect(ctrl.gaveUp, isTrue);
      expect(ctrl.state, MeshcoreConnectionState.failed);
      // initial attempt + exactly maxAttempts retries.
      expect(calls, 1 + 3);
      ctrl.dispose();
    });

    test('manual disconnect cancels a pending reconnect', () async {
      int calls = 0;
      final MeshcoreController ctrl = MeshcoreController(
        reconnectPolicy: ReconnectPolicy(
            base: const Duration(milliseconds: 5), maxAttempts: 10),
        reconnectDelay: (Duration d) async => Future<void>.delayed(
            const Duration(milliseconds: 20)),
        transportFactory: () async {
          calls++;
          throw StateError('fail');
        },
      );

      await ctrl.connect(); // calls == 1, schedules a retry
      await ctrl.disconnect(); // should cancel it
      await _pump(20);

      expect(calls, 1, reason: 'no retry after manual disconnect');
      ctrl.dispose();
    });

    test('link drop after ready auto-recovers', () async {
      final List<FakeMeshcoreTransport> made = <FakeMeshcoreTransport>[];
      final MeshcoreController ctrl = MeshcoreController(
        connection: MeshcoreConnection(
            handshakeTimeout: const Duration(seconds: 5)),
        reconnectPolicy: ReconnectPolicy(
            base: const Duration(milliseconds: 1), random: () => 1.0),
        reconnectDelay: (Duration d) async {},
        transportFactory: () async {
          final FakeMeshcoreTransport f =
              FakeMeshcoreTransport(connected: true);
          made.add(f);
          return f;
        },
      );

      await ctrl.connect();
      await _pump();
      made.last.emit(selfInfoFrame());
      await _pump();
      expect(ctrl.isReady, isTrue);

      // Drop the link → connection reports `reconnecting`, then the
      // controller (immediate backoff in this test) re-acquires a
      // fresh transport and re-handshakes. With a 0ms delay it races
      // straight through `reconnecting`, so assert recovery instead.
      made.last.setConnected(false);
      await _pump();
      expect(ctrl.isReady, isFalse);

      // Controller re-acquired a fresh transport; finish its handshake.
      made.last.emit(selfInfoFrame());
      await _pump();
      expect(ctrl.isReady, isTrue);
      expect(made.length, greaterThanOrEqualTo(2));
      ctrl.dispose();
    });
  });
}
