import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';
import '../../services/download_service.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

const int kFreeDailyLimit = 20;
const int kMaxFileSizeMb = 40;
const int kMaxFileSizeBytes = kMaxFileSizeMb * 1024 * 1024;

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}

String getTodayUsageKey() {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  return 'axom_cp_usage_$today';
}

class CompressPdfScreen extends StatefulWidget {
  const CompressPdfScreen({super.key});

  @override
  State<CompressPdfScreen> createState() => _CompressPdfScreenState();
}

class _CompressPdfScreenState extends State<CompressPdfScreen> {
  String _level = 'moderate'; // 'extreme' | 'moderate' | 'less'
  bool _isPro = false;
  int _dailyUsage = 0;

  PlatformFile? _selectedPdf;
  bool _isCompressing = false;
  String _progressMsg = '';
  String? _errorMessage;

  Map<String, dynamic>? _result;
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
          _isPro = user.isStaff;
        });
      }
    } catch (_) {}
  }

  Future<void> _incrementDailyUsage() async {
    if (_isPro) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = getTodayUsageKey();
      final newCount = _dailyUsage + 1;
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
      _selectedPdf = null;
      _isCompressing = false;
      _errorMessage = null;
      _result = null;
      _progressMsg = '';
      _isDownloading = false;
      _downloadProgress = 0.0;
      _downloadStatusMsg = '';
      _downloadResult = null;
    });
  }

  Future<void> _pickPdf() async {
    setState(() => _errorMessage = null);

    if (!_isPro && _dailyUsage >= kFreeDailyLimit) {
      setState(() {
        _errorMessage =
            'Daily free limit reached ($kFreeDailyLimit/$kFreeDailyLimit files). Please upgrade to Premium.';
      });
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;

      if (!(file.extension ?? '').toLowerCase().contains('pdf')) {
        setState(() => _errorMessage = 'Please select a valid PDF file.');
        return;
      }
      if (file.size > kMaxFileSizeBytes) {
        setState(() => _errorMessage =
            'File exceeds maximum size limit of $kMaxFileSizeMb MB.');
        return;
      }

      setState(() {
        _selectedPdf = file;
        _result = null;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Could not select PDF: $e');
    }
  }

  Future<void> _handleCompress() async {
    if (_selectedPdf == null) return;

    if (!_isPro && _dailyUsage >= kFreeDailyLimit) {
      setState(() {
        _errorMessage =
            'Daily free limit reached ($kFreeDailyLimit/$kFreeDailyLimit files). Please upgrade to Premium.';
      });
      return;
    }

    setState(() {
      _isCompressing = true;
      _errorMessage = null;
      _progressMsg = 'Analyzing PDF stream objects & embedded images...';
    });

    _timer1 = Timer(const Duration(milliseconds: 900), () {
      if (mounted && _isCompressing) {
        setState(() {
          _progressMsg =
              'Compressing raster streams with Ghostscript / FlateDecode...';
        });
      }
    });

    _timer2 = Timer(const Duration(milliseconds: 2200), () {
      if (mounted && _isCompressing) {
        setState(() {
          _progressMsg = 'Optimizing cross-reference tables & fonts...';
        });
      }
    });

    try {
      final res = await ApiService.executePdfTool(
        op: 'compress',
        files: [_selectedPdf!],
        level: _level,
      );

      _timer1?.cancel();
      _timer2?.cancel();

      if (!mounted) return;

      if (res['success'] == true) {
        await _incrementDailyUsage();
        setState(() {
          _isCompressing = false;
          _result = res;
          _progressMsg = '';
        });
      } else {
        setState(() {
          _isCompressing = false;
          _errorMessage = res['error'] ?? 'Compression failed. Please try again.';
          _progressMsg = '';
        });
      }
    } catch (e) {
      _timer1?.cancel();
      _timer2?.cancel();
      if (!mounted) return;
      setState(() {
        _isCompressing = false;
        _errorMessage = 'An error occurred during compression: $e';
        _progressMsg = '';
      });
    }
  }

  Future<void> _handleDownloadAndSave() async {
    if (_result == null || _result!['download_url'] == null) return;

    final targetName = _result!['output_name'] ??
        '${_selectedPdf?.name.replaceAll(RegExp(r'\.[^/.]+$'), '') ?? "document"}_compressed.pdf';

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.05;
      _downloadStatusMsg = 'Starting download...';
    });

    final res = await DownloadService.downloadToAppStorage(
      rawUrl: _result!['download_url']!,
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
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.error ?? 'Could not download PDF.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() {
      _isDownloading = false;
      _downloadResult = res;
    });

    final savedPath = await DownloadService.promptNativeSaveDialog(
      filePath: res.filePath!,
      fileName: targetName,
      isBatch: false,
      customExtension: 'pdf',
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
              Expanded(child: Text('Saved: $targetName')),
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
    final dlUrl = _result?['download_url'] ?? '';
    final filePath = _downloadResult?.filePath;

    if (filePath == null) {
      if (dlUrl.isNotEmpty) {
        await DownloadService.openInGoogleDriveViewer(dlUrl);
      }
      return;
    }

    final openRes = await DownloadService.openFile(filePath);

    if (openRes.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No PDF reader found. Opening in Google Drive Viewer...',
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
      text: 'Compressed with Axom AI Compress PDF',
    );
  }

  @override
  Widget build(BuildContext context) {
    final remainingFree = (_dailyUsage >= kFreeDailyLimit)
        ? 0
        : (kFreeDailyLimit - _dailyUsage);
    final isDailyLimitReached = !_isPro && _dailyUsage >= kFreeDailyLimit;

    // Calculate reduction metrics if available
    int origBytes = (_result?['original_bytes'] as num?)?.toInt() ??
        (_selectedPdf?.size ?? 0);
    int outBytes = (_result?['output_bytes'] as num?)?.toInt() ?? 0;
    double savedPercent = 0.0;
    if (origBytes > 0 && outBytes > 0) {
      savedPercent =
          ((origBytes - outBytes) / origBytes * 100).clamp(0.0, 99.9);
    }

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Compress PDF',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isPro
                  ? Colors.amber.withValues(alpha: 0.15)
                  : const Color(0xFFEF4444).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isPro
                    ? Colors.amber.withValues(alpha: 0.4)
                    : const Color(0xFFEF4444).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isPro
                      ? Icons.workspace_premium_rounded
                      : Icons.bolt_rounded,
                  size: 14,
                  color: _isPro ? Colors.amber : const Color(0xFFEF4444),
                ),
                const SizedBox(width: 4),
                Text(
                  _isPro
                      ? 'PRO UNLIMITED'
                      : '$remainingFree/$kFreeDailyLimit FREE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: _isPro ? Colors.amber : const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.borderColor, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFEF4444).withValues(alpha: 0.14),
                    AppTheme.accentPurple.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.compress_rounded,
                        color: Color(0xFFEF4444), size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reduce PDF File Size',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Shrink large PDF documents by up to 80% while maintaining crisp typography and layout fidelity.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Compression Level Selector
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'COMPRESSION LEVEL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildLevelTile(
                    level: 'moderate',
                    title: 'Recommended Compression',
                    subtitle: 'Good quality & high compression (Default)',
                    badge: 'POPULAR',
                  ),
                  const SizedBox(height: 8),
                  _buildLevelTile(
                    level: 'extreme',
                    title: 'Extreme Compression',
                    subtitle: 'Smallest possible file size for strict portals',
                    badge: 'MAX REDUCTION',
                  ),
                  const SizedBox(height: 8),
                  _buildLevelTile(
                    level: 'less',
                    title: 'Less Compression',
                    subtitle: 'Highest visual quality with gentle shrinking',
                    badge: 'HIGH QUALITY',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

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

            if (_result != null) ...[
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.successGreen.withValues(alpha: 0.35),
                  ),
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
                    const Text(
                      'PDF Successfully Compressed!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (savedPercent > 0)
                      Text(
                        'Saved ${savedPercent.toStringAsFixed(1)}% (${formatBytes(origBytes)} → ${formatBytes(outBytes)})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successGreen,
                        ),
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
                                  _result!['output_name'] ?? 'compressed.pdf',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${_result!['file_size'] ?? ''} • Compressed PDF',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_downloadResult != null) ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
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
                                if (_result?['download_url'] != null) {
                                  DownloadService.openInGoogleDriveViewer(
                                      _result!['download_url']!);
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
                    ] else ...[
                    if (_isDownloading) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEC4899).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEC4899).withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
                                  ),
                                ),
                                const SizedBox(width: 8),
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
                                    color: Color(0xFFEC4899),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _downloadProgress,
                                backgroundColor: const Color(0xFFEC4899).withValues(alpha: 0.15),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.download_rounded,
                            size: 18, color: Colors.white),
                        label: const Text(
                          'Download Compressed PDF',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        onPressed: _handleDownloadAndSave,
                      ),
                    ],
                    const SizedBox(height: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.borderColor),
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _resetAll,
                      child: const Text('Compress Another PDF',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary)),
                    ),
                  ],
                ),
              ),
            ] else if (_selectedPdf != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded,
                          color: AppTheme.errorRed, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedPdf!.name,
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
                            'Original: ${formatBytes(_selectedPdf!.size)}',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppTheme.textMuted, size: 18),
                      onPressed: _isCompressing ? null : _resetAll,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 6,
                ),
                onPressed: _isCompressing || isDailyLimitReached
                    ? null
                    : _handleCompress,
                child: _isCompressing
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
                                : 'Compressing...',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.compress_rounded,
                              size: 20, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Compress PDF Now',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ] else ...[
              InkWell(
                onTap: _isCompressing || isDailyLimitReached ? null : _pickPdf,
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
                              const Color(0xFFEF4444).withValues(alpha: 0.2),
                              AppTheme.accentPurple.withValues(alpha: 0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.35)),
                        ),
                        child: const Icon(Icons.compress_rounded,
                            color: Color(0xFFEF4444), size: 30),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tap to select PDF to compress',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Reduce PDF size by up to 80% without losing readable text\nMax size: 40 MB',
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
                          color: const Color(0xFFEF4444)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.file_upload_outlined,
                                size: 16, color: Color(0xFFEF4444)),
                            SizedBox(width: 6),
                            Text(
                              'Select PDF File (Free 20/day)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEF4444),
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

            _buildTrustItem(
              icon: Icons.compress_rounded,
              color: const Color(0xFFEF4444),
              title: 'Up to 80% Size Reduction',
              subtitle: 'Shrinks multi-megabyte PDFs into lightweight files',
              badge: 'Smart Engine',
              badgeColor: const Color(0xFFEF4444),
            ),
            const SizedBox(height: 10),
            _buildTrustItem(
              icon: Icons.shield_outlined,
              color: AppTheme.successGreen,
              title: 'Free: 20 Compressions / Day',
              subtitle: 'Zero watermarks with instant clean exports',
              badge: 'Free Tier',
              badgeColor: AppTheme.successGreen,
            ),
            const SizedBox(height: 10),
            _buildTrustItem(
              icon: Icons.lock_outline_rounded,
              color: AppTheme.accentPurple,
              title: '100% Private & Secure',
              subtitle: 'Encrypted transfer with automatic immediate purge',
              badge: 'Secure',
              badgeColor: AppTheme.accentPurple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelTile({
    required String level,
    required String title,
    required String subtitle,
    required String badge,
  }) {
    final isSelected = _level == level;
    return InkWell(
      onTap: () => setState(() => _level = level),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEF4444).withValues(alpha: 0.12)
              : const Color(0xFF13172E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFEF4444)
                : AppTheme.borderColor,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 18,
              color: isSelected
                  ? const Color(0xFFEF4444)
                  : AppTheme.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 10.5, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? const Color(0xFFEF4444)
                      : AppTheme.textSecondary,
                ),
              ),
            ),
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
