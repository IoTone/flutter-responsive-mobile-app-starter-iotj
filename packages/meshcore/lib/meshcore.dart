// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
/// Meshcore companion-radio protocol — pure-Dart implementation.
///
/// Public API barrel. As milestones land, codec/model/crypto/session
/// exports are added here.
library;

export 'src/codec/cayenne_lpp.dart';
export 'src/codec/constants.dart';
export 'src/codec/decode_error.dart';
export 'src/codec/frame_codec.dart';
export 'src/codec/inbound.dart';
export 'src/crypto/channel_crypto.dart';
export 'src/crypto/dm_crypto.dart';
export 'src/crypto/identity_crypto.dart';
export 'src/diagnostics/channel_tail_oracle.dart';
export 'src/model/advert.dart';
export 'src/model/channel_info.dart';
export 'src/model/channel_message.dart';
export 'src/model/contact.dart';
export 'src/model/contact_message.dart';
export 'src/model/device_config.dart';
export 'src/model/ota_packet.dart';
export 'src/model/rf_log.dart';
export 'src/model/self_info.dart';
export 'src/transport/transport.dart';
