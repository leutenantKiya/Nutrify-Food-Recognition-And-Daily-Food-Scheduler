class ChatMessage {
  final String id;
  final String sessionId;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final Map<String, String>? recommendationActions;

  ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.recommendationActions,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sessionId': sessionId,
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'recommendationActions': recommendationActions,
    };
  }

  factory ChatMessage.fromMap(Map<dynamic, dynamic> map) {
    final actionsMap = map['recommendationActions'];
    Map<String, String>? recommendationActions;
    if (actionsMap != null) {
      recommendationActions = Map<String, String>.from(
        (actionsMap as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
      );
    }
    return ChatMessage(
      id: map['id'] ?? '',
      sessionId: map['sessionId'] ?? '',
      role: map['role'] ?? 'user',
      content: map['content'] ?? '',
      timestamp: DateTime.parse(
          map['timestamp'] ?? DateTime.now().toIso8601String()),
      recommendationActions: recommendationActions,
    );
  }

  ChatMessage copyWith({
    String? id,
    String? sessionId,
    String? role,
    String? content,
    DateTime? timestamp,
    Map<String, String>? recommendationActions,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      recommendationActions: recommendationActions ?? this.recommendationActions,
    );
  }
}

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime? lastMessageAt;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    this.lastMessageAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'lastMessageAt': lastMessageAt?.toIso8601String(),
    };
  }

  factory ChatSession.fromMap(Map<dynamic, dynamic> map) {
    return ChatSession(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Sesi Baru',
      createdAt: DateTime.parse(
          map['createdAt'] ?? DateTime.now().toIso8601String()),
      lastMessageAt: map['lastMessageAt'] != null
          ? DateTime.parse(map['lastMessageAt'])
          : null,
    );
  }

  ChatSession copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? lastMessageAt,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }
}
