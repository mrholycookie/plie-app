import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../services/config_service.dart';
import '../services/vk_service.dart';
import '../widgets/dance_loader.dart';

class VkShortsScreen extends StatefulWidget {
  const VkShortsScreen({super.key});

  @override
  State<VkShortsScreen> createState() => _VkShortsScreenState();
}

class _VkShortsScreenState extends State<VkShortsScreen> with AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();
  List<String> _videoUrls = [];
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
      _videoUrls = [];
      _currentBatchIndex = 0;
      _hasMoreGroups = true;
    });

    // Сброс шафла, чтобы при обновлении порядок групп менялся
    VkService.resetVideoShuffle();
    
    await ConfigService.ready;
    final videos = await VkService.fetchVideosBatch(batchIndex: 0);

    if (mounted) {
      setState(() {
        _videoUrls = videos;
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
          final currentSet = _videoUrls.toSet();
          _videoUrls.addAll(newVideos.where((v) => !currentSet.contains(v)));
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
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        title: Text(
          "КЛИПЫ",
          style: GoogleFonts.unbounded(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _videoUrls.isEmpty) {
      return const Center(child: DanceLoader(color: Color(0xFFCCFF00)));
    }
    if (_videoUrls.isEmpty && _isInit) {
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
      itemCount: _videoUrls.length,
      onPageChanged: (index) {
        // Подгружаем, когда осталось 3 видео до конца
        if (index >= _videoUrls.length - 3) {
          loadMoreVideos();
        }
      },
      itemBuilder: (context, index) {
        return _VideoCard(url: _videoUrls[index]);
      },
    );
  }
}

class _VideoCard extends StatefulWidget {
  final String url;
  const _VideoCard({required this.url});
  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  late final WebViewController _controller;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(onPageFinished: (_) {
          if (mounted) setState(() => _isLoaded = true);
        }),
      )
      ..loadRequest(Uri.parse(widget.url));
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
    final String cleanUrl = _fixVkUrl(widget.url);
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
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        
        if (!_isLoaded)
          const Center(child: CircularProgressIndicator(color: Color(0xFFCCFF00))),
        
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0), 
              child: GestureDetector(
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
            ),
          ),
        ),

        Positioned(
          bottom: 0, left: 0, right: 0,
          child: IgnorePointer(
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
