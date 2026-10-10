import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class AiNotesGeneratorScreen extends StatefulWidget {
  const AiNotesGeneratorScreen({super.key});

  @override
  State<AiNotesGeneratorScreen> createState() => _AiNotesGeneratorScreenState();
}

class _AiNotesGeneratorScreenState extends State<AiNotesGeneratorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _askQuestionController = TextEditingController();

  PlatformFile? _selectedFile;
  bool _isAnalyzing = false;
  bool _isGenerating = false;
  bool _isRefining = false;
  bool _isAsking = false;
  bool _isGeneratingStudyTool = false;
  bool _isExporting = false;

  String? _documentAnalysisSummary;
  String _generatedNotes = '';
  String _notesTitle = 'Comprehensive Study Notes';
  String _selectedLanguage = 'English';
  String _selectedLevel = 'College / Degree';
  String _selectedStyle = 'Comprehensive';

  // Doubt Q&A history
  final List<Map<String, String>> _doubtMessages = [];

  // Study Tools State
  String _selectedStudyTool = 'flashcards';
  dynamic _studyToolData;

  final List<String> _languages = ['English', 'Assamese', 'Bengali', 'Hindi'];
  final List<String> _levels = [
    'School (Class 9-12)',
    'College / Degree',
    'Competitive Exams (UPSC/APSC/SSC)',
    'Professional & Research',
  ];
  final List<String> _styles = [
    'Comprehensive',
    'Bullet Points & Quick Recall',
    'Exam Focused (Q&A & Formulas)',
    'Conceptual & Intuitive',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _topicController.dispose();
    _instructionsController.dispose();
    _askQuestionController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc', 'txt', 'rtf'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          _documentAnalysisSummary = null;
        });
        _analyzeDocument();
      }
    } catch (e) {
      _showSnackbar('File selection error: $e', isError: true);
    }
  }

  Future<void> _analyzeDocument() async {
    if (_selectedFile == null) return;
    setState(() => _isAnalyzing = true);

    final res = await ApiService.analyzeNotesDoc(file: _selectedFile);
    if (!mounted) return;
    setState(() => _isAnalyzing = false);

    if (res['success'] == true) {
      setState(() {
        _documentAnalysisSummary =
            "Document: ${_selectedFile!.name} • Pages: ${res['pages'] ?? 1} • Words: ~${res['words'] ?? 'N/A'} • Complexity: ${res['complexity'] ?? 'Normal'}";
      });
    }
  }

  Future<void> _generateNotes() async {
    if (_selectedFile == null && _topicController.text.trim().isEmpty) {
      _showSnackbar('Please enter a topic or upload a study document.', isError: true);
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedNotes = '';
    });

    final res = await ApiService.generateNotes(
      file: _selectedFile,
      topic: _topicController.text.trim().isNotEmpty ? _topicController.text.trim() : null,
      customInstructions: _instructionsController.text.trim().isNotEmpty ? _instructionsController.text.trim() : null,
      language: _selectedLanguage,
      level: _selectedLevel,
      style: _selectedStyle,
    );

    if (!mounted) return;
    setState(() => _isGenerating = false);

    if (res['success'] == true || res['notes'] != null) {
      final notesText = (res['notes'] ?? res['content'] ?? '').toString();
      setState(() {
        _generatedNotes = notesText;
        _notesTitle = _topicController.text.trim().isNotEmpty
            ? _topicController.text.trim()
            : (_selectedFile?.name ?? 'Study Notes');
      });
      _tabController.animateTo(1); // Switch to Generated Notes tab
      _showSnackbar('✨ Notes generated successfully!');
    } else {
      _showSnackbar(res['error'] ?? 'Failed to generate notes. Please try again.', isError: true);
    }
  }

  Future<void> _refineNotes(String action) async {
    if (_generatedNotes.trim().isEmpty) return;
    setState(() => _isRefining = true);

    final res = await ApiService.refineNotes(
      action: action,
      currentNotes: _generatedNotes,
    );

    if (!mounted) return;
    setState(() => _isRefining = false);

    if (res['success'] == true && res['refined_notes'] != null) {
      setState(() {
        _generatedNotes = res['refined_notes'];
      });
      _showSnackbar('Notes updated with $action refinement!');
    } else {
      _showSnackbar(res['error'] ?? 'Refinement failed.', isError: true);
    }
  }

  Future<void> _askDoubt() async {
    final q = _askQuestionController.text.trim();
    if (q.isEmpty || _generatedNotes.isEmpty) return;

    _askQuestionController.clear();
    setState(() {
      _doubtMessages.add({'role': 'user', 'text': q});
      _isAsking = true;
    });

    final res = await ApiService.askNotesDoubt(
      question: q,
      notesContext: _generatedNotes,
    );

    if (!mounted) return;
    setState(() {
      _isAsking = false;
      if (res['success'] == true && res['answer'] != null) {
        _doubtMessages.add({'role': 'assistant', 'text': res['answer'].toString()});
      } else {
        _doubtMessages.add({'role': 'assistant', 'text': res['error'] ?? 'Could not resolve doubt.'});
      }
    });
  }

  Future<void> _loadStudyTool(String toolType) async {
    if (_generatedNotes.trim().isEmpty) {
      _showSnackbar('Please generate notes first.', isError: true);
      return;
    }

    setState(() {
      _selectedStudyTool = toolType;
      _isGeneratingStudyTool = true;
      _studyToolData = null;
    });

    final res = await ApiService.generateStudyTools(
      toolType: toolType,
      notesContent: _generatedNotes,
    );

    if (!mounted) return;
    setState(() => _isGeneratingStudyTool = false);

    if (res['success'] == true) {
      setState(() {
        _studyToolData = res['data'] ?? res['content'] ?? res['tools'];
      });
    } else {
      _showSnackbar(res['error'] ?? 'Could not build study tool.', isError: true);
    }
  }

  Future<void> _exportToDocx() async {
    if (_generatedNotes.trim().isEmpty) return;
    setState(() => _isExporting = true);

    final res = await ApiService.exportNotesDocx(
      title: _notesTitle,
      notesMarkdown: _generatedNotes,
    );

    if (!mounted) return;
    setState(() => _isExporting = false);

    if (res['success'] == true && res['download_url'] != null) {
      final uri = Uri.parse(res['download_url']);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      _showSnackbar('📄 Word document exported!');
    } else {
      _showSnackbar(res['error'] ?? 'Export failed.', isError: true);
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? AppTheme.accentPink : AppTheme.accentPurple,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.accentPurple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_stories_rounded, color: AppTheme.accentPurple, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'AI Notes Generator',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppTheme.accentPurple,
          indicatorWeight: 3,
          labelColor: AppTheme.accentPurple,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'Create & Setup'),
            Tab(icon: Icon(Icons.article_rounded, size: 18), text: 'Notes'),
            Tab(icon: Icon(Icons.psychology_rounded, size: 18), text: 'Study Tools'),
            Tab(icon: Icon(Icons.forum_rounded, size: 18), text: 'Ask Doubts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSetupTab(),
          _buildNotesTab(),
          _buildStudyToolsTab(),
          _buildAskDoubtsTab(),
        ],
      ),
    );
  }

  // ─── TAB 1: CREATE & SETUP ─────────────────────────────────────────
  Widget _buildSetupTab() {
    return SingleChildScrollView(
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
                  AppTheme.accentCyan.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accentPurple.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPurple.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.stars_rounded, color: AppTheme.accentPurple, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedagogical Note Synthesis',
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Upload textbook chapters, syllabi, or enter a topic to create exam-ready notes.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Upload Box
          const Text('1. Upload Document or Syllabus (Optional)', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickDocument,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedFile != null ? AppTheme.accentPurple : AppTheme.glassBorder,
                  style: BorderStyle.solid,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _selectedFile != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                    color: _selectedFile != null ? AppTheme.accentPurple : AppTheme.textSecondary,
                    size: 36,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _selectedFile != null ? _selectedFile!.name : 'Click to select PDF, DOCX, or TXT file',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _selectedFile != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_selectedFile != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_isAnalyzing) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                SpinKitThreeBounce(color: AppTheme.accentPurple, size: 16),
                SizedBox(width: 8),
                Text('Analyzing document structure...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ] else if (_documentAnalysisSummary != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.accentPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _documentAnalysisSummary!,
                style: const TextStyle(color: AppTheme.accentPurple, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Topic Input
          const Text('2. Topic or Subject Name', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _topicController,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'e.g., Photosynthesis & Light Reactions in Plants',
              hintStyle: const TextStyle(color: AppTheme.textSecondary),
              filled: true,
              fillColor: AppTheme.bgSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.accentPurple)),
            ),
          ),
          const SizedBox(height: 20),

          // Options Grid
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Language', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.glassBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLanguage,
                          dropdownColor: AppTheme.bgSurface,
                          isExpanded: true,
                          items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedLanguage = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Academic Level', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.glassBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLevel,
                          dropdownColor: AppTheme.bgSurface,
                          isExpanded: true,
                          items: _levels.map((l) => DropdownMenuItem(value: l, child: Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedLevel = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Style
          const Text('Note Depth & Style', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStyle,
                dropdownColor: AppTheme.bgSurface,
                isExpanded: true,
                items: _styles.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedStyle = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Generate Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isGenerating ? null : _generateNotes,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              child: _isGenerating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SpinKitRing(color: Colors.white, size: 20, lineWidth: 2.5),
                        SizedBox(width: 12),
                        Text('Synthesizing Pedagogical Notes...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Generate AI Study Notes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 2: NOTES & REFINEMENTS ────────────────────────────────────
  Widget _buildNotesTab() {
    if (_generatedNotes.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 60, color: AppTheme.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text(
              'No Notes Generated Yet',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Head to the Create tab and tap Generate to begin.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Action Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: AppTheme.bgSurface,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildActionButton(
                  icon: Icons.compress_rounded,
                  label: 'Shorter',
                  onTap: () => _refineNotes('shorter'),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.expand_rounded,
                  label: 'Elaborate',
                  onTap: () => _refineNotes('longer'),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.lightbulb_outline_rounded,
                  label: 'Simpler',
                  onTap: () => _refineNotes('simpler'),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.star_outline_rounded,
                  label: '+ Exam Points',
                  onTap: () => _refineNotes('exam_points'),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.translate_rounded,
                  label: 'Assamese',
                  onTap: () => _refineNotes('assamese'),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.download_rounded,
                  label: 'Export Word',
                  color: AppTheme.accentCyan,
                  isLoading: _isExporting,
                  onTap: _exportToDocx,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _generatedNotes));
                    _showSnackbar('Notes copied to clipboard!');
                  },
                ),
              ],
            ),
          ),
        ),

        if (_isRefining)
          const LinearProgressIndicator(
            color: AppTheme.accentPurple,
            backgroundColor: AppTheme.bgSurface,
          ),

        // Notes Markdown Body
        Expanded(
          child: Markdown(
            data: _generatedNotes,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, height: 1.6),
              h1: const TextStyle(color: AppTheme.accentPurple, fontSize: 20, fontWeight: FontWeight.bold),
              h2: const TextStyle(color: AppTheme.accentCyan, fontSize: 17, fontWeight: FontWeight.bold),
              h3: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
              code: const TextStyle(backgroundColor: Color(0xFF1E293B), color: Color(0xFF38BDF8), fontFamily: 'monospace'),
              blockquoteDecoration: BoxDecoration(
                color: AppTheme.accentPurple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: const Border(left: BorderSide(color: AppTheme.accentPurple, width: 4)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppTheme.accentPurple,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SpinKitRing(color: color, size: 14, lineWidth: 2)
            else
              Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ─── TAB 3: STUDY TOOLS (FLASHCARDS, QUIZ, MINDMAP) ────────────────
  Widget _buildStudyToolsTab() {
    return Column(
      children: [
        // Selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppTheme.bgSurface,
          child: Row(
            children: [
              Expanded(
                child: _buildToolSelectorChip('Flashcards', 'flashcards', Icons.style_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildToolSelectorChip('MCQ Quiz', 'quiz', Icons.quiz_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildToolSelectorChip('Mind Map', 'mindmap', Icons.account_tree_rounded),
              ),
            ],
          ),
        ),

        // Body
        Expanded(
          child: _isGeneratingStudyTool
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SpinKitFadingCube(color: AppTheme.accentPurple, size: 36),
                      SizedBox(height: 16),
                      Text('Generating interactive study tools...', style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : _studyToolData == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, size: 48, color: AppTheme.textSecondary.withOpacity(0.5)),
                          const SizedBox(height: 12),
                          const Text('Select a study tool above to synthesize', style: TextStyle(color: AppTheme.textSecondary)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _loadStudyTool(_selectedStudyTool),
                            icon: const Icon(Icons.bolt_rounded),
                            label: Text('Generate $_selectedStudyTool'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentPurple),
                          ),
                        ],
                      ),
                    )
                  : _buildStudyToolContent(),
        ),
      ],
    );
  }

  Widget _buildToolSelectorChip(String label, String type, IconData icon) {
    final isSelected = _selectedStudyTool == type;
    return InkWell(
      onTap: () => _loadStudyTool(type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentPurple : AppTheme.bgMain,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppTheme.accentPurple : AppTheme.glassBorder),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : AppTheme.textSecondary),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildStudyToolContent() {
    if (_selectedStudyTool == 'mindmap') {
      final text = _studyToolData.toString();
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mermaid Mind Map Structure', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.glassBorder),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    text,
                    style: const TextStyle(color: Color(0xFF38BDF8), fontFamily: 'monospace', fontSize: 13),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  _showSnackbar('Mermaid syntax copied! Paste into Mermaid Live Editor.');
                },
                icon: const Icon(Icons.copy_rounded, color: AppTheme.accentCyan),
                label: const Text('Copy Mermaid Syntax', style: TextStyle(color: AppTheme.accentCyan)),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Markdown(
        data: _studyToolData is String ? _studyToolData : _studyToolData.toString(),
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, height: 1.5),
          h2: const TextStyle(color: AppTheme.accentPurple, fontSize: 16, fontWeight: FontWeight.bold),
          listBullet: const TextStyle(color: AppTheme.accentCyan),
        ),
      ),
    );
  }

  // ─── TAB 4: ASK DOUBTS ─────────────────────────────────────────────
  Widget _buildAskDoubtsTab() {
    return Column(
      children: [
        Expanded(
          child: _doubtMessages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.help_outline_rounded, size: 48, color: AppTheme.textSecondary.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      const Text('Ask any doubt about the generated notes', style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _doubtMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _doubtMessages[index];
                    final isUser = msg['role'] == 'user';
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                        decoration: BoxDecoration(
                          color: isUser ? AppTheme.accentPurple : AppTheme.bgSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isUser ? Colors.transparent : AppTheme.glassBorder),
                        ),
                        child: Text(
                          msg['text'] ?? '',
                          style: TextStyle(color: isUser ? Colors.white : AppTheme.textPrimary, fontSize: 14),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Input bar
        Container(
          padding: const EdgeInsets.all(12),
          color: AppTheme.bgSurface,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _askQuestionController,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ask a doubt regarding this chapter...',
                    hintStyle: const TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.bgMain,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _askDoubt(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: _isAsking
                    ? const SpinKitRing(color: AppTheme.accentPurple, size: 20, lineWidth: 2)
                    : const Icon(Icons.send_rounded, color: AppTheme.accentPurple),
                onPressed: _isAsking ? null : _askDoubt,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
