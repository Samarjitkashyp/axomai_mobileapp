import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class MemeGeneratorScreen extends StatefulWidget {
  const MemeGeneratorScreen({super.key});

  @override
  State<MemeGeneratorScreen> createState() => _MemeGeneratorScreenState();
}

class _MemeGeneratorScreenState extends State<MemeGeneratorScreen> {
  final TextEditingController _topTextController =
      TextEditingController(text: 'WHEN AXOM AI WRITES IN ASSAMESE');
  final TextEditingController _bottomTextController =
      TextEditingController(text: 'PURE MASTERPIECE 🔥');

  int _selectedTemplateIndex = 0;

  final List<String> _templates = [
    'https://images.unsplash.com/photo-1534361960057-19889db9621e?q=80&w=600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1517849845537-4d257902454a?q=80&w=600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?q=80&w=600&auto=format&fit=crop',
  ];

  @override
  void dispose() {
    _topTextController.dispose();
    _bottomTextController.dispose();
    super.dispose();
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
          'Meme Generator',
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
            // Live Meme Preview Canvas
            Container(
              height: 260,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      _templates[_selectedTemplateIndex],
                      fit: BoxFit.cover,
                    ),
                    // Top Text Overlay
                    Positioned(
                      top: 14,
                      left: 14,
                      right: 14,
                      child: Text(
                        _topTextController.text.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1,
                          shadows: [
                            Shadow(
                              offset: const Offset(2, 2),
                              blurRadius: 4,
                              color: Colors.black.withValues(alpha: 0.9),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Bottom Text Overlay
                    Positioned(
                      bottom: 14,
                      left: 14,
                      right: 14,
                      child: Text(
                        _bottomTextController.text.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1,
                          shadows: [
                            Shadow(
                              offset: const Offset(2, 2),
                              blurRadius: 4,
                              color: Colors.black.withValues(alpha: 0.9),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Template Selector Row
            const Text(
              'Choose Template',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(_templates.length, (index) {
                final isSelected = _selectedTemplateIndex == index;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedTemplateIndex = index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.accentPink
                            : AppTheme.borderColor,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.network(
                        _templates[index],
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 18),

            // Text Inputs
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _topTextController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                        fontSize: 13.5, color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Top Text',
                      labelStyle: TextStyle(
                          color: AppTheme.textMuted, fontSize: 13),
                      border: InputBorder.none,
                    ),
                  ),
                  const Divider(color: AppTheme.borderColor),
                  TextField(
                    controller: _bottomTextController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                        fontSize: 13.5, color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Bottom Text',
                      labelStyle: TextStyle(
                          color: AppTheme.textMuted, fontSize: 13),
                      border: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Export Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Export & Share Meme',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Meme saved to Gallery!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
