import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../theme/app_theme.dart';

class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  final TextEditingController _contentController =
      TextEditingController(text: 'https://chat.aiaxom.co.in');
  Color _qrColor = Colors.white;

  final List<Color> _availableColors = [
    Colors.white,
    AppTheme.accentPurple,
    AppTheme.accentCyan,
    AppTheme.accentPink,
    AppTheme.successGreen,
    Colors.amber,
  ];

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qrData = _contentController.text.trim();

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
          'QR Code Generator',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Interactive QR Canvas Card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06060B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _qrColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: qrData.isNotEmpty
                        ? QrImageView(
                            data: qrData,
                            version: QrVersions.auto,
                            size: 190.0,
                            eyeStyle: QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: _qrColor,
                            ),
                            dataModuleStyle: QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: _qrColor,
                            ),
                          )
                        : const SizedBox(
                            width: 190,
                            height: 190,
                            child: Center(
                              child: Text(
                                'Enter URL or text below',
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 13),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Scan with any smartphone camera',
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Content Input Field
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'QR Content / Link',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _contentController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                        fontSize: 13.5, color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'https://...',
                      hintStyle:
                          TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      prefixIcon: Icon(Icons.link_rounded,
                          size: 18, color: AppTheme.textSecondary),
                      border: InputBorder.none,
                    ),
                  ),
                  const Divider(color: AppTheme.borderColor),
                  const SizedBox(height: 4),
                  const Text(
                    'QR Color Accent',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: _availableColors.map((color) {
                      final isSelected = _qrColor == color;
                      return GestureDetector(
                        onTap: () => setState(() => _qrColor = color),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.6),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Download & Share Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentPurple,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.download_rounded,
                        size: 18, color: Colors.white),
                    label: const Text('Save to Gallery',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white)),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('QR Code saved to photo album!')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.borderColor),
                    padding: const EdgeInsets.symmetric(
                        vertical: 13, horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied link to clipboard!')),
                    );
                  },
                  child: const Icon(Icons.share_rounded,
                      size: 18, color: AppTheme.textPrimary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
