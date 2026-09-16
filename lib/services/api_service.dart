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
  static Future<ChatResponseResult> sendMessage({
    required String prompt,
    required bool webSearch,
    required String sessionId,
    required List<ChatMessage> history,
    void Function(String tokenChunk)? onTokenReceived,
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
      'language': 'assamese',
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

      // Check if it's a streaming response
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
        // Non-streaming JSON or error response
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
            // Raw text fallback
            return ChatResponseResult(
              text: responseBody,
              model: 'Axom AI',
            );
          }
        } else if (streamedResponse.statusCode == 403) {
          return ChatResponseResult(
            text: '',
            error: 'Session expired or not authorized. Please refresh.',
          );
        } else if (streamedResponse.statusCode == 429) {
          return ChatResponseResult(
            text: '',
            error: 'Rate limit reached. Please wait a moment before asking again.',
          );
        } else {
          return ChatResponseResult(
            text: '',
            error:
                'Server busy (${streamedResponse.statusCode}). Please try again shortly.',
          );
        }
      }
    } catch (e) {
      String err = e.toString();
      if (err.contains('Failed to fetch')) {
        err = 'CORS restriction in Web Browser. Please run on Windows desktop (flutter run -d windows) or Android, or restart Chrome with web security disabled.';
      }
      return ChatResponseResult(
        text: '',
        error: err,
      );
    }
  }

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
      request.headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) AxomAI/1.0 Safari/537.36';

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
                    : '${files[0].name.replaceAll(RegExp(r'\.[^/.]+$'), '')}.pdf'),
            downloadUrl: rawDownload,
            fileSize: data['file_size'] ??
                (isBatch ? 'ZIP Archive' : 'PDF Document'),
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
            error: data['error'] ??
                'Server error (${streamedResponse.statusCode})',
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
}
