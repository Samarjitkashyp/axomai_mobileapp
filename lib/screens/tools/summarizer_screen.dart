import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../theme/app_theme.dart';

class SummarizerScreen extends StatefulWidget {
  const SummarizerScreen({super.key});

  @override
  State<SummarizerScreen> createState() => _SummarizerScreenState();
}

class _SummarizerScreenState extends State<SummarizerScreen> {
  final TextEditingController _inputController = TextEditingController();
  String _summaryLength = 'Key Highlights';
  bool _isSummarizing = false;
  String? _summaryResult;
  bool _copied = false;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _handleSummarize() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSummarizing = true;
      _summaryResult = null;
    });

    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    setState(() {
      _isSummarizing = false;
      _summaryResult = """### মূল সাৰাংশ (Key Summary)

• **প্ৰধান বিষয়**: অসমৰ অৰ্থনৈতিক আৰু সাংস্কৃতিক উন্নয়নৰ শেহতীয়া অগ্ৰগতি।
• **বিশেষ পদক্ষেপ**: ডিজিটেল আন্তঃগাঁথনি আৰু গ্ৰাম্য সংযোগ ব্যৱস্থাৰ সম্প্ৰসাৰণ।
• **প্ৰভাৱ**: স্থানীয় নিবনুৱা সমস্যা সমাধান আৰু উদ্যোগৰ বাবে নতুন সুযোগৰ সৃষ্টি।
• **ভৱিষ্যত পৰিকল্পনা**: পৰ্যটন আৰু তথ্যপ্ৰযুক্তি খণ্ডত ৰাজ্য চৰকাৰৰ বিশেষ গুৰুত্ব।""";
    });
  }

  void _handleCopy() {
    if (_summaryResult == null) return;
    Clipboard.setData(ClipboardData(text: _summaryResult!));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
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
          'AI Text Summarizer',
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
            // Text Area Container
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
                    'Input Text or Essay',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _inputController,
                    maxLines: 6,
                    style: const TextStyle(
                        fontSize: 13.5, color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText:
                          'Paste your Assamese or English article, news, or report here...',
                      hintStyle:
                          TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      border: InputBorder.none,
                    ),
                  ),
                  const Divider(color: AppTheme.borderColor),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Wrap(
                        spacing: 6,
                        children: [
                          _buildLengthChip('Brief'),
                          _buildLengthChip('Key Highlights'),
                          _buildLengthChip('Detailed'),
                        ],
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.clear_all_rounded, size: 16),
                        label: const Text('Clear',
                            style: TextStyle(fontSize: 12)),
                        onPressed: () => _inputController.clear(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Summarize Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSummarizing ? null : _handleSummarize,
              child: _isSummarizing
                  ? const SpinKitRing(
                      color: Colors.white, size: 18, lineWidth: 2)
                  : const Text(
                      'Summarize in Assamese',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
            ),

            // Summary Result Card
            if (_summaryResult != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppTheme.accentPurple.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                size: 16, color: AppTheme.accentPink),
                            SizedBox(width: 8),
                            Text(
                              'Assamese AI Summary',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentPink,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: _handleCopy,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  _copied ? Icons.check : Icons.copy_rounded,
                                  size: 14,
                                  color: _copied
                                      ? AppTheme.successGreen
                                      : AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _copied ? 'Copied!' : 'Copy',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _copied
                                        ? AppTheme.successGreen
                                        : AppTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _summaryResult!,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: AppTheme.textPrimary,
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

  Widget _buildLengthChip(String label) {
    final isSelected = _summaryLength == label;
    return InkWell(
      onTap: () => setState(() => _summaryLength = label),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentBlue.withValues(alpha: 0.2)
              : AppTheme.bgPill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.accentBlue : AppTheme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppTheme.accentBlue : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
