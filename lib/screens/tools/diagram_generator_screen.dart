import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class DiagramGeneratorScreen extends StatefulWidget {
  const DiagramGeneratorScreen({super.key});

  @override
  State<DiagramGeneratorScreen> createState() => _DiagramGeneratorScreenState();
}

class _DiagramGeneratorScreenState extends State<DiagramGeneratorScreen> {
  final TextEditingController _promptController = TextEditingController();
  String _selectedType = 'flowchart';
  bool _isGenerating = false;
  String? _diagramCode;
  String? _explanation;
  String? _errorMessage;

  final List<Map<String, String>> _types = [
    {'id': 'flowchart', 'label': 'Flowchart', 'desc': 'Processes & decision trees'},
    {'id': 'sequence', 'label': 'Sequence', 'desc': 'API & interaction lifecycles'},
    {'id': 'architecture', 'label': 'System Architecture', 'desc': 'Cloud & infra diagrams'},
    {'id': 'mindmap', 'label': 'Mind Map', 'desc': 'Concept breakdown & brainstorms'},
    {'id': 'erDiagram', 'label': 'Database ERD', 'desc': 'Tables & SQL relations'},
  ];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generateDiagram() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _diagramCode = null;
      _explanation = null;
    });

    final res = await ApiService.generateDiagram(
      prompt: prompt,
      type: _selectedType,
    );

    if (!mounted) return;
    setState(() {
      _isGenerating = false;
      if (res['success'] == true || res['mermaid'] != null) {
        _diagramCode = res['mermaid'] ?? res['diagram'] ?? res['code'];
        _explanation = res['explanation'] ?? res['description'];
      } else {
        _errorMessage = res['error'] ?? 'Failed to generate diagram.';
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
        title: const Text('AI Diagram & Flowchart Generator', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentCyan.withOpacity(0.15),
                    AppTheme.accentPurple.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.account_tree_rounded, color: AppTheme.accentCyan, size: 30),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mermaid & Architecture Synthesizer', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 4),
                        Text('Describe any process or database to get clean Mermaid diagrams and visual syntax.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Diagram Type Selector
            const Text('Diagram Style', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _types.map((t) {
                  final isSelected = _selectedType == t['id'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t['label']!),
                      selected: isSelected,
                      selectedColor: AppTheme.accentCyan,
                      backgroundColor: AppTheme.bgSurface,
                      labelStyle: TextStyle(color: isSelected ? Colors.black : AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                      onSelected: (_) => setState(() => _selectedType = t['id']!),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Prompt Input
            const Text('Describe Your Diagram', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _promptController,
              maxLines: 4,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g., User authentication flow with OAuth2, JWT verification, and Redis token refresh...',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.bgSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.accentCyan)),
              ),
            ),
            const SizedBox(height: 16),

            // Generate Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generateDiagram,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentCyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isGenerating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SpinKitRing(color: Colors.black, size: 20, lineWidth: 2),
                          SizedBox(width: 12),
                          Text('Synthesizing Diagram Structure...', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, size: 18),
                          SizedBox(width: 8),
                          Text('Generate Architecture Diagram', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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

            // Result
            if (_diagramCode != null) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Generated Mermaid Code', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: AppTheme.accentCyan, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _diagramCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Diagram code copied to clipboard!')),
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
                  _diagramCode!,
                  style: const TextStyle(color: Color(0xFF38BDF8), fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              if (_explanation != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.glassBorder),
                  ),
                  child: Text(
                    _explanation!,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
