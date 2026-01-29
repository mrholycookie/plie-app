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

  // --- ЛОГИКА ДЛЯ НОВОСТЕЙ (Использует getVkGroups) ---
  static Future<List<Article>> fetchWallPosts() async {
    await ConfigService.ready;

    if (_accessToken.isEmpty) {
      debugPrint('VK_ACCESS_TOKEN is missing in .env');
      return [];
    }

    // Для новостей берем ОБЫЧНЫЕ группы
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
              groupAvatars[group['id']] =
                  group['photo_100'] ?? group['photo_50'];
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

      final String link =
          'https://vk.com/wall${item['owner_id']}_${item['id']}';

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
