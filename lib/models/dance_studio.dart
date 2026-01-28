class DanceStudio {
  final String id;
  final String name;
  final String city;
  final String metro;
  final List<String> styles;
  final String imageUrl;
  final String siteUrl;
  final String? address; // Полный адрес для точного поиска на карте
  final List<double>? coords; // Координаты [lat, lng] - опционально, для точности
  final String? yandexMapUrl; // Ссылка на Яндекс карты для построения маршрута

  DanceStudio({
    required this.id,
    required this.name,
    required this.city,
    required this.metro,
    required this.styles,
    required this.imageUrl,
    required this.siteUrl,
    this.address,
    this.coords,
    this.yandexMapUrl,
  });

  factory DanceStudio.fromJson(Map<String, dynamic> json) {
    // Парсим address: может быть строкой или массивом строк
    String? parseAddress(dynamic addressData) {
      if (addressData == null) return null;
      if (addressData is String) return addressData.isNotEmpty ? addressData : null;
      if (addressData is List) {
        if (addressData.isEmpty) return null;
        final first = addressData.first?.toString();
        return first != null && first.isNotEmpty ? first : null;
      }
      return null;
    }

    return DanceStudio(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      city: json['city'] ?? '',
      metro: json['metro'] ?? '',
      styles: (json['styles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      imageUrl: json['image'] ?? '',
      siteUrl: json['url'] ?? '',
      address: parseAddress(json['address']),
      coords: json['coords'] != null
          ? (json['coords'] as List<dynamic>).map((e) => (e as num).toDouble()).toList()
          : null,
      yandexMapUrl: json['yandex_map_url'] as String?,
    );
  }
}
