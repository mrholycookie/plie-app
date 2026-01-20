import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import '../models/article.dart';
import 'config_service.dart';

class TelegramService {
  // УДАЛЕНА static const Map<String, String> channels

  static Future<List<Article>> fetchTelegramPosts() async {
    List<Article> articles = [];
    
    // Получаем список из ConfigService
    final channels = ConfigService.getTelegramChannels();
    if (channels.isEmpty) return [];

    final keys = channels.keys.toList();

    // Грузим батчами
    for (var i = 0; i < keys.length; i += 3) {
      final end = (i + 3 < keys.length) ? i + 3 : keys.length;
      final batch = keys.sublist(i, end);
      
      final results = await Future.wait(batch.map((slug) => _fetchChannel(slug, channels[slug]!)));
      for (var list in results) {
        articles.addAll(list);
      }
    }
    return articles;
  }

  // Метод _fetchChannel остается БЕЗ изменений
  static Future<List<Article>> _fetchChannel(String slug, String name) async {
      // ... старый код ...
      List<Article> items = [];
    try {
      final url = 'https://t.me/s/$slug';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final document = parse(response.body);
        
        String? channelAvatar;
        final avatarEl = document.querySelector('.tgme_page_photo_image');
        if (avatarEl != null) {
          channelAvatar = avatarEl.attributes['src'];
        }

        final messages = document.getElementsByClassName('tgme_widget_message');

        for (var msg in messages.reversed.take(20)) { 
          try {
            final textEl = msg.querySelector('.tgme_widget_message_text');
            String text = textEl?.text.trim() ?? '';
            
            String? imageUrl;
            
            final photoEl = msg.querySelector('.tgme_widget_message_photo_wrap');
            if (photoEl != null) {
              final style = photoEl.attributes['style'];
              if (style != null && style.contains("url('")) {
                imageUrl = style.split("url('")[1].split("')")[0];
              }
            }
            if (imageUrl == null) {
              final videoThumb = msg.querySelector('.tgme_widget_message_video_thumb');
              if (videoThumb != null) {
                  final style = videoThumb.attributes['style'];
                  if (style != null && style.contains("url('")) {
                     imageUrl = style.split("url('")[1].split("')")[0];
                  }
              }
            }

            imageUrl ??= channelAvatar;

            final postLink = "https://t.me/$slug/${msg.attributes['data-post']?.split('/').last}";

            DateTime? date;
            final dateEl = msg.querySelector('.tgme_widget_message_date time');
            if (dateEl != null) {
              final dt = dateEl.attributes['datetime'];
              if (dt != null) date = DateTime.tryParse(dt);
            }

            if (date == null) continue;

            if (text.isNotEmpty || imageUrl != null) {
              items.add(Article.fromTelegram(text, imageUrl, postLink, date, name));
            }
          } catch (e) {}
        }
      }
    } catch (e) {}
    return items;
  }
}
