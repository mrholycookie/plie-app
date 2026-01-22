import '../models/article.dart';
import '../models/dance_studio.dart';
import '../models/education_institution.dart';
import '../models/event.dart';

enum SearchResultType { news, studio, education, event }

class SearchResult {
  final SearchResultType type;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final dynamic data; // Article, DanceStudio, EducationInstitution, or Event
  final int relevanceScore; // Для сортировки по релевантности

  SearchResult({
    required this.type,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    required this.data,
    this.relevanceScore = 0,
  });

  static SearchResult fromArticle(Article article, String query) {
    int score = 0;
    final lowerTitle = article.title.toLowerCase();
    final lowerQuery = query.toLowerCase();
    
    // Высший приоритет - точное совпадение в заголовке
    if (lowerTitle == lowerQuery) score = 100;
    else if (lowerTitle.startsWith(lowerQuery)) score = 80;
    else if (lowerTitle.contains(lowerQuery)) score = 60;
    
    return SearchResult(
      type: SearchResultType.news,
      title: article.title,
      subtitle: article.sourceName,
      imageUrl: article.imageUrl,
      data: article,
      relevanceScore: score,
    );
  }

  static SearchResult fromStudio(DanceStudio studio, String query) {
    int score = 0;
    final lowerName = studio.name.toLowerCase();
    final lowerQuery = query.toLowerCase();
    
    if (lowerName == lowerQuery) score = 100;
    else if (lowerName.startsWith(lowerQuery)) score = 80;
    else if (lowerName.contains(lowerQuery)) score = 60;
    
    return SearchResult(
      type: SearchResultType.studio,
      title: studio.name,
      subtitle: '${studio.city}${studio.metro.isNotEmpty ? ', ${studio.metro}' : ''}',
      imageUrl: studio.imageUrl,
      data: studio,
      relevanceScore: score,
    );
  }

  static SearchResult fromEducation(EducationInstitution edu, String query) {
    int score = 0;
    final lowerName = edu.name.toLowerCase();
    final lowerQuery = query.toLowerCase();
    
    if (lowerName == lowerQuery) score = 100;
    else if (lowerName.startsWith(lowerQuery)) score = 80;
    else if (lowerName.contains(lowerQuery)) score = 60;
    
    return SearchResult(
      type: SearchResultType.education,
      title: edu.name,
      subtitle: edu.city,
      imageUrl: edu.imageUrl,
      data: edu,
      relevanceScore: score,
    );
  }

  static SearchResult fromEvent(Event event, String query) {
    int score = 0;
    final lowerTitle = event.title.toLowerCase();
    final lowerQuery = query.toLowerCase();
    
    if (lowerTitle == lowerQuery) score = 100;
    else if (lowerTitle.startsWith(lowerQuery)) score = 80;
    else if (lowerTitle.contains(lowerQuery)) score = 60;
    
    return SearchResult(
      type: SearchResultType.event,
      title: event.title,
      subtitle: '${event.city}, ${event.place}',
      imageUrl: event.imageUrl,
      data: event,
      relevanceScore: score,
    );
  }
}
