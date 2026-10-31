import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';
import 'storage_service.dart';

class DownloadResult {
  final bool success;
  final String? filePath;
  final String? filename;
  final int? fileSizeBytes;
  final String? error;

  DownloadResult({
    required this.success,
    this.filePath,
    this.filename,
    this.fileSizeBytes,
    this.error,
  });

  String get formattedSize {
    if (fileSizeBytes == null || fileSizeBytes == 0) return '';
    if (fileSizeBytes! < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes! < 1024 * 1024) {
      return '${(fileSizeBytes! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes! / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class DownloadService {
  /// Downloads a file directly into the app's canonical documents directory.
  /// This directory is 100% exempt from Android 11+ MANAGE_EXTERNAL_STORAGE restrictions,
  /// allowing FileProvider in OpenFilex to open it reliably in Adobe, Chrome, Drive, etc.
  static Future<DownloadResult> downloadToAppStorage({
    required String rawUrl,
    required String preferredFilename,
    void Function(double progress, String status)? onProgress,
  }) async {
    final client = http.Client();
    try {
      final baseUrl = await StorageService.loadApiBaseUrl();
      String finalUrl = rawUrl;
      if (finalUrl.startsWith('/')) {
        finalUrl = '$baseUrl$finalUrl';
      }

      final uri = Uri.parse(finalUrl);
      final request = http.Request('GET', uri);

      final sessionCookie = await AuthService.getSessionCookie();
      if (sessionCookie != null && sessionCookie.isNotEmpty) {
        request.headers['Cookie'] = sessionCookie;
      }
      final deviceId = await StorageService.getDeviceId();
      request.headers['X-Device-Id'] = deviceId;
      request.headers['Accept'] = '*/*';

      onProgress?.call(0.05, 'Connecting to server...');

      final response = await client.send(request);

      if (response.statusCode != 200) {
        return DownloadResult(
          success: false,
          error: 'Server returned HTTP ${response.statusCode}',
        );
      }

      final totalBytes = response.contentLength ?? 0;

      final appDir = await getApplicationDocumentsDirectory();

      // Clean filename
      String safeName = preferredFilename.replaceAll(RegExp(r'[\/:*?"<>|]'), '_');
      if (safeName.isEmpty) safeName = 'axom_document.pdf';

      final savePath = '${appDir.path}/$safeName';
      final targetFile = File(savePath);

      final sink = targetFile.openWrite();
      int receivedBytes = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          final progress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
          final progressPercent = (progress * 100).toInt();
          onProgress?.call(progress, 'Downloading $progressPercent%...');
        } else {
          final mb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
          onProgress?.call(0.5, 'Downloaded ${mb}MB...');
        }
      }

      await sink.flush();
      await sink.close();

      onProgress?.call(1.0, 'Downloaded successfully!');

      return DownloadResult(
        success: true,
        filePath: savePath,
        filename: safeName,
        fileSizeBytes: receivedBytes,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Download error: $e');
      }
      return DownloadResult(
        success: false,
        error: 'Download failed: $e',
      );
    } finally {
      client.close();
    }
  }

  /// Prompts the user with the native default Android system dialog (Storage Access Framework)
  /// asking WHERE they want to save the document (Downloads, SD Card, Documents, Google Drive, etc.).
  static Future<String?> promptNativeSaveDialog({
    required String filePath,
    required String fileName,
    required bool isBatch,
    String? customExtension,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();

      String ext = customExtension ??
          (fileName.contains('.')
              ? fileName.split('.').last.toLowerCase()
              : 'pdf');
      if (ext.isEmpty) ext = 'pdf';

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle:
            'Save ${isBatch ? "ZIP Archive" : "${ext.toUpperCase()} Document"}',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: isBatch ? ['zip'] : [ext],
        bytes: bytes,
      );
      return savedPath;
    } catch (e) {
      if (kDebugMode) {
        print('Native save dialog error: $e');
      }
      return null;
    }
  }

  /// Opens the downloaded file using Android's native system app chooser ("Open With...").
  /// Passes explicit MIME type so installed reader apps (Adobe, Gallery, Docs, Video Player) appear.
  static Future<OpenResult> openFile(String filePath) async {
    final lower = filePath.toLowerCase();
    String? mimeType;
    if (lower.endsWith('.pdf')) {
      mimeType = 'application/pdf';
    } else if (lower.endsWith('.zip')) {
      mimeType = 'application/zip';
    } else if (lower.endsWith('.docx')) {
      mimeType =
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      mimeType = 'image/jpeg';
    } else if (lower.endsWith('.png')) {
      mimeType = 'image/png';
    } else if (lower.endsWith('.webp')) {
      mimeType = 'image/webp';
    } else if (lower.endsWith('.mp4')) {
      mimeType = 'video/mp4';
    }
    return await OpenFilex.open(filePath, type: mimeType);
  }

  /// Opens the file directly in Google Drive cloud viewer.
  static Future<bool> openInGoogleDriveViewer(String rawUrl) async {
    try {
      final baseUrl = await StorageService.loadApiBaseUrl();
      String finalUrl = rawUrl;
      if (finalUrl.startsWith('/')) {
        finalUrl = '$baseUrl$finalUrl';
      }
      final driveUrl = 'https://docs.google.com/viewer?url=${Uri.encodeComponent(finalUrl)}';
      final uri = Uri.parse(driveUrl);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Shares the downloaded file to external apps (WhatsApp, Telegram, Email, Drive)
  /// using the native Android system share sheet.
  static Future<void> shareFile(String filePath, {String? text}) async {
    final xfile = XFile(filePath);
    await SharePlus.instance.share(
      ShareParams(
        files: [xfile],
        text: text ?? 'Converted with Axom AI',
      ),
    );
  }
}
