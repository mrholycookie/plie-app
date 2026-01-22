import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:webfeed_plus/webfeed_plus.dart';

import '../models/article.dart';
import 'config_service.dart';
import 'telegram_service.dart';
import 'vk_service.dart';

class RssService {
  static final http.Client _client = http.Client();
  static List<Article>? _memoryCache;
  static DateTime? _lastFetch;
  static const Duration _cacheTtl = Duration(minutes: 5);

  static Future<List<Article>> fetchNews({bool forceRefresh = false}) async {
    await ConfigService.ready;

    if (!forceRefresh &&
        _memoryCache != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheTtl) {
      return _memoryCache!;
    }

    final rssFeeds = ConfigService.getRssFeeds();
    final worldFeeds = ConfigService.getWorldFeeds(); // Берем зарубежные
    
    final results = await Future.wait<List<Article>>([
      _safe(() => TelegramService.fetchTelegramPosts().timeout(const Duration(seconds: 15))),
      _safe(() => VkService.fetchWallPosts().timeout(const Duration(seconds: 15))),
      
      // Русские RSS -> SourceType.rss
      _safe(() async {
        if (rssFeeds.isEmpty) return <Article>[];
        final rssLists = await Future.wait(
          rssFeeds.map((feed) => fetchRssFeedSafe(feed, SourceType.rss)),
        );
        return rssLists.expand((x) => x).toList();
      }),

      // Зарубежные RSS -> SourceType.rss_world
      _safe(() async {
        if (worldFeeds.isEmpty) return <Article>[];
        final rssLists = await Future.wait(
          worldFeeds.map((feed) => fetchRssFeedSafe(feed, SourceType.rss_world)),
        );
        return rssLists.expand((x) => x).toList();
      }),
    ]);

    final List<Article> allArticles = [];
    for (final list in results) {
      allArticles.addAll(list);
    }

    if (allArticles.isEmpty && _memoryCache != null) return _memoryCache!;

    // Дедупликация по ссылке и заголовку
    final seenLinks = <String>{};
    final seenTitles = <String>{};
    final deduplicated = <Article>[];
    
    for (final article in allArticles) {
      // Нормализуем заголовок для сравнения
      final normalizedTitle = article.title.trim().toLowerCase();
      final link = article.link.trim();
      
      // Пропускаем дубликаты
      if (seenLinks.contains(link) || seenTitles.contains(normalizedTitle)) {
        continue;
      }
      
      // Фильтрация низкокачественного контента
      // Минимальная длина текста
      if (article.description.trim().length < 30 && article.title.trim().length < 10) {
        continue;
      }
      
      // Фильтрация рекламных постов по ключевым словам
      final lowerText = (article.title + ' ' + article.description).toLowerCase();
      final adKeywords = ['купить', 'скидка', 'акция', 'распродажа', 'только сегодня', 
                         'заказать', 'доставка', 'бесплатно', 'промокод', 'реклама'];
      if (adKeywords.any((keyword) => lowerText.contains(keyword) && 
          (lowerText.split(keyword).length - 1) > 2)) {
        continue; // Слишком много рекламных слов
      }
      
      seenLinks.add(link);
      seenTitles.add(normalizedTitle);
      deduplicated.add(article);
    }

    deduplicated.sort((a, b) {
      final ad = a.pubDate;
      final bd = b.pubDate;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });

    _memoryCache = deduplicated;
    _lastFetch = DateTime.now();
    return deduplicated;
  }

  static Future<List<Article>> fetchRssFeedSafe(Map<String, String> feed, SourceType type) async {
    final url = feed['url'];
    if (url == null || url.isEmpty) return [];

    try {
      final response = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = utf8.decode(response.bodyBytes, allowMalformed: true);
        final rssFeed = RssFeed.parse(decoded);
        return rssFeed.items
                ?.take(15)
                .map((item) => Article.fromRssItem(item, feed['category']!, feed['name']!, type))
                .toList() ?? [];
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Article>> _safe(Future<List<Article>> Function() fn) async {
    try {
      return await fn();
    } catch (_) {
      return [];
    }
  }
}
