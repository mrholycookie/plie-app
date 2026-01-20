import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // Для открытия внешнего приложения
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
  bool _isInit = false; // Флаг: загружали ли мы данные

  @override
  bool get wantKeepAlive => true; // Сохраняем состояние при скролле

  @override
  void initState() {
    super.initState();
    // НЕ грузим сразу. Ждем первого билда, а лучше - проверки видимости.
    // Но для простоты: оставим загрузку, но WebView будет создаваться лениво.
    loadInitialVideos();
  }

  Future<void> loadInitialVideos() async {
    setState(() => _isLoading = true);
    await ConfigService.ready;
    final videos = await VkService.fetchVideosFromWall();
    if (mounted) setState(() { _videoUrls = videos; _isLoading = false; _isInit = true; });
  }

  Future<void> loadMoreVideos() async {
    await ConfigService.ready;
    final newVideos = await VkService.fetchVideosFromWall();
    if (mounted) setState(() {
      final currentSet = _videoUrls.toSet();
      _videoUrls.addAll(newVideos.where((v) => !currentSet.contains(v)));
    });
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

  // Функция открытия оригинала в приложении VK
  Future<void> _openInVkApp() async {
    final uri = Uri.parse(widget.url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // WebView с клипом
        WebViewWidget(controller: _controller),
        
        if (!_isLoaded)
          const Center(child: CircularProgressIndicator(color: Color(0xFFCCFF00))),
        
        // Градиент и кнопка снизу
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
