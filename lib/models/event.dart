class Event {
  final int id;
  final String title;
  final String description;
  final String? imageUrl;
  final String siteUrl;
  final String place;
  final String dates;
  final String price; // Добавим цену

  Event({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.siteUrl,
    required this.place,
    required this.dates,
    required this.price,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    // 1. Картинка
    String? img;
    if (json['images'] != null && (json['images'] as List).isNotEmpty) {
      img = json['images'][0]['image'];
    }

    // 2. Место
    String placeText = 'Площадка уточняется';
    if (json['place'] != null && json['place'] is Map) {
       placeText = json['place']['title'] ?? json['place']['address'] ?? 'Адрес скрыт';
    }

    // 3. Дата
    String dateText = '';
    if (json['dates'] != null && (json['dates'] as List).isNotEmpty) {
      final firstDate = json['dates'][0];
      if (firstDate['start'] != null && firstDate['start'] > 0) {
        final dt = DateTime.fromMillisecondsSinceEpoch(firstDate['start'] * 1000);
        dateText = "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}";
      } else if (firstDate['start_date'] != null) {
        dateText = firstDate['start_date'];
      }
    }

    // 4. Очистка описания
    String rawDesc = json['description'] ?? '';
    String cleanDesc = rawDesc.replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&mdash;', '—')
        .trim();
        
    // 5. Цена
    String priceText = json['price'] ?? '';

    return Event(
      id: json['id'],
      title: json['title'] != null ? _capitalize(json['title']) : '',
      description: cleanDesc,
      imageUrl: img,
      siteUrl: json['site_url'] ?? '',
      place: placeText,
      dates: dateText,
      price: priceText,
    );
  }

  static String _capitalize(String s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '';
}
