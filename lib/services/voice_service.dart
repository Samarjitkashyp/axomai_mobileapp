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

  static const int firstPiece = 60;
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
    return {
      if (cookie != null) 'Cookie': cookie,
      'User-Agent': 'Dart/Flutter-AxomAI',
    };
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
    } catch (e) {
      if (run == _run) onError?.call('Could not play the voice (${e.runtimeType}). Check your internet and try again.');
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
  /// How loud the voice is right now, 0..1 (drives the listening animation).
  final ValueNotifier<double> level = ValueNotifier<double>(0);
  Timer? _poll;
  String? _path;

  static const int maxSeconds = 40;
  static const int calibrateMs = 600; // the first moments set the room's (and the mic's) own noise level
  static const double speechAboveNoiseDb = 9; // speech is this much louder than that noise level
  static const double minSpeechDb = -52; // the speech threshold never goes below / above these,
  static const double maxSpeechDb = -32; // whatever the mic (a headset mic is quiet, a phone mic is loud)
  static const int silenceStopMs = 1200; // stop after 1.2s quiet once speech was heard (matches web speed)

  Future<bool> hasMicPermission() => _recorder.hasPermission();

  /// Starts recording. [onAutoStop] is called when the recording ended by itself (silence or the time limit).
  Future<bool> startRecording({required VoidCallback onAutoStop}) async {
    await stop(); // do not record the voice reply
    if (!await _recorder.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/axom_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 96000, // 32 kbps smeared the Assamese sounds
        autoGain: true, // a quiet (headset) mic is brought up
        echoCancel: true,
        noiseSuppress: true,
        androidConfig: AndroidRecordConfig(audioSource: AndroidAudioSource.voiceRecognition),
      ),
      path: _path!,
    );
    recording.value = true;
    final started = DateTime.now();
    var heardSpeech = false;
    DateTime? quietSince;
    var noiseFloor = 0.0; // the quietest moment of the first listen: speech in it does not raise it
    var calibrating = true;
    var speechDb = minSpeechDb;
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(milliseconds: 100), (t) async {
      if (!recording.value) return;
      final amp = await _recorder.getAmplitude();
      final db = amp.current.isFinite ? amp.current : -90.0;
      level.value = ((db - (speechDb - 13)) / 45).clamp(0.0, 1.0);
      final now = DateTime.now();
      if (now.difference(started).inMilliseconds < calibrateMs) {
        noiseFloor = calibrating ? db : (db < noiseFloor ? db : noiseFloor);
        calibrating = false;
        speechDb = (noiseFloor + speechAboveNoiseDb).clamp(minSpeechDb, maxSpeechDb);
        if (db > speechDb) heardSpeech = true; // already talking while it listened to the room
        return;
      }
      if (db > speechDb) {
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
    level.value = 0;
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
    level.value = 0;
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
      var text = (data['text'] as String? ?? '').trim();
      if (text.isEmpty || isGibberish(text)) {
        throw VoiceException('I did not catch any words. Please speak a little closer and try again.');
      }
      if (language == 'assamese') {
        text = purifyAssamese(text);
      }
      return text;
    } on VoiceException {
      rethrow;
    } on TimeoutException {
      throw VoiceException('That took too long. Check your internet and try again.');
    } catch (e) {
      throw VoiceException('Voice typing failed (${e.runtimeType}). Check your internet and try again.');
    } finally {
      transcribing.value = false;
      _deleteTemp();
    }
  }

  /// Transcribes a user-selected audio file (mp3, m4a, wav, etc.) via Axom AI STT
  Future<String> transcribeAudioFile({required String filePath, required String language}) async {
    transcribing.value = true;
    try {
      final file = File(filePath);
      if (!await file.exists() || await file.length() < 500) {
        throw VoiceException('Selected audio file is empty or missing.');
      }
      if (await file.length() > 25 * 1024 * 1024) {
        throw VoiceException('Audio file exceeds the 25MB limit.');
      }
      final base = await StorageService.loadApiBaseUrl();
      final req = http.MultipartRequest('POST', Uri.parse('$base/api/stt/'));
      req.headers.addAll(await _headers());
      req.fields['language'] = language;
      final ext = filePath.split('.').last.toLowerCase();
      req.files.add(await http.MultipartFile.fromPath('audio', filePath, filename: 'voice.$ext'));
      final streamed = await req.send().timeout(const Duration(seconds: 90));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode != 200) {
        throw VoiceException(_friendly(streamed.statusCode, body, listening: false));
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      var text = (data['text'] as String? ?? '').trim();
      if (text.isEmpty || isGibberish(text)) {
        throw VoiceException('Could not detect speech in the uploaded audio.');
      }
      if (language == 'assamese') {
        text = purifyAssamese(text);
      }
      return text;
    } on VoiceException {
      rethrow;
    } on TimeoutException {
      throw VoiceException('Speech processing timed out. Please try a shorter audio clip.');
    } catch (e) {
      throw VoiceException('Audio transcription error: ${e.toString()}');
    } finally {
      transcribing.value = false;
    }
  }

  // ─── Assamese Script & Hallucination Sanitizer ───────────────
  static const _hallucinations = {
    'thank you',
    'thanks for watching',
    'thank you for watching',
    'you',
    'bye',
    'bye bye',
    'okay',
    'the end',
    'no_speech',
  };

  static bool isGibberish(String text) {
    if (text.isEmpty) return true;
    final t = text.trim().toLowerCase().replaceAll(RegExp(r'[.!?,]'), '');
    if (_hallucinations.contains(t)) return true;
    final words = text.split(RegExp(r'\s+'));
    if (words.isNotEmpty &&
        words.every((w) {
          final stripped = w.replaceAll(RegExp(r'[^a-zA-Z]'), '');
          return stripped.length >= 3 &&
              !stripped.contains(RegExp(r'[aeiouyAEIOUY]')) &&
              RegExp(r'^[a-zA-Z]+$').hasMatch(stripped);
        })) {
      return true;
    }
    return false;
  }

  static String purifyAssamese(String text) {
    if (text.isEmpty) return text;
    var s = text.replaceAll('\u09B0', '\u09F0'); // Bengali 'র' -> Assamese 'ৰ'
    s = s
        .replaceAll('কোবা', 'কোৱা')
        .replaceAll('খোবা', 'খোৱা')
        .replaceAll('যোবা', 'যোৱা')
        .replaceAll('হোবা', 'হোৱা')
        .replaceAll('লোবা', 'লোৱা')
        .replaceAll('শোবা', 'শোৱা')
        .replaceAll('দিবা', 'দিৱা')
        .replaceAll('নহবা', 'নহ’বা')
        .replaceAll(RegExp(r'\bহব\b'), 'হ’ব')
        .replaceAll(RegExp(r'\bনহব\b'), 'নহ’ব');
    s = s.replaceAll(RegExp(r'\s+([।?!,])'), r'$1');
    return s.trim();
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
