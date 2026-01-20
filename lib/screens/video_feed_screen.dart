import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/article.dart';

class VideoFeedScreen extends StatefulWidget {
  final List<Article> videos;
  const VideoFeedScreen({super.key, required this.videos});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical, // Вертикальный свайп как в Reels
      itemCount: widget.videos.length,
      itemBuilder: (context, index) {
        return YoutubeReelItem(article: widget.videos[index]);
      },
    );
  }
}

class YoutubeReelItem extends StatefulWidget {
  final Article article;
  const YoutubeReelItem({super.key, required this.article});

  @override
  State<YoutubeReelItem> createState() => _YoutubeReelItemState();
}

class _YoutubeReelItemState extends State<YoutubeReelItem> {
  late YoutubePlayerController _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    // Вытаскиваем ID видео из ссылки
    final videoId = YoutubePlayer.convertUrlToId(widget.article.link);
    
    if (videoId != null) {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false, // Можно true, но лучше по нажатию
          mute: false,
          disableDragSeek: true,
          loop: true,
        ),
      )..addListener(() {
          if (mounted) setState(() {});
      });
      _isReady = true;
    }
  }

  @override
  void dispose() {
    if (_isReady) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Center(child: Text("Видео недоступно"));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Черный фон
        Container(color: Colors.black),
        
        // Плеер по центру
        Center(
          child: YoutubePlayer(
            controller: _controller,
            showVideoProgressIndicator: true,
            progressIndicatorColor: Colors.amber,
          ),
        ),

        // Текст поверх видео (внизу)
        Positioned(
          bottom: 20,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.article.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.article.formattedDate,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
