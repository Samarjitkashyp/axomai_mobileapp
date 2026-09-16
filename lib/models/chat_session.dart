import 'chat_message.dart';

class ChatSession {
  final String id;
  String title;
  final List<ChatMessage> messages;
  bool isPinned;
  final DateTime createdAt;
  DateTime updatedAt;

  ChatSession({
    required this.id,
    this.title = 'New Chat',
    List<ChatMessage>? messages,
    this.isPinned = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory ChatSession.create() {
    final now = DateTime.now();
    return ChatSession(
      id: 'session_${now.millisecondsSinceEpoch}',
      title: 'New Chat',
      messages: [],
      createdAt: now,
      updatedAt: now,
    );
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    var rawMsgs = json['messages'] as List<dynamic>? ?? [];
    List<ChatMessage> parsedMsgs =
        rawMsgs.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>)).toList();

    return ChatSession(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'New Chat',
      messages: parsedMsgs,
      isPinned: json['isPinned'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.map((m) => m.toJson()).toList(),
    'isPinned': isPinned,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
