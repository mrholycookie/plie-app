import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:metadata_fetch/metadata_fetch.dart';

import '../services/rss_service.dart';
import '../models/article.dart';
import '../widgets/dance_loader.dart';
import '../widgets/common_widgets.dart';
import 'article_reader_screen.dart';
import 'info_screen.dart';

class NewsListWithKeepAlive extends StatefulWidget {
  const NewsListWithKeepAlive({super.key});
  @override
  State<NewsListWithKeepAlive> createState() => _NewsListWithKeepAliveState();
}

class _NewsListWithKeepAliveState extends State<NewsListWithKeepAlive> with AutomaticKeepAliveClientMixin {
  List<Article> allNews = [];
  List<Article> filteredNews = [];
  List<Article> visibleNews = [];
  bool isLoading = true;
  int currentMax = 15;
  final int pageSize = 15;
  String selectedFilter = 'all';
  DateTime? _lastUpdateTime;
  DateTime? _previousUpdateTime; // Время предыдущего обновления для определения новых статей
  
  // ДОБАВИЛИ КОНТРОЛЛЕР
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    loadData();
  }
  
  // НЕ ЗАБЫВАЕМ DISPOSE
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> loadData({bool force = false}) async {
    // Сохраняем время предыдущего обновления ПЕРЕД загрузкой новых данных
    // Это нужно для определения новых статей
    _previousUpdateTime = _lastUpdateTime;
    
    setState(() => isLoading = true);
    final data = await RssService.fetchNews(forceRefresh: force);
    if (mounted) {
      setState(() {
        allNews = data;
        // Обновляем время после загрузки новых данных
        _lastUpdateTime = DateTime.now();
        applyFilter();
        isLoading = false;
      });
    }
  }

  void applyFilter() {
    if (selectedFilter == 'all') {
      filteredNews = List.from(allNews);
    } else {
      filteredNews = allNews.where((article) {
        if (selectedFilter == 'web') {
           return (article.sourceType == SourceType.web || article.sourceType == SourceType.rss) && article.category != 'world';
        }
        if (selectedFilter == 'world') return article.sourceType == SourceType.rss_world;
        if (selectedFilter == 'vk') return article.sourceType == SourceType.vk;
        if (selectedFilter == 'telegram') return article.sourceType == SourceType.telegram;
        return true;
      }).toList();
    }
    currentMax = pageSize;
    updateVisibleList();
  }

  void onFilterChanged(String newFilter) {
    if (selectedFilter != newFilter) {
      setState(() {
        selectedFilter = newFilter;
        applyFilter();
      });
      // СКРОЛЛИМ ВВЕРХ
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }

  void loadMore() {
    if (currentMax < filteredNews.length) {
      setState(() {
        currentMax += pageSize;
        updateVisibleList();
      });
    }
  }

  void updateVisibleList() {
    int count = currentMax;
    if (count > filteredNews.length) count = filteredNews.length;
    visibleNews = filteredNews.sublist(0, count);
  }

  bool _isNewArticle(Article article) {
    // Показываем "НОВОЕ" только для статей, которые появились после предыдущего обновления
    if (article.pubDate == null) return false;
    
    // При первой загрузке (_previousUpdateTime == null) не показываем "НОВОЕ"
    // Показываем только если пользователь обновил ленту и появились новые статьи
    if (_previousUpdateTime == null) return false;
    
    // Статья считается новой, если она опубликована после предыдущего обновления
    // Добавляем небольшую задержку (2 минуты) для учета времени загрузки и возможных расхождений во времени
    final previousUpdateWithDelay = _previousUpdateTime!.subtract(const Duration(minutes: 2));
    return article.pubDate!.isAfter(previousUpdateWithDelay);
  }

  String _getDateGroup(Article article) {
    if (article.pubDate == null) return 'Ранее';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final articleDate = DateTime(article.pubDate!.year, article.pubDate!.month, article.pubDate!.day);
    
    if (articleDate == today) return 'Сегодня';
    if (articleDate == today.subtract(const Duration(days: 1))) return 'Вчера';
    
    final weekAgo = today.subtract(const Duration(days: 7));
    if (articleDate.isAfter(weekAgo)) return 'На этой неделе';
    
    return 'Ранее';
  }

  Map<String, List<Article>> _groupByDate(List<Article> articles) {
    final groups = <String, List<Article>>{};
    for (final article in articles) {
      final group = _getDateGroup(article);
      groups.putIfAbsent(group, () => []).add(article);
    }
    return groups;
  }

  Future<void> onArticleTap(Article article) async {
    if (article.sourceType == SourceType.web) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArticleReaderScreen(url: article.link, title: article.title),
        ),
      );
    } else {
      final Uri url = Uri.parse(article.link);
      try {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  Color getFilterColor(String filter) {
    switch (filter) {
      case 'all': return Colors.white;
      case 'web': return const Color(0xFF00E5FF);
      case 'world': return const Color(0xFFE040FB);
      case 'telegram': return const Color(0xFF2AABEE);
      case 'vk': return const Color(0xFF0077FF);
      default: return Colors.white;
    }
  }
  
  Color getSourceColor(SourceType type, String category) {
    if (type == SourceType.rss_world) return const Color(0xFFE040FB);
    if (type == SourceType.vk) return const Color(0xFF0077FF);
    if (type == SourceType.telegram) return const Color(0xFF2AABEE);
    if (type == SourceType.web || type == SourceType.rss) return const Color(0xFF00E5FF);
    return const Color(0xFFCCFF00);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: CommonAppBar(
        title: "НОВОСТИ",
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            color: Colors.white,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 50,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                buildFilterChip("ВСЁ", 'all', FontAwesomeIcons.infinity),
                buildFilterChip("У НАС", 'web', FontAwesomeIcons.earthAsia),
                buildFilterChip("В МИРЕ", 'world', FontAwesomeIcons.earthAmericas),
                buildFilterChip("ТГ", 'telegram', FontAwesomeIcons.telegram),
                buildFilterChip("ВК", 'vk', FontAwesomeIcons.vk),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: DanceLoader(color: Color(0xFFCCFF00)))
                : RefreshIndicator(
                    color: Colors.black,
                    backgroundColor: const Color(0xFFCCFF00),
                    onRefresh: () => loadData(force: true),
                    child: visibleNews.isEmpty
                        ? ListView(children: const [SizedBox(height: 100), Center(child: Text("Лента пуста", style: TextStyle(color: Colors.grey)))])
                        : NotificationListener<ScrollNotification>(
                            onNotification: (scrollInfo) {
                              if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                                loadMore();
                              }
                              return false;
                            },
                            child: _buildGroupedList(),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  // ... Остальные методы (buildFilterChip, buildCard, SmartImageLoader) остаются БЕЗ ИЗМЕНЕНИЙ ...
  // Скопируйте их из вашего старого файла feeds_screen.dart, они там в порядке.
  
  Widget buildFilterChip(String label, String value, IconData icon) {
    final isSelected = selectedFilter == value;
    final color = isSelected ? Colors.black : getFilterColor(value);
    final bgColor = isSelected ? getFilterColor(value) : const Color(0xFF1A1A1A);
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => onFilterChanged(value),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: isSelected ? bgColor : const Color(0xFF333333)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.unbounded(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildCard(Article article, {Key? key}) {
    final badgeColor = getSourceColor(article.sourceType, article.category);

    return Container(
      key: key, 
      height: 125, 
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onArticleTap(article),
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              // Картинка (или плейсхолдер)
              Container(
                width: 110,
                height: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                  child: SmartImageLoader(article: article),
                ),
              ),

              // Контент
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(2)),
                            child: Text(getSourceShort(article), style: GoogleFonts.manrope(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w800)),
                          ),
                          if (_isNewArticle(article)) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFCCFF00),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                'НОВОЕ',
                                style: GoogleFonts.manrope(
                                  color: Colors.black,
                                  fontSize: 7,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              article.sourceName.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.unbounded(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Icon(Icons.open_in_new, size: 12, color: Colors.grey[600]),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        article.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
                      ),
                      const Spacer(),
                      Text(
                        article.formattedDate,
                        style: GoogleFonts.manrope(color: Colors.grey[700], fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String getSourceShort(Article article) {
    if (article.sourceType == SourceType.rss_world) return 'В МИРЕ';
    switch (article.sourceType) {
      case SourceType.vk: return 'ВК';
      case SourceType.telegram: return 'ТГ';
      default: return 'У НАС';
    }
  }

  String _formatUpdateTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    return '${diff.inDays} дн назад';
  }

  Widget _buildGroupedList() {
    final groups = _groupByDate(visibleNews);
    final groupOrder = ['Сегодня', 'Вчера', 'На этой неделе', 'Ранее'];
    
    int totalItems = 0;
    for (final group in groups.values) {
      totalItems += group.length;
    }
    totalItems += groups.length; // Заголовки групп
    if (_lastUpdateTime != null) totalItems += 1; // Индикатор обновления
    if (visibleNews.length < filteredNews.length) totalItems += 1; // Индикатор загрузки

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        int currentIndex = 0;
        
        // Индикатор обновления (показываем первым)
        if (_lastUpdateTime != null && index == currentIndex) {
          currentIndex++;
          return _buildUpdateIndicator();
        }
        
        for (final groupName in groupOrder) {
          if (!groups.containsKey(groupName)) continue;
          
          final groupArticles = groups[groupName]!;
          
          // Заголовок группы
          if (index == currentIndex) {
            currentIndex++;
            return Padding(
              padding: EdgeInsets.only(bottom: 12, top: currentIndex > 1 ? 24 : 0),
              child: Text(
                groupName.toUpperCase(),
                style: GoogleFonts.unbounded(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }
          
          // Статьи в группе
          for (int i = 0; i < groupArticles.length; i++) {
            if (index == currentIndex) {
              currentIndex++;
              return Padding(
                padding: EdgeInsets.only(bottom: i < groupArticles.length - 1 ? 16 : 0),
                child: buildCard(groupArticles[i], key: ValueKey(groupArticles[i].link)),
              );
            }
            currentIndex++;
          }
        }
        
        // Индикатор загрузки
        if (index == currentIndex && visibleNews.length < filteredNews.length) {
          return const SizedBox(
            height: 50,
            child: Center(child: CircularProgressIndicator(color: Color(0xFF333333))),
          );
        }
        
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildUpdateIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.refresh, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            'Обновлено: ${_formatUpdateTime(_lastUpdateTime!)}',
            style: GoogleFonts.manrope(
              color: Colors.grey[600],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class SmartImageLoader extends StatefulWidget {
  final Article article;
  const SmartImageLoader({super.key, required this.article});

  @override
  State<SmartImageLoader> createState() => _SmartImageLoaderState();
}

class _SmartImageLoaderState extends State<SmartImageLoader> {
  late Future<String?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SmartImageLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.article.link != widget.article.link) {
      _load();
    }
  }

  void _load() {
    if (widget.article.link.contains('news.google.com')) {
      _imageFuture = Future.value(null);
      return;
    }

    if (widget.article.imageUrl != null && widget.article.imageUrl!.isNotEmpty) {
      _imageFuture = Future.value(widget.article.imageUrl);
    } else {
      _imageFuture = _fetchOgImage(widget.article.link);
    }
  }

  Future<String?> _fetchOgImage(String url) async {
    if (!mounted) return null;
    try {
      var data = await MetadataFetch.extract(url);
      if (data?.image != null) {
        widget.article.imageUrl = data!.image;
        return data.image;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.network(
            snapshot.data!, 
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF333333))));
        }
        return _buildPlaceholder();
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Text(
          widget.article.sourceName.isNotEmpty ? widget.article.sourceName[0] : '?',
          style: GoogleFonts.unbounded(color: const Color(0xFF333333), fontSize: 30, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
