import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/download_service.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

const int kFreeDailyLimit = 20;
const int kMaxFileSizeMb = 25;
const int kMaxFileSizeBytes = kMaxFileSizeMb * 1024 * 1024;

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}

String getTodayUsageKey() {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  return 'axom_ic_usage_$today';
}

class ImageCompressorScreen extends StatefulWidget {
  const ImageCompressorScreen({super.key});

  @override
  State<ImageCompressorScreen> createState() => _ImageCompressorScreenState();
}

class _ImageCompressorScreenState extends State<ImageCompressorScreen> {
  double _quality = 70; // 50 (Max), 70 (Balanced), 85 (Light)
  bool _isPro = false;
  int _dailyUsage = 0;

  List<PlatformFile> _selectedImages = [];
  bool _isCompressing = false;
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
      _selectedImages = [];
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

  Future<void> _pickImages() async {
    setState(() => _errorMessage = null);

    if (!_isPro && _dailyUsage >= kFreeDailyLimit) {
      setState(() {
        _errorMessage =
            'Daily free limit reached ($kFreeDailyLimit/$kFreeDailyLimit images). Please upgrade to Pro.';
      });
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'jfif'],
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final valid = <PlatformFile>[];
      for (final f in result.files) {
        if (f.size > kMaxFileSizeBytes) {
          setState(() {
            _errorMessage =
                'Image "${f.name}" exceeds the ${kMaxFileSizeMb}MB limit.';
          });
          return;
        }
        valid.add(f);
      }

      setState(() {
        _selectedImages = valid;
        _result = null;
        _errorMessage = null;
        _downloadResult = null;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Could not select images: $e');
    }
  }

  Future<void> _compressImages() async {
    if (_selectedImages.isEmpty) return;

    if (!_isPro && _dailyUsage >= kFreeDailyLimit) {
      setState(() {
        _errorMessage =
            'Daily free limit reached ($kFreeDailyLimit/$kFreeDailyLimit images). Upgrade to Pro for unlimited compressions.';
      });
      return;
    }

    setState(() {
      _isCompressing = true;
      _errorMessage = null;
      _result = null;
      _progressMsg = 'Reading & analyzing image pixels...';
      _downloadResult = null;
    });

    _timer1 = Timer(const Duration(milliseconds: 1200), () {
      if (mounted && _isCompressing) {
        setState(() => _progressMsg = 'Optimizing color palette & compression tables...');
      }
    });

    _timer2 = Timer(const Duration(milliseconds: 2800), () {
      if (mounted && _isCompressing) {
        setState(() => _progressMsg = 'Finalizing compressed output...');
      }
    });

    try {
      final res = await ApiService.convertFile(
        files: _selectedImages,
        target: 'compress',
        quality: _quality.toInt().toString(),
      );

      _timer1?.cancel();
      _timer2?.cancel();

      if (!mounted) return;

      if (res.limitReached) {
        setState(() {
          _isCompressing = false;
          _errorMessage =
              'Daily limit reached ($kFreeDailyLimit/$kFreeDailyLimit images). Upgrade to Pro for unlimited compressions.';
        });
        _showUpgradeModal();
        return;
      }

      if (res.success && res.downloadUrl != null) {
        await _incrementDailyUsage();
        setState(() {
          _isCompressing = false;
          _result = res;
        });

        _autoDownloadResult(res);
      } else {
        setState(() {
          _isCompressing = false;
          _errorMessage = res.error ?? 'Compression failed. Please try again.';
        });
      }
    } catch (e) {
      _timer1?.cancel();
      _timer2?.cancel();
      if (mounted) {
        setState(() {
          _isCompressing = false;
          _errorMessage = 'An error occurred during compression: $e';
        });
      }
    }
  }

  Future<void> _autoDownloadResult(FileConversionResult res) async {
    final dlUrl = res.downloadUrl;
    if (dlUrl == null) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.05;
      _downloadStatusMsg = 'Preparing compressed image...';
    });

    final isBatch = _selectedImages.length > 1;
    final filename = res.outputName ??
        (isBatch
            ? 'compressed_images.zip'
            : 'compressed_${_selectedImages.first.name}');

    final downloadRes = await DownloadService.downloadToAppStorage(
      rawUrl: dlUrl,
      preferredFilename: filename,
      onProgress: (p, msg) {
        if (mounted) {
          setState(() {
            _downloadProgress = p;
            _downloadStatusMsg = msg;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isDownloading = false;
        _downloadResult = downloadRes;
      });
    }
  }

  Future<void> _saveWithNativeDialog() async {
    if (_result == null || _result!.downloadUrl == null) return;

    final isBatch = _selectedImages.length > 1;
    final defaultName = _result!.outputName ??
        (isBatch
            ? 'axom_compressed_images.zip'
            : 'axom_compressed_${_selectedImages.first.name}');

    if (_downloadResult == null || !_downloadResult!.success || _downloadResult!.filePath == null) {
      await _autoDownloadResult(_result!);
    }

    if (_downloadResult != null && _downloadResult!.filePath != null) {
      await DownloadService.promptNativeSaveDialog(
        filePath: _downloadResult!.filePath!,
        fileName: defaultName,
        isBatch: isBatch,
        customExtension: isBatch ? 'zip' : 'jpg',
      );
    }
  }

  Future<void> _openImageFile() async {
    final dlUrl = _result?.downloadUrl ?? '';
    final filePath = _downloadResult?.filePath;

    if (filePath == null) {
      if (dlUrl.isNotEmpty) {
        await DownloadService.openInGoogleDriveViewer(dlUrl);
      }
      return;
    }

    final openRes = await DownloadService.openFile(filePath);
    if (openRes.type != ResultType.done && mounted) {
      if (dlUrl.isNotEmpty) {
        await DownloadService.openInGoogleDriveViewer(dlUrl);
      }
    }
  }

  Future<void> _shareImageFile() async {
    final filePath = _downloadResult?.filePath;
    if (filePath != null) {
      await DownloadService.shareFile(
        filePath,
        text: 'Compressed with Axom AI Image Compressor ⭐',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait, preparing file for sharing...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showUpgradeModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildUpgradeSheet(),
    );
  }

  Widget _buildUpgradeSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppTheme.bgCard : Colors.white;
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final textSecondary = isDark ? AppTheme.textSecondary : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Color(0xFFF59E0B), size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            'Daily Limit Reached',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Free accounts are limited to $kFreeDailyLimit image compressions per day. Upgrade to Axom AI Pro for unlimited batch compression, 100MB file limits, and instant priority encoding.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: textSecondary, height: 1.45),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Razorpay integration is active on web. Subscription syncing to app...'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Upgrade to Pro — ₹99/month',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCol = isDark ? AppTheme.bgDark : const Color(0xFFF8FAFC);
    final cardBg = isDark ? AppTheme.bgCard : Colors.white;
    final borderCol = isDark ? AppTheme.borderColor : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? AppTheme.textSecondary : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgCol,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Image Compressor',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            Text(
              'Lossless JPEG, PNG & WebP Reducer',
              style: TextStyle(
                fontSize: 11,
                color: textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderCol, height: 1),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderCol),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.electric_bolt_rounded,
                  size: 14,
                  color: _isPro
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 4),
                Text(
                  _isPro
                      ? 'Pro VIP'
                      : '${kFreeDailyLimit - _dailyUsage} left',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── ERROR BANNER ──────────────────────────────────────────
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ─── UPLOAD ZONE ───────────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _selectedImages.isNotEmpty
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                      : borderCol,
                  width: _selectedImages.isNotEmpty ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (_selectedImages.isEmpty) ...[
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.photo_size_select_small_rounded,
                          color: Color(0xFFF59E0B),
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Select Images to Compress',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Supports JPG, PNG, WebP • Up to ${kMaxFileSizeMb}MB per file • Single or Batch',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, color: textSecondary),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _pickImages,
                          icon: const Icon(Icons.add_photo_alternate_rounded,
                              size: 18),
                          label: const Text('Choose Image(s)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFF59E0B),
                            side:
                                const BorderSide(color: Color(0xFFF59E0B)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // File header
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.image_rounded,
                              color: Color(0xFFF59E0B),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedImages.length == 1
                                      ? _selectedImages.first.name
                                      : '${_selectedImages.length} Images Selected',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Total: ${formatBytes(_selectedImages.fold<int>(0, (sum, f) => sum + f.size))}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            color: textSecondary,
                            onPressed: _resetAll,
                            tooltip: 'Clear',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // If multiple, show small pill list
                      if (_selectedImages.length > 1) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined,
                                  size: 15, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Output will be packaged into a clean ZIP archive.',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Compression Quality Selector
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF131D31)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderCol),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Compression Level',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${_quality.toInt()}% Quality',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Presets
                            Row(
                              children: [
                                _buildQualityPresetChip(
                                    'Balanced (70%)', 70, isDark),
                                const SizedBox(width: 8),
                                _buildQualityPresetChip(
                                    'Extreme (50%)', 50, isDark),
                                const SizedBox(width: 8),
                                _buildQualityPresetChip(
                                    'Light (85%)', 85, isDark),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Fine tune slider
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFFF59E0B),
                                inactiveTrackColor: borderCol,
                                thumbColor: const Color(0xFFF59E0B),
                                overlayColor: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.2),
                                trackHeight: 3,
                              ),
                              child: Slider(
                                value: _quality,
                                min: 20,
                                max: 95,
                                divisions: 15,
                                onChanged: (val) {
                                  setState(() => _quality = val);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Compress Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isCompressing ? null : _compressImages,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isCompressing
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SpinKitRing(
                                      color: Colors.white,
                                      size: 20,
                                      lineWidth: 2.2,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _progressMsg.isNotEmpty
                                          ? _progressMsg
                                          : 'Compressing...',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                        Icons.auto_fix_high_rounded,
                                        size: 19),
                                    const SizedBox(width: 8),
                                    Text(
                                      _selectedImages.length == 1
                                          ? 'Compress Image Now'
                                          : 'Compress ${_selectedImages.length} Images Now',
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ─── RESULT CARD ───────────────────────────────────────────
            if (_result != null && _result!.success) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFF10B981).withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Compression Completed!',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _result!.savedPercent != null &&
                                        _result!.savedPercent! > 0
                                    ? 'Saved ${_result!.savedPercent!.toStringAsFixed(0)}% storage space ⭐'
                                    : 'Optimized image successfully',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Metrics Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF131D31)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderCol),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          if (_result!.origSizeBytes != null) ...[
                            _buildSizeMetric(
                              'Original',
                              formatBytes(_result!.origSizeBytes!),
                              textSecondary,
                              textPrimary,
                            ),
                            Container(
                                width: 1, height: 26, color: borderCol),
                          ],
                          _buildSizeMetric(
                            'Optimized',
                            _result!.fileSize ?? 'Available',
                            textSecondary,
                            const Color(0xFF10B981),
                          ),
                          if (_result!.savedPercent != null &&
                              _result!.savedPercent! > 0) ...[
                            Container(
                                width: 1, height: 26, color: borderCol),
                            _buildSizeMetric(
                              'Reduced',
                              '-${_result!.savedPercent!.toStringAsFixed(0)}%',
                              textSecondary,
                              const Color(0xFFF59E0B),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    if (_isDownloading) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
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
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _downloadStatusMsg,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(_downloadProgress * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _downloadProgress,
                                backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],


                    // Action 1: Native Storage Access Framework Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _saveWithNativeDialog,
                        icon: const Icon(Icons.download_rounded, size: 20),
                        label: const Text(
                          'Save to Device (SAF Modal)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Action 2 & 3: Open Image Chooser & Share
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openImageFile,
                            icon: const Icon(Icons.visibility_rounded, size: 17),
                            label: const Text('Open / View'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textPrimary,
                              side: BorderSide(color: borderCol),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 11),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _shareImageFile,
                            icon: const Icon(Icons.share_rounded, size: 17),
                            label: const Text('Share'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textPrimary,
                              side: BorderSide(color: borderCol),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ─── 1 CARD PER ROW TRUST HIGHLIGHTS ───────────────────────
            Text(
              'Why Axom AI Image Compressor',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            _buildFeatureCard(
              icon: Icons.high_quality_rounded,
              color: const Color(0xFFF59E0B),
              title: 'Visual Quality Retention',
              description:
                  'Proprietary perceptual color optimization retains edge sharpness and fine photographic details.',
              isDark: isDark,
              cardBg: cardBg,
              borderCol: borderCol,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 10),

            _buildFeatureCard(
              icon: Icons.layers_outlined,
              color: const Color(0xFF10B981),
              title: 'Universal Batch Compression',
              description:
                  'Upload multiple photos together. Fast server-side multithreading packs outputs into a clean zip.',
              isDark: isDark,
              cardBg: cardBg,
              borderCol: borderCol,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 10),

            _buildFeatureCard(
              icon: Icons.shield_rounded,
              color: const Color(0xFF6366F1),
              title: '100% Private & Auto-Cleaned',
              description:
                  'Uploaded images are processed in isolated memory and permanently deleted after conversion.',
              isDark: isDark,
              cardBg: cardBg,
              borderCol: borderCol,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityPresetChip(String label, double val, bool isDark) {
    final isSelected = (_quality - val).abs() < 5;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _quality = val),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFF59E0B)
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFF59E0B)
                  : (isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFCBD5E1)),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : const Color(0xFF334155)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSizeMetric(
      String title, String val, Color labelColor, Color valColor) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 11, color: labelColor)),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(
              fontSize: 13.5, fontWeight: FontWeight.bold, color: valColor),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required bool isDark,
    required Color cardBg,
    required Color borderCol,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
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
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
