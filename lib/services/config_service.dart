import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ConfigService {
  static String get _configUrl => dotenv.env['CONFIG_URL'] ?? '';
  static const String _cacheKey = 'config_cache_v160'; 
  static Map<String, dynamic>? config;
  static final Completer<void> _readyCompleter = Completer<void>();
  static Future<void> get ready => _readyCompleter.future;
  static Future<void> loadConfig() async {
    bool loaded = false;
    if (_configUrl.isEmpty) {
      debugPrint("Warning: CONFIG_URL is missing in .env");
    } else {
      try {
        final uniqueUrl = '$_configUrl?t=${DateTime.now().millisecondsSinceEpoch}';
        final response = await http.get(Uri.parse(uniqueUrl)).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final raw = utf8.decode(response.bodyBytes);
          final decoded = json.decode(raw);
          
          if (decoded is Map<String, dynamic>) {
            config = decoded;
            loaded = true;
            
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_cacheKey, raw);
          }
        }
      } catch (e) {
        debugPrint("Config fetch error: $e");
      }
    }

    // 2. Если сеть недоступна или URL не задан, берем из кэша
    if (!loaded) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(_cacheKey);
        if (cached != null) {
          config = json.decode(cached);
          loaded = true;
        }
      } catch (_) {}
    }

    if (!_readyCompleter.isCompleted) _readyCompleter.complete();
  }
  
  static Map<String, String> getTelegramChannels() {
    return _parseIdNameList(config?['telegram']);
  }

  static Map<String, String> getVkGroups() {
    return _parseIdNameList(config?['vk']);
  }

  // Русские RSS
  static List<Map<String, String>> getRssFeeds() {
    return _parseRssList(config?['rss']);
  }

  // Зарубежные RSS
  static List<Map<String, String>> getWorldFeeds() {
    return _parseRssList(config?['rss_world']);
  }

  // Универсальный парсер для списков RSS
  static List<Map<String, String>> _parseRssList(dynamic list) {
    if (list is! List) return [];
    
    final List<Map<String, String>> feeds = [];
    for (final item in list) {
      if (item is! Map || item['enabled'] != true) continue;
      final url = _safeString(item['url']);
      if (url.isNotEmpty) {
        feeds.add({
          'url': url,
          'category': _safeString(item['category']),
          'name': _safeString(item['name']),
        });
      }
    }
    return feeds;
  }

  static Map<String, String> _parseIdNameList(dynamic list) {
    if (list is! List) return {};
    final Map<String, String> result = {};
    for (final item in list) {
      if (item is! Map || item['enabled'] != true) continue;
      final id = _safeString(item['id']);
      final name = _safeString(item['name']);
      if (id.isNotEmpty && name.isNotEmpty) {
        result[id] = name;
      }
    }
    return result;
  }

  static String _safeString(dynamic value) => value?.toString().trim() ?? '';
}
