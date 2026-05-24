import '../../core/services/hive_service.dart';
import '../models/chat_message.dart';

class ChatRepository {
  // ---- Sessions ----
  static List<ChatSession> getAllSessions() {
    return HiveService.chatSessionBox.values
        .map((e) => ChatSession.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static ChatSession? getSession(String id) {
    final data = HiveService.chatSessionBox.get(id);
    if (data == null) return null;
    return ChatSession.fromMap(Map<dynamic, dynamic>.from(data));
  }

  static Future<void> saveSession(ChatSession session) async {
    await HiveService.chatSessionBox.put(session.id, session.toMap());
  }

  static Future<void> deleteSession(String id) async {
    await HiveService.chatSessionBox.delete(id);
    // Also delete all messages in this session
    final messages = getMessagesBySession(id);
    for (final msg in messages) {
      await HiveService.chatMessageBox.delete(msg.id);
    }
  }

  // ---- Messages ----
  static List<ChatMessage> getMessagesBySession(String sessionId) {
    return HiveService.chatMessageBox.values
        .map((e) => ChatMessage.fromMap(Map<dynamic, dynamic>.from(e)))
        .where((m) => m.sessionId == sessionId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  static Future<void> saveMessage(ChatMessage message) async {
    await HiveService.chatMessageBox.put(message.id, message.toMap());
  }

  static Future<void> deleteMessage(String id) async {
    await HiveService.chatMessageBox.delete(id);
  }
}
