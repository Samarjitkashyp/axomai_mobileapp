class WebSource {
  final String title;
  final String uri;

  WebSource({required this.title, required this.uri});

  factory WebSource.fromJson(Map<String, dynamic> json) {
    return WebSource(
      title: json['title'] as String? ?? 'Source',
      uri: json['uri'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'uri': uri,
  };
}

class ChatMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  String text;
  final String model;
  final bool webSearch;
  final List<WebSource> sources;
  final bool fromDatabase;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.model = 'Axom AI',
    this.webSearch = false,
    this.sources = const [],
    this.fromDatabase = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    var rawSources = json['sources'] as List<dynamic>? ?? [];
    List<WebSource> parsedSources = rawSources
        .map((s) => s is Map<String, dynamic>
            ? WebSource.fromJson(s)
            : WebSource(title: s.toString(), uri: s.toString()))
        .toList();

    return ChatMessage(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      role: json['role'] as String? ?? 'assistant',
      text: json['text'] as String? ?? '',
      model: json['model'] as String? ?? 'Axom AI',
      webSearch: json['web_search'] as bool? ?? false,
      sources: parsedSources,
      fromDatabase: json['from_database'] as bool? ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'text': text,
    'model': model,
    'web_search': webSearch,
    'sources': sources.map((s) => s.toJson()).toList(),
    'from_database': fromDatabase,
    'timestamp': timestamp.toIso8601String(),
  };
}
