import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/download_service.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

const int kFreeDailyLimit = 20;
const int kMaxFileSizeMb = 30;
const int kMaxFileSizeBytes = kMaxFileSizeMb * 1024 * 1024;
const List<String> kSupportedInputs = [
  'jpg',
  'jpeg',
  'png',
  'webp',
  'bmp',
  'gif',
  'ico',
  'tiff',
  'tif',
  'svg',
  'jfif',
  'avif'
];
const List<String> kTargetFormats = ['png', 'jpg', 'webp', 'pdf', 'svg'];

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}

String getTodayUsageKey() {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  return 'axom_ifc_usage_$today';
}

class ImageFormatConverterScreen extends StatefulWidget {
  const ImageFormatConverterScreen({super.key});

  @override
  State<ImageFormatConverterScreen> createState() =>
      _ImageFormatConverterScreenState();
}

class _ImageFormatConverterScreenState
    extends State<ImageFormatConverterScreen> {
  String _targetFormat = 'png';
  bool _isPro = false;
  int _dailyUsage = 0;

  PlatformFile? _selectedFile;
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
      _selectedFile = null;
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

  Future<void> _pickImage() async {
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
        allowedExtensions: kSupportedInputs,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;

      final ext = (file.extension ?? '').toLowerCase();
      if (!kSupportedInputs.contains(ext)) {
        setState(() => _errorMessage = 'Unsupported image format: .$ext');
        return;
      }
      if (file.size > kMaxFileSizeBytes) {
        setState(() => _errorMessage =
            'File exceeds maximum size limit of $kMaxFileSizeMb MB.');
        return;
      }

      setState(() {
        _selectedFile = file;
        _result = null;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Could not select image: $e');
    }
  }

  Future<void> _handleConvert() async {
    if (_selectedFile == null) return;

    if (!_isPro && _dailyUsage >= kFreeDailyLimit) {
      setState(() {
        _errorMessage =
            'Daily free limit reached ($kFreeDailyLimit/$kFreeDailyLimit files). Please upgrade to Premium.';
      });
      return;
    }

    setState(() {
      _isConverting = true;
      _errorMessage = null;
      _progressMsg = 'Reading image metadata & color channels...';
    });

    _timer1 = Timer(const Duration(milliseconds: 700), () {
      if (mounted && _isConverting) {
        setState(() {
          _progressMsg =
              'Converting to ${_targetFormat.toUpperCase()} with lossless raster/vector mapping...';
        });
      }
    });

    _timer2 = Timer(const Duration(milliseconds: 1800), () {
      if (mounted && _isConverting) {
        setState(() {
          _progressMsg = 'Finalizing and packaging output...';
        });
      }
    });

    try {
      final res = await ApiService.convertFile(
        files: [_selectedFile!],
        target: _targetFormat,
      );

      _timer1?.cancel();
      _timer2?.cancel();

      if (!mounted) return;

      if (res.success) {
        await _incrementDailyUsage();
        setState(() {
          _isConverting = false;
          _result = res;
          _progressMsg = '';
        });
      } else {
        setState(() {
          _isConverting = false;
          _errorMessage = res.error ?? 'Conversion failed. Please try again.';
          _progressMsg = '';
        });
      }
    } catch (e) {
      _timer1?.cancel();
      _timer2?.cancel();
      if (!mounted) return;
      setState(() {
        _isConverting = false;
        _errorMessage = 'An error occurred during conversion: $e';
        _progressMsg = '';
      });
    }
  }

  Future<void> _handleDownloadAndSave() async {
    if (_result == null || _result!.downloadUrl == null) return;

    final targetName = _result!.outputName ??
        '${_selectedFile?.name.replaceAll(RegExp(r'\.[^/.]+$'), '') ?? "image"}.$_targetFormat';

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.05;
      _downloadStatusMsg = 'Starting download...';
    });

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
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.error ?? 'Could not download file.'),
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
      customExtension: _targetFormat,
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
            onPressed: _handleOpenFile,
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
            onPressed: _handleOpenFile,
          ),
        ),
      );
    }
  }

  Future<void> _handleOpenFile() async {
    final filePath = _downloadResult?.filePath;
    if (filePath == null) return;
    await DownloadService.openFile(filePath);
  }

  Future<void> _handleShareFile() async {
    if (_downloadResult?.filePath == null) return;
    await DownloadService.shareFile(
      _downloadResult!.filePath!,
      text:
          'Converted with Axom AI Image Format Converter to ${_targetFormat.toUpperCase()}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final remainingFree = (_dailyUsage >= kFreeDailyLimit)
        ? 0
        : (kFreeDailyLimit - _dailyUsage);
    final isDailyLimitReached = !_isPro && _dailyUsage >= kFreeDailyLimit;

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
          'Image Format Converter',
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
                  : const Color(0xFF06B6D4).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isPro
                    ? Colors.amber.withValues(alpha: 0.4)
                    : const Color(0xFF06B6D4).withValues(alpha: 0.4),
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
                  color: _isPro ? Colors.amber : const Color(0xFF06B6D4),
                ),
                const SizedBox(width: 4),
                Text(
                  _isPro
                      ? 'PRO UNLIMITED'
                      : '$remainingFree/$kFreeDailyLimit FREE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: _isPro ? Colors.amber : const Color(0xFF06B6D4),
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
                    const Color(0xFF06B6D4).withValues(alpha: 0.14),
                    AppTheme.accentPurple.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.transform_rounded,
                        color: Color(0xFF06B6D4), size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Universal Image Format Converter',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Convert any image across PNG, JPG, WebP, SVG, and PDF formats with precision color profiles.',
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

            // Target Format Picker
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
                    'CONVERT TO TARGET FORMAT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kTargetFormats.map((fmt) {
                      final isSelected = _targetFormat == fmt;
                      return ChoiceChip(
                        label: Text(fmt.toUpperCase()),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textSecondary,
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFF06B6D4),
                        backgroundColor: const Color(0xFF13172E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF06B6D4)
                                : AppTheme.borderColor,
                          ),
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _targetFormat = fmt);
                        },
                      );
                    }).toList(),
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
                    Text(
                      'Converted to ${_targetFormat.toUpperCase()}!',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pristine quality and transparent alpha preserved.',
                      style: TextStyle(
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
                              color: const Color(0xFF06B6D4)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.image_rounded,
                                color: Color(0xFF06B6D4), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _result!.outputName ?? 'converted_image',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${_result!.fileSize ?? ''} • ${_targetFormat.toUpperCase()}',
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
                                backgroundColor: const Color(0xFF06B6D4),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.visibility_rounded,
                                  size: 18, color: Colors.white),
                              label: const Text(
                                'View Image',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              onPressed: _handleOpenFile,
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
                          color: const Color(0xFF14B8A6).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.25)),
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
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF14B8A6)),
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
                                    color: Color(0xFF14B8A6),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _downloadProgress,
                                backgroundColor: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF14B8A6)),
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06B6D4),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.download_rounded,
                            size: 18, color: Colors.white),
                        label: Text(
                          'Download ${_targetFormat.toUpperCase()} Image',
                          style: const TextStyle(
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
                      child: const Text('Convert Another Image',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary)),
                    ),
                  ],
                ),
              ),
            ] else if (_selectedFile != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.image_rounded,
                          color: Color(0xFF06B6D4), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFile!.name,
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
                            '${formatBytes(_selectedFile!.size)} • ${(_selectedFile!.extension ?? "img").toUpperCase()} format',
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

              const SizedBox(height: 18),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 6,
                ),
                onPressed: _isConverting || isDailyLimitReached
                    ? null
                    : _handleConvert,
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
                          const Icon(Icons.transform_rounded,
                              size: 20, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Convert to ${_targetFormat.toUpperCase()} Now',
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
              InkWell(
                onTap: _isConverting || isDailyLimitReached ? null : _pickImage,
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
                              const Color(0xFF06B6D4).withValues(alpha: 0.2),
                              AppTheme.accentPurple.withValues(alpha: 0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: const Color(0xFF06B6D4)
                                  .withValues(alpha: 0.35)),
                        ),
                        child: const Icon(Icons.add_photo_alternate_rounded,
                            color: Color(0xFF06B6D4), size: 30),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tap to select image to convert to ${_targetFormat.toUpperCase()}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Supports PNG, JPG, WebP, SVG, BMP, GIF, TIFF, and AVIF\nMax size: 30 MB',
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
                          color: const Color(0xFF06B6D4)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFF06B6D4)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_library_outlined,
                                size: 16, color: Color(0xFF06B6D4)),
                            SizedBox(width: 6),
                            Text(
                              'Select Image (Free 20/day)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF06B6D4),
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
              icon: Icons.high_quality_rounded,
              color: const Color(0xFF06B6D4),
              title: 'Lossless Visual Quality',
              subtitle: 'Precision color encoding and transparent channel mapping',
              badge: 'Lossless',
              badgeColor: const Color(0xFF06B6D4),
            ),
            const SizedBox(height: 10),
            _buildTrustItem(
              icon: Icons.shield_outlined,
              color: AppTheme.successGreen,
              title: 'Free: 20 Conversions / Day',
              subtitle: 'Zero watermarks with instant clean exports',
              badge: 'Free Tier',
              badgeColor: AppTheme.successGreen,
            ),
            const SizedBox(height: 10),
            _buildTrustItem(
              icon: Icons.lock_outline_rounded,
              color: AppTheme.accentPurple,
              title: '100% Private & Secure',
              subtitle: 'Instant server purge with zero data retention',
              badge: 'Secure',
              badgeColor: AppTheme.accentPurple,
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
