import 'dart:typed_data';

import '../model/advert.dart';
import '../model/channel_info.dart';
import '../model/channel_message.dart';
import '../model/contact.dart';
import '../model/contact_message.dart';
import '../model/device_config.dart';
import '../model/rf_log.dart';
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

/// `RESP_CODE_SENT` (0x06) — send confirmation.
class MsgSentFrame extends MeshcoreInbound {
  const MsgSentFrame(this.sent);
  final MsgSent sent;
  @override
  String toString() => 'MsgSentFrame($sent)';
}

/// `RESP_CODE_CHANNEL_MSG_RECV` (0x08) and V3 (0x11).
class ChannelMessageFrame extends MeshcoreInbound {
  const ChannelMessageFrame(this.message);
  final ChannelMessage message;
  @override
  String toString() => 'ChannelMessageFrame($message)';
}

/// `RESP_CODE_CHANNEL_INFO` (0x12).
class ChannelInfoFrame extends MeshcoreInbound {
  const ChannelInfoFrame(this.info);
  final ChannelInfo info;
  @override
  String toString() => 'ChannelInfoFrame($info)';
}

/// `RESP_CODE_CONTACT_MSG_RECV` (0x07) and V3 (0x10).
class ContactMessageFrame extends MeshcoreInbound {
  const ContactMessageFrame(this.message);
  final ContactMessage message;
  @override
  String toString() => 'ContactMessageFrame($message)';
}

/// `PUSH_CODE_ADVERTISEMENT` (0x80).
class AdvertFrame extends MeshcoreInbound {
  const AdvertFrame(this.advert);
  final Advert advert;
  @override
  String toString() => 'AdvertFrame($advert)';
}

/// `RESP_CODE_DEVICE_INFO` (0x0D).
class DeviceInfoFrame extends MeshcoreInbound {
  const DeviceInfoFrame(this.info);
  final DeviceInfo info;
  @override
  String toString() => 'DeviceInfoFrame($info)';
}

/// `RESP_CODE_BATT_AND_STORAGE` (0x0C).
class BatteryStorageFrame extends MeshcoreInbound {
  const BatteryStorageFrame(this.battery);
  final BatteryStorage battery;
  @override
  String toString() => 'BatteryStorageFrame($battery)';
}

/// `PUSH_CODE_LOG_RX_DATA` (0x88) — raw received OTA packet + SNR/RSSI.
class RfLogFrame extends MeshcoreInbound {
  const RfLogFrame(this.log);
  final RfLog log;
  @override
  String toString() => 'RfLogFrame($log)';
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
