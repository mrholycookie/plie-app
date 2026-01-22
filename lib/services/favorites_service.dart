import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const String _favoriteVideosKey = 'favorite_videos';
  static const String _favoriteArticlesKey = 'favorite_articles';

  // Видео
  static Future<Set<String>> getFavoriteVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_favoriteVideosKey) ?? [];
    return list.toSet();
  }

  static Future<void> addFavoriteVideo(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavoriteVideos();
    favorites.add(url);
    await prefs.setStringList(_favoriteVideosKey, favorites.toList());
  }

  static Future<void> removeFavoriteVideo(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavoriteVideos();
    favorites.remove(url);
    await prefs.setStringList(_favoriteVideosKey, favorites.toList());
  }

  static Future<bool> isFavoriteVideo(String url) async {
    final favorites = await getFavoriteVideos();
    return favorites.contains(url);
  }

  // Статьи
  static Future<Set<String>> getFavoriteArticles() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_favoriteArticlesKey) ?? [];
    return list.toSet();
  }

  static Future<void> addFavoriteArticle(String link) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavoriteArticles();
    favorites.add(link);
    await prefs.setStringList(_favoriteArticlesKey, favorites.toList());
  }

  static Future<void> removeFavoriteArticle(String link) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavoriteArticles();
    favorites.remove(link);
    await prefs.setStringList(_favoriteArticlesKey, favorites.toList());
  }

  static Future<bool> isFavoriteArticle(String link) async {
    final favorites = await getFavoriteArticles();
    return favorites.contains(link);
  }
}
