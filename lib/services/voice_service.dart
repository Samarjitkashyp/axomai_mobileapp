import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'auth_service.dart';
import 'storage_service.dart';

/// Voice typing (speech to text) and voice reply (text to speech) against the Axom AI server.
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  // ─── Voice reply ─────────────────────────────────────────────
  /// The id of the message that is being read aloud (null when silent).
  final ValueNotifier<String?> speakingId = ValueNotifier<String?>(null);
  final AudioPlayer _player = AudioPlayer();
  int _run = 0;

  static const int firstPiece = 90;
  static const int nextPiece = 150;
  static const int maxPiece = 380;

  /// Markdown removed and the answer cut into pieces: a short first one (the first sound comes sooner), then about 150 characters.
  static List<String> splitForVoice(String markdown) {
    var t = markdown
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m.group(1) ?? '')
        .replaceAll(RegExp(r'https?://\S+'), ' ')
        .replaceAll(RegExp(r'[#*`>_|~]'), ' ')
        .replaceAll(RegExp(r'^\s*[-+]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
    if (t.isEmpty) return [];
    final sentences = <String>[];
    for (final line in t.split(RegExp(r'\n+'))) {
      final parts = line.split(RegExp(r'(?<=[।.!?;])\s+'));
      for (final p in parts) {
        final s = p.trim();
        if (s.isNotEmpty) sentences.add(s);
      }
    }
    final flat = <String>[];
    for (final s in sentences) {
      flat.addAll(_cut(s, nextPiece));
    }
    final out = <String>[];
    var buf = '';
    for (final s in flat) {
      final limit = out.isEmpty ? firstPiece : nextPiece;
      if (buf.isEmpty) {
        buf = s;
      } else if (out.isNotEmpty && buf.length + 1 + s.length <= limit) {
        buf = '$buf $s';
      } else {
        out.add(buf);
        buf = s;
      }
      if (out.isEmpty && buf.length >= firstPiece * 0.6) {
        out.add(buf);
        buf = '';
      }
    }
    if (buf.isNotEmpty) out.add(buf);
    return out.expand((p) => _cut(p, maxPiece)).toList();
  }

  static List<String> _cut(String s, int size) {
    if (s.length <= size) return [s];
    final out = <String>[];
    var rest = s;
    while (rest.length > size) {
      var at = rest.lastIndexOf(RegExp(r'[,،、 ]'), size);
      if (at < size ~/ 3) at = size;
      out.add(rest.substring(0, at).trim());
      rest = rest.substring(at).trim();
    }
    if (rest.isNotEmpty) out.add(rest);
    return out;
  }

  Future<Map<String, String>> _headers() async {
    final cookie = await AuthService.getSessionCookie();
    return {if (cookie != null) 'Cookie': cookie};
  }

  /// Fetches the audio of one piece. Returns bytes, or throws [VoiceException] with a message fit for the user.
  Future<Uint8List> _fetch(String text, String voice) async {
    final base = await StorageService.loadApiBaseUrl();
    final r = await http
        .post(Uri.parse('$base/api/tts/speak/'),
            headers: {...await _headers(), 'Content-Type': 'application/json'},
            body: jsonEncode({'text': text, 'voice': voice}))
        .timeout(const Duration(seconds: 40));
    if (r.statusCode == 200) return r.bodyBytes;
    throw VoiceException(_friendly(r.statusCode, r.body, listening: true));
  }


  /// Reads the message aloud, piece by piece (the next piece is fetched while the last one plays). Tapping again stops it.
  Future<void> speak(String id, String markdown, {void Function(String message)? onError}) async {
    if (speakingId.value == id) {
      await stop();
      return;
    }
    await stop();
    final run = ++_run;
    final pieces = splitForVoice(markdown);
    if (pieces.isEmpty) return;
    speakingId.value = id;
    final voice = await StorageService.loadVoice();
    final speed = await StorageService.loadVoiceSpeed();
    try {
      Future<Uint8List> next = _fetch(pieces.first, voice);
      for (var i = 0; i < pieces.length; i++) {
        final bytes = await next;
        if (run != _run) return;
        if (i + 1 < pieces.length) next = _fetch(pieces[i + 1], voice);
        final done = Completer<void>();
        final sub = _player.onPlayerComplete.listen((_) {
          if (!done.isCompleted) done.complete();
        });
        await _player.setPlaybackRate(speed);
        await _player.play(BytesSource(bytes));
        await done.future.timeout(const Duration(minutes: 2), onTimeout: () {});
        await sub.cancel();
        if (run != _run) return;
      }
    } on VoiceException catch (e) {
      if (run == _run) onError?.call(e.message);
    } catch (_) {
      if (run == _run) onError?.call('Could not play the voice. Check your internet and try again.');
    } finally {
      if (run == _run) speakingId.value = null;
    }
  }

  Future<void> stop() async {
    _run++;
    speakingId.value = null;
    try {
      await _player.stop();
    } catch (_) {}
  }

  // ─── Voice typing ────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  final ValueNotifier<bool> recording = ValueNotifier<bool>(false);
  final ValueNotifier<bool> transcribing = ValueNotifier<bool>(false);
  Timer? _poll;
  String? _path;

  static const int maxSeconds = 40;
  static const double silenceDb = -42; // quieter than this counts as silence
  static const int silenceStopMs = 2200; // stop after this much quiet once speech was heard

  Future<bool> hasMicPermission() => _recorder.hasPermission();

  /// Starts recording. [onAutoStop] is called when the recording ended by itself (silence or the time limit).
  Future<bool> startRecording({required VoidCallback onAutoStop}) async {
    await stop(); // do not record the voice reply
    if (!await _recorder.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/axom_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1, bitRate: 32000),
      path: _path!,
    );
    recording.value = true;
    final started = DateTime.now();
    var heardSpeech = false;
    DateTime? quietSince;
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(milliseconds: 150), (t) async {
      if (!recording.value) return;
      final amp = await _recorder.getAmplitude();
      final now = DateTime.now();
      if (amp.current > silenceDb + 8) {
        heardSpeech = true;
        quietSince = null;
      } else if (heardSpeech) {
        quietSince ??= now;
      }
      final tooLong = now.difference(started).inSeconds >= maxSeconds;
      final silent = quietSince != null && now.difference(quietSince!).inMilliseconds >= silenceStopMs;
      if (tooLong || silent) onAutoStop();
    });
    return true;
  }

  Future<void> cancelRecording() async {
    _poll?.cancel();
    recording.value = false;
    try {
      await _recorder.cancel();
    } catch (_) {}
    _deleteTemp();
  }

  void _deleteTemp() {
    final p = _path;
    _path = null;
    if (p != null) {
      try {
        File(p).deleteSync();
      } catch (_) {}
    }
  }

  /// Stops the recording and returns the text the server heard. Throws [VoiceException] with a friendly message.
  Future<String> finishRecording({required String language}) async {
    _poll?.cancel();
    if (!recording.value) return '';
    recording.value = false;
    final path = await _recorder.stop() ?? _path;
    if (path == null) return '';
    transcribing.value = true;
    try {
      final file = File(path);
      if (!await file.exists() || await file.length() < 1500) {
        throw VoiceException('I did not hear anything. Tap the mic and speak again.');
      }
      if (await file.length() > 3 * 1024 * 1024) {
        throw VoiceException('That recording is too long. Please speak a shorter message.');
      }
      final base = await StorageService.loadApiBaseUrl();
      final req = http.MultipartRequest('POST', Uri.parse('$base/api/stt/'));
      req.headers.addAll(await _headers());
      req.fields['language'] = language;
      req.files.add(await http.MultipartFile.fromPath('audio', path, filename: 'voice.m4a'));
      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode != 200) {
        throw VoiceException(_friendly(streamed.statusCode, body, listening: false));
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final text = (data['text'] as String? ?? '').trim();
      if (text.isEmpty) throw VoiceException('I did not catch that. Please try again.');
      return text;
    } on VoiceException {
      rethrow;
    } on TimeoutException {
      throw VoiceException('That took too long. Check your internet and try again.');
    } catch (_) {
      throw VoiceException('Voice typing failed. Check your internet and try again.');
    } finally {
      transcribing.value = false;
      _deleteTemp();
    }
  }

  // ─── Messages ────────────────────────────────────────────────
  /// A message fit for the user for a server answer to a voice request (limits, plan, server off).
  static String friendlyLimit(int status, String body) => _friendly(status, body, listening: false);

  static String _friendly(int status, String body, {required bool listening}) {
    String? serverText;
    try {
      final d = jsonDecode(body);
      if (d is Map && d['error'] is String) serverText = d['error'] as String;
    } catch (_) {}
    final what = listening ? 'Voice reply' : 'Voice typing';
    switch (status) {
      case 429:
        return '$what limit reached for today. It will work again tomorrow, or upgrade your plan for more.';
      case 503:
        return '$what is switched off right now. Please try again later.';
      case 401:
      case 403:
        return 'Please log in again to use ${what.toLowerCase()}.';
      case 413:
        return listening ? 'That answer is too long to read aloud.' : 'That recording is too long.';
      case 422:
        return listening ? 'I could not read that text aloud.' : 'I could not understand that recording.';
      default:
        return serverText ?? '$what is busy ($status). Please try again shortly.';
    }
  }
}

class VoiceException implements Exception {
  final String message;
  VoiceException(this.message);
  @override
  String toString() => message;
}
