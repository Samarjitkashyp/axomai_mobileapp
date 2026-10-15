import 'package:axomai_app/services/convert_intent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('conversion requests are caught', () {
    for (final t in [
      'convert this file',
      'Please convert my PDF to Word',
      'pdf to word',
      'JPG to PDF kar do',
      'I need a converter for docx',
      'convert kar do',
      'change this word 2 pdf',
    ]) {
      expect(isFileConvertRequest(t), isTrue, reason: t);
    }
  });

  test('normal questions are not caught', () {
    for (final t in [
      'summarise this document',
      'What is in this image?',
      'Tell me about Assam',
      'convertible car price',
      '',
    ]) {
      expect(isFileConvertRequest(t), isFalse, reason: t);
    }
  });

  test('the message is plain English and has the tools link', () {
    expect(convertNotInAppMessage, contains('https://aiaxom.co.in/tools'));
    expect(RegExp(r'[^\x00-\x7F]').hasMatch(convertNotInAppMessage), isFalse);
  });
}
