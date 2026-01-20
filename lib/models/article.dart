import 'package:intl/intl.dart';
import 'package:webfeed_plus/webfeed_plus.dart';

// Добавлен rss_world в enum
enum SourceType { vk, telegram, rss, rss_world, web }

class Article {
  final String title;
  final String description;
  final String link;
  
  // imageUrl не final, чтобы SmartImageLoader мог его обновлять
  String? imageUrl; 
  
  final DateTime? pubDate;
  final String category;
  final SourceType sourceType;
  final String sourceName;

  Article({
    required this.title,
    required this.description,
    required this.link,
    this.imageUrl,
    this.pubDate,
    required this.category,
    required this.sourceType,
    required this.sourceName,
  });

  String get formattedDate {
    if (pubDate == null) return '';
    try {
      return DateFormat('dd MMMM yyyy, HH:mm', 'ru').format(pubDate!);
    } catch (e) {
      return '';
    }
  }

  // --- Фабрика для RSS (Обновленная) ---
  // Добавлен 4-й аргумент: sourceType
  factory Article.fromRssItem(
    RssItem item, 
    String category, 
    String sourceName, 
    SourceType type, // <--- ВОТ ОН
  ) {
    String? img;

    // 1. Enclosure
    img = item.enclosure?.url;

    // 2. Media Content
    if (img == null && item.media?.contents != null && item.media!.contents!.isNotEmpty) {
      img = item.media!.contents!.first.url;
    }
    
    // 3. Media Thumbnail
    if (img == null && item.media?.thumbnails != null && item.media!.thumbnails!.isNotEmpty) {
      img = item.media!.thumbnails!.first.url;
    }

    // 4. Google News ХАК
    if (img == null && item.description != null) {
      RegExp exp1 = RegExp(r'src="([^"]+)"');
      var match = exp1.firstMatch(item.description!);
      if (match != null) {
        img = match.group(1);
      } else {
        RegExp exp2 = RegExp(r"src='([^']+)'");
        match = exp2.firstMatch(item.description!);
        if (match != null) {
          img = match.group(1);
        }
      }
    }

    if (img != null && img.startsWith('//')) {
      img = 'https:$img';
    }

    String desc = item.description ?? '';
    try {
      desc = desc.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    } catch (_) {}

    return Article(
      title: item.title ?? 'Без заголовка',
      description: desc,
      link: item.link ?? '',
      imageUrl: img,
      pubDate: item.pubDate ?? DateTime.now(),
      category: category,
      sourceType: type, // <--- Используем переданный тип (rss или rss_world)
      sourceName: sourceName,
    );
  }

  // --- Фабрика для Telegram ---
  factory Article.fromTelegram(
    String text,
    String? imageUrl,
    String link,
    DateTime date,
    String sourceName,
  ) {
    String title = text.split('\n')[0];
    if (title.length > 100) title = '${title.substring(0, 100)}...';
    if (title.isEmpty) title = 'Пост из Telegram';

    return Article(
      title: title,
      description: text,
      link: link,
      imageUrl: imageUrl,
      pubDate: date,
      category: 'telegram',
      sourceType: SourceType.telegram,
      sourceName: sourceName,
    );
  }
}
