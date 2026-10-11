import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
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
  bool _isAssameseTranslit = false;
  String? _streamingText;
  AuthUser _currentUser = AuthUser.guest();

  Timer? _streamThrottleTimer;
  String _streamBuffer = '';

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
    _streamThrottleTimer?.cancel();
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
        final newSession = ChatSession.create();
        _sessions.add(newSession);
        _activeSessionId = newSession.id;
      }
    });

    _saveState();

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

  void _scrollToBottom({bool immediate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (immediate) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } else {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });
  }

  void _flushStreamBuffer() {
    if (_streamBuffer.isNotEmpty && mounted) {
      setState(() {
        _streamingText = (_streamingText ?? '') + _streamBuffer;
        _streamBuffer = '';
      });
      _scrollToBottom(immediate: true);
    }
  }

  void _handleNewChat() {
    final newSession = ChatSession.create();
    setState(() {
      _sessions.insert(0, newSession);
      _activeSessionId = newSession.id;
      _streamingText = null;
      _streamBuffer = '';
      _isLoading = false;
    });
    _saveState();
  }

  void _handleSelectSession(String sessionId) {
    setState(() {
      _activeSessionId = sessionId;
      _streamingText = null;
      _streamBuffer = '';
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

  Future<void> _handleSendMessage([String? overrideText]) async {
    String text = overrideText ?? _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    if (_isAssameseTranslit && overrideText == null) {
      text = await ApiService.transliterateAssamese(text);
    }

    _inputController.clear();

    var session = _currentSession;
    if (session == null) {
      _handleNewChat();
      session = _currentSession!;
    }

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
      _streamBuffer = '';
    });
    _saveState();
    _scrollToBottom();

    final result = await ApiService.sendMessage(
      prompt: text,
      webSearch: _webSearch,
      sessionId: session.id,
      history: session.messages,
      onTokenReceived: (chunk) {
        _streamBuffer += chunk;
        if (_streamThrottleTimer == null || !_streamThrottleTimer!.isActive) {
          _streamThrottleTimer = Timer(const Duration(milliseconds: 40), () {
            _flushStreamBuffer();
          });
        }
      },
    );

    _streamThrottleTimer?.cancel();
    _flushStreamBuffer();

    if (mounted) {
      final replyText = result.error != null
          ? '⚠️ ${result.error}'
          : (_streamingText ?? result.text);

      setState(() {
        _isLoading = false;
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
        _streamBuffer = '';
      });
      _saveState();
      _scrollToBottom();

      // Deduct words in backend quota for assistant reply
      if (result.error == null && replyText.isNotEmpty) {
        final replyWords = replyText
            .split(RegExp(r'\s+'))
            .where((w) => w.trim().isNotEmpty)
            .length;
        if (replyWords > 0) {
          ApiService.deductWordUsage(replyWords);
        }
      }
    }
  }

  Future<void> _handlePickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'docx'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final isImage = ['jpg', 'jpeg', 'png', 'webp'].contains(file.extension?.toLowerCase());

        if (isImage) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🔍 Extracting OCR text from ${file.name}...'),
              backgroundColor: AppTheme.accentPurple,
            ),
          );
          final ocrRes = await ApiService.performOCR(file);
          if (ocrRes['success'] == true && ocrRes['text'] != null) {
            final extracted = ocrRes['text'].toString().trim();
            if (extracted.isNotEmpty) {
              _inputController.text = 'Analyze this extracted image text:\n\n$extracted';
            }
          } else {
            _inputController.text = 'Attached image: ${file.name}. Please explain the visual contents.';
          }
        } else {
          _inputController.text = 'Attached document: ${file.name}. Please provide a comprehensive summary.';
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attachment error: $e')),
      );
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
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: RepaintBoundary(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              LandingHero(
                                username: _currentUser.isAuthenticated
                                    ? (_currentUser.name.isNotEmpty
                                        ? _currentUser.name
                                        : _currentUser.username)
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              // Suggestion chips
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    _buildSuggestionChip('অসমৰ ইতিহাস কওক', 'অসমৰ প্ৰাচীন আৰু মধ্যযুগীয় ইতিহাসৰ বিষয়ে চমুকৈ বুজাই দিয়া।'),
                                    _buildSuggestionChip('Generate Study Notes', 'Create comprehensive exam study notes on Photosynthesis and plant biology.'),
                                    _buildSuggestionChip('Web Search: Assam News', 'Find the latest news and technology updates in Assam today.'),
                                    _buildSuggestionChip('Explain Quantum Computing', 'Explain quantum computing in simple terms with analogies.'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      cacheExtent: 1000,
                      addRepaintBoundaries: true,
                      padding: const EdgeInsets.only(top: 10, bottom: 20),
                      itemCount: messages.length +
                          (_streamingText != null ? 1 : 0) +
                          (_isLoading && _streamingText == null ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < messages.length) {
                          return MessageBubble(
                            key: ValueKey(messages[index].id),
                            message: messages[index],
                          );
                        } else if (_streamingText != null) {
                          return MessageBubble(
                            key: const ValueKey('streaming_msg'),
                            message: ChatMessage(
                              id: 'streaming',
                              role: 'assistant',
                              text: _streamingText!,
                              model: 'Axom AI',
                            ),
                            isStreaming: true,
                          );
                        } else {
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
                                    color: widget.isDarkMode ? AppTheme.bgCard : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: widget.isDarkMode ? AppTheme.borderColor : const Color(0xFFE2E8F0),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: widget.isDarkMode ? 0.2 : 0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _webSearch
                                            ? 'Searching web & synthesizing...'
                                            : 'Axom AI is thinking...',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: widget.isDarkMode ? AppTheme.textSecondary : const Color(0xFF475569),
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
              isAssameseTranslit: _isAssameseTranslit,
              bottomPadding: 8,
              onToggleWebSearch: () {
                setState(() => _webSearch = !_webSearch);
              },
              onToggleTranslit: () {
                setState(() => _isAssameseTranslit = !_isAssameseTranslit);
              },
              onPickAttachment: _handlePickAttachment,
              onOpenTools: _openToolsSheet,
              onSend: () => _handleSendMessage(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String label, String prompt) {
    final chipBg = widget.isDarkMode ? AppTheme.bgSurface : const Color(0xFFFFFFFF);
    final chipBorder = widget.isDarkMode ? AppTheme.glassBorder : const Color(0xFFE2E8F0);
    final chipText = widget.isDarkMode ? AppTheme.textPrimary : const Color(0xFF0F172A);

    return InkWell(
      onTap: () => _handleSendMessage(prompt),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: chipBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: widget.isDarkMode ? 0.15 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, size: 14, color: AppTheme.accentEmerald),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: chipText, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
