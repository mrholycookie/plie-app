import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/config_service.dart';
import '../services/rss_service.dart';
import '../models/article.dart';
import '../models/dance_studio.dart';
import '../models/education_institution.dart';
import '../models/event.dart';
import '../models/search_result.dart';
import '../widgets/common_widgets.dart';
import 'article_reader_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  List<SearchResult> _allResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _query = '';
        _allResults = [];
      });
      return;
    }

    setState(() {
      _query = query.trim();
      _isSearching = true;
    });

    // Поиск по всем источникам
    Future.microtask(() async {
      await ConfigService.ready;
      final queryLower = _query.toLowerCase();
      final List<SearchResult> results = [];

      // Поиск по новостям
      final allNews = await RssService.fetchNews(forceRefresh: false);
      for (final article in allNews) {
        if (article.title.toLowerCase().contains(queryLower) ||
            article.description.toLowerCase().contains(queryLower) ||
            article.sourceName.toLowerCase().contains(queryLower)) {
          results.add(SearchResult.fromArticle(article, _query));
        }
      }

      // Поиск по студиям
      final allStudios = ConfigService.getStudios();
      for (final studio in allStudios) {
        if (studio.name.toLowerCase().contains(queryLower) ||
            studio.city.toLowerCase().contains(queryLower) ||
            studio.metro.toLowerCase().contains(queryLower) ||
            studio.styles.any((s) => s.toLowerCase().contains(queryLower))) {
          results.add(SearchResult.fromStudio(studio, _query));
        }
      }

      // Поиск по образованию
      final allEducation = ConfigService.getEducationInstitutions();
      for (final edu in allEducation) {
        if (edu.name.toLowerCase().contains(queryLower) ||
            edu.city.toLowerCase().contains(queryLower) ||
            edu.programs.any((p) => p.toLowerCase().contains(queryLower))) {
          results.add(SearchResult.fromEducation(edu, _query));
        }
      }

      // Поиск по событиям
      final allEvents = ConfigService.getEvents();
      for (final event in allEvents) {
        if (event.title.toLowerCase().contains(queryLower) ||
            event.city.toLowerCase().contains(queryLower) ||
            event.place.toLowerCase().contains(queryLower) ||
            event.description.toLowerCase().contains(queryLower)) {
          results.add(SearchResult.fromEvent(event, _query));
        }
      }

      // Сортируем по релевантности (сначала самые релевантные)
      results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

      if (mounted) {
        setState(() {
          _allResults = results;
          _isSearching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "ПОИСК",
          style: GoogleFonts.unbounded(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Поисковая строка
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _performSearch,
              autofocus: true,
              style: GoogleFonts.manrope(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Поиск по новостям, студиям, образованию, событиям...',
                hintStyle: GoogleFonts.manrope(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF222222)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF222222)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCCFF00)),
                ),
              ),
            ),
          ),

          // Результаты поиска
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFCCFF00)))
                : _query.isEmpty
                    ? Center(
                        child: Text(
                          'Введите запрос для поиска',
                          style: GoogleFonts.manrope(color: Colors.grey),
                        ),
                      )
                    : _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_allResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'Ничего не найдено',
              style: GoogleFonts.manrope(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // Группируем по типам для статистики
    final newsCount = _allResults.where((r) => r.type == SearchResultType.news).length;
    final studiosCount = _allResults.where((r) => r.type == SearchResultType.studio).length;
    final educationCount = _allResults.where((r) => r.type == SearchResultType.education).length;
    final eventsCount = _allResults.where((r) => r.type == SearchResultType.event).length;

    return Column(
      children: [
        // Статистика результатов
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF222222)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (newsCount > 0) _buildStatBadge('НОВОСТИ', newsCount, const Color(0xFF00E5FF)),
              if (studiosCount > 0) _buildStatBadge('СТУДИИ', studiosCount, const Color(0xFFCCFF00)),
              if (educationCount > 0) _buildStatBadge('ОБРАЗОВАНИЕ', educationCount, const Color(0xFFE040FB)),
              if (eventsCount > 0) _buildStatBadge('СОБЫТИЯ', eventsCount, const Color(0xFFFF6B6B)),
            ],
          ),
        ),
        // Единый список результатов
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _allResults.length,
            itemBuilder: (context, index) {
              return _buildSmartResultCard(_allResults[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatBadge(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $count',
          style: GoogleFonts.manrope(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSmartResultCard(SearchResult result) {
    IconData icon;
    Color badgeColor;
    
    switch (result.type) {
      case SearchResultType.news:
        icon = FontAwesomeIcons.newspaper;
        badgeColor = const Color(0xFF00E5FF);
        break;
      case SearchResultType.studio:
        icon = FontAwesomeIcons.building;
        badgeColor = const Color(0xFFCCFF00);
        break;
      case SearchResultType.education:
        icon = FontAwesomeIcons.graduationCap;
        badgeColor = const Color(0xFFE040FB);
        break;
      case SearchResultType.event:
        icon = FontAwesomeIcons.calendarDays;
        badgeColor = const Color(0xFFFF6B6B);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleResultTap(result),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Иконка типа
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: badgeColor, size: 18),
                ),
                const SizedBox(width: 12),
                // Контент
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.title,
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.subtitle,
                        style: GoogleFonts.manrope(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleResultTap(SearchResult result) {
    switch (result.type) {
      case SearchResultType.news:
        final article = result.data as Article;
        if (article.sourceType == SourceType.web) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ArticleReaderScreen(url: article.link, title: article.title),
            ),
          );
        } else {
          launchUrl(Uri.parse(article.link), mode: LaunchMode.externalApplication);
        }
        break;
      case SearchResultType.studio:
      case SearchResultType.education:
      case SearchResultType.event:
        Navigator.pop(context);
        // Можно добавить навигацию к конкретному элементу
        break;
    }
  }
}
