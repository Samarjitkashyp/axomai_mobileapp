import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class ScreenshotToCodeScreen extends StatefulWidget {
  const ScreenshotToCodeScreen({super.key});

  @override
  State<ScreenshotToCodeScreen> createState() => _ScreenshotToCodeScreenState();
}

class _ScreenshotToCodeScreenState extends State<ScreenshotToCodeScreen> {
  PlatformFile? _selectedImage;
  String _selectedFramework = 'HTML / Tailwind CSS';
  bool _isGenerating = false;
  String? _generatedCode;
  String? _errorMessage;

  final List<String> _frameworks = [
    'HTML / Tailwind CSS',
    'Flutter (Dart Widget)',
    'React (JSX + Tailwind)',
    'Vue.js',
    'SwiftUI (iOS)',
  ];

  Future<void> _pickScreenshot() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedImage = result.files.first;
          _generatedCode = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'File selection error: $e');
    }
  }

  Future<void> _extractCode() async {
    if (_selectedImage == null) return;

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _generatedCode = null;
    });

    final res = await ApiService.screenshotToCode(
      file: _selectedImage!,
      framework: _selectedFramework,
    );

    if (!mounted) return;
    setState(() {
      _isGenerating = false;
      if (res['success'] == true || res['code'] != null) {
        _generatedCode = res['code'] ?? res['result'];
      } else {
        _errorMessage = res['error'] ?? 'Failed to convert screenshot to code.';
      }
    });
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
        title: const Text('Screenshot to Code', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentPurple.withOpacity(0.15),
                    Colors.indigo.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.accentPurple.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.code_rounded, color: AppTheme.accentPurple, size: 30),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Visual UI Decompiler', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 4),
                        Text('Upload any screenshot of a website or mobile app to generate clean responsive UI code.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Framework selector
            const Text('Target Framework', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedFramework,
                  isExpanded: true,
                  dropdownColor: AppTheme.bgSurface,
                  items: _frameworks.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedFramework = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Image Upload Box
            GestureDetector(
              onTap: _pickScreenshot,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedImage != null ? AppTheme.accentPurple : AppTheme.glassBorder,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedImage != null ? Icons.image_rounded : Icons.add_photo_alternate_outlined,
                      size: 44,
                      color: _selectedImage != null ? AppTheme.accentPurple : AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selectedImage != null ? _selectedImage!.name : 'Click to select screenshot (PNG, JPG)',
                      style: TextStyle(
                        color: _selectedImage != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Generate Button
            if (_selectedImage != null)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isGenerating ? null : _extractCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isGenerating
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SpinKitRing(color: Colors.white, size: 20, lineWidth: 2),
                            SizedBox(width: 12),
                            Text('Analyzing layout and generating code...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bolt_rounded, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Decompile UI to Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                ),
              ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentPink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accentPink.withOpacity(0.3)),
                ),
                child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.accentPink, fontSize: 13)),
              ),
            ],

            // Generated Code Box
            if (_generatedCode != null) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Generated $_selectedFramework Code', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: AppTheme.accentPurple, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _generatedCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied to clipboard!')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.glassBorder),
                ),
                child: SelectableText(
                  _generatedCode!,
                  style: const TextStyle(color: Color(0xFF38BDF8), fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
