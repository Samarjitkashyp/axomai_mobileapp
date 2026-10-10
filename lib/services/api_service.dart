import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import 'storage_service.dart';
import 'auth_service.dart';

class FileConversionResult {
  final bool success;
  final String? filename;
  final String? outputName;
  final String? downloadUrl;
  final String? fileSize;
  final String? message;
  final String? error;
  final bool isBatch;
  final int count;

  FileConversionResult({
    required this.success,
    this.filename,
    this.outputName,
    this.downloadUrl,
    this.fileSize,
    this.message,
    this.error,
    this.isBatch = false,
    this.count = 1,
  });
}

class ChatResponseResult {
  final String text;
  final String model;
  final bool webSearch;
  final List<WebSource> sources;
  final bool fromDatabase;
  final String? error;

  ChatResponseResult({
    required this.text,
    this.model = 'Axom AI',
    this.webSearch = false,
    this.sources = const [],
    this.fromDatabase = false,
    this.error,
  });
}

class ApiService {
  // ─── 1. CHAT & STREAMING ───────────────────────────────────────────
  static Future<ChatResponseResult> sendMessage({
    required String prompt,
    required bool webSearch,
    required String sessionId,
    required List<ChatMessage> history,
    void Function(String tokenChunk)? onTokenReceived,
    String? language,
  }) async {
    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/chat/');

    final recentHistory = history.length > 20
        ? history.sublist(history.length - 20)
        : history;

    final requestBody = jsonEncode({
      'prompt': prompt,
      'web_search': webSearch,
      'session_id': sessionId,
      'language': language ?? 'assamese',
      'history': recentHistory
          .map((m) => {'role': m.role, 'text': m.text})
          .toList(),
    });

    try {
      final sessionCookie = await AuthService.getSessionCookie();
      final request = http.Request('POST', url);
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/event-stream, text/plain, */*',
      });
      if (sessionCookie != null && sessionCookie.isNotEmpty) {
        request.headers['Cookie'] = sessionCookie;
      }
      request.body = requestBody;

      final client = http.Client();
      final streamedResponse = await client.send(request);

      final isStreamingEngine = streamedResponse.headers.containsKey('x-engine') ||
          streamedResponse.headers['content-type']?.contains('text/plain') == true ||
          streamedResponse.headers['content-type']?.contains('event-stream') == true;

      final fromDatabase =
          streamedResponse.headers['x-from-database'] == 'true';

      if (streamedResponse.statusCode == 200 && isStreamingEngine) {
        final StringBuffer fullTextBuffer = StringBuffer();

        await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
          if (chunk.isNotEmpty) {
            fullTextBuffer.write(chunk);
            if (onTokenReceived != null) {
              onTokenReceived(chunk);
            }
          }
        }

        final fullText = fullTextBuffer.toString();
        if (fullText.trim().isEmpty) {
          return ChatResponseResult(
            text: '',
            error: 'No response received from Axom AI. Please try again.',
          );
        }

        return ChatResponseResult(
          text: fullText,
          model: 'Axom AI',
          webSearch: false,
          fromDatabase: fromDatabase,
        );
      } else {
        final responseBody =
            await streamedResponse.stream.transform(utf8.decoder).join();

        if (streamedResponse.statusCode == 200) {
          try {
            final data = jsonDecode(responseBody) as Map<String, dynamic>;
            final responseText = data['response'] as String? ?? '';
            final model = data['model'] as String? ?? 'Axom AI';
            final isWebSearch = data['web_search'] as bool? ?? false;
            final fromDb = data['from_database'] as bool? ?? false;

            var rawSources = data['sources'] as List<dynamic>? ?? [];
            List<WebSource> sources = rawSources
                .map((s) => s is Map<String, dynamic>
                    ? WebSource.fromJson(s)
                    : WebSource(title: s.toString(), uri: s.toString()))
                .toList();

            return ChatResponseResult(
              text: responseText,
              model: model,
              webSearch: isWebSearch,
              sources: sources,
              fromDatabase: fromDb,
            );
          } catch (e) {
            return ChatResponseResult(
              text: responseBody,
              model: 'Axom AI',
            );
          }
        } else if (streamedResponse.statusCode == 403) {
          return ChatResponseResult(
            text: '',
            error: 'Session expired or not authorized. Please log in again.',
          );
        } else if (streamedResponse.statusCode == 429) {
          return ChatResponseResult(
            text: '',
            error: 'Rate limit reached. Please wait a moment before asking again.',
          );
        } else {
          return ChatResponseResult(
            text: '',
            error: 'Server busy (${streamedResponse.statusCode}). Please try again shortly.',
          );
        }
      }
    } catch (e) {
      return ChatResponseResult(
        text: '',
        error: 'Network error: $e',
      );
    }
  }

  // ─── 2. ASSAMESE TRANSLITERATION ────────────────────────────────────
  static Future<String> transliterateAssamese(String text) async {
    if (text.trim().isEmpty) return text;
    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/chat/transliterate/');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['transliterated'] ?? data['result'] ?? text;
      }
    } catch (_) {}
    return text;
  }

  // ─── 3. CHAT OCR & IMAGE UNDERSTANDING ─────────────────────────────
  static Future<Map<String, dynamic>> performOCR(PlatformFile file) async {
    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/chat/ocr/');

    try {
      final request = http.MultipartRequest('POST', url);
      final sessionCookie = await AuthService.getSessionCookie();
      if (sessionCookie != null) request.headers['Cookie'] = sessionCookie;

      if (file.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name));
      } else if (file.path != null) {
        request.files.add(await http.MultipartFile.fromPath('file', file.path!, filename: file.name));
      }

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final respStr = await streamed.stream.bytesToString();
      return jsonDecode(respStr) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── 4. EXPORT CHAT TO DOCX ────────────────────────────────────────
  static Future<Map<String, dynamic>> exportChatDocx({
    required String title,
    required List<Map<String, String>> messages,
  }) async {
    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/chat/export-docx/');

    try {
      final sessionCookie = await AuthService.getSessionCookie();
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (sessionCookie != null) 'Cookie': sessionCookie,
        },
        body: jsonEncode({
          'title': title,
          'messages': messages,
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String downloadUrl = data['download_url'] ?? '';
        if (downloadUrl.startsWith('/')) downloadUrl = '$baseUrl$downloadUrl';
        return {'success': true, 'download_url': downloadUrl, 'filename': data['filename']};
      }
      return {'success': false, 'error': 'Export failed (${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── 5. AI NOTES GENERATOR SUITE ────────────────────────────────────
  static Future<Map<String, dynamic>> analyzeNotesDoc({
    PlatformFile? file,
    String? textContent,
  }) async {
    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/ai-notes/analyze/');

    try {
      final request = http.MultipartRequest('POST', url);
      final sessionCookie = await AuthService.getSessionCookie();
      if (sessionCookie != null) request.headers['Cookie'] = sessionCookie;

      if (file != null) {
        if (file.bytes != null) {
          request.files.add(http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name));
        } else if (file.path != null) {
          request.files.add(await http.MultipartFile.fromPath('file', file.path!, filename: file.name));
        }
      }
      if (textContent != null) {
        request.fields['text'] = textContent;
      }

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final respStr = await streamed.stream.bytesToString();
      return jsonDecode(respStr) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> generateNotes({
    PlatformFile? file,
    String? topic,
    String? customInstructions,
    String language = 'English',
    String level = 'College / Degree',
    String style = 'Comprehensive',
  }) async {
    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/ai-notes/generate/');

    try {
      final request = http.MultipartRequest('POST', url);
      final sessionCookie = await AuthService.getSessionCookie();
      if (sessionCookie != null) request.headers['Cookie'] = sessionCookie;

      request.fields['language'] = language;
      request.fields['level'] = level;
      request.fields['style'] = style;
      if (topic != null) request.fields['topic'] = topic;
      if (customInstructions != null) request.fields['instructions'] = customInstructions;

      if (file != null) {
        if (file.bytes != null) {
          request.files.add(http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name));
        } else if (file.path != null) {
          request.files.add(await http.MultipartFile.fromPath('file', file.path!, filename: file.name));
        }
      }

      final streamed = await request.send().timeout(const Duration(seconds: 120));
      final respStr = await streamed.stream.bytesToString();
      return jsonDecode(respStr) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> refineNotes({
    required String action,
    required String currentNotes,
    String? customPrompt,
  }) async {
    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/ai-notes/refine/');

    try {
      final sessionCookie = await AuthService.getSessionCookie();
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (sessionCookie != null) 'Cookie': sessionCookie,
        },
        body: jsonEncode({
          'action': action,
          'notes': currentNotes,
          if (customPrompt != null) 'custom_prompt': customPrompt,
        }),
      ).timeout(const Duration(seconds: 90));

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> askNotesDoubt({
    required String question,
    required String notesContext,
  }) async {
    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/ai-notes/ask/');

    try {
      final sessionCookie = await AuthService.getSessionCookie();
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (sessionCookie != null) 'Cookie': sessionCookie,
        },
        body: jsonEncode({
          'question': question,
          'context': notesContext,
        }),
      ).timeout(const Duration(seconds: 60));

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> generateStudyTools({
    required String toolType, // 'flashcards', 'quiz', 'mindmap', 'exam_qa'
    required String notesContent,
  }) async {
    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/ai-notes/study-tools/');

    try {
      final sessionCookie = await AuthService.getSessionCookie();
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (sessionCookie != null) 'Cookie': sessionCookie,
        },
        body: jsonEncode({
          'tool_type': toolType,
          'notes': notesContent,
        }),
      ).timeout(const Duration(seconds: 90));

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> exportNotesDocx({
    required String title,
    required String notesMarkdown,
  }) async {
    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/ai-notes/export-docx/');

    try {
      final sessionCookie = await AuthService.getSessionCookie();
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (sessionCookie != null) 'Cookie': sessionCookie,
        },
        body: jsonEncode({
          'title': title,
          'notes': notesMarkdown,
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String downloadUrl = data['download_url'] ?? '';
        if (downloadUrl.startsWith('/')) downloadUrl = '$baseUrl$downloadUrl';
        return {'success': true, 'download_url': downloadUrl, 'filename': data['filename']};
      }
      return {'success': false, 'error': 'Export failed (${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── 6. UNIVERSAL FILE CONVERTER ────────────────────────────────────
  static Future<FileConversionResult> convertFile({
    required List<PlatformFile> files,
    String target = 'pdf',
  }) async {
    if (files.isEmpty) {
      return FileConversionResult(
        success: false,
        error: 'No file selected for conversion.',
      );
    }

    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/convert-file/');

    try {
      final request = http.MultipartRequest('POST', url);
      request.fields['target'] = target;
      request.headers['Accept'] = 'application/json, */*';

      final sessionCookie = await AuthService.getSessionCookie();
      if (sessionCookie != null && sessionCookie.isNotEmpty) {
        request.headers['Cookie'] = sessionCookie;
      }

      final isBatch = files.length > 1;
      for (final file in files) {
        final fieldName = isBatch ? 'files' : 'file';
        if (file.bytes != null) {
          request.files.add(http.MultipartFile.fromBytes(
            fieldName,
            file.bytes!,
            filename: file.name,
          ));
        } else if (file.path != null) {
          request.files.add(await http.MultipartFile.fromPath(
            fieldName,
            file.path!,
            filename: file.name,
          ));
        }
      }

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 120));
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        if (data['success'] == true) {
          String rawDownload = data['download_url'] ?? '';
          if (rawDownload.startsWith('/')) {
            rawDownload = '$baseUrl$rawDownload';
          }
          return FileConversionResult(
            success: true,
            filename: data['filename'],
            outputName: data['output_name'] ??
                (isBatch
                    ? 'converted_${files.length}_documents.zip'
                    : '${files[0].name.replaceAll(RegExp(r'\.[^/.]+$'), '')}.$target'),
            downloadUrl: rawDownload,
            fileSize: data['file_size'] ??
                (isBatch ? 'ZIP Archive' : target.toUpperCase()),
            message: data['message'],
            isBatch: isBatch,
            count: files.length,
          );
        } else {
          return FileConversionResult(
            success: false,
            error: data['error'] ??
                'Conversion failed. Please verify your document and try again.',
          );
        }
      } else {
        try {
          final data = jsonDecode(responseBody) as Map<String, dynamic>;
          return FileConversionResult(
            success: false,
            error: data['error'] ?? 'Server error (${streamedResponse.statusCode})',
          );
        } catch (_) {
          return FileConversionResult(
            success: false,
            error: 'Server error (${streamedResponse.statusCode})',
          );
        }
      }
    } catch (e) {
      return FileConversionResult(
        success: false,
        error: 'Network or conversion error: $e',
      );
    }
  }

  // ─── 7. AI DIAGRAM GENERATOR ────────────────────────────────────────
  static Future<Map<String, dynamic>> generateDiagram({
    required String prompt,
    String type = 'flowchart',
  }) async {
    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/generate-diagram/');

    try {
      final sessionCookie = await AuthService.getSessionCookie();
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (sessionCookie != null) 'Cookie': sessionCookie,
        },
        body: jsonEncode({
          'prompt': prompt,
          'diagram_type': type,
        }),
      ).timeout(const Duration(seconds: 60));

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── 8. SCREENSHOT TO CODE ─────────────────────────────────────────
  static Future<Map<String, dynamic>> screenshotToCode({
    required PlatformFile file,
    String framework = 'HTML/Tailwind',
  }) async {
    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/screenshot-to-code/');

    try {
      final request = http.MultipartRequest('POST', url);
      final sessionCookie = await AuthService.getSessionCookie();
      if (sessionCookie != null) request.headers['Cookie'] = sessionCookie;

      request.fields['framework'] = framework;
      if (file.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes('image', file.bytes!, filename: file.name));
      } else if (file.path != null) {
        request.files.add(await http.MultipartFile.fromPath('image', file.path!, filename: file.name));
      }

      final streamed = await request.send().timeout(const Duration(seconds: 90));
      final respStr = await streamed.stream.bytesToString();
      return jsonDecode(respStr) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── 9. AI IMAGE GENERATOR ─────────────────────────────────────────
  static Future<Map<String, dynamic>> generateImage({
    required String prompt,
    String style = 'cinematic',
    String aspectRatio = '1:1',
  }) async {
    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/generate-image/');

    try {
      final sessionCookie = await AuthService.getSessionCookie();
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (sessionCookie != null) 'Cookie': sessionCookie,
        },
        body: jsonEncode({
          'prompt': prompt,
          'style': style,
          'aspect_ratio': aspectRatio,
        }),
      ).timeout(const Duration(seconds: 90));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['image_url'] != null && data['image_url'].toString().startsWith('/')) {
        data['image_url'] = '$baseUrl${data['image_url']}';
      }
      return data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── 10. AI BACKGROUND REMOVER ─────────────────────────────────────
  static Future<Map<String, dynamic>> removeBackground({
    required PlatformFile file,
  }) async {
    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/remove-background/');

    try {
      final request = http.MultipartRequest('POST', url);
      final sessionCookie = await AuthService.getSessionCookie();
      if (sessionCookie != null) request.headers['Cookie'] = sessionCookie;

      if (file.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes('image', file.bytes!, filename: file.name));
      } else if (file.path != null) {
        request.files.add(await http.MultipartFile.fromPath('image', file.path!, filename: file.name));
      }

      final streamed = await request.send().timeout(const Duration(seconds: 90));
      final respStr = await streamed.stream.bytesToString();
      final data = jsonDecode(respStr) as Map<String, dynamic>;
      if (data['image_url'] != null && data['image_url'].toString().startsWith('/')) {
        data['image_url'] = '$baseUrl${data['image_url']}';
      }
      return data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── 11. STOCK MEDIA SEARCH ────────────────────────────────────────
  static Future<Map<String, dynamic>> searchStockImages({
    required String query,
    int page = 1,
    int perPage = 20,
  }) async {
    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/stock-images/?q=${Uri.encodeComponent(query)}&page=$page&per_page=$perPage');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 20));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'images': []};
    }
  }

  static Future<Map<String, dynamic>> searchStockVideos({
    required String query,
    int page = 1,
    int perPage = 15,
  }) async {
    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/stock-videos/?q=${Uri.encodeComponent(query)}&page=$page&per_page=$perPage');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 20));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'videos': []};
    }
  }

  // ─── 12. VIDEO COMPRESSOR & DOWNLOADER ────────────────────────────
  static Future<Map<String, dynamic>> uploadVideoCompress({
    required PlatformFile file,
    String targetQuality = 'medium',
  }) async {
    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/video-compress/upload/');

    try {
      final request = http.MultipartRequest('POST', url);
      final sessionCookie = await AuthService.getSessionCookie();
      if (sessionCookie != null) request.headers['Cookie'] = sessionCookie;

      request.fields['quality'] = targetQuality;
      if (file.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes('video', file.bytes!, filename: file.name));
      } else if (file.path != null) {
        request.files.add(await http.MultipartFile.fromPath('video', file.path!, filename: file.name));
      }

      final streamed = await request.send().timeout(const Duration(seconds: 180));
      final respStr = await streamed.stream.bytesToString();
      return jsonDecode(respStr) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> checkVideoCompressStatus(String taskId) async {
    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/video-compress/status/$taskId/');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['download_url'] != null && data['download_url'].toString().startsWith('/')) {
        data['download_url'] = '$baseUrl${data['download_url']}';
      }
      return data;
    } catch (e) {
      return {'status': 'error', 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getVideoDownloadInfo(String videoUrl) async {
    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/video-download/info/');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': videoUrl}),
      ).timeout(const Duration(seconds: 30));

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
