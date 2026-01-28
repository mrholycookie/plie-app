import 'dance_studio.dart';
import 'education_institution.dart';

enum PlaceType { studio, education }

class PlaceItem {
  final PlaceType type;
  final DanceStudio? studio;
  final EducationInstitution? education;

  PlaceItem.studio(this.studio) : type = PlaceType.studio, education = null;
  PlaceItem.education(this.education) : type = PlaceType.education, studio = null;

  String get id => type == PlaceType.studio ? studio!.id : education!.id;
  String get name => type == PlaceType.studio ? studio!.name : education!.name;
  String get city => type == PlaceType.studio ? studio!.city : education!.city;
  String get metro => type == PlaceType.studio ? studio!.metro : education!.metro;
  String get imageUrl => type == PlaceType.studio ? studio!.imageUrl : education!.imageUrl;
  String get siteUrl => type == PlaceType.studio ? studio!.siteUrl : education!.siteUrl;
  List<double>? get coords => type == PlaceType.studio ? studio!.coords : education!.coords;
  String? get address => type == PlaceType.studio ? studio!.address : null;
  String? get yandexMapUrl => type == PlaceType.studio ? studio!.yandexMapUrl : null;
  
  // Получить локацию для отображения: метро (если есть) или адрес (если метро нет)
  String get displayLocation {
    if (type == PlaceType.studio) {
      if (metro.isNotEmpty) {
        return "м. $metro";
      } else if (address != null && address!.isNotEmpty) {
        return address!;
      } else {
        return city;
      }
    } else {
      // Для образования всегда показываем метро или город
      return metro.isNotEmpty ? "м. $metro" : city;
    }
  }
  
  // Проверка, есть ли метро
  bool get hasMetro => metro.isNotEmpty;

  // Дополнительная информация для детального экрана
  String get description {
    if (type == PlaceType.studio) {
      return studio!.styles.join(', ');
    } else {
      final edu = education!;
      final parts = <String>[];
      if (edu.type.isNotEmpty) parts.add(edu.type);
      if (edu.level.isNotEmpty) parts.add(edu.level.join(', '));
      if (edu.programs.isNotEmpty) parts.add(edu.programs.join(', '));
      return parts.join('\n');
    }
  }

  String get typeLabel => type == PlaceType.studio ? 'СТУДИЯ' : education!.type.toUpperCase();
}
