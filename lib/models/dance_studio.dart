class DanceStudio {
  final String id;
  final String name;
  final String city;
  final String metro;
  final List<String> styles;
  final String imageUrl;
  final String siteUrl;
  final List<double>? coords;

  DanceStudio({
    required this.id,
    required this.name,
    required this.city,
    required this.metro,
    required this.styles,
    required this.imageUrl,
    required this.siteUrl,
    this.coords,
  });

  factory DanceStudio.fromJson(Map<String, dynamic> json) {
    return DanceStudio(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      city: json['city'] ?? '',
      metro: json['metro'] ?? '',
      styles: (json['styles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      imageUrl: json['image'] ?? '',
      siteUrl: json['url'] ?? '',
      coords: json['coords'] != null
          ? (json['coords'] as List<dynamic>).map((e) => (e as num).toDouble()).toList()
          : null,
    );
  }
}
