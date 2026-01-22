import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../services/config_service.dart';
import '../services/vk_service.dart';
import '../services/favorites_service.dart';
import '../models/video_item.dart';
import '../widgets/dance_loader.dart';
import '../widgets/common_widgets.dart';

class VkShortsScreen extends StatefulWidget {
  const VkShortsScreen({super.key});

  @override
  State<VkShortsScreen> createState() => _VkShortsScreenState();
}

class _VkShortsScreenState extends State<VkShortsScreen> with AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();
  List<VideoItem> _videoItems = [];
  bool _isLoading = false;
  bool _isInit = false; 
  
  // Пагинация по группам
  int _currentBatchIndex = 0;
  bool _hasMoreGroups = true;

  @override
  bool get wantKeepAlive => true; 

  @override
  void initState() {
    super.initState();
    loadInitialVideos();
  }

  Future<void> loadInitialVideos() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _videoItems = [];
      _currentBatchIndex = 0;
      _hasMoreGroups = true;
    });

    // Сброс шафла, чтобы при обновлении порядок групп менялся
    VkService.resetVideoShuffle();
    
    await ConfigService.ready;
    final videos = await VkService.fetchVideosBatch(batchIndex: 0);

    if (mounted) {
      setState(() {
        _videoItems = videos;
        _isLoading = false;
        _isInit = true;
        if (videos.isEmpty) _hasMoreGroups = false;
      });
    }
  }

  Future<void> loadMoreVideos() async {
    if (!_hasMoreGroups || _isLoading) return;
    
    _currentBatchIndex++;
    
    // Грузим в фоне, без фуллскрин лоадера
    final newVideos = await VkService.fetchVideosBatch(batchIndex: _currentBatchIndex);
    
    if (mounted) {
      if (newVideos.isEmpty) {
        setState(() => _hasMoreGroups = false);
      } else {
        setState(() {
          final currentUrls = _videoItems.map((v) => v.url).toSet();
          _videoItems.addAll(newVideos.where((v) => !currentUrls.contains(v.url)));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Colors.black,

      extendBodyBehindAppBar: true,
      appBar: const CommonAppBar(
        title: "КЛИПЫ",
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _videoItems.isEmpty) {
      return const Center(child: DanceLoader(color: Color(0xFFCCFF00)));
    }
    if (_videoItems.isEmpty && _isInit) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Text(
              "Нет видео",
              style: GoogleFonts.unbounded(color: Colors.white),
            ),
            const SizedBox(height: 20),
            IconButton(
              icon: const Icon(Icons.refresh, size: 30),
              color: Colors.white,
              onPressed: loadInitialVideos,
            ),
          ],
        ),
      );
    }
    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller: _pageController,
      itemCount: _videoItems.length,
      onPageChanged: (index) {
        // Подгружаем, когда осталось 3 видео до конца
        if (index >= _videoItems.length - 3) {
          loadMoreVideos();
        }
      },
      itemBuilder: (context, index) {
        return _VideoCard(videoItem: _videoItems[index]);
      },
    );
  }
}

class _VideoCard extends StatefulWidget {
  final VideoItem videoItem;
  const _VideoCard({required this.videoItem});
  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  late final WebViewController _controller;
  bool _isLoaded = false;
  bool _isFavorite = false;
  bool _showInfo = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(onPageFinished: (_) {
          if (mounted) setState(() => _isLoaded = true);
        }),
      )
      ..loadRequest(Uri.parse(widget.videoItem.url));
  }

  Future<void> _loadFavoriteStatus() async {
    final isFav = await FavoritesService.isFavoriteVideo(widget.videoItem.url);
    if (mounted) {
      setState(() => _isFavorite = isFav);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await FavoritesService.removeFavoriteVideo(widget.videoItem.url);
    } else {
      await FavoritesService.addFavoriteVideo(widget.videoItem.url);
    }
    if (mounted) {
      setState(() => _isFavorite = !_isFavorite);
    }
  }

  Future<void> _shareVideo() async {
    final url = _fixVkUrl(widget.videoItem.url);
    try {
      await Share.share(url);
    } catch (e) {
      debugPrint('Error sharing: $e');
    }
  }

  String _fixVkUrl(String url) {
    if (url.contains('vk.com/clip') || url.contains('vk.com/video') && !url.contains('video_ext.php')) {
      return url;
    }
    try {
      final uri = Uri.parse(url);
      final oid = uri.queryParameters['oid'];
      final id = uri.queryParameters['id'];
      if (oid != null && id != null) {
        return 'https://vk.com/clip${oid}_$id';
      }
    } catch (e) {
      debugPrint('Error parsing VK url: $e');
    }
    return url;
  }

  Future<void> _openInVkApp() async {
    final String cleanUrl = _fixVkUrl(widget.videoItem.url);
    final Uri uri = Uri.parse(cleanUrl);

    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _showInfo = !_showInfo);
      },
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          
          if (!_isLoaded)
            const Center(child: CircularProgressIndicator(color: Color(0xFFCCFF00))),
          
          // Верхние кнопки
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _openInVkApp,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.open_in_new,
                            color: Colors.white,
                            size: 24
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _shareVideo,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.share,
                                color: Colors.white,
                                size: 24
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _toggleFavorite,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                            ),
                            child: Center(
                              child: Icon(
                                _isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: _isFavorite ? Colors.red : Colors.white,
                                size: 24
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Информация о видео (показывается по тапу)
          if (_showInfo && (widget.videoItem.title != null || widget.videoItem.description != null))
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.95), Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.videoItem.groupName != null) ...[
                        Text(
                          widget.videoItem.groupName!.toUpperCase(),
                          style: GoogleFonts.unbounded(
                            color: const Color(0xFFCCFF00),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (widget.videoItem.title != null) ...[
                        Text(
                          widget.videoItem.displayTitle,
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (widget.videoItem.description != null && widget.videoItem.description!.isNotEmpty) ...[
                        Text(
                          widget.videoItem.displayDescription,
                          style: GoogleFonts.manrope(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // Градиент снизу (всегда)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
