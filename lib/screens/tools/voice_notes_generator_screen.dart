import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/voice_service.dart';
import '../../theme/app_theme.dart';

class VoiceNotesGeneratorScreen extends StatefulWidget {
  final String initialMode;
  const VoiceNotesGeneratorScreen({super.key, this.initialMode = 'study'});

  @override
  State<VoiceNotesGeneratorScreen> createState() =>
      _VoiceNotesGeneratorScreenState();
}

class _VoiceNotesGeneratorScreenState extends State<VoiceNotesGeneratorScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController(
    text: 'Spoken Transcript (কথোপকথনৰ টোকা)',
  );
  final TextEditingController _transcriptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Language & Mode
  String _spokenLanguage =
      'assamese'; // 'assamese', 'english', 'hindi', 'hinglish'
  String _targetLanguage = 'same'; // 'same', 'assamese', 'english', 'hindi'
  String _synthesisMode = 'study'; // 'study', 'meeting', 'ideas', 'summary'

  // Recording & Processing States
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isContinuousMode =
      true; // Auto-resume listening after sentence transcription
  bool _isSynthesizing = false;
  bool _isExporting = false;
  String _statusMessage = '';

  // Timer
  Timer? _recordTimer;
  int _recordSeconds = 0;

  // Synthesized Note Results
  String _structuredMarkdown = '';
  String _summarySnippet = '';
  int _selectedTabIndex =
      0; // 0: Live Transcript Editor, 1: Structured AI Notes

  late AnimationController _pulseController;

  final Map<String, String> _spokenLangLabels = {
    'assamese': 'অসমীয়া (Assamese)',
    'english': 'English',
    'hindi': 'हिन्दी (Hindi)',
    'hinglish': 'Hinglish',
  };

  final Map<String, String> _targetLangLabels = {
    'same': 'Original (মূলে ৰাখক)',
    'assamese': 'অসমীয়া (Assamese)',
    'english': 'English',
    'hindi': 'हिन्दी (Hindi)',
  };

  final List<Map<String, dynamic>> _modes = [
    {
      'id': 'study',
      'label': 'Study Notes',
      'assamese': 'পাঠৰ টোকা',
      'icon': Icons.school_rounded,
      'color': Color(0xFF8B5CF6),
    },
    {
      'id': 'meeting',
      'label': 'Meeting Minutes',
      'assamese': 'কাৰ্যবিৱৰণী',
      'icon': Icons.business_center_rounded,
      'color': Color(0xFF06B6D4),
    },
    {
      'id': 'ideas',
      'label': 'Brainstorm',
      'assamese': 'ধাৰণা & চিন্তা',
      'icon': Icons.lightbulb_rounded,
      'color': Color(0xFFF59E0B),
    },
    {
      'id': 'summary',
      'label': 'Summary',
      'assamese': 'সাৰাংশ',
      'icon': Icons.bolt_rounded,
      'color': Color(0xFF10B981),
    },
  ];

  @override
  void initState() {
    super.initState();
    _synthesisMode = widget.initialMode;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _pulseController.dispose();
    _titleController.dispose();
    _transcriptController.dispose();
    _scrollController.dispose();
    if (_isListening) {
      VoiceService.instance.cancelRecording();
    }
    super.dispose();
  }

  // ─── RECORDING & VOICE-TO-TEXT LOGIC ──────────────────────────────────────
  Future<void> _toggleRecording() async {
    if (_isListening) {
      await _stopRecording(manualStop: true);
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await VoiceService.instance.hasMicPermission();
    if (!hasPermission) {
      final allowed = await VoiceService.instance.startRecording(
        onAutoStop: () {},
      );
      if (!allowed) {
        _showSnackBar(
          'Microphone permission is required to dictate voice.',
          isError: true,
        );
        return;
      }
      await VoiceService.instance.cancelRecording();
    }

    setState(() {
      _isListening = true;
      _statusMessage = _spokenLanguage == 'assamese'
          ? 'শুনিয়ে আছোঁ... আপুনি অসমীয়াত কৈ যাওক...'
          : 'Listening... speak now...';
      _recordSeconds = 0;
    });

    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) setState(() => _recordSeconds++);
    });

    final started = await VoiceService.instance.startRecording(
      onAutoStop: () {
        if (mounted && _isListening) {
          _handleSpeechChunk();
        }
      },
    );

    if (!started) {
      setState(() {
        _isListening = false;
        _statusMessage = '';
      });
      _recordTimer?.cancel();
      _showSnackBar('Could not start microphone.', isError: true);
    }
  }

  Future<void> _handleSpeechChunk() async {
    if (!_isListening) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = _spokenLanguage == 'assamese'
          ? 'লিখি থকা হৈছে...'
          : 'Transcribing speech to text...';
    });

    try {
      final text = await VoiceService.instance.finishRecording(
        language: _spokenLanguage,
      );
      if (text.trim().isNotEmpty) {
        String processedText = text.trim();

        // Check translation
        if (_targetLanguage != 'same' && _targetLanguage != _spokenLanguage) {
          setState(() {
            _statusMessage =
                'অনুবাদ কৰি থকা হৈছে (${_targetLangLabels[_targetLanguage]})...';
          });
          final transRes = await ApiService.translateVoiceNotes(
            text: processedText,
            sourceLang: _spokenLanguage,
            targetLang: _targetLanguage,
          );
          if (transRes['success'] == true &&
              transRes['translated_text'] != null) {
            processedText = transRes['translated_text'].toString().trim();
          }
        }

        // Script purification for Assamese
        if (_targetLanguage == 'assamese' ||
            (_targetLanguage == 'same' && _spokenLanguage == 'assamese')) {
          processedText = VoiceService.purifyAssamese(processedText);
        }

        // Type out automatically into editor
        _appendSpokenText(processedText);
      }
    } on VoiceException catch (e) {
      // Gentle feedback
      debugPrint('Voice note info: ${e.message}');
    } catch (e) {
      debugPrint('Speech handling error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = '';
        });

        // Continuous dictation: auto-resume listening if enabled
        if (_isContinuousMode && _isListening) {
          await _startRecording();
        } else {
          _stopRecording(manualStop: false);
        }
      }
    }
  }

  Future<void> _stopRecording({bool manualStop = true}) async {
    _recordTimer?.cancel();
    if (manualStop && _isListening) {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'চূড়ান্ত বাক্য লিখি থকা হৈছে...';
      });
      try {
        final text = await VoiceService.instance.finishRecording(
          language: _spokenLanguage,
        );
        if (text.trim().isNotEmpty) {
          String processedText = text.trim();
          if (_targetLanguage != 'same' && _targetLanguage != _spokenLanguage) {
            final transRes = await ApiService.translateVoiceNotes(
              text: processedText,
              sourceLang: _spokenLanguage,
              targetLang: _targetLanguage,
            );
            if (transRes['success'] == true &&
                transRes['translated_text'] != null) {
              processedText = transRes['translated_text'].toString().trim();
            }
          }
          if (_targetLanguage == 'assamese' ||
              (_targetLanguage == 'same' && _spokenLanguage == 'assamese')) {
            processedText = VoiceService.purifyAssamese(processedText);
          }
          _appendSpokenText(processedText);
        }
      } catch (_) {}
    } else {
      await VoiceService.instance.cancelRecording();
    }

    if (mounted) {
      setState(() {
        _isListening = false;
        _isProcessing = false;
        _statusMessage = '';
      });
    }
  }

  void _appendSpokenText(String newText) {
    if (newText.trim().isEmpty) return;
    final current = _transcriptController.text.trim();
    final updated = current.isEmpty ? newText : '$current $newText';

    setState(() {
      _transcriptController.text = updated;
      _transcriptController.selection = TextSelection.collapsed(
        offset: updated.length,
      );
    });

    // Auto-scroll to bottom
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

  // ─── UPLOAD AUDIO FILE ──────────────────────────────────────────────────
  Future<void> _pickAndTranscribeAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m4a', 'mp3', 'wav', 'aac', 'ogg', 'webm'],
      );

      if (result == null || result.files.single.path == null) return;
      final path = result.files.single.path!;

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Uploading and transcribing audio file...';
      });

      String text = await VoiceService.instance.transcribeAudioFile(
        filePath: path,
        language: _spokenLanguage,
      );

      if (_targetLanguage != 'same' && _targetLanguage != _spokenLanguage) {
        setState(() {
          _statusMessage = 'Translating audio content...';
        });
        final transRes = await ApiService.translateVoiceNotes(
          text: text,
          sourceLang: _spokenLanguage,
          targetLang: _targetLanguage,
        );
        if (transRes['success'] == true &&
            transRes['translated_text'] != null) {
          text = transRes['translated_text'];
        }
      }

      if (_targetLanguage == 'assamese' ||
          (_targetLanguage == 'same' && _spokenLanguage == 'assamese')) {
        text = VoiceService.purifyAssamese(text);
      }

      _appendSpokenText(text);
      _showSnackBar('🎙️ Audio transcribed and typed successfully!');
    } catch (e) {
      _showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = '';
        });
      }
    }
  }

  // ─── AI SYNTHESIS ────────────────────────────────────────────────────────
  Future<void> _synthesizeNotes() async {
    final transcript = _transcriptController.text.trim();
    if (transcript.length < 5) {
      _showSnackBar(
        'Please speak or type some text first before generating notes.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSynthesizing = true;
    });

    final res = await ApiService.synthesizeVoiceNotes(
      transcript: transcript,
      mode: _synthesisMode,
      language: _targetLanguage != 'same' ? _targetLanguage : _spokenLanguage,
    );

    if (!mounted) return;
    setState(() => _isSynthesizing = false);

    if (res['success'] == true) {
      setState(() {
        _structuredMarkdown = res['notes'] ?? '';
        _summarySnippet = res['summary'] ?? '';
        if (res['title'] != null && res['title'].toString().isNotEmpty) {
          _titleController.text = res['title'];
        }
        _selectedTabIndex = 1; // Auto switch to Structured Notes view
      });
      _showSnackBar('✨ Structured notes generated successfully!');
    } else {
      _showSnackBar(
        res['error'] ?? 'Could not synthesize notes.',
        isError: true,
      );
    }
  }

  // ─── EXPORT TO WORD (.DOCX) ─────────────────────────────────────────────
  Future<void> _exportToDocx() async {
    final content = _selectedTabIndex == 1 && _structuredMarkdown.isNotEmpty
        ? _structuredMarkdown
        : _transcriptController.text.trim();

    if (content.isEmpty) {
      _showSnackBar(
        'No content to export. Speak or type some notes first.',
        isError: true,
      );
      return;
    }

    setState(() => _isExporting = true);

    final res = await ApiService.exportVoiceNotesDocx(
      title: _titleController.text.trim(),
      notes: content,
      mode: _synthesisMode.toUpperCase(),
    );

    if (!mounted) return;
    setState(() => _isExporting = false);

    if (res['success'] == true) {
      if (res['download_url'] != null) {
        final uri = Uri.parse(res['download_url']);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          _showSnackBar('📄 Word document (.docx) downloaded successfully!');
        } else {
          _showSnackBar('Downloaded: ${res['download_url']}');
        }
      } else if (res['file_path'] != null) {
        _showSnackBar('📄 Saved to: ${res['file_path']}');
      }
    } else {
      _showSnackBar(res['error'] ?? 'Export failed.', isError: true);
    }
  }

  // ─── UTILITIES ──────────────────────────────────────────────────────────
  void _copyToClipboard() {
    final text = _selectedTabIndex == 1 && _structuredMarkdown.isNotEmpty
        ? _structuredMarkdown
        : _transcriptController.text.trim();

    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('📋 Copied to clipboard!');
  }

  void _purifyTextScript() {
    final current = _transcriptController.text;
    if (current.isEmpty) return;
    final purified = VoiceService.purifyAssamese(current);
    setState(() {
      _transcriptController.text = purified;
    });
    _showSnackBar('✅ Assamese script purified (ৰ & ৱ enforced)!');
  }

  void _clearContent() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Clear Transcript?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete all spoken text and generated notes?',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _transcriptController.clear();
                _structuredMarkdown = '';
                _summarySnippet = '';
              });
              _showSnackBar('Cleared transcript.');
            },
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatTimer(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ─── BUILD UI ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgMain = isDark ? AppTheme.bgMain : const Color(0xFFF8FAFC);
    final cardBg = isDark ? AppTheme.bgCard : Colors.white;
    final borderColor = isDark ? AppTheme.borderColor : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? AppTheme.textSecondary
        : const Color(0xFF64748B);

    final wordCount = _transcriptController.text
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .length;

    return Scaffold(
      backgroundColor: bgMain,
      appBar: AppBar(
        backgroundColor: bgMain,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Voice Notes Generator',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'VOICE AI',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
            const Text(
              'বাণীৰ পৰা নিখুঁত টোকা • Real-time Speech-to-Text',
              style: TextStyle(fontSize: 11, color: AppTheme.accentEmerald),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.cleaning_services_rounded,
              color: textSecondary,
              size: 20,
            ),
            tooltip: 'Purify Assamese (ৰ & ৱ)',
            onPressed: _purifyTextScript,
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: textSecondary,
              size: 20,
            ),
            tooltip: 'Clear',
            onPressed: _clearContent,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Tab Switcher: Live Transcript vs Structured Notes
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      index: 0,
                      icon: Icons.edit_note_rounded,
                      label: 'Spoken Editor',
                      active: _selectedTabIndex == 0,
                      badge: '$wordCount words',
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildTabButton(
                      index: 1,
                      icon: Icons.auto_awesome_rounded,
                      label: 'AI Notes',
                      active: _selectedTabIndex == 1,
                      badge: _structuredMarkdown.isNotEmpty ? 'READY' : null,
                    ),
                  ),
                ],
              ),
            ),

            // Language & Mode Bar
            _buildLanguageConfigBar(
              isDark,
              cardBg,
              borderColor,
              textPrimary,
              textSecondary,
            ),

            // Main Editor Body
            Expanded(
              child: _selectedTabIndex == 0
                  ? _buildTranscriptEditor(
                      isDark,
                      cardBg,
                      borderColor,
                      textPrimary,
                      textSecondary,
                    )
                  : _buildStructuredNotesView(
                      isDark,
                      cardBg,
                      borderColor,
                      textPrimary,
                      textSecondary,
                    ),
            ),

            // Bottom Voice Dictation & Action Console
            _buildBottomVoiceConsole(
              isDark,
              cardBg,
              borderColor,
              textPrimary,
              textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  // ─── TABS ────────────────────────────────────────────────────────────────
  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String label,
    required bool active,
    String? badge,
  }) {
    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF10B981) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? Colors.white : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.25)
                      : const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : const Color(0xFFCBD5E1),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── CONFIG BAR ─────────────────────────────────────────────────────────
  Widget _buildLanguageConfigBar(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // Spoken Language Selector
          Expanded(
            child: PopupMenuButton<String>(
              tooltip: 'Spoken Language',
              onSelected: (v) => setState(() => _spokenLanguage = v),
              itemBuilder: (_) => _spokenLangLabels.entries
                  .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              child: Row(
                children: [
                  const Icon(
                    Icons.mic_rounded,
                    size: 14,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _spokenLangLabels[_spokenLanguage] ?? 'Assamese',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 18,
                    color: textSecondary,
                  ),
                ],
              ),
            ),
          ),

          Container(
            width: 1,
            height: 20,
            color: borderColor,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),

          // Target Language Selector
          Expanded(
            child: PopupMenuButton<String>(
              tooltip: 'Translate To',
              onSelected: (v) => setState(() => _targetLanguage = v),
              itemBuilder: (_) => _targetLangLabels.entries
                  .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              child: Row(
                children: [
                  const Icon(
                    Icons.translate_rounded,
                    size: 14,
                    color: Color(0xFF06B6D4),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _targetLanguage == 'same'
                          ? 'Keep Original'
                          : _targetLangLabels[_targetLanguage]!,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _targetLanguage != 'same'
                            ? const Color(0xFF06B6D4)
                            : textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 18,
                    color: textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // File Audio Upload Button
          IconButton(
            icon: Icon(
              Icons.upload_file_rounded,
              size: 19,
              color: textSecondary,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Transcribe Audio File (mp3/m4a)',
            onPressed: _isListening || _isProcessing
                ? null
                : _pickAndTranscribeAudio,
          ),
        ],
      ),
    );
  }

  // ─── TRANSCRIPT EDITOR VIEW ──────────────────────────────────────────────
  Widget _buildTranscriptEditor(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isListening
              ? const Color(0xFF10B981).withValues(alpha: 0.6)
              : borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Document Title Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _titleController,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Note Title...',
                    hintStyle: TextStyle(color: textSecondary),
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 17, color: textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Copy Transcript',
                onPressed: _copyToClipboard,
              ),
            ],
          ),

          const Divider(height: 16),

          // Live Dictation Status Alert
          if (_isListening || _isProcessing)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isListening
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : const Color(0xFF06B6D4).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isListening
                      ? const Color(0xFF10B981)
                      : const Color(0xFF06B6D4),
                  width: 0.6,
                ),
              ),
              child: Row(
                children: [
                  if (_isProcessing)
                    const SpinKitRing(
                      color: Color(0xFF06B6D4),
                      size: 14,
                      lineWidth: 2,
                    )
                  else
                    FadeTransition(
                      opacity: _pulseController,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _isListening
                            ? const Color(0xFF10B981)
                            : const Color(0xFF06B6D4),
                      ),
                    ),
                  ),
                  if (_isListening)
                    Text(
                      _formatTimer(_recordSeconds),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            ),

          // Scrollable Editor Field
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: TextField(
                controller: _transcriptController,
                maxLines: null,
                style: TextStyle(fontSize: 15, height: 1.6, color: textPrimary),
                decoration: InputDecoration(
                  hintText:
                      'Tap the microphone below and speak.\n\nYour words will automatically type here in real-time in authentic Assamese or your chosen language...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: textSecondary.withValues(alpha: 0.8),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── STRUCTURED NOTES VIEW ───────────────────────────────────────────────
  Widget _buildStructuredNotesView(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (_structuredMarkdown.isEmpty && !_isSynthesizing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  size: 32,
                  color: Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Structured Notes Yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Speak or type your transcript in the editor, select a mode below, and tap "Synthesize Structured Notes".',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text(
                  'Back to Spoken Editor',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () => setState(() => _selectedTabIndex = 0),
              ),
            ],
          ),
        ),
      );
    }

    if (_isSynthesizing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SpinKitCubeGrid(color: Color(0xFF10B981), size: 44),
            const SizedBox(height: 20),
            Text(
              'Synthesizing Structured Notes...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Applying multi-tier AI, chapter outlines & Assamese orthography...',
              style: TextStyle(fontSize: 12, color: Color(0xFF10B981)),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _titleController.text.trim(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 17, color: textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Copy Markdown',
                onPressed: _copyToClipboard,
              ),
            ],
          ),
          const Divider(height: 16),
          if (_summarySnippet.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    size: 16,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _summarySnippet,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Markdown(
              data: _structuredMarkdown,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                  .copyWith(
                    h1: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                    h2: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                    ),
                    h3: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                    p: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: textPrimary,
                    ),
                    listBullet: const TextStyle(color: Color(0xFF10B981)),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── BOTTOM VOICE CONSOLE ───────────────────────────────────────────────
  Widget _buildBottomVoiceConsole(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: borderColor, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mode Selection Chips (Study, Meeting, Ideas, Summary)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _modes.map((m) {
                final isSelected = _synthesisMode == m['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(
                      m['icon'] as IconData,
                      size: 14,
                      color: isSelected ? Colors.white : (m['color'] as Color),
                    ),
                    label: Text('${m['label']} (${m['assamese']})'),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _synthesisMode = m['id']);
                    },
                    selectedColor: m['color'] as Color,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? Colors.white : textSecondary,
                    ),
                    backgroundColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    side: BorderSide(
                      color: isSelected ? (m['color'] as Color) : borderColor,
                      width: 0.6,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 10),

          // Main Controls Row: Synthesize AI | Big Pulsing Mic | Export Word
          Row(
            children: [
              // 1. Synthesize Notes Button
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: _isSynthesizing ? null : _synthesizeNotes,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isSynthesizing)
                          const SpinKitRing(
                            color: Colors.white,
                            size: 16,
                            lineWidth: 2,
                          )
                        else
                          const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        const SizedBox(width: 6),
                        const Flexible(
                          child: Text(
                            'Synthesize',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // 2. Big Microphone Button with Audio Level Reaction
              ValueListenableBuilder<double>(
                valueListenable: VoiceService.instance.level,
                builder: (context, lv, child) {
                  return InkWell(
                    onTap: _toggleRecording,
                    borderRadius: BorderRadius.circular(30),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _isListening
                            ? const LinearGradient(
                                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                              )
                            : const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: _isListening
                                ? Colors.redAccent.withValues(
                                    alpha: 0.4 + 0.5 * lv,
                                  )
                                : const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.35),
                            blurRadius: _isListening ? (12 + 16 * lv) : 10,
                            spreadRadius: _isListening ? (2 + 6 * lv) : 0,
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isProcessing
                            ? const SpinKitRing(
                                color: Colors.white,
                                size: 24,
                                lineWidth: 2.5,
                              )
                            : Icon(
                                _isListening
                                    ? Icons.stop_rounded
                                    : Icons.mic_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(width: 12),

              // 3. Export Word (.docx) Button
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: _isExporting ? null : _exportToDocx,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isExporting)
                          const SpinKitRing(
                            color: Color(0xFF10B981),
                            size: 16,
                            lineWidth: 2,
                          )
                        else
                          const Icon(
                            Icons.description_rounded,
                            color: Color(0xFF10B981),
                            size: 18,
                          ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Word .docx',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Continuous Dictation Toggle Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: () {
                  setState(() => _isContinuousMode = !_isContinuousMode);
                  _showSnackBar(
                    _isContinuousMode
                        ? 'Continuous mode enabled: Mic keeps listening after sentence.'
                        : 'Single sentence mode enabled.',
                  );
                },
                child: Row(
                  children: [
                    Icon(
                      _isContinuousMode
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 13,
                      color: _isContinuousMode
                          ? const Color(0xFF10B981)
                          : textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Continuous Dictation (অনবৰত বাক্য গ্ৰহণ)',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: _isContinuousMode
                            ? const Color(0xFF10B981)
                            : textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
