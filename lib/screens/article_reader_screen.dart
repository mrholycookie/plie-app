import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ArticleReaderScreen extends StatefulWidget {
  final String url;
  final String title;

  const ArticleReaderScreen({required this.url, required this.title, super.key});

  @override
  State<ArticleReaderScreen> createState() => _ArticleReaderScreenState();
}

class _ArticleReaderScreenState extends State<ArticleReaderScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white) // Светлый фон
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onProgress: (p) => setState(() => _progress = p / 100),
          onPageFinished: (url) {
            setState(() => _isLoading = false);
            // JS удален - оставляем оригинальный дизайн сайта
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    // WebViewController не требует явного dispose, но оставляем для ясности
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF2D2D2D)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Просмотр новости",
          style: GoogleFonts.unbounded(color: const Color(0xFF2D2D2D), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Color(0xFFCCFF00)),
            onPressed: () {
              Share.share('${widget.title}\n\n${widget.url}');
            },
          ),
        ],
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey[200],
                  color: const Color(0xFFCCFF00),
                ),
              )
            : null,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          // Плавающая кнопка для перехода к новости
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton.extended(
              onPressed: () async {
                try {
                  await launchUrl(
                    Uri.parse(widget.url),
                    mode: LaunchMode.externalApplication,
                  );
                } catch (_) {}
              },
              backgroundColor: const Color(0xFFCCFF00),
              icon: const Icon(Icons.open_in_new, color: Colors.black),
              label: Text(
                'ОТКРЫТЬ В БРАУЗЕРЕ',
                style: GoogleFonts.unbounded(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
