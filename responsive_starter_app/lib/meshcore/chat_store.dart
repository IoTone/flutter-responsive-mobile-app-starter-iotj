import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'chat_message.dart';

/// Local persistence for channel chat history.
///
/// MeshCore's companion protocol has **no history-fetch** — the
/// device's message queue is drained destructively via
/// `SYNC_NEXT_MESSAGE`. So, like the official app, history is kept
/// on the phone: previously-sent/received messages survive app
/// restarts and reconnects. Bounded JSON in `shared_preferences`
/// (message volumes are human/mesh-rate and short).
abstract final class ChatStore {
  static const String _kKey = 'mm.chat.v1';

  /// Hard cap on persisted messages (oldest dropped first).
  static const int cap = 250;

  static Future<List<ChatMessage>> load() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    final String? raw = p.getString(_kKey);
    if (raw == null || raw.isEmpty) return <ChatMessage>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <ChatMessage>[];
      return decoded
          .whereType<Map<String, Object?>>()
          .map(ChatMessage.fromJson)
          .toList();
    } catch (_) {
      return <ChatMessage>[]; // corrupt store → start clean
    }
  }

  static Future<void> save(List<ChatMessage> messages) async {
    final List<ChatMessage> tail = messages.length > cap
        ? messages.sublist(messages.length - cap)
        : messages;
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setString(
        _kKey,
        jsonEncode(
            tail.map((ChatMessage m) => m.toJson()).toList()));
  }

  static Future<void> clear() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.remove(_kKey);
  }
}
