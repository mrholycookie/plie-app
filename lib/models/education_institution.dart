class EducationInstitution {
  final String id;
  final String name;
  final String shortName;
  final String city;
  final String type; // 'Академия', 'Институт', 'Колледж'
  final String metro; // Станция метро
  final List<String> level; // 'Высшее', 'Среднее'
  final List<String> programs; // Направления
  final String imageUrl;
  final String siteUrl;
  final List<double>? coords; // [lat, lng]

  EducationInstitution({
    required this.id,
    required this.name,
    required this.shortName,
    required this.city,
    required this.type,
    required this.metro,
    required this.level,
    required this.programs,
    required this.imageUrl,
    required this.siteUrl,
    this.coords,
  });

  factory EducationInstitution.fromJson(Map<String, dynamic> json) {
    // Парсим metro: может быть строкой, массивом строк (берем первую), или отсутствовать
    String parseMetro(dynamic metroData) {
      if (metroData == null) return '';
      if (metroData is String) {
        return metroData.trim();
      }
      if (metroData is List && metroData.isNotEmpty) {
        return metroData.first?.toString().trim() ?? '';
      }
      return '';
    }

    return EducationInstitution(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      shortName: json['short_name'] ?? json['name'] ?? '',
      city: json['city'] ?? '',
      type: json['type'] ?? 'ВУЗ',
      metro: parseMetro(json['metro']),
      level: (json['level'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      programs: (json['programs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      imageUrl: json['image'] ?? '',
      siteUrl: json['url'] ?? '',
      coords: json['coords'] != null
          ? (json['coords'] as List<dynamic>).map((e) => (e as num).toDouble()).toList()
          : null,
    );
  }
}
