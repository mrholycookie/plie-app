import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/article.dart';
import 'config_service.dart';

class VkService {
  // Берём токен из .env, чтобы не хранить его в репозитории
  static String get _accessToken => dotenv.env['VK_ACCESS_TOKEN'] ?? '';

  static final Map<int, String> groupAvatars = {};

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

  static Future<List<String>> fetchVideosFromWall() async {
    await ConfigService.ready;

    if (_accessToken.isEmpty) {
      debugPrint('VK_ACCESS_TOKEN is missing in .env');
      return [];
    }

    final groups = ConfigService.getVkGroups();
    if (groups.isEmpty) return [];

    final List<String> videoUrls = [];
    final groupIds = groups.keys.toList();

    groupIds.shuffle();
    final targetGroups = groupIds.take(8).toList();

    final futures = targetGroups.map((domain) async {
      final url = Uri.parse(
        'https://api.vk.com/method/wall.get'
        '?domain=$domain'
        '&count=15'
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
      } catch (_) {}

      return <String>[];
    });

    final results = await Future.wait(futures);
    for (final list in results) {
      videoUrls.addAll(list);
    }

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
