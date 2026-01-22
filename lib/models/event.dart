class Event {
  final int id;
  final String title;
  final String description;
  final String? imageUrl;
  final String siteUrl;
  final String place;
  final String city; // Город для фильтрации
  final String dates; // Строковое представление для отображения
  final String price;
  final List<DateTime> eventDates; // Массив дат для календаря
  final DateTime? startDate; // Первая дата события
  final DateTime? endDate; // Последняя дата события (если многосерийное)

  Event({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.siteUrl,
    required this.place,
    required this.city,
    required this.dates,
    required this.price,
    required this.eventDates,
    this.startDate,
    this.endDate,
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

    // 3. Город
    String cityText = '';
    if (json['city'] != null) {
      cityText = json['city'].toString().toUpperCase();
    } else if (json['place'] != null && json['place'] is Map) {
      // Пытаемся извлечь город из адреса
      final address = json['place']['address']?.toString() ?? '';
      if (address.contains('Москва')) {
        cityText = 'МОСКВА';
      } else if (address.contains('Санкт-Петербург') || address.contains('СПб')) {
        cityText = 'САНКТ-ПЕТЕРБУРГ';
      }
    }

    // 4. Парсинг дат (поддержка массива дат для многосерийных событий)
    List<DateTime> parsedDates = [];
    String dateText = '';
    
    if (json['dates'] != null && (json['dates'] as List).isNotEmpty) {
      for (var dateItem in json['dates']) {
        DateTime? parsedDate;
        if (dateItem['start'] != null && dateItem['start'] > 0) {
          // Timestamp в секундах
          parsedDate = DateTime.fromMillisecondsSinceEpoch(dateItem['start'] * 1000);
        } else if (dateItem['start_date'] != null) {
          // Строковая дата
          try {
            parsedDate = DateTime.parse(dateItem['start_date']);
          } catch (_) {
            // Пробуем другие форматы
            try {
              final dateStr = dateItem['start_date'].toString();
              if (dateStr.contains('.')) {
                final parts = dateStr.split('.');
                if (parts.length >= 3) {
                  parsedDate = DateTime(
                    int.parse(parts[2]),
                    int.parse(parts[1]),
                    int.parse(parts[0]),
                  );
                }
              }
            } catch (_) {}
          }
        }
        
        if (parsedDate != null) {
          parsedDates.add(parsedDate);
        }
      }
      
      // Формируем строковое представление
      if (parsedDates.isNotEmpty) {
        parsedDates.sort();
        if (parsedDates.length == 1) {
          dateText = "${parsedDates[0].day.toString().padLeft(2, '0')}.${parsedDates[0].month.toString().padLeft(2, '0')}";
        } else {
          final first = parsedDates.first;
          final last = parsedDates.last;
          dateText = "${first.day.toString().padLeft(2, '0')}.${first.month.toString().padLeft(2, '0')} - ${last.day.toString().padLeft(2, '0')}.${last.month.toString().padLeft(2, '0')}";
        }
      }
    }

    // 5. Очистка описания
    String rawDesc = json['description'] ?? '';
    String cleanDesc = rawDesc.replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&mdash;', '—')
        .trim();
        
    // 6. Цена
    String priceText = json['price'] ?? '';

    return Event(
      id: json['id'],
      title: json['title'] != null ? _capitalize(json['title']) : '',
      description: cleanDesc,
      imageUrl: img,
      siteUrl: json['site_url'] ?? '',
      place: placeText,
      city: cityText,
      dates: dateText,
      price: priceText,
      eventDates: parsedDates,
      startDate: parsedDates.isNotEmpty ? parsedDates.first : null,
      endDate: parsedDates.length > 1 ? parsedDates.last : null,
    );
  }

  static String _capitalize(String s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '';
}
