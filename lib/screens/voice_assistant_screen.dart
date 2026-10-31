import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import '../services/storage_service.dart';

enum AssistantVoiceState { connecting, speaking, listening, thinking }

class VoiceAssistantScreen extends StatefulWidget {
  final bool isDarkMode;

  const VoiceAssistantScreen({super.key, required this.isDarkMode});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen>
    with TickerProviderStateMixin {
  // Assistant State
  AssistantVoiceState _state = AssistantVoiceState.connecting;
  String _statusText = 'Connecting to Axom AI Voice...';
  String _currentDialogue = '';
  String _selectedVoice = 'male';
  bool _showSubtitles = true;
  bool _isMuted = false;

  // User Profile
  String _userName = 'সমৰজিৎ';

  // Audio Playback & Recording
  final AudioPlayer _player = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription? _playerCompleteSub;

  // Animation Controllers for Glowing Fluid Orb
  late AnimationController _pulseController;
  late AnimationController _waveController;
  Timer? _silenceTimer;
  Timer? _amplitudeTimer;
  Timer? _speakingWaveTimer;
  final List<Uint8List> _audioQueue = [];
  bool _isPlayingAudioQueue = false;
  double _audioLevel = 0.0;
  String? _recordingPath;

  // Conversation History
  final List<Map<String, String>> _conversationHistory = [];

  // Real-Time Full-Duplex WebSocket
  WebSocket? _webSocket;
  StreamSubscription? _wsSub;
  bool _useWebSocket = false;

  @override
  void initState() {
    super.initState();

    // Pulse & Wave animations
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _playerCompleteSub = _player.onPlayerComplete.listen((_) {
      if (_audioQueue.isNotEmpty) {
        _playNextAudioQueueItem();
      } else if (_state == AssistantVoiceState.speaking && mounted) {
        _stopSpeakingWaveTimer();
        _startListening();
      }
    });

    _initVoiceSession();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _amplitudeTimer?.cancel();
    _playerCompleteSub?.cancel();
    _speakingWaveTimer?.cancel();
    _audioQueue.clear();
    _pulseController.dispose();
    _waveController.dispose();
    _wsSub?.cancel();
    try {
      _webSocket?.close();
    } catch (_) {}
    _player.stop();
    _player.dispose();
    _recorder.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _startSpeakingWaveTimer() {
    _stopSpeakingWaveTimer();
    _speakingWaveTimer = Timer.periodic(const Duration(milliseconds: 60), (
      timer,
    ) {
      if (_state != AssistantVoiceState.speaking) {
        timer.cancel();
        return;
      }
      final t = DateTime.now().millisecondsSinceEpoch / 140.0;
      final dynamicLevel =
          (math.sin(t) * 0.35 + math.cos(t * 1.8) * 0.25 + 0.55).clamp(
            0.25,
            0.95,
          );
      if (mounted) {
        setState(() {
          _audioLevel = dynamicLevel;
        });
      }
    });
  }

  void _stopSpeakingWaveTimer() {
    _speakingWaveTimer?.cancel();
    _speakingWaveTimer = null;
    if (_state != AssistantVoiceState.listening && mounted) {
      setState(() {
        _audioLevel = 0.0;
      });
    }
  }

  Future<void> _playNextAudioQueueItem() async {
    if (_audioQueue.isEmpty) {
      _isPlayingAudioQueue = false;
      _stopSpeakingWaveTimer();
      if (_state == AssistantVoiceState.speaking && mounted) {
        _startListening();
      }
      return;
    }

    _isPlayingAudioQueue = true;
    _startSpeakingWaveTimer();
    final nextAudio = _audioQueue.removeAt(0);
    try {
      await _player.play(BytesSource(nextAudio));
      await _player.setPlaybackRate(1.0);
    } catch (e) {
      debugPrint('Error playing audio chunk: $e');
      _playNextAudioQueueItem();
    }
  }

  Future<void> _initVoiceSession() async {
    // 1. Get user name
    final user = await AuthService.getCurrentUser();
    if (user.isAuthenticated) {
      if (user.name.isNotEmpty) {
        _userName = user.name.split(' ').first;
      } else if (user.username.isNotEmpty) {
        _userName = user.username;
      }
    }

    _selectedVoice = await StorageService.loadVoice();

    // 2. Connect via Real-Time WebSocket (Sub-Second Latency) or Fallback to HTTP
    await _connectWebSocketOrFallback();
  }

  // ─── REAL-TIME FULL-DUPLEX WEBSOCKET CONNECTION ──────────────
  Future<void> _connectWebSocketOrFallback() async {
    if (!mounted) return;
    setState(() {
      _state = AssistantVoiceState.connecting;
      _statusText = 'Axom AI Live Voice সক্ৰিয় হৈছে...';
    });

    try {
      final base = await StorageService.loadApiBaseUrl();
      final wsBase = base.startsWith('https://')
          ? base.replaceFirst('https://', 'wss://')
          : base.replaceFirst('http://', 'ws://');

      final wsUrl =
          '$wsBase/ws/voice/?user_name=${Uri.encodeComponent(_userName)}&voice=$_selectedVoice';

      _webSocket = await WebSocket.connect(
        wsUrl,
        headers: {'User-Agent': 'Dart/Flutter-AxomAI'},
      ).timeout(const Duration(seconds: 4));

      _useWebSocket = true;
      _wsSub?.cancel();
      _wsSub = _webSocket!.listen(
        _onWebSocketMessage,
        onError: (err) {
          debugPrint('WebSocket stream error: $err');
          _useWebSocket = false;
        },
        onDone: () {
          _useWebSocket = false;
        },
      );
    } catch (e) {
      debugPrint('WebSocket connection failed, falling back to HTTP: $e');
      _useWebSocket = false;
      await _fetchAndPlayGreeting();
    }
  }

  void _onWebSocketMessage(dynamic message) async {
    if (message is! String) return;

    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final event = data['event'] as String?;

      if (event == 'greeting') {
        final greetingText = data['text'] as String? ?? 'নমস্কাৰ!';
        final audioB64 = data['audio'] as String?;

        if (mounted) {
          setState(() {
            _currentDialogue = greetingText;
            _statusText = 'Axom AI আপোনাৰ সৈতে কথা পাতিছে...';
            _state = AssistantVoiceState.speaking;
          });
        }

        if (audioB64 != null && audioB64.isNotEmpty) {
          final audioBytes = base64Decode(audioB64);
          await _player.play(BytesSource(audioBytes));
          await _player.setPlaybackRate(1.0);
        } else {
          Timer(const Duration(seconds: 3), () {
            if (mounted && _state == AssistantVoiceState.speaking) {
              _startListening();
            }
          });
        }
      } else if (event == 'status') {
        final status = data['text'] as String? ?? '';
        if (mounted && status.isNotEmpty) {
          setState(() {
            _statusText = status;
          });
        }
      } else if (event == 'user_transcript') {
        final text = data['text'] as String? ?? '';
        if (text.isNotEmpty) {
          _conversationHistory.add({'role': 'user', 'text': text});
          if (mounted) {
            setState(() {
              _currentDialogue = '?????: "$text"';
              _statusText = '???? ????... (Thinking)';
              _state = AssistantVoiceState.thinking;
            });
          }
        }
      } else if (event == 'assistant_chunk') {
        final text = data['text'] as String? ?? '';
        final audioB64 = data['audio'] as String?;
        final isFinal = data['is_final'] as bool? ?? false;

        if (text.isNotEmpty) {
          if (_currentDialogue.isEmpty ||
              _currentDialogue.startsWith('?????:')) {
            _currentDialogue = text;
          } else if (!_currentDialogue.contains(text)) {
            _currentDialogue = '$_currentDialogue $text';
          }
          if (isFinal &&
              !_conversationHistory.any((m) => m['text'] == _currentDialogue)) {
            _conversationHistory.add({
              'role': 'assistant',
              'text': _currentDialogue,
            });
          }
        }

        if (mounted) {
          setState(() {
            _statusText = 'Axom AI ????? ????...';
            _state = AssistantVoiceState.speaking;
          });
          _startSpeakingWaveTimer();
        }

        if (audioB64 != null && audioB64.isNotEmpty) {
          final audioBytes = base64Decode(audioB64);
          _audioQueue.add(audioBytes);
          if (!_isPlayingAudioQueue) {
            _playNextAudioQueueItem();
          }
        }
      } else if (event == 'reply') {
        final userText = data['user_text'] as String? ?? '';
        final replyText = data['reply_text'] as String? ?? '';
        final audioB64 = data['audio'] as String?;

        if (userText.isNotEmpty &&
            !_conversationHistory.any((m) => m['text'] == userText)) {
          _conversationHistory.add({'role': 'user', 'text': userText});
        }
        if (replyText.isNotEmpty) {
          _conversationHistory.add({'role': 'assistant', 'text': replyText});
        }

        if (mounted) {
          setState(() {
            _currentDialogue = replyText;
            _statusText = 'Axom AI উত্তৰ দিছে...';
            _state = AssistantVoiceState.speaking;
          });
        }

        if (audioB64 != null && audioB64.isNotEmpty) {
          final audioBytes = base64Decode(audioB64);
          await _player.play(BytesSource(audioBytes));
          await _player.setPlaybackRate(1.0);
        } else {
          Timer(const Duration(seconds: 4), () {
            if (mounted && _state == AssistantVoiceState.speaking) {
              _startListening();
            }
          });
        }
      } else if (event == 'interrupted') {
        if (mounted && _state != AssistantVoiceState.listening) {
          _startListening();
        }
      }
    } catch (e) {
      debugPrint('Error handling WS event: $e');
    }
  }

  Future<void> _fetchAndPlayGreeting() async {
    if (!mounted) return;
    setState(() {
      _state = AssistantVoiceState.connecting;
      _statusText = 'Axom AI Voice Assistant সাজু হৈছে...';
    });

    try {
      final base = await StorageService.loadApiBaseUrl();
      final cookie = await AuthService.getSessionCookie();

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'User-Agent': 'Dart/Flutter-AxomAI',
      };
      if (cookie != null) headers['Cookie'] = cookie;

      final res = await http
          .post(
            Uri.parse('$base/api/voice-assistant/greeting/'),
            headers: headers,
            body: jsonEncode({'user_name': _userName, 'voice': _selectedVoice}),
          )
          .timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final greetingText = data['greeting_text'] as String? ?? 'নমস্কাৰ!';
        final audioB64 = data['audio_base64'] as String?;

        if (mounted) {
          setState(() {
            _currentDialogue = greetingText;
            _statusText = 'Axom AI আপোনাৰ সৈতে কথা পাতিছে...';
            _state = AssistantVoiceState.speaking;
          });
        }

        if (audioB64 != null && audioB64.isNotEmpty) {
          final audioBytes = base64Decode(audioB64);
          await _player.play(BytesSource(audioBytes));
          await _player.setPlaybackRate(1.0);
        } else {
          // Fallback timer if no audio bytes
          Timer(const Duration(seconds: 4), () {
            if (mounted && _state == AssistantVoiceState.speaking) {
              _startListening();
            }
          });
        }
      } else {
        _onFallbackListening();
      }
    } catch (e) {
      _onFallbackListening();
    }
  }

  Future<void> _sendAudioViaHttp(File file) async {
    final base = await StorageService.loadApiBaseUrl();
    final cookie = await AuthService.getSessionCookie();

    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$base/api/voice-assistant/converse/'),
    );
    if (cookie != null) req.headers['Cookie'] = cookie;
    req.headers['User-Agent'] = 'Dart/Flutter-AxomAI';

    req.fields['user_name'] = _userName;
    req.fields['voice'] = _selectedVoice;
    req.fields['history'] = jsonEncode(_conversationHistory);
    req.files.add(
      await http.MultipartFile.fromPath(
        'audio',
        file.path,
        filename: 'voice.m4a',
      ),
    );

    final streamed = await req.send().timeout(const Duration(seconds: 35));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200) {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final userText = data['user_text'] as String? ?? '';
      final replyText = data['reply_text'] as String? ?? '';
      final audioB64 = data['audio_base64'] as String?;

      if (userText.isNotEmpty) {
        _conversationHistory.add({'role': 'user', 'text': userText});
      }
      if (replyText.isNotEmpty) {
        _conversationHistory.add({'role': 'assistant', 'text': replyText});
      }

      if (mounted) {
        setState(() {
          _currentDialogue = replyText;
          _statusText = 'Axom AI উত্তৰ দিছে...';
          _state = AssistantVoiceState.speaking;
        });
      }

      if (audioB64 != null && audioB64.isNotEmpty) {
        final audioBytes = base64Decode(audioB64);
        await _player.play(BytesSource(audioBytes));
        await _player.setPlaybackRate(1.0);
      } else {
        Timer(const Duration(seconds: 4), () {
          if (mounted && _state == AssistantVoiceState.speaking) {
            _startListening();
          }
        });
      }
    } else {
      _startListening();
    }
  }

  void _onFallbackListening() {
    if (!mounted) return;
    setState(() {
      _currentDialogue =
          'নমস্কাৰ $_userName ডাঙৰীয়া! কওকচোন মই আপোনাক কেনেকৈ সহায় কৰিব পাৰোঁ?';
      _statusText = 'কথা কওক (Listening...)';
    });
    _startListening();
  }

  // ─── START LISTENING (MIC + VAD) ─────────────────────────────
  Future<void> _startListening() async {
    if (_isMuted) {
      setState(() {
        _state = AssistantVoiceState.listening;
        _statusText = 'Microphone Muted';
      });
      return;
    }

    if (!await _recorder.hasPermission()) {
      setState(() {
        _statusText = 'Microphone permission needed';
      });
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      _recordingPath =
          '${dir.path}/voice_query_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 64000,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
          androidConfig: AndroidRecordConfig(
            audioSource: AndroidAudioSource.mic,
          ),
        ),
        path: _recordingPath!,
      );

      if (mounted) {
        setState(() {
          _state = AssistantVoiceState.listening;
          _statusText = 'মই শুনি আছোঁ, কওক...';
        });
      }

      // Voice Activity Detection (VAD) loop
      DateTime? quietSince;
      final DateTime startedAt = DateTime.now();
      bool heardSpeech = false;

      _amplitudeTimer?.cancel();
      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (
        timer,
      ) async {
        if (_state != AssistantVoiceState.listening) return;

        final amp = await _recorder.getAmplitude();
        final db = amp.current.isFinite ? amp.current : -90.0;
        final level = ((db + 60) / 45).clamp(0.0, 1.0);

        if (mounted) {
          setState(() {
            _audioLevel = level;
          });
        }

        final now = DateTime.now();
        // Sensitive speech threshold: -52 dB
        if (db > -52) {
          if (!heardSpeech && mounted) {
            setState(() {
              _statusText = 'মাত শুনি আছোঁ, কৈ যাওক...';
            });
          }
          heardSpeech = true;
          quietSince = null;
        } else if (heardSpeech) {
          quietSince ??= now;
        }

        // Auto-stop after 1.2s silence once speech is detected
        if (quietSince != null &&
            now.difference(quietSince!).inMilliseconds >= 750) {
          timer.cancel();
          _stopListeningAndProcess();
          return;
        }

        // Safety max duration: auto-process after 8.5 seconds
        if (now.difference(startedAt).inMilliseconds >= 35000 && heardSpeech) {
          timer.cancel();
          _stopListeningAndProcess();
          return;
        }
      });
    } catch (e) {
      debugPrint('Error starting recorder: $e');
    }
  }

  // ─── STOP RECORDING & SEND TO CONVERSE API ────────────────────
  Future<void> _stopListeningAndProcess() async {
    _amplitudeTimer?.cancel();
    _silenceTimer?.cancel();

    if (_state != AssistantVoiceState.listening) return;

    final path = await _recorder.stop() ?? _recordingPath;
    if (path == null) return;

    final file = File(path);
    if (!await file.exists() || await file.length() < 400) {
      // Empty noise or silence: seamlessly re-listen
      _startListening();
      return;
    }

    setState(() {
      _state = AssistantVoiceState.thinking;
      _statusText = 'ভাবি আছোঁ... (Thinking)';
      _audioLevel = 0.0;
    });

    try {
      final audioBytes = await file.readAsBytes();

      if (_useWebSocket &&
          _webSocket != null &&
          _webSocket!.readyState == WebSocket.open) {
        // Real-Time Sub-Second WebSocket Streaming!
        _webSocket!.add(audioBytes);
        _webSocket!.add(jsonEncode({'event': 'speech_end'}));
      } else {
        // Fallback to HTTP Multipart
        await _sendAudioViaHttp(file);
      }
    } catch (e) {
      _startListening();
    } finally {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  // ─── BARGE-IN (INTERRUPT AI SPEECH) ──────────────────────────

  void _toggleVoice() async {
    final newVoice = _selectedVoice == 'male' ? 'female' : 'male';
    setState(() {
      _selectedVoice = newVoice;
    });
    await StorageService.saveVoice(newVoice);

    // Reconnect WebSocket with new voice
    try {
      _wsSub?.cancel();
      _webSocket?.close();
    } catch (_) {}
    _connectWebSocketOrFallback();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newVoice == 'male'
              ? 'পুৰুষ কণ্ঠ (Male Energetic) সক্ৰিয় হ’ল'
              : 'মহিলা কণ্ঠ সক্ৰিয় হ’ল',
        ),
        duration: const Duration(milliseconds: 1400),
        backgroundColor: const Color(0xFF1F2937),
      ),
    );
  }

  void _bargeInInterrupt() async {
    _stopSpeakingWaveTimer();
    _audioQueue.clear();
    _isPlayingAudioQueue = false;
    try {
      await _player.stop();
    } catch (_) {}

    if (_useWebSocket &&
        _webSocket != null &&
        _webSocket!.readyState == WebSocket.open) {
      _webSocket!.add(jsonEncode({'event': 'interrupt'}));
    }

    if (mounted) {
      setState(() {
        _state = AssistantVoiceState.listening;
        _statusText = '?? ???? ????, ???... (Listening)';
        _audioLevel = 0.0;
      });
      _startListening();
    }
  }

  // ─── TOGGLE MUTE ─────────────────────────────────────────────
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    if (_isMuted) {
      _recorder.cancel();
      _amplitudeTimer?.cancel();
      setState(() {
        _statusText = 'Microphone Muted';
        _audioLevel = 0;
      });
    } else {
      _startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16), // Dark immersive background
      body: SafeArea(
        child: Stack(
          children: [
            // Ambient Radial Gradient Aura
            Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale =
                      1.0 +
                      (_pulseController.value * 0.15) +
                      (_audioLevel * 0.25);
                  Color auraColor = const Color(0xFF10B981); // Emerald
                  if (_state == AssistantVoiceState.speaking) {
                    auraColor = const Color(0xFF8B5CF6); // Violet
                  } else if (_state == AssistantVoiceState.thinking) {
                    auraColor = const Color(0xFFF59E0B); // Amber
                  }

                  return Container(
                    width: 320 * scale,
                    height: 320 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          auraColor.withValues(alpha: 0.35),
                          auraColor.withValues(alpha: 0.12),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Top Header Bar
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // App Badge & Status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _state == AssistantVoiceState.listening
                                ? const Color(0xFF10B981)
                                : (_state == AssistantVoiceState.speaking
                                      ? const Color(0xFF8B5CF6)
                                      : const Color(0xFFF59E0B)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Axom AI • $_userName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Voice Mode Toggle Button
                  GestureDetector(
                    onTap: _toggleVoice,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _selectedVoice == 'male'
                                ? Icons.male_rounded
                                : Icons.female_rounded,
                            color: Colors.lightBlueAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _selectedVoice == 'male'
                                ? 'পুৰুষ (Energetic)'
                                : 'মহিলা',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Close / End Voice Call Button
                  GestureDetector(
                    onTap: () {
                      _player.stop();
                      _recorder.cancel();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.withValues(alpha: 0.2),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Center Interactive Fluid Voice Orb
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tap Orb to Barge-In or Send
                  GestureDetector(
                    onTap: _bargeInInterrupt,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _pulseController,
                        _waveController,
                      ]),
                      builder: (context, child) {
                        return CustomPaint(
                          painter: VoiceOrbPainter(
                            pulse: _pulseController.value,
                            wave: _waveController.value,
                            audioLevel: _audioLevel,
                            state: _state,
                          ),
                          child: const SizedBox(width: 200, height: 200),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Dynamic State Subtitle
                  Text(
                    _statusText,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Subtitles Text Box (Live Spoken Dialogue)
                  if (_showSubtitles && _currentDialogue.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _currentDialogue.isNotEmpty ? 1.0 : 0.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            _currentDialogue,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFF1F5F9),
                              fontSize: 14,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Action Controls
            Positioned(
              bottom: 28,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute / Unmute Button
                  _buildControlCircle(
                    icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    active: _isMuted,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    onTap: _toggleMute,
                  ),

                  // Large Center Tap to Speak / Barge-in Button
                  GestureDetector(
                    onTap: _bargeInInterrupt,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.4),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _state == AssistantVoiceState.speaking
                            ? Icons.pause_rounded
                            : (_state == AssistantVoiceState.thinking
                                  ? Icons.hourglass_top_rounded
                                  : Icons.graphic_eq_rounded),
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),

                  // Subtitles Toggle
                  _buildControlCircle(
                    icon: _showSubtitles
                        ? Icons.subtitles_rounded
                        : Icons.subtitles_off_rounded,
                    active: !_showSubtitles,
                    label: 'Subtitles',
                    onTap: () {
                      setState(() => _showSubtitles = !_showSubtitles);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlCircle({
    required IconData icon,
    required bool active,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? Colors.redAccent.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.1),
              border: Border.all(
                color: active
                    ? Colors.redAccent.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CUSTOM PAINTER FOR CHATGPT / GEMINI LIVE FLUID ORB ─────────
class VoiceOrbPainter extends CustomPainter {
  final double pulse;
  final double wave;
  final double audioLevel;
  final AssistantVoiceState state;

  VoiceOrbPainter({
    required this.pulse,
    required this.wave,
    required this.audioLevel,
    required this.state,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) * 0.72;

    // Colors according to state
    Color primary = const Color(0xFF10B981); // Emerald
    Color secondary = const Color(0xFF06B6D4); // Cyan
    if (state == AssistantVoiceState.speaking) {
      primary = const Color(0xFF8B5CF6); // Violet
      secondary = const Color(0xFFEC4899); // Pink
    } else if (state == AssistantVoiceState.thinking) {
      primary = const Color(0xFFF59E0B); // Amber
      secondary = const Color(0xFFEF4444); // Red
    }

    // Outer Glow Rings
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primary.withValues(alpha: 0.7),
          secondary.withValues(alpha: 0.3),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.5))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    canvas.drawCircle(
      center,
      radius * (1.0 + (pulse * 0.1) + (audioLevel * 0.25)),
      glowPaint,
    );

    // Inner Fluid Sphere
    final orbPaint = Paint()
      ..shader = SweepGradient(
        colors: [primary, secondary, primary],
        transform: GradientRotation(wave * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, orbPaint);

    // Dynamic Sound Waves inside Orb
    if (state == AssistantVoiceState.speaking ||
        state == AssistantVoiceState.listening) {
      final wavePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final barCount = 5;
      final spacing = 12.0;
      final startX = center.dx - ((barCount - 1) * spacing) / 2;

      for (int i = 0; i < barCount; i++) {
        final x = startX + (i * spacing);
        final factor = math.sin((wave * 4 * math.pi) + (i * 0.8));
        final height = 14 + (28 * (audioLevel + 0.3) * factor.abs());

        canvas.drawLine(
          Offset(x, center.dy - height / 2),
          Offset(x, center.dy + height / 2),
          wavePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant VoiceOrbPainter oldDelegate) => true;
}
