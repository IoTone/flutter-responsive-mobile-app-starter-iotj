// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:meshcore/meshcore.dart';
import 'package:test/test.dart';

void main() {
  group('firmware pin', () {
    test('pin metadata is recorded', () {
      expect(kMeshcoreFirmwarePinTag, 'companion-v1.15.0');
      expect(kMeshcoreFirmwarePinCommit, hasLength(40));
      expect(
        kMeshcoreFirmwarePinCommit,
        matches(RegExp(r'^[0-9a-f]{40}$')),
        reason: 'pin must be a full 40-char git SHA',
      );
    });
  });

  group('BLE transport identifiers', () {
    test('service + characteristic UUIDs match the pinned doc', () {
      expect(MeshcoreBle.serviceUuid,
          equalsIgnoringCase('6E400001-B5A3-F393-E0A9-E50E24DCCA9E'));
      expect(MeshcoreBle.rxCharacteristicUuid,
          equalsIgnoringCase('6E400002-B5A3-F393-E0A9-E50E24DCCA9E'));
      expect(MeshcoreBle.txCharacteristicUuid,
          equalsIgnoringCase('6E400003-B5A3-F393-E0A9-E50E24DCCA9E'));
    });
  });

  group('opcodes', () {
    test('core command opcodes', () {
      expect(MeshcoreCommand.appStart.code, 0x01);
      expect(MeshcoreCommand.sendChannelMessage.code, 0x03);
      expect(MeshcoreCommand.getContacts.code, 0x04);
      expect(MeshcoreCommand.getDeviceTime.code, 0x05);
      expect(MeshcoreCommand.setDeviceTime.code, 0x06);
      expect(MeshcoreCommand.syncNextMessage.code, 0x0A);
      expect(MeshcoreCommand.setChannel.code, 0x20);
    });

    test('core response opcodes', () {
      expect(MeshcoreResponse.ok.code, 0x00);
      expect(MeshcoreResponse.selfInfo.code, 0x05);
      expect(MeshcoreResponse.channelMsgRecv.code, 0x08);
    });

    test('push codes are >= 0x80 and flagged', () {
      expect(MeshcoreResponse.advertisement.isPush, isTrue);
      expect(MeshcoreResponse.messagesWaiting.isPush, isTrue);
      expect(MeshcoreResponse.ok.isPush, isFalse);
      expect(MeshcoreResponse.selfInfo.isPush, isFalse);
    });
  });

  group('snrByteToDb', () {
    test('positive and negative (two’s complement) bytes', () {
      expect(snrByteToDb(0x00), 0.0);
      expect(snrByteToDb(0x04), 1.0); // 4 / 4
      expect(snrByteToDb(0xFC), -1.0); // (252-256)/4 = -1
      expect(snrByteToDb(0x80), -32.0); // (128-256)/4
    });
  });
}
