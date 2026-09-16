import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../theme/app_theme.dart';

class BackgroundRemoverScreen extends StatefulWidget {
  const BackgroundRemoverScreen({super.key});

  @override
  State<BackgroundRemoverScreen> createState() =>
      _BackgroundRemoverScreenState();
}

class _BackgroundRemoverScreenState extends State<BackgroundRemoverScreen> {
  bool _hasImage = false;
  bool _isProcessing = false;
  bool _isDone = false;

  void _simulatePickImage() {
    setState(() {
      _hasImage = true;
      _isDone = false;
    });
  }

  Future<void> _handleRemoveBg() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _isDone = true;
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'AI Background Remover',
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
            // Upload / Preview Box
            InkWell(
              onTap: _isProcessing ? null : _simulatePickImage,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 280,
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _hasImage
                        ? AppTheme.accentCyan
                        : AppTheme.borderColor,
                    width: 1.5,
                  ),
                ),
                child: !_hasImage
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded,
                              size: 48, color: AppTheme.accentCyan),
                          SizedBox(height: 12),
                          Text(
                            'Tap to choose a photo',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Supports JPG, PNG, WEBP up to 20MB',
                            style: TextStyle(
                                fontSize: 11.5, color: AppTheme.textMuted),
                          ),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Checkerboard transparency pattern when cutout done
                            if (_isDone)
                              CustomPaint(
                                painter: _CheckerboardPainter(),
                              ),
                            Image.network(
                              'https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=600&auto=format&fit=crop',
                              fit: BoxFit.cover,
                            ),
                            if (_isProcessing)
                              Container(
                                color: Colors.black.withValues(alpha: 0.6),
                                alignment: Alignment.center,
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SpinKitFadingCircle(
                                        color: AppTheme.accentCyan, size: 40),
                                    SizedBox(height: 12),
                                    Text(
                                      'Detecting subjects & removing background...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 18),

            // Action Buttons
            if (_hasImage && !_isDone)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentCyan,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isProcessing ? null : _handleRemoveBg,
                child: const Text(
                  'Remove Background with AI',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),

            if (_isDone) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Download Transparent PNG',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Cutout saved to Gallery!')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.borderColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      setState(() {
                        _hasImage = false;
                        _isDone = false;
                      });
                    },
                    child: const Text('New',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 28),

            // Tips & Features
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Edge Detection',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Detects hair strands, complex fur, jewellery, and fine transparent edges with high precision.',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const squareSize = 10.0;
    final paintLight = Paint()..color = const Color(0xFF2A2D3D);
    final paintDark = Paint()..color = const Color(0xFF1E2130);

    for (double x = 0; x < size.width; x += squareSize) {
      for (double y = 0; y < size.height; y += squareSize) {
        final isEven = ((x / squareSize).floor() + (y / squareSize).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, squareSize, squareSize),
          isEven ? paintLight : paintDark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
