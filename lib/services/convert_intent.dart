/// File conversion is not in the app yet; the website has it. These decide when to point the user there.
const String convertToolsUrl = 'https://aiaxom.co.in/tools';

const String convertNotInAppMessage =
    'File conversion is not available in the app yet. '
    'Please use our website instead: [aiaxom.co.in/tools]($convertToolsUrl). '
    'Open it in your browser, upload your file and convert it there.';

final RegExp _verb = RegExp(
  r'\b(convert|converts|converting|converted|conversion|converter)\b|কনভাৰ্ট|রূপান্তৰ|कन्वर्ट|बदलो',
  caseSensitive: false,
);

const String _formats = r'(pdf|word|docx?|jpe?g|png|webp|excel|xlsx?|ppt|pptx|txt|text)';

final RegExp _formatToFormat = RegExp(
  '\\b$_formats\\s*(to|into|2|->|→)\\s*$_formats\\b',
  caseSensitive: false,
);

/// True when the message asks to convert a file (also "pdf to word" and the like).
bool isFileConvertRequest(String text) {
  final t = text.trim();
  if (t.isEmpty) return false;
  return _verb.hasMatch(t) || _formatToFormat.hasMatch(t);
}
