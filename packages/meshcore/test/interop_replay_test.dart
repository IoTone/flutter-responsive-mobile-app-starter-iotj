import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meshcore/meshcore.dart';
import 'package:test/test.dart';

Uint8List _hex(String s) {
  final Uint8List out = Uint8List(s.length ~/ 2);
  for (int i = 0; i < out.length; i++) {
    out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

/// Replays real T1000-E captures dropped into `test/vectors/interop/`.
///
/// No fixtures yet → one skipped test (CI stays green). Once the
/// operator follows `meshmore-sns/M6-interop-runbook.md` and commits
/// captures, these assert our codec/crypto against the real device and
/// mechanically resolve the channel-secret-tail open item.
void main() {
  final Directory dir = Directory('test/vectors/interop');
  final List<File> fixtures = dir.existsSync()
      ? dir
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.endsWith('.json'))
          .toList()
      : <File>[];

  if (fixtures.isEmpty) {
    test('interop fixtures (none present yet)', () {},
        skip: 'No real captures in test/vectors/interop/ — see '
            'meshmore-sns/M6-interop-runbook.md');
    return;
  }

  for (final File f in fixtures) {
    final Map<String, Object?> fx =
        jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
    final String name = f.uri.pathSegments.last;

    test('interop: $name (${fx['kind']})', () {
      expect(fx['kind'], 'grp_txt_capture',
          reason: 'unknown fixture kind');

      final MeshcoreInbound frame = MeshcoreFrameCodec.decode(
          _hex(fx['rf_log_frame_hex']! as String));
      expect(frame, isA<RfLogFrame>(),
          reason: 'capture must be a 0x88 RF-log frame');

      final OtaPacket? pkt = (frame as RfLogFrame).log.packet;
      expect(pkt, isNotNull, reason: 'OTA packet failed to parse');
      expect(pkt!.isGrpTxt, isTrue, reason: 'expected a GRP_TXT packet');

      final ChannelTailResult r = resolveChannelTail(
        psk: _hex(fx['psk_hex']! as String),
        knownPlaintext: Uint8List.fromList(
            utf8.encode(fx['known_plaintext_utf8']! as String)),
        grpTxt: pkt.grpTxt!,
      );

      // The decisive M6 assertion + report.
      // ignore: avoid_print
      print('[interop] $name → channel-secret tail = '
          '${r.match?.name ?? "UNRESOLVED"} '
          '(hash-matched: ${r.channelHashMatched.map((e) => e.name)})');
      expect(r.resolved, isTrue,
          reason: 'no tail hypothesis reproduced the real device MAC + '
              'channel hash + plaintext for $name');
    });
  }
}
