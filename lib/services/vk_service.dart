import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/article.dart';
import 'config_service.dart';

class VkService {
  // Берём токен из .env
  static String get _accessToken => dotenv.env['VK_ACCESS_TOKEN'] ?? '';

  static final Map<int, String> groupAvatars = {};

  // Храним перемешанный список ID групп для видео, чтобы при пагинации идти по порядку
  static List<String>? _shuffledVideoGroups;

  // --- ЛОГИКА ДЛЯ НОВОСТЕЙ (ОСТАЕТСЯ БЕЗ ИЗМЕНЕНИЙ) ---
  static Future<List<Article>> fetchWallPosts() async {
    await ConfigService.ready;

    if (_accessToken.isEmpty) {
      debugPrint('VK_ACCESS_TOKEN is missing in .env');
      return [];
    }

    final groups = ConfigService.getVkGroups();
    if (groups.isEmpty) return [];

    final groupIds = groups.keys.toList();
    final List<Article> allArticles = [];

    // Грузим пачками по 3
    for (var i = 0; i < groupIds.length; i += 3) {
      final end = (i + 3 < groupIds.length) ? i + 3 : groupIds.length;
      final batch = groupIds.sublist(i, end);

      final results = await Future.wait(
        batch.map((id) => fetchSingleGroup(id, groups[id]!)),
      );

      for (final list in results) {
        allArticles.addAll(list);
      }
    }
    return allArticles;
  }

  // --- НОВАЯ ЛОГИКА ДЛЯ ВИДЕО (БАТЧИ) ---
  
  /// Сбрасывает кэш порядка групп. Нужно вызывать при Pull-to-refresh.
  static void resetVideoShuffle() {
    _shuffledVideoGroups = null;
  }

  /// Загружает видео из следующей пачки групп.
  /// [batchIndex] - номер порции (0, 1, 2...).
  /// [batchSize] - сколько групп опрашивать за раз (рекомендую 5).
  static Future<List<String>> fetchVideosBatch({int batchIndex = 0, int batchSize = 5}) async {
    await ConfigService.ready;

    if (_accessToken.isEmpty) {
      debugPrint('VK_ACCESS_TOKEN is missing in .env');
      return [];
    }

    final groupsMap = ConfigService.getVkGroups();
    if (groupsMap.isEmpty) return [];

    // 1. Если список групп еще не перемешан или пуст — инициализируем
    if (_shuffledVideoGroups == null || _shuffledVideoGroups!.isEmpty) {
      _shuffledVideoGroups = groupsMap.keys.toList();
      _shuffledVideoGroups!.shuffle(); // Мешаем один раз для сессии
    }

    // 2. Вычисляем диапазон групп для текущего батча
    final totalGroups = _shuffledVideoGroups!.length;
    final start = batchIndex * batchSize;

    // Если мы вышли за пределы списка групп — возвращаем пустоту (конец ленты)
    if (start >= totalGroups) {
      return [];
    }

    final end = (start + batchSize < totalGroups) ? start + batchSize : totalGroups;
    final targetGroups = _shuffledVideoGroups!.sublist(start, end);

    debugPrint("Loading videos from groups batch $batchIndex: $targetGroups");

    final List<String> videoUrls = [];

    // 3. Делаем запросы параллельно для выбранных групп
    final futures = targetGroups.map((domain) async {
      // Используем wall.get, но берем больше постов (50), чтобы найти видео
      final url = Uri.parse(
        'https://api.vk.com/method/wall.get'
        '?domain=$domain'
        '&count=50' // УВЕЛИЧИЛИ С 15 ДО 50
        '&access_token=$_accessToken'
        '&v=5.131',
      );

      try {
        final response = await http.get(url).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['response'] != null) {
            final items = data['response']['items'] as List;
            return extractVideosFromItems(items);
          }
        }
      } catch (e) {
        debugPrint("Error fetching video from $domain: $e");
      }

      return <String>[];
    });

    final results = await Future.wait(futures);
    for (final list in results) {
      videoUrls.addAll(list);
    }

    // 4. Перемешиваем видео внутри этого батча, чтобы контент был разнообразным
    final unique = videoUrls.toSet().toList();
    unique.shuffle();
    
    return unique;
  }

  static List<String> extractVideosFromItems(List items) {
    final List<String> urls = [];
    for (final item in items) {
      if (item['attachments'] != null) {
        for (final att in item['attachments']) {
          if (att['type'] == 'video') addVideoUrl(urls, att['video']);
        }
      }
      if (item['copy_history'] != null) {
        for (final copy in item['copy_history']) {
          if (copy['attachments'] != null) {
            for (final att in copy['attachments']) {
              if (att['type'] == 'video') addVideoUrl(urls, att['video']);
            }
          }
        }
      }
    }
    return urls;
  }

  static void addVideoUrl(List<String> urls, dynamic videoObj) {
    if (videoObj == null) return;

    String? link = videoObj['player'];

    if (link == null && videoObj['owner_id'] != null && videoObj['id'] != null) {
      link =
          'https://vk.com/video_ext.php?oid=${videoObj['owner_id']}&id=${videoObj['id']}&hd=2';
      if (videoObj['access_key'] != null) link += '&hash=${videoObj['access_key']}';
    }

    if (link != null) {
      if (!link.startsWith('http')) link = link.replaceFirst('//', 'https://');
      if (!link.contains('autoplay=1')) link += (link.contains('?') ? '&' : '?') + 'autoplay=1';
      urls.add(link);
    }
  }

  static Future<List<Article>> fetchSingleGroup(String id, String name) async {
    if (_accessToken.isEmpty) return [];

    final List<Article> articles = [];
    final url = Uri.parse(
      'https://api.vk.com/method/wall.get'
      '?domain=$id'
      '&count=10'
      '&extended=1'
      '&access_token=$_accessToken'
      '&v=5.131',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['response'] != null) {
          if (data['response']['groups'] != null) {
            final groups = data['response']['groups'] as List;
            if (groups.isNotEmpty) {
              final group = groups[0];
              groupAvatars[group['id']] = group['photo_100'] ?? group['photo_50'];
            }
          }

          final items = data['response']['items'] as List;
          for (final item in items) {
            final post = parsePost(item, name);
            if (post != null) articles.add(post);
          }
        }
      }
    } catch (_) {}

    return articles;
  }

  static Article? parsePost(dynamic item, String sourceName) {
    try {
      final String text = item['text'] ?? '';
      final int dateTs = item['date'];
      final DateTime date = DateTime.fromMillisecondsSinceEpoch(dateTs * 1000);

      String? imageUrl;

      // 1) Сначала ищем фото
      if (item['attachments'] != null) {
        for (final att in item['attachments']) {
          if (att['type'] == 'photo') {
            final sizes = att['photo']['sizes'] as List;
            imageUrl = sizes.last['url'];
            break;
          }
        }
      }

      // 2) Если фото нет, ищем превью видео
      if (imageUrl == null && item['attachments'] != null) {
        for (final att in item['attachments']) {
          if (att['type'] == 'video' && att['video']['image'] != null) {
            final images = att['video']['image'] as List;
            if (images.isNotEmpty) {
              imageUrl = images.last['url'];
            }
            break;
          }
        }
      }

      // 3) Если совсем ничего нет — аватарка группы
      if (imageUrl == null) {
        final groupId = (item['owner_id'] as int).abs();
        imageUrl = groupAvatars[groupId];
      }

      final String link = 'https://vk.com/wall${item['owner_id']}_${item['id']}';

      if (text.isNotEmpty || imageUrl != null) {
        return Article(
          title: text.split('\n')[0],
          description: text,
          link: link,
          imageUrl: imageUrl,
          pubDate: date,
          category: 'vk_news',
          sourceType: SourceType.vk,
          sourceName: sourceName,
        );
      }
    } catch (_) {}

    return null;
  }
}
