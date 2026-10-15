import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/voice_service.dart';
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
    StorageService.loadChatLanguage().then((v) {
      if (mounted) setState(() => _language = v == 'english' ? 'english' : 'assamese');
    });
    VoiceService.instance.recording.addListener(_onVoiceChanged);
    VoiceService.instance.transcribing.addListener(_onVoiceChanged);
    _initializeData();
  }

  String _language = 'assamese';

  void _onVoiceChanged() {
    if (mounted) setState(() {});
  }

  static const Map<String, String> _languageNames = {
    'assamese': 'Assamese',
    'english': 'English',
  };

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleMic() async {
    final voice = VoiceService.instance;
    if (voice.recording.value) {
      await _finishVoice();
      return;
    }
    final ok = await voice.startRecording(onAutoStop: _finishVoice);
    if (!ok) _snack('Allow the microphone to use voice typing.');
  }

  Future<void> _finishVoice() async {
    final voice = VoiceService.instance;
    if (!voice.recording.value) return;
    try {
      final text = await voice.finishRecording(language: _language);
      if (!mounted || text.isEmpty) return;
      final old = _inputController.text.trim();
      _inputController.text = old.isEmpty ? text : '$old $text';
      _inputController.selection = TextSelection.collapsed(offset: _inputController.text.length);
      _handleSendMessage(); // spoken words go straight to the AI: no second tap
    } on VoiceException catch (e) {
      _snack(e.message);
    }
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
    VoiceService.instance.recording.removeListener(_onVoiceChanged);
    VoiceService.instance.transcribing.removeListener(_onVoiceChanged);
    VoiceService.instance.cancelRecording();
    VoiceService.instance.stop();
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
    final attachPath = overrideText == null ? _attachPath : null;
    final attachIsImage = _attachIsImage;
    final attachName = _attachName;
    if ((text.isEmpty && attachPath == null) || _isLoading) return;

    if (_isAssameseTranslit && overrideText == null && text.isNotEmpty) {
      text = await ApiService.transliterateAssamese(text);
    }

    // The file is read before anything is shown, so a failure leaves the message and the attachment as they were.
    String? imageB64, pdfB64;
    if (attachPath != null) {
      try {
        final bytes = await File(attachPath).readAsBytes();
        if (attachIsImage) {
          imageB64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        } else {
          pdfB64 = 'data:application/pdf;base64,${base64Encode(bytes)}';
        }
      } catch (_) {
        _snack('Could not read the file. Please attach it again.');
        setState(() => _attachPath = null);
        return;
      }
    }
    final sentText = text;
    if (text.isEmpty) {
      final asm = _language == 'assamese';
      text = attachIsImage
          ? (asm ? 'এই ছবিখনত কি আছে? বুজাই দিয়ক।' : 'What is in this image? Please explain.')
          : (asm ? 'এই নথিখনৰ সাৰাংশ দিয়ক।' : 'Please summarise this document.');
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
      text: sentText,
      timestamp: DateTime.now(),
      imagePath: attachIsImage ? attachPath : null,
      fileName: (!attachIsImage && attachPath != null) ? attachName : null,
    );

    setState(() {
      session!.messages.add(userMessage);
      _isLoading = true;
      _streamingText = null;
      _streamBuffer = '';
      if (attachPath != null) _attachPath = null;
    });
    _saveState();
    _scrollToBottom();

    final result = await ApiService.sendMessage(
      prompt: text,
      webSearch: _webSearch,
      language: _language,
      attachedImage: imageB64,
      attachedPdf: pdfB64,
      attachedFilename: attachName,
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

  // A picture or a PDF waiting to be sent with the next message.
  String? _attachPath;
  String? _attachName;
  bool _attachIsImage = true;

  Future<void> _handlePickAttachment() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: widget.isDarkMode ? AppTheme.bgSurface : Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Photo from gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: const Text('PDF document'),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    try {
      if (choice == 'pdf') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        final f = result?.files.firstOrNull;
        if (f?.path == null) return;
        if (f!.size > 8 * 1024 * 1024) {
          _snack('That PDF is too big (over 8 MB). Please pick a smaller one.');
          return;
        }
        setState(() {
          _attachPath = f.path;
          _attachName = f.name;
          _attachIsImage = false;
        });
        return;
      }
      // The picker shrinks the picture (longest side 1600 px, JPEG) so the upload is quick.
      final picked = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/attachments');
      if (!folder.existsSync()) folder.createSync(recursive: true);
      final keep = '${folder.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(picked.path).copy(keep);
      setState(() {
        _attachPath = keep;
        _attachName = picked.name;
        _attachIsImage = true;
      });
    } catch (e) {
      _snack('Could not open the file: $e');
    }
  }

  Widget _buildListeningStrip() {
    final voice = VoiceService.instance;
    final listening = voice.recording.value;
    final busy = voice.transcribing.value;
    if (!listening && !busy) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (listening ? Colors.redAccent : AppTheme.accentPurple).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (listening ? Colors.redAccent : AppTheme.accentPurple).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          if (listening)
            ValueListenableBuilder<double>(
              valueListenable: voice.level,
              builder: (_, v, __) => Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (final k in const [0.5, 0.9, 1.0, 0.8, 0.55, 0.9, 0.6])
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 110),
                      width: 4,
                      height: 6 + 24 * (v * k),
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(3)),
                    ),
                ],
              ),
            )
          else
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentPurple),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              listening ? 'Listening... speak now' : 'Understanding what you said...',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          if (listening)
            TextButton(
              onPressed: () => VoiceService.instance.cancelRecording(),
              child: const Text('Cancel'),
            ),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview() {
    if (_attachPath == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? AppTheme.bgSurface : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (_attachIsImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(_attachPath!), width: 54, height: 54, fit: BoxFit.cover, cacheWidth: 160),
            )
          else
            const Icon(Icons.picture_as_pdf_rounded, size: 36, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_attachName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: 'Remove',
            onPressed: () => setState(() => _attachPath = null),
          ),
        ],
      ),
    );
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

            _buildAttachmentPreview(),
            _buildListeningStrip(),

            // Bottom Floating Input Bar
            InputBar(
              controller: _inputController,
              isLoading: _isLoading,
              webSearch: _webSearch,
              isAssameseTranslit: _isAssameseTranslit,
              bottomPadding: 8,
              languageLabel: _languageNames[_language] ?? 'Assamese',
              onLanguageChanged: (v) {
                setState(() => _language = v == 'english' ? 'english' : 'assamese');
                StorageService.saveChatLanguage(v);
              },
              listening: VoiceService.instance.recording.value,
              hasAttachment: _attachPath != null,
              transcribing: VoiceService.instance.transcribing.value,
              onMic: _toggleMic,
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
