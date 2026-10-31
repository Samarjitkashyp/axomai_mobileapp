import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import '../../services/download_service.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

const int kFreeDailyLimit = 20;
const int kProBatchLimit = 20;
const int kMaxFileSizeMb = 25;
const int kMaxFileSizeBytes = kMaxFileSizeMb * 1024 * 1024;
const List<String> kAllowedExtensions = ['docx', 'doc', 'rtf', 'txt', 'odt'];

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}

String getTodayUsageKey() {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  return 'axom_w2p_usage_$today';
}

class WordToPdfScreen extends StatefulWidget {
  const WordToPdfScreen({super.key});

  @override
  State<WordToPdfScreen> createState() => _WordToPdfScreenState();
}

class _WordToPdfScreenState extends State<WordToPdfScreen> {
  bool _isPro = false;
  int _dailyUsage = 0;
  String _mode = 'single'; // 'single' | 'batch'

  List<PlatformFile> _selectedFiles = [];
  bool _isConverting = false;
  String _progressMsg = '';
  String? _errorMessage;
  FileConversionResult? _result;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatusMsg = '';
  DownloadResult? _downloadResult;

  Timer? _timer1;
  Timer? _timer2;

  @override
  void initState() {
    super.initState();
    _loadUsageAndPlan();
  }

  @override
  void dispose() {
    _timer1?.cancel();
    _timer2?.cancel();
    super.dispose();
  }

  Future<void> _loadUsageAndPlan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = getTodayUsageKey();
      final count = prefs.getInt(key) ?? 0;
      final user = await AuthService.getCurrentUser();

      if (mounted) {
        setState(() {
          _dailyUsage = count;
          _isPro = user.isStaff; // Staff or subscription tier
        });
      }
    } catch (_) {}
  }

  Future<void> _incrementDailyUsage(int count) async {
    if (_isPro) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = getTodayUsageKey();
      final newCount = _dailyUsage + count;
      await prefs.setInt(key, newCount);
      if (mounted) {
        setState(() => _dailyUsage = newCount);
      }
    } catch (_) {}
  }

  void _resetAll() {
    _timer1?.cancel();
    _timer2?.cancel();
    setState(() {
      _selectedFiles = [];
      _isConverting = false;
      _errorMessage = null;
      _result = null;
      _progressMsg = '';
      _isDownloading = false;
      _downloadProgress = 0.0;
      _downloadStatusMsg = '';
      _downloadResult = null;
    });
  }

  Future<void> _pickFiles() async {
    setState(() => _errorMessage = null);

    if (!_isPro && _dailyUsage >= kFreeDailyLimit) {
      setState(() {
        _errorMessage =
            'You have reached the free limit of $kFreeDailyLimit files for today. Please upgrade to Axom AI Premium for unlimited conversions.';
      });
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: kAllowedExtensions,
        allowMultiple: _mode == 'batch' || _isPro,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final picked = result.files;

      if (picked.length > 1 && !_isPro && _mode == 'single') {
        _showUpgradeDialog();
      }

      final List<PlatformFile> valid = [];
      for (final f in picked) {
        final ext = (f.extension ?? '').toLowerCase();
        if (!kAllowedExtensions.contains(ext)) {
          setState(() {
            _errorMessage =
                '"${f.name}" is not a supported Word document (${kAllowedExtensions.join(', ')}).';
          });
          return;
        }
        if (f.size > kMaxFileSizeBytes) {
          setState(() {
            _errorMessage =
                '"${f.name}" exceeds the $kMaxFileSizeMb MB limit.';
          });
          return;
        }
        valid.add(f);
      }

      if (!_isPro && _mode != 'batch') {
        setState(() {
          _selectedFiles = [valid.first];
          _result = null;
        });
        return;
      }

      if (picked.length > 1 && !_isPro) {
        _showUpgradeDialog();
        setState(() {
          _selectedFiles = [valid.first];
          _result = null;
        });
        return;
      }

      final capped = valid.take(kProBatchLimit).toList();
      setState(() {
        _selectedFiles = capped;
        _result = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not select file: $e';
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
      if (_selectedFiles.isEmpty) {
        _resetAll();
      }
    });
  }

  Future<void> _handleConvert() async {
    if (_selectedFiles.isEmpty) return;

    if (!_isPro && _dailyUsage >= kFreeDailyLimit) {
      setState(() {
        _errorMessage =
            'Daily free limit reached ($kFreeDailyLimit/$kFreeDailyLimit files converted). Upgrade to Premium for unlimited conversions.';
      });
      return;
    }

    setState(() {
      _isConverting = true;
      _errorMessage = null;
      _progressMsg = _selectedFiles.length > 1
          ? 'Uploading ${_selectedFiles.length} documents securely...'
          : 'Uploading document securely...';
    });

    _timer1?.cancel();
    _timer2?.cancel();

    _timer1 = Timer(const Duration(milliseconds: 1000), () {
      if (mounted && _isConverting) {
        setState(() {
          _progressMsg = _selectedFiles.length > 1
              ? 'Processing fonts, tables and margins for ${_selectedFiles.length} files...'
              : 'Preserving fonts, margins and tables...';
        });
      }
    });

    _timer2 = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && _isConverting) {
        setState(() {
          _progressMsg = _selectedFiles.length > 1
              ? 'Bundling converted PDFs into package...'
              : 'Rendering high-definition PDF...';
        });
      }
    });

    try {
      final res = await ApiService.convertFile(
        files: _selectedFiles,
        target: 'pdf',
      );

      _timer1?.cancel();
      _timer2?.cancel();

      if (!mounted) return;

      if (res.success) {
        await _incrementDailyUsage(_selectedFiles.length);
        setState(() {
          _isConverting = false;
          _result = res;
          _progressMsg = '';
        });
      } else {
        String msg = res.error ??
            'Conversion failed. Please verify your document and try again.';
        if (msg.contains('Failed to fetch')) {
          msg =
              'Connection interrupted. Please verify your network and retry.';
        }
        setState(() {
          _isConverting = false;
          _errorMessage = msg;
          _progressMsg = '';
        });
      }
    } catch (e) {
      _timer1?.cancel();
      _timer2?.cancel();
      if (!mounted) return;
      String msg = 'An error occurred during conversion: $e';
      if (msg.contains('Failed to fetch')) {
        msg =
            'Connection interrupted. Please verify your network and retry.';
      }
      setState(() {
        _isConverting = false;
        _errorMessage = msg;
        _progressMsg = '';
      });
    }
  }

  Future<void> _handleDownloadAndSave() async {
    if (_result == null || _result!.downloadUrl == null) return;

    final targetName = _result!.outputName ??
        (_result!.isBatch
            ? 'axom_batch_documents.zip'
            : '${_selectedFiles.isNotEmpty ? _selectedFiles[0].name.replaceAll(RegExp(r'\.[^/.]+$'), '') : "converted_document"}.pdf');

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.05;
      _downloadStatusMsg = 'Starting download...';
    });

    // Step 1: Download into app canonical storage (exempt from Scoped Storage restrictions)
    final res = await DownloadService.downloadToAppStorage(
      rawUrl: _result!.downloadUrl!,
      preferredFilename: targetName,
      onProgress: (prog, status) {
        if (mounted) {
          setState(() {
            _downloadProgress = prog;
            _downloadStatusMsg = status;
          });
        }
      },
    );

    if (!mounted) return;

    if (!res.success || res.filePath == null) {
      setState(() {
        _isDownloading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.error ?? 'Could not download document.'),
          backgroundColor: AppTheme.errorRed,
          action: SnackBarAction(
            label: 'Drive View',
            textColor: Colors.white,
            onPressed: () {
              if (_result?.downloadUrl != null) {
                DownloadService.openInGoogleDriveViewer(_result!.downloadUrl!);
              }
            },
          ),
        ),
      );
      return;
    }

    setState(() {
      _isDownloading = false;
      _downloadResult = res;
    });

    // Step 2: Open DEFAULT ANDROID SYSTEM MODAL (Storage Access Framework)
    // Asks the user WHERE they want to save the document (Downloads, Documents, Drive, SD Card)
    final savedPath = await DownloadService.promptNativeSaveDialog(
      filePath: res.filePath!,
      fileName: targetName,
      isBatch: _result!.isBatch,
    );

    if (!mounted) return;

    if (savedPath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Saved: $targetName'),
              ),
            ],
          ),
          backgroundColor: AppTheme.successGreen,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: _handleOpenPdf,
          ),
        ),
      );
    } else {
      // User cancelled system save dialog, but file is downloaded and ready in app cache
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File ready: $targetName'),
          backgroundColor: AppTheme.accentPurple,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: _handleOpenPdf,
          ),
        ),
      );
    }
  }

  Future<void> _handleOpenPdf() async {
    final dlUrl = _result?.downloadUrl ?? '';
    final filePath = _downloadResult?.filePath;

    if (filePath == null) {
      if (dlUrl.isNotEmpty) {
        await DownloadService.openInGoogleDriveViewer(dlUrl);
      }
      return;
    }

    // Default Android system "Open with..." app chooser (Adobe Acrobat, Chrome, Drive, WPS)
    final openRes = await DownloadService.openFile(filePath);

    if (openRes.type != ResultType.done && mounted) {
      // Fallback directly to Google Drive Cloud Viewer if no local PDF reader is installed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No PDF reader app found on device. Opening in Google Drive Viewer...',
          ),
          backgroundColor: AppTheme.accentPurple,
          duration: Duration(seconds: 3),
        ),
      );
      if (dlUrl.isNotEmpty) {
        await DownloadService.openInGoogleDriveViewer(dlUrl);
      }
    }
  }

  Future<void> _handleShareFile() async {
    if (_downloadResult?.filePath == null) return;
    await DownloadService.shareFile(
      _downloadResult!.filePath!,
      text: 'Converted with Axom AI Word to PDF',
    );
  }

  Future<void> _openDownloadUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: $url'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E0F1C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.amber.withValues(alpha: 0.4)),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0x33F59E0B), Color(0x33D946EF)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: Colors.amber, size: 30),
            ),
            const SizedBox(height: 16),
            const Text(
              'Unlock Pro Batch Mode',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Free users can convert 1 file at a time (up to 20 files/day). Upgrade to Axom AI Premium to convert up to 20 documents simultaneously with 1-click batch ZIP download!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  _buildDialogFeature('Batch convert up to 20 files in 1 click'),
                  const SizedBox(height: 6),
                  _buildDialogFeature('Unlimited daily document conversions'),
                  const SizedBox(height: 6),
                  _buildDialogFeature('Highest priority cloud conversion speed'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _openDownloadUrl('https://chat.aiaxom.co.in/subscription');
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.workspace_premium_rounded,
                      size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Upgrade to Premium Now',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Continue with Free Single Mode',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogFeature(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded,
            color: AppTheme.successGreen, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11.5, color: AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final remainingFree = (kFreeDailyLimit - _dailyUsage).clamp(0, kFreeDailyLimit);
    final isDailyLimitReached = !_isPro && _dailyUsage >= kFreeDailyLimit;

    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      appBar: AppBar(
        backgroundColor: AppTheme.bgMain,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Word to PDF Converter',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quota & Tier Badge Banner
            Center(
              child: _isPro
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.withValues(alpha: 0.2),
                            AppTheme.accentPurple.withValues(alpha: 0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.workspace_premium_rounded,
                              color: Colors.amber, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'Pro Plan Active: Unlimited Conversions',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    )
                  : InkWell(
                      onTap: () => _openDownloadUrl(
                          'https://chat.aiaxom.co.in/subscription'),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.accentPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppTheme.accentPurple
                                  .withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded,
                                color: AppTheme.accentPurple, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Free Limit: $remainingFree / $kFreeDailyLimit remaining today',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accentPurple,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.accentPink.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Upgrade',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentPink,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            const SizedBox(height: 14),

            // Mode Selector (Single Document vs Pro Batch)
            Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModeButton(
                      mode: 'single',
                      title: 'Single Document',
                      icon: Icons.description_rounded,
                      isActive: _mode == 'single',
                      onTap: () {
                        setState(() {
                          _mode = 'single';
                          if (_selectedFiles.length > 1) {
                            _selectedFiles = [_selectedFiles.first];
                          }
                        });
                      },
                    ),
                    _buildModeButton(
                      mode: 'batch',
                      title: '👑 Pro Batch',
                      icon: Icons.layers_rounded,
                      isActive: _mode == 'batch',
                      isProBadge: !_isPro,
                      onTap: () {
                        if (!_isPro) {
                          _showUpgradeDialog();
                        } else {
                          setState(() => _mode = 'batch');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Limit Reached Banner
            if (isDailyLimitReached) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.amber, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Daily Free Limit Reached ($kFreeDailyLimit/$kFreeDailyLimit files). Upgrade to Premium to continue.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openDownloadUrl(
                          'https://chat.aiaxom.co.in/subscription'),
                      child: const Text('Upgrade',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Error Alert Banner
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.errorRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppTheme.errorRed, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.errorRed),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 16, color: AppTheme.errorRed),
                      onPressed: () => setState(() => _errorMessage = null),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // STATE 1: RESULT READY
            if (_result != null) ...[
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.successGreen.withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.successGreen.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppTheme.successGreen
                                .withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.check_circle_rounded,
                          color: AppTheme.successGreen, size: 34),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _result!.isBatch
                          ? '${_result!.count} Documents Converted!'
                          : 'Your PDF is Ready!',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _result!.isBatch
                          ? 'Converted and bundled into package.'
                          : 'Converted with formatting, tables & fonts preserved.',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgMain,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.errorRed.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.picture_as_pdf_rounded,
                                color: AppTheme.errorRed, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _result!.outputName ?? 'document.pdf',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${_result!.fileSize ?? ''} • Axom AI Engine',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.successGreen.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: AppTheme.successGreen
                                      .withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'READY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.successGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isDownloading) ...[
                      // LIVE DOWNLOADING STATE
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.accentPurple.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppTheme.accentPurple.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        AppTheme.accentPurple),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _downloadStatusMsg,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(_downloadProgress * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accentPurple,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _downloadProgress,
                                backgroundColor:
                                    AppTheme.accentPurple.withValues(alpha: 0.15),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppTheme.accentPurple),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_downloadResult != null && _downloadResult!.success) ...[
                      // DOWNLOAD COMPLETE BANNER & BIG COMPANY ACTION BUTTONS
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppTheme.successGreen.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: AppTheme.successGreen, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Saved to Device Downloads',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.successGreen,
                                    ),
                                  ),
                                  Text(
                                    '📁 ${_downloadResult!.filename} (${_downloadResult!.formattedSize})',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentPurple,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.visibility_rounded,
                                  size: 18, color: Colors.white),
                              label: const Text(
                                'Open PDF',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              onPressed: _handleOpenPdf,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1F2238),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                      color: AppTheme.borderColor),
                                ),
                              ),
                              icon: const Icon(Icons.add_to_drive_rounded,
                                  size: 18, color: Colors.amber),
                              label: const Text(
                                'Drive',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              onPressed: () {
                                if (_result?.downloadUrl != null) {
                                  DownloadService.openInGoogleDriveViewer(
                                      _result!.downloadUrl!);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F2238),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.share_rounded,
                                  size: 18, color: AppTheme.accentCyan),
                              tooltip: 'Share',
                              onPressed: _handleShareFile,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.borderColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _resetAll,
                        child: const Text('Convert Another Document',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.textSecondary)),
                      ),
                    ] else ...[
                      // INITIAL STATE: DOWNLOAD TO DEVICE
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentPurple,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.download_rounded,
                                  size: 18, color: Colors.white),
                              label: Text(
                                _result!.isBatch
                                    ? 'Download All (ZIP)'
                                    : 'Download Converted PDF',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              onPressed: _handleDownloadAndSave,
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.borderColor),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _resetAll,
                            child: const Text('New',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ] else if (_selectedFiles.isNotEmpty) ...[
              // STATE 2: FILES SELECTED
              if (_selectedFiles.length == 1) ...[
                // Single File Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.accentPurple.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.accentPurple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.accentPurple
                                  .withValues(alpha: 0.25)),
                        ),
                        child: const Icon(Icons.description_rounded,
                            color: AppTheme.accentPurple, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFiles.first.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${formatBytes(_selectedFiles.first.size)} • ${(_selectedFiles.first.extension ?? 'docx').toUpperCase()}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: AppTheme.textMuted, size: 18),
                        onPressed: _isConverting ? null : _resetAll,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Batch Multi-File List
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_selectedFiles.length} Documents Selected',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            formatBytes(_selectedFiles.fold(
                                0, (acc, f) => acc + f.size)),
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                      const Divider(height: 18, color: AppTheme.borderColor),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _selectedFiles.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, idx) {
                            final f = _selectedFiles[idx];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.bgMain,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.borderColor),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '${idx + 1}.',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      f.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textPrimary),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    formatBytes(f.size),
                                    style: const TextStyle(
                                        fontSize: 10.5,
                                        color: AppTheme.textMuted),
                                  ),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.close_rounded,
                                        size: 14, color: AppTheme.textMuted),
                                    onPressed: _isConverting
                                        ? null
                                        : () => _removeFile(idx),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Convert Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 6,
                ),
                onPressed:
                    _isConverting || isDailyLimitReached ? null : _handleConvert,
                child: _isConverting
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SpinKitRing(
                            color: Colors.white,
                            size: 20,
                            lineWidth: 2,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _progressMsg.isNotEmpty
                                ? _progressMsg
                                : 'Converting...',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.picture_as_pdf_rounded,
                              size: 20, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            _selectedFiles.length > 1
                                ? 'Convert All ${_selectedFiles.length} Documents to PDF'
                                : 'Convert to PDF Now',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ] else ...[
              // STATE 3: DROPZONE EMPTY
              InkWell(
                onTap: _isConverting || isDailyLimitReached ? null : _pickFiles,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.borderColor,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.accentPurple.withValues(alpha: 0.2),
                              AppTheme.accentPink.withValues(alpha: 0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: AppTheme.accentPurple
                                  .withValues(alpha: 0.35)),
                        ),
                        child: const Icon(Icons.cloud_upload_rounded,
                            color: AppTheme.accentPurple, size: 30),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _mode == 'batch' || _isPro
                            ? 'Tap to select up to 20 Word documents'
                            : 'Tap to browse or select your Word document',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Supports .DOCX, .DOC, as well as .RTF, .TXT, and .ODT\nMax file size: 25 MB',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentPurple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppTheme.accentPurple
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.file_upload_outlined,
                                size: 16, color: AppTheme.accentPurple),
                            const SizedBox(width: 6),
                            Text(
                              _mode == 'batch' || _isPro
                                  ? 'Select up to 20 Files (Batch)'
                                  : 'Select Word File (Free 20/day)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Trust Details Cards (1 card per row for clean, neat mobile UI)
            _buildTrustItem(
              icon: Icons.shield_outlined,
              color: AppTheme.successGreen,
              title: 'Free: 20 Files / Day',
              subtitle:
                  '100% original fonts, tables, margins & zero watermarks',
              badge: 'Free Tier',
              badgeColor: AppTheme.successGreen,
            ),
            const SizedBox(height: 10),
            _buildTrustItem(
              icon: Icons.workspace_premium_rounded,
              color: Colors.amber,
              title: 'Pro Batch Mode',
              subtitle:
                  'Convert up to 20 documents simultaneously with 1-click ZIP',
              badge: 'PRO',
              badgeColor: Colors.amber,
            ),
            const SizedBox(height: 10),
            _buildTrustItem(
              icon: Icons.lock_outline_rounded,
              color: AppTheme.accentPurple,
              title: 'Private & Secure Processing',
              subtitle:
                  'TLS 1.3 encrypted transfer with instantaneous automatic purge',
              badge: 'Secure',
              badgeColor: AppTheme.accentPurple,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required String mode,
    required String title,
    required IconData icon,
    required bool isActive,
    bool isProBadge = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.accentPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 14,
                color: isActive ? Colors.white : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : AppTheme.textSecondary,
              ),
            ),
            if (isProBadge) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border:
                      Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrustItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (badgeColor ?? color).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: (badgeColor ?? color).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: badgeColor ?? color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
