import 'package:axomai_app/services/voice_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('markdown is removed and pieces stay short', () {
    final pieces = VoiceService.splitForVoice(
        '# Title\n**Hello** world. This is `code` and [a link](http://x.y). ' * 12);
    expect(pieces, isNotEmpty);
    expect(pieces.first.length, lessThanOrEqualTo(VoiceService.maxPiece));
    for (final p in pieces) {
      expect(p.length, lessThanOrEqualTo(VoiceService.maxPiece));
      expect(p.contains('http'), isFalse);
      expect(p.contains('**'), isFalse);
    }
  });

  test('empty and code-only text give no pieces', () {
    expect(VoiceService.splitForVoice(''), isEmpty);
    expect(VoiceService.splitForVoice('```\nprint(1)\n```'), isEmpty);
  });

  test('server limit answers become friendly messages', () {
    expect(VoiceService.friendlyLimit(429, '{}'), contains('limit'));
    expect(VoiceService.friendlyLimit(503, '{}'), contains('switched off'));
  });
}
