import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'auth_gate_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'tools_hub_screen.dart';
import '../widgets/header_bar.dart';
import '../widgets/input_bar.dart';
import '../widgets/landing_hero.dart';
import '../widgets/left_drawer.dart';
import '../widgets/message_bubble.dart';
import '../widgets/right_drawer.dart';

class ChatScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final ValueChanged<bool>? onDrawerChanged;

  const ChatScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.onDrawerChanged,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatSession> _sessions = [];
  String? _activeSessionId;
  bool _isLoading = false;
  bool _webSearch = false;
  String? _streamingText;
  AuthUser _currentUser = AuthUser.guest();

  @override
  void initState() {
    super.initState();
    AuthService.currentUserNotifier.addListener(_onAuthChanged);
    _initializeData();
  }

  void _onAuthChanged() {
    if (mounted) {
      setState(() {
        _currentUser = AuthService.currentUserNotifier.value;
      });
    }
  }

  @override
  void dispose() {
    AuthService.currentUserNotifier.removeListener(_onAuthChanged);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    final loadedSessions = await StorageService.loadSessions();
    final lastSessionId = await StorageService.loadCurrentSessionId();
    final user = await AuthService.getCurrentUser();

    setState(() {
      _currentUser = user;
      _sessions = loadedSessions;
      if (_sessions.isNotEmpty) {
        if (lastSessionId != null &&
            _sessions.any((s) => s.id == lastSessionId)) {
          _activeSessionId = lastSessionId;
        } else {
          _activeSessionId = _sessions.first.id;
        }
      } else {
        // Create initial default session
        final newSession = ChatSession.create();
        _sessions.add(newSession);
        _activeSessionId = newSession.id;
      }
    });

    _saveState();

    // Background sync user session status with server
    AuthService.syncUserStatus().then((synced) {
      if (mounted) {
        setState(() => _currentUser = synced);
      }
    });
  }

  void _saveState() {
    StorageService.saveSessions(_sessions);
    if (_activeSessionId != null) {
      StorageService.saveCurrentSessionId(_activeSessionId!);
    }
  }

  ChatSession? get _currentSession {
    if (_activeSessionId == null) return null;
    return _sessions.firstWhere(
      (s) => s.id == _activeSessionId,
      orElse: () => _sessions.first,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleNewChat() {
    final newSession = ChatSession.create();
    setState(() {
      _sessions.insert(0, newSession);
      _activeSessionId = newSession.id;
      _streamingText = null;
      _isLoading = false;
    });
    _saveState();
  }

  void _handleSelectSession(String sessionId) {
    setState(() {
      _activeSessionId = sessionId;
      _streamingText = null;
      _isLoading = false;
    });
    _saveState();
    _scrollToBottom();
  }

  void _handleDeleteSession(String sessionId) {
    setState(() {
      _sessions.removeWhere((s) => s.id == sessionId);
      if (_activeSessionId == sessionId) {
        if (_sessions.isNotEmpty) {
          _activeSessionId = _sessions.first.id;
        } else {
          final newSession = ChatSession.create();
          _sessions.add(newSession);
          _activeSessionId = newSession.id;
        }
      }
    });
    _saveState();
  }

  Future<void> _handleSendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    _inputController.clear();

    var session = _currentSession;
    if (session == null) {
      _handleNewChat();
      session = _currentSession!;
    }

    // Generate smart title from first message
    if (session.messages.isEmpty) {
      session.title = text.length > 28 ? '${text.substring(0, 28)}...' : text;
    }

    final userMessage = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      text: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      session!.messages.add(userMessage);
      _isLoading = true;
      _streamingText = null;
    });
    _saveState();
    _scrollToBottom();

    // Call API with token callback
    final result = await ApiService.sendMessage(
      prompt: text,
      webSearch: _webSearch,
      sessionId: session.id,
      history: session.messages,
      onTokenReceived: (chunk) {
        setState(() {
          _streamingText = (_streamingText ?? '') + chunk;
        });
        _scrollToBottom();
      },
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        final replyText = result.error != null
            ? '⚠️ ${result.error}'
            : (_streamingText ?? result.text);

        final assistantMsg = ChatMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          text: replyText,
          model: result.model,
          webSearch: result.webSearch,
          sources: result.sources,
          fromDatabase: result.fromDatabase,
          timestamp: DateTime.now(),
        );

        session!.messages.add(assistantMsg);
        _streamingText = null;
      });
      _saveState();
      _scrollToBottom();
    }
  }

  void _openToolsSheet() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => const ToolsHubScreen()),
    );
  }

  void _openLoginModal() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => LoginScreen(
          onLoginSuccess: () async {
            final user = await AuthService.getCurrentUser();
            setState(() => _currentUser = user);
            if (mounted) {
              final name = user.name.isNotEmpty ? user.name : user.username;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Welcome back, $name!'),
                  backgroundColor: AppTheme.accentPurple,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    await AuthService.logout();
    setState(() => _currentUser = AuthUser.guest());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged out successfully.'),
          duration: Duration(seconds: 1),
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => AuthGateScreen(
            isDarkMode: widget.isDarkMode,
            onToggleTheme: widget.onToggleTheme,
          ),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSession = _currentSession;
    final messages = currentSession?.messages ?? [];
    final isChatEmpty = messages.isEmpty && _streamingText == null;

    return Scaffold(
      key: _scaffoldKey,
      onDrawerChanged: (isOpened) {
        widget.onDrawerChanged?.call(isOpened);
      },
      onEndDrawerChanged: (isOpened) {
        widget.onDrawerChanged?.call(isOpened);
      },
      backgroundColor: widget.isDarkMode ? AppTheme.bgMain : const Color(0xFFF8FAFC),
      appBar: HeaderBar(
        onOpenLeftDrawer: () async {
          final user = await AuthService.getCurrentUser();
          if (mounted) setState(() => _currentUser = user);
          _scaffoldKey.currentState?.openDrawer();
        },
        onOpenRightDrawer: () async {
          final user = await AuthService.getCurrentUser();
          if (mounted) setState(() => _currentUser = user);
          _scaffoldKey.currentState?.openEndDrawer();
        },
        onOpenTools: _openToolsSheet,
        onToggleTheme: widget.onToggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      drawer: LeftDrawer(
        sessions: _sessions,
        activeSessionId: _activeSessionId,
        onSelectSession: _handleSelectSession,
        onDeleteSession: _handleDeleteSession,
        onNewChat: _handleNewChat,
        onClose: () => Navigator.pop(context),
        user: _currentUser,
        onOpenLogin: _openLoginModal,
        onLogout: _handleLogout,
        onOpenSettings: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileScreen(
                isDarkMode: widget.isDarkMode,
                onToggleTheme: widget.onToggleTheme,
                isModal: true,
              ),
            ),
          );
        },
      ),
      endDrawer: RightDrawer(
        onClose: () => Navigator.pop(context),
        user: _currentUser,
        onOpenLogin: _openLoginModal,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Chat Feed or Landing Hero
            Expanded(
              child: isChatEmpty
                  ? Center(
                      child: LandingHero(
                        username: _currentUser.isAuthenticated
                            ? (_currentUser.name.isNotEmpty
                                ? _currentUser.name
                                : _currentUser.username)
                            : null,
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 10, bottom: 20),
                      itemCount: messages.length +
                          (_streamingText != null ? 1 : 0) +
                          (_isLoading && _streamingText == null ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < messages.length) {
                          return MessageBubble(message: messages[index]);
                        } else if (_streamingText != null) {
                          // Live streaming bubble
                          return MessageBubble(
                            message: ChatMessage(
                              id: 'streaming',
                              role: 'assistant',
                              text: _streamingText!,
                              model: 'Axom AI',
                            ),
                            isStreaming: true,
                          );
                        } else {
                          // Typing dots loader
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 16),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF8B5CF6),
                                        Color(0xFF6D28D9)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.auto_awesome,
                                    color: Colors.white,
                                    size: 15,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.bgCard,
                                    borderRadius: BorderRadius.circular(16),
                                    border:
                                        Border.all(color: AppTheme.borderColor),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _webSearch
                                            ? 'Searching web & synthesizing...'
                                            : 'Axom AI is thinking...',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
            ),

            // Bottom Floating Input Bar
            InputBar(
              controller: _inputController,
              isLoading: _isLoading,
              webSearch: _webSearch,
              bottomPadding: 92,
              onToggleWebSearch: () {
                setState(() => _webSearch = !_webSearch);
              },
              onOpenTools: _openToolsSheet,
              onSend: _handleSendMessage,
            ),
          ],
        ),
      ),
    );
  }
}
