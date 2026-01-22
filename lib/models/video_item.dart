class VideoItem {
  final String url;
  final String? title;
  final String? description;
  final String? groupName;
  final DateTime? date;
  final bool isAvailable;

  VideoItem({
    required this.url,
    this.title,
    this.description,
    this.groupName,
    this.date,
    this.isAvailable = true,
  });

  String get displayTitle => title?.isNotEmpty == true ? title! : 'Без названия';
  String get displayDescription => description?.isNotEmpty == true ? description! : '';
}
