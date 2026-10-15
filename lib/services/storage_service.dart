import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_session.dart';

class StorageService {
  static const String _sessionsKey = 'axom_ai_chat_sessions';
  static const String _currentSessionIdKey = 'axom_ai_current_session_id';
  static const String _isDarkModeKey = 'axom_ai_is_dark_mode';
  static const String _apiUrlKey = 'axom_ai_api_base_url';

  // Load all chat sessions
  static Future<List<ChatSession>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final rawData = prefs.getString(_sessionsKey);
    if (rawData == null || rawData.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> jsonList = jsonDecode(rawData) as List<dynamic>;
      return jsonList
          .map((item) => ChatSession.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Save all chat sessions
  static Future<void> saveSessions(List<ChatSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = sessions.map((s) => s.toJson()).toList();
    await prefs.setString(_sessionsKey, jsonEncode(jsonList));
  }

  // Save current active session ID
  static Future<void> saveCurrentSessionId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentSessionIdKey, id);
  }

  // Load current active session ID
  static Future<String?> loadCurrentSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentSessionIdKey);
  }

  // Theme mode
  static Future<bool> loadIsDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isDarkModeKey) ?? true;
  }

  static Future<void> saveIsDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isDarkModeKey, isDark);
  }

  // Base API URL
  static Future<String> loadApiBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiUrlKey) ?? 'https://chat.aiaxom.co.in';
  }

  static Future<void> saveApiBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiUrlKey, url);
  }

  // Chat language (assamese | hinglish | english), voice (male | female) and voice speed
  static Future<String> loadChatLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('axom_ai_chat_language') ?? 'assamese';
  }

  static Future<void> saveChatLanguage(String v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('axom_ai_chat_language', v);
  }

  static Future<String> loadVoice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('axom_ai_voice') ?? 'female';
  }

  static Future<void> saveVoice(String v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('axom_ai_voice', v);
  }

  static Future<double> loadVoiceSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('axom_ai_voice_speed') ?? 1.0;
  }

  static Future<void> saveVoiceSpeed(double v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('axom_ai_voice_speed', v);
  }
}
