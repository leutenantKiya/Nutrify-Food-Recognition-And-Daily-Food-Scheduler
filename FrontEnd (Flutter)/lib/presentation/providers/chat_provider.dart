import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/ai_response_parser.dart';
import '../../data/models/chat_message.dart';
import '../../data/repositories/chat_repository.dart';

class ChatProvider extends ChangeNotifier {
  List<ChatSession> _sessions = [];
  List<ChatMessage> _messages = [];
  String? _currentSessionId;
  bool _isLoading = false;
  final _uuid = const Uuid();

  List<ChatSession> get sessions => _sessions;
  List<ChatMessage> get messages => _messages;
  String? get currentSessionId => _currentSessionId;
  bool get isLoading => _isLoading;

  void loadSessions() {
    _sessions = ChatRepository.getAllSessions();
    notifyListeners();
  }

  void selectSession(String sessionId) {
    _currentSessionId = sessionId;
    _messages = ChatRepository.getMessagesBySession(sessionId);
    notifyListeners();
  }

  Future<String> createNewSession() async {
    final id = _uuid.v4();
    final session = ChatSession(
      id: id,
      title: 'Sesi Baru',
      createdAt: DateTime.now(),
    );
    await ChatRepository.saveSession(session);
    _currentSessionId = id;
    _messages = [];
    loadSessions();
    return id;
  }

  Future<void> sendMessage(String content, {String? userContext}) async {
    if (_currentSessionId == null) return;
    if (_isLoading) return; // ← Guard: tolak request baru jika masih loading

    // Save user message
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      sessionId: _currentSessionId!,
      role: 'user',
      content: content,
      timestamp: DateTime.now(),
    );
    await ChatRepository.saveMessage(userMsg);
    _messages.add(userMsg);
    notifyListeners();

    // Update session title from first message
    if (_messages.length == 1) {
      final session = ChatRepository.getSession(_currentSessionId!);
      if (session != null) {
        final title = content.length > 30 ? '${content.substring(0, 30)}...' : content;
        await ChatRepository.saveSession(session.copyWith(
          title: title,
          lastMessageAt: DateTime.now(),
        ));
        loadSessions();
      }
    }

    // Send to AI
    _isLoading = true;
    notifyListeners();

    try {
      final chatHistory = _messages
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final response = await ApiService.sendChatMessage(
        messages: chatHistory,
        userContext: userContext,
      );

      final aiMsg = ChatMessage(
        id: _uuid.v4(),
        sessionId: _currentSessionId!,
        role: 'assistant',
        content: response,
        timestamp: DateTime.now(),
      );
      await ChatRepository.saveMessage(aiMsg);
      _messages.add(aiMsg);

      // Update session lastMessageAt
      final session = ChatRepository.getSession(_currentSessionId!);
      if (session != null) {
        await ChatRepository.saveSession(
            session.copyWith(lastMessageAt: DateTime.now()));
      }
    } catch (e) {
      final errorMsg = ChatMessage(
        id: _uuid.v4(),
        sessionId: _currentSessionId!,
        role: 'assistant',
        content: 'Maaf, terjadi kesalahan: $e',
        timestamp: DateTime.now(),
      );
      await ChatRepository.saveMessage(errorMsg);
      _messages.add(errorMsg);
    }

    _isLoading = false;
    loadSessions();
    notifyListeners();
  }

  Future<void> deleteSession(String id) async {
    await ChatRepository.deleteSession(id);
    if (_currentSessionId == id) {
      _currentSessionId = null;
      _messages = [];
    }
    loadSessions();
  }

  Future<void> updateRecommendationAction({
    required String messageId,
    required String menuName,
    required String action,
  }) async {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final msg = _messages[index];
      final currentActions = Map<String, String>.from(msg.recommendationActions ?? {});
      currentActions[menuName] = action;
      final updatedMsg = msg.copyWith(recommendationActions: currentActions);
      _messages[index] = updatedMsg;
      await ChatRepository.saveMessage(updatedMsg);
      notifyListeners();
    }
  }

  /// Parse buttons dari AI message
  List<String> getButtons(String content) {
    return AiResponseParser.parseButtons(content);
  }

  /// Parse rekomendasi dari AI message
  List<FoodRecommendation> getRekomendasi(String content) {
    return AiResponseParser.parseRekomendasi(content);
  }

  /// Clean text tanpa tags
  String getCleanText(String content) {
    return AiResponseParser.stripTags(content);
  }
}
