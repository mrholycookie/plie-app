class Review {
  final String authorName;
  final String text;
  final String date;
  final double? rating; // Опциональный рейтинг (1-5)

  Review({
    required this.authorName,
    required this.text,
    required this.date,
    this.rating,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      authorName: json['author_name'] ?? json['authorName'] ?? '',
      text: json['text'] ?? '',
      date: json['date'] ?? '',
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'author_name': authorName,
      'text': text,
      'date': date,
      if (rating != null) 'rating': rating,
    };
  }
}
