import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class StockMediaScreen extends StatefulWidget {
  final bool isVideoMode;
  const StockMediaScreen({super.key, this.isVideoMode = false});

  @override
  State<StockMediaScreen> createState() => _StockMediaScreenState();
}

class _StockMediaScreenState extends State<StockMediaScreen> {
  final TextEditingController _searchController = TextEditingController();
  late bool _isVideo;
  bool _isLoading = false;
  List<dynamic> _items = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isVideo = widget.isVideoMode;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchMedia() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _items = [];
    });

    try {
      if (_isVideo) {
        final res = await ApiService.searchStockVideos(query: query);
        setState(() {
          _items = res['videos'] ?? res['results'] ?? [];
        });
      } else {
        final res = await ApiService.searchStockImages(query: query);
        setState(() {
          _items = res['images'] ?? res['results'] ?? [];
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Search error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        title: Text(
          _isVideo ? 'Stock Video Finder' : 'Stock Image Finder',
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Search & toggle
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.bgSurface,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: _isVideo ? 'Search 4K videos (e.g., Assam tea garden, river flow)...' : 'Search stock photos (e.g., Kaziranga rhino, modern office)...',
                          hintStyle: const TextStyle(color: AppTheme.textSecondary),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                          filled: true,
                          fillColor: AppTheme.bgMain,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onSubmitted: (_) => _searchMedia(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _searchMedia,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      child: const Text('Search', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Photos'),
                      selected: !_isVideo,
                      selectedColor: AppTheme.accentPurple,
                      backgroundColor: AppTheme.bgMain,
                      labelStyle: TextStyle(color: !_isVideo ? Colors.white : AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 12),
                      onSelected: (val) {
                        if (val) setState(() { _isVideo = false; _items = []; });
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Videos'),
                      selected: _isVideo,
                      selectedColor: AppTheme.accentCyan,
                      backgroundColor: AppTheme.bgMain,
                      labelStyle: TextStyle(color: _isVideo ? Colors.black : AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 12),
                      onSelected: (val) {
                        if (val) setState(() { _isVideo = true; _items = []; });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: SpinKitRing(color: AppTheme.accentPurple, size: 36, lineWidth: 3),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.accentPink)),
                      )
                    : _items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_isVideo ? Icons.videocam_outlined : Icons.image_search_rounded, size: 54, color: AppTheme.textSecondary.withOpacity(0.4)),
                                const SizedBox(height: 12),
                                Text(
                                  'Search millions of free high-res ${_isVideo ? 'stock videos' : 'photos'}',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final previewUrl = item['preview_url'] ?? item['thumbnail'] ?? item['src']?['medium'] ?? item['image'] ?? '';
                              final downloadUrl = item['download_url'] ?? item['url'] ?? item['link'] ?? previewUrl;

                              return ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (previewUrl.isNotEmpty)
                                      Image.network(
                                        previewUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(color: AppTheme.bgSurface, child: const Icon(Icons.broken_image, color: AppTheme.textSecondary)),
                                      )
                                    else
                                      Container(color: AppTheme.bgSurface),
                                    // Gradient overlay
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [
                                              Colors.black.withOpacity(0.85),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item['photographer'] ?? item['title'] ?? (_isVideo ? 'Stock Video' : 'Stock Photo'),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () async {
                                                final uri = Uri.parse(downloadUrl);
                                                if (await canLaunchUrl(uri)) {
                                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
