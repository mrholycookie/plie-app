import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/place_item.dart';
import '../widgets/common_widgets.dart';

class DetailScreen extends StatelessWidget {
  final PlaceItem item;

  const DetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          item.typeLabel,
          style: GoogleFonts.unbounded(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Картинка
            ClipRRect(
              child: Image.network(
                item.imageUrl,
                width: double.infinity,
                height: 300,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 300,
                  color: const Color(0xFF1A1A1A),
                  child: Center(
                    child: Icon(
                      item.type == PlaceType.studio 
                          ? FontAwesomeIcons.music 
                          : FontAwesomeIcons.graduationCap,
                      color: Colors.grey,
                      size: 60,
                    ),
                  ),
                ),
              ),
            ),
            
            // Контент
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Название
                  Text(
                    item.name,
                    style: GoogleFonts.unbounded(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Информация о местоположении
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF222222)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Метро и город
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFCCFF00).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                FontAwesomeIcons.locationDot,
                                size: 14,
                                color: const Color(0xFFCCFF00),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.displayLocation,
                                    style: GoogleFonts.unbounded(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.city,
                                    style: GoogleFonts.manrope(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        // Адрес (если есть)
                        if (item.address != null && item.address!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  FontAwesomeIcons.mapMarkerAlt,
                                  size: 12,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.address!,
                                    style: GoogleFonts.manrope(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Описание/Информация
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF222222)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFCCFF00).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ИНФОРМАЦИЯ',
                                style: GoogleFonts.unbounded(
                                  color: const Color(0xFFCCFF00),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.description,
                          style: GoogleFonts.manrope(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Кнопки
                  Row(
                    children: [
                      Expanded(
                        child: SiteButton(url: item.siteUrl),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            try {
                              // Если есть прямая ссылка на Яндекс карты - используем её
                              if (item.yandexMapUrl != null && item.yandexMapUrl!.isNotEmpty) {
                                await launchUrl(
                                  Uri.parse(item.yandexMapUrl!),
                                  mode: LaunchMode.externalApplication,
                                );
                                return;
                              }
                              
                              // Иначе строим ссылку по координатам или поиску
                              String searchQuery;
                              if (item.address != null && item.address!.isNotEmpty) {
                                searchQuery = Uri.encodeComponent('${item.name} ${item.address}');
                              } else if (item.hasMetro) {
                                searchQuery = Uri.encodeComponent('${item.name} ${item.city} м.${item.metro}');
                              } else {
                                searchQuery = Uri.encodeComponent('${item.name} ${item.city}');
                              }
                              
                              Uri mapUrl;
                              if (item.coords != null && item.coords!.length == 2) {
                                final lat = item.coords![0];
                                final lng = item.coords![1];
                                mapUrl = Uri.parse("https://yandex.ru/maps/?pt=$lng,$lat&z=15&text=$searchQuery");
                              } else {
                                mapUrl = Uri.parse("https://yandex.ru/maps/?text=$searchQuery");
                              }
                              
                              await launchUrl(mapUrl, mode: LaunchMode.externalApplication);
                            } catch (_) {}
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFCCFF00)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: Text(
                            "КАРТА",
                            style: GoogleFonts.unbounded(
                              color: const Color(0xFFCCFF00),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
