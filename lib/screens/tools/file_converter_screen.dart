import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class ConverterTypeOption {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> allowedExtensions;
  final String target;
  final Color color;

  const ConverterTypeOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.allowedExtensions,
    required this.target,
    required this.color,
  });
}

class FileConverterScreen extends StatefulWidget {
  final String initialTarget;
  const FileConverterScreen({super.key, this.initialTarget = 'pdf'});

  @override
  State<FileConverterScreen> createState() => _FileConverterScreenState();
}

class _FileConverterScreenState extends State<FileConverterScreen> {
  late ConverterTypeOption _selectedOption;
  List<PlatformFile> _selectedFiles = [];
  bool _isConverting = false;
  FileConversionResult? _result;
  String? _errorMessage;

  static const List<ConverterTypeOption> _options = [
    ConverterTypeOption(
      id: 'word2pdf',
      title: 'Word to PDF',
      subtitle: 'Convert .docx, .doc, .rtf, .txt to PDF',
      icon: Icons.picture_as_pdf_rounded,
      allowedExtensions: ['docx', 'doc', 'rtf', 'txt', 'odt'],
      target: 'pdf',
      color: AppTheme.accentPurple,
    ),
    ConverterTypeOption(
      id: 'pdf2word',
      title: 'PDF to Word',
      subtitle: 'Convert .pdf documents to editable .docx',
      icon: Icons.description_rounded,
      allowedExtensions: ['pdf'],
      target: 'docx',
      color: AppTheme.accentBlue,
    ),
    ConverterTypeOption(
      id: 'img2pdf',
      title: 'Image to PDF',
      subtitle: 'Combine PNG, JPG, WebP into a clean PDF',
      icon: Icons.photo_library_rounded,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
      target: 'pdf',
      color: AppTheme.accentCyan,
    ),
    ConverterTypeOption(
      id: 'pdf2jpg',
      title: 'PDF to JPG/PNG',
      subtitle: 'Extract high-resolution images from PDF pages',
      icon: Icons.image_rounded,
      allowedExtensions: ['pdf'],
      target: 'jpg',
      color: Colors.amber,
    ),
    ConverterTypeOption(
      id: 'excel2pdf',
      title: 'Excel to PDF',
      subtitle: 'Convert .xlsx, .xls spreadsheets to PDF',
      icon: Icons.table_chart_rounded,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      target: 'pdf',
      color: AppTheme.successGreen,
    ),
    ConverterTypeOption(
      id: 'ppt2pdf',
      title: 'PPT to PDF',
      subtitle: 'Convert .pptx, .ppt presentations to PDF',
      icon: Icons.slideshow_rounded,
      allowedExtensions: ['pptx', 'ppt'],
      target: 'pdf',
      color: AppTheme.accentPink,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedOption = _options.firstWhere(
      (opt) => opt.id == widget.initialTarget || opt.target == widget.initialTarget,
      orElse: () => _options.first,
    );
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _selectedOption.allowedExtensions,
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles = result.files;
          _result = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'File selection error: $e');
    }
  }

  Future<void> _convertFiles() async {
    if (_selectedFiles.isEmpty) return;

    setState(() {
      _isConverting = true;
      _errorMessage = null;
      _result = null;
    });

    final res = await ApiService.convertFile(
      files: _selectedFiles,
      target: _selectedOption.target,
    );

    if (!mounted) return;
    setState(() {
      _isConverting = false;
      if (res.success) {
        _result = res;
      } else {
        _errorMessage = res.error ?? 'Conversion failed.';
      }
    });
  }

  Future<void> _downloadResult() async {
    if (_result?.downloadUrl == null) return;
    final uri = Uri.parse(_result!.downloadUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      appBar: AppBar(
        backgroundColor: AppTheme.bgMain,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Universal Document Converter',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode Selectors Grid
            const Text(
              'Select Conversion Target',
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _options.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, idx) {
                final opt = _options[idx];
                final isSelected = _selectedOption.id == opt.id;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedOption = opt;
                      _selectedFiles = [];
                      _result = null;
                      _errorMessage = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? opt.color.withOpacity(0.15) : AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? opt.color : AppTheme.glassBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: opt.color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(opt.icon, color: opt.color, size: 20),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                opt.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected ? opt.color : AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                opt.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Upload Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: Column(
                children: [
                  Icon(_selectedOption.icon, size: 48, color: _selectedOption.color),
                  const SizedBox(height: 12),
                  Text(
                    'Upload ${_selectedOption.title.split(' ')[0]} Files',
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Supported: ${_selectedOption.allowedExtensions.map((e) => '.$e').join(', ')}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isConverting ? null : _pickFiles,
                    icon: const Icon(Icons.cloud_upload_rounded),
                    label: Text(_selectedFiles.isEmpty ? 'Choose Files' : 'Add More Files'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedOption.color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Selected Files List
            if (_selectedFiles.isNotEmpty) ...[
              const Text('Selected Documents', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedFiles.length,
                itemBuilder: (context, idx) {
                  final f = _selectedFiles[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.glassBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.insert_drive_file_rounded, color: _selectedOption.color, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            f.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                          ),
                        ),
                        Text(
                          '${(f.size / 1024).toStringAsFixed(1)} KB',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textSecondary),
                          onPressed: () {
                            setState(() {
                              _selectedFiles.removeAt(idx);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Convert Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isConverting ? null : _convertFiles,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedOption.color,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isConverting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SpinKitRing(color: Colors.white, size: 20, lineWidth: 2),
                            SizedBox(width: 12),
                            Text('Converting Documents...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        )
                      : Text(
                          'Convert ${_selectedFiles.length} File${_selectedFiles.length > 1 ? 's' : ''} to ${_selectedOption.target.toUpperCase()}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
              ),
            ],

            // Error
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentPink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accentPink.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.accentPink),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.accentPink, fontSize: 13))),
                  ],
                ),
              ),
            ],

            // Success Result
            if (_result != null && _result!.success) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.successGreen.withOpacity(0.15),
                      AppTheme.accentCyan.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.successGreen.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 28),
                        SizedBox(width: 10),
                        Text(
                          'Conversion Complete! 🎉',
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'File: ${_result!.outputName ?? _result!.filename ?? 'Converted Document'}',
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    ),
                    if (_result!.fileSize != null)
                      Text(
                        'Size: ${_result!.fileSize}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _downloadResult,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Download Converted Document'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
