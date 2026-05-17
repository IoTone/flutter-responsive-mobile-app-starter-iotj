/// Meshcore companion-radio protocol — pure-Dart implementation.
///
/// Public API barrel. As milestones land, codec/model/crypto/session
/// exports are added here.
library;

export 'src/codec/constants.dart';
export 'src/codec/decode_error.dart';
export 'src/codec/frame_codec.dart';
export 'src/codec/inbound.dart';
export 'src/crypto/channel_crypto.dart';
export 'src/crypto/dm_crypto.dart';
export 'src/crypto/identity_crypto.dart';
export 'src/model/advert.dart';
export 'src/model/channel_info.dart';
export 'src/model/channel_message.dart';
export 'src/model/contact.dart';
export 'src/model/contact_message.dart';
export 'src/model/device_config.dart';
export 'src/model/self_info.dart';
export 'src/transport/transport.dart';
