// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/screens/node_detail_sheet.dart';

void main() {
  const String key64 =
      '5f3a9c0d1e2b4a6c8d0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f90123456';

  test('accepts a clean 64-hex key', () {
    expect(parsePastedPubKey(key64), key64);
  });

  test('strips separators (spaces / colons / dashes)', () {
    expect(parsePastedPubKey('5f:3a:9c:0d:1e:2b:4a:6c'), '5f3a9c0d1e2b4a6c');
    expect(parsePastedPubKey('5f 3a 9c 0d 1e 2b'), '5f3a9c0d1e2b');
  });

  test('lowercases', () {
    expect(parsePastedPubKey('ABCDEF0123456789'), 'abcdef0123456789');
  });

  test('accepts a 12-hex prefix', () {
    expect(parsePastedPubKey('5f3a9c0d1e2b'), '5f3a9c0d1e2b');
  });

  test('REJECTS a name (no letter pollution) — the reported bug', () {
    // "Davi1" must never become a key, and a seeded name + pasted key
    // must not fuse into a corrupted key.
    expect(parsePastedPubKey('Davi1'), isNull);
    expect(parsePastedPubKey('Davi1 $key64'), isNull); // 'v','i' aren't hex
    expect(parsePastedPubKey('node-beef cafe babe'), isNull);
  });

  test('rejects too-short and too-long', () {
    expect(parsePastedPubKey('abc'), isNull);
    expect(parsePastedPubKey('a' * 65), isNull);
  });
}
