// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:typed_data';

import '../codec/constants.dart';
import '../crypto/channel_crypto.dart';
import '../model/ota_packet.dart';

/// Candidate constructions for the 32-byte `GroupChannel.secret` from
/// the 16-byte PSK the companion link carries. The AES-128 key is
/// always `secret[0..16] == psk` (the firmware copies the 16 sent
/// bytes there); only the HMAC-only tail `secret[16..32]` is unknown.
enum ChannelTailHypothesis {
  /// `psk ‖ 0x00·16` — struct zero-init; strongly favoured by
  /// `qr_codes.md` (ecosystem only ever shares 16 bytes).
  zeros,

  /// `psk ‖ psk`.
  pskRepeat,

  /// `psk ‖ SHA256(psk)[0..16]`.
  sha256Low,

  /// `psk ‖ SHA256(psk)[16..32]`.
  sha256High,
}

Uint8List _secretFor(ChannelTailHypothesis h, Uint8List psk) {
  final int n = psk.length < kCipherKeySize ? psk.length : kCipherKeySize;
  final Uint8List s = Uint8List(kChannelSecretSize)
    ..setRange(0, n, psk);
  switch (h) {
    case ChannelTailHypothesis.zeros:
      break; // already zero
    case ChannelTailHypothesis.pskRepeat:
      s.setRange(kCipherKeySize, kCipherKeySize + n, psk);
    case ChannelTailHypothesis.sha256Low:
      s.setRange(kCipherKeySize, kChannelSecretSize,
          MeshcoreChannelCrypto.sha256(psk).sublist(0, 16));
    case ChannelTailHypothesis.sha256High:
      s.setRange(kCipherKeySize, kChannelSecretSize,
          MeshcoreChannelCrypto.sha256(psk).sublist(16, 32));
  }
  return s;
}

/// Outcome of running the oracle against one captured GRP_TXT packet.
class ChannelTailResult {
  const ChannelTailResult({
    required this.match,
    required this.channelHashOk,
    required this.recoveredPlaintext,
  });

  /// The hypothesis whose 32-byte secret produced a MAC-valid
  /// decryption recovering [recoveredPlaintext], or null.
  final ChannelTailHypothesis? match;

  /// Whether `SHA256(psk)[0]` equals the packet's channel-hash byte —
  /// a tail-independent sanity that the PSK identifies this channel
  /// (the on-air hash is keyed on the 16-byte PSK only, not the
  /// 32-byte HMAC secret).
  final bool channelHashOk;

  /// The decrypted (de-padded to the known length) plaintext for the
  /// matching hypothesis, if any.
  final Uint8List? recoveredPlaintext;

  bool get resolved => match != null;

  @override
  String toString() => resolved
      ? 'ChannelTailResult(MATCH: ${match!.name}; channelHashOk='
          '$channelHashOk)'
      : 'ChannelTailResult(unresolved; channelHashOk=$channelHashOk)';
}

/// Resolves the channel-secret tail from a *real captured* GRP_TXT
/// over-the-air packet (extracted from a `RfLogFrame`/`0x88`).
///
/// Inputs are all known at capture time:
///  * [psk] — the 16-byte channel PSK (e.g. [kPublicChannelPsk]).
///  * [knownPlaintext] — the exact bytes the sender transmitted.
///  * [grpTxt] — `OtaPacket.grpTxt` from the captured packet.
///
/// [channelHashOk] (tail-independent, `SHA256(psk)[0]`) confirms the
/// packet is for this PSK; the tail is then resolved purely by the
/// HMAC-validated decryption recovering [knownPlaintext]. NOTE: the
/// `zeros` tail is now authoritative (docs.meshcore.io + wirehack7
/// gist: 32-byte secret = `psk ‖ 0·16`); this oracle is on-device
/// corroboration / regression-anchor, not the sole proof.
ChannelTailResult resolveChannelTail({
  required Uint8List psk,
  required Uint8List knownPlaintext,
  required GrpTxtPayload grpTxt,
}) {
  // The on-air channel hash is keyed on the 16-byte PSK only, so it
  // does NOT vary by tail hypothesis — it just confirms the packet is
  // for this channel/PSK.
  final bool channelHashOk =
      MeshcoreChannelCrypto.channelHashFromPsk(psk) == grpTxt.channelHash;

  ChannelTailHypothesis? match;
  Uint8List? recovered;

  // The tail is disambiguated solely by the HMAC over the candidate
  // 32-byte secret (2-byte MAC: 1/65536 collision; the plaintext
  // recovery check makes a false positive negligible).
  for (final ChannelTailHypothesis h in ChannelTailHypothesis.values) {
    final Uint8List secret = _secretFor(h, psk);
    final Uint8List? dec = MeshcoreChannelCrypto.macThenDecrypt(
        secret, grpTxt.macAndCiphertext);
    if (dec == null || dec.length < knownPlaintext.length) continue;
    final Uint8List prefix =
        Uint8List.sublistView(dec, 0, knownPlaintext.length);
    if (_eq(prefix, knownPlaintext)) {
      match = h;
      recovered = prefix;
      break;
    }
  }

  return ChannelTailResult(
    match: match,
    channelHashOk: channelHashOk,
    recoveredPlaintext: recovered,
  );
}

bool _eq(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
