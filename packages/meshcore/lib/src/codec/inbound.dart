import 'dart:typed_data';

import '../model/contact.dart';
import '../model/self_info.dart';
import 'decode_error.dart';

/// A decoded device→app frame. Sealed so callers exhaustively switch.
sealed class MeshcoreInbound {
  const MeshcoreInbound();
}

/// `RESP_CODE_OK` (0x00). [value] is the optional trailing uint32.
class OkFrame extends MeshcoreInbound {
  const OkFrame(this.value);
  final int? value;
  @override
  String toString() => 'OkFrame($value)';
}

/// `RESP_CODE_ERR` (0x01). [code] is the optional trailing error byte.
class ErrorFrame extends MeshcoreInbound {
  const ErrorFrame(this.code);
  final int? code;
  @override
  String toString() => 'ErrorFrame($code)';
}

/// `RESP_CODE_CONTACTS_START` (0x02).
class ContactsStartFrame extends MeshcoreInbound {
  const ContactsStartFrame(this.count);
  final int count;
  @override
  String toString() => 'ContactsStartFrame($count)';
}

/// `RESP_CODE_CONTACT` (0x03).
class ContactFrame extends MeshcoreInbound {
  const ContactFrame(this.contact);
  final Contact contact;
  @override
  String toString() => 'ContactFrame($contact)';
}

/// `RESP_CODE_END_OF_CONTACTS` (0x04).
class EndOfContactsFrame extends MeshcoreInbound {
  const EndOfContactsFrame(this.mostRecentLastMod);
  final int mostRecentLastMod;
  @override
  String toString() => 'EndOfContactsFrame($mostRecentLastMod)';
}

/// `RESP_CODE_SELF_INFO` (0x05) — also the APP_START reply.
class SelfInfoFrame extends MeshcoreInbound {
  const SelfInfoFrame(this.selfInfo);
  final SelfInfo selfInfo;
  @override
  String toString() => 'SelfInfoFrame($selfInfo)';
}

/// `RESP_CODE_CURR_TIME` (0x09).
class CurrentTimeFrame extends MeshcoreInbound {
  const CurrentTimeFrame(this.unixSeconds);
  final int unixSeconds;

  DateTime get utc =>
      DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000, isUtc: true);

  @override
  String toString() => 'CurrentTimeFrame($unixSeconds)';
}

/// `RESP_CODE_NO_MORE_MESSAGES` (0x0A).
class NoMoreMessagesFrame extends MeshcoreInbound {
  const NoMoreMessagesFrame();
  @override
  String toString() => 'NoMoreMessagesFrame()';
}

/// A well-formed frame whose opcode this milestone does not decode yet.
/// Carries the raw bytes so higher layers can log/skip without data loss.
class UnsupportedFrame extends MeshcoreInbound {
  const UnsupportedFrame(this.opcode, this.raw);
  final int opcode;
  final Uint8List raw;
  @override
  String toString() =>
      'UnsupportedFrame(0x${opcode.toRadixString(16)}, ${raw.length}B)';
}

/// Decoding failed (empty/truncated). Never thrown — always returned.
class DecodeFailure extends MeshcoreInbound {
  const DecodeFailure(this.error);
  final MeshcoreDecodeError error;
  @override
  String toString() => 'DecodeFailure($error)';
}
