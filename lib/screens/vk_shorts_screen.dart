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

  @override
  bool get wantKeepAlive => true; 

  @override
  void initState() {
    super.initState();
    loadInitialVideos();
  }

  Future<void> loadInitialVideos() async {
    setState(() => _isLoading = true);
    await ConfigService.ready;
    final videos = await VkService.fetchVideosFromWall();
    if (mounted) {
      setState(() {
        _videoUrls = videos;
        _isLoading = false;
        _isInit = true;
      });
    }
  }

  Future<void> loadMoreVideos() async {
    await ConfigService.ready;
    final newVideos = await VkService.fetchVideosFromWall();
    if (mounted) {
      setState(() {
        final currentSet = _videoUrls.toSet();
        _videoUrls.addAll(newVideos.where((v) => !currentSet.contains(v)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
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
        child: IconButton(
          icon: const Icon(Icons.refresh),
          color: Colors.white,
          onPressed: loadInitialVideos,
        ),
      );
    }
    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller: _pageController,
      itemCount: _videoUrls.length,
      onPageChanged: (index) {
        if (index >= _videoUrls.length - 2) loadMoreVideos();
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

  /// Метод преобразует ссылку плеера (video_ext.php) в ссылку на клип/видео,
  /// которую понимает нативное приложение VK.
  String _fixVkUrl(String url) {
    // Если ссылка уже нормальная (vk.com/clip... или vk.com/video...), возвращаем как есть
    if (url.contains('vk.com/clip') || url.contains('vk.com/video') && !url.contains('video_ext.php')) {
      return url;
    }

    try {
      // Пытаемся вытащить параметры oid (owner_id) и id (video_id) из ссылки
      // Формат обычно: https://vk.com/video_ext.php?oid=-123456&id=789012&...
      final uri = Uri.parse(url);
      final oid = uri.queryParameters['oid'];
      final id = uri.queryParameters['id'];

      if (oid != null && id != null) {
        // Собираем ссылку, которая 100% открывается в приложении
        // Используем /clip, так как экран называется "Shorts"
        return 'https://vk.com/clip${oid}_$id';
      }
    } catch (e) {
      debugPrint('Error parsing VK url: $e');
    }

    // Если распарсить не удалось, возвращаем оригинал (откроется в браузере)
    return url;
  }

  Future<void> _openInVkApp() async {
    // 1. Сначала чистим URL
    final String cleanUrl = _fixVkUrl(widget.url);
    final Uri uri = Uri.parse(cleanUrl);

    debugPrint('Opening VK URL: $cleanUrl'); // Для отладки

    try {
      // 2. Пробуем открыть внешнее приложение (LaunchMode.externalApplication)
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        // 3. Fallback: если приложения нет или ссылка "кривая", открываем в браузере
        await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      }
    } catch (e) {
      debugPrint("Ошибка запуска VK: $e");
      // Последний шанс - открыть как есть
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
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.9), Colors.transparent],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _openInVkApp,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text("Открыть в VK", style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCCFF00),
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
