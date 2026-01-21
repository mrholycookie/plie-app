import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/config_service.dart';
import '../models/education_institution.dart';
import '../widgets/dance_loader.dart';

class EducationListScreen extends StatefulWidget {
  const EducationListScreen({super.key});

  @override
  State<EducationListScreen> createState() => _EducationListScreenState();
}

class _EducationListScreenState extends State<EducationListScreen> with AutomaticKeepAliveClientMixin {
  bool isLoading = true;
  List<EducationInstitution> allInstitutions = [];
  List<EducationInstitution> visibleInstitutions = [];
  
  List<String> cities = ['ВСЕ'];
  String selectedCity = 'ВСЕ';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    await ConfigService.ready;
    final data = ConfigService.getEducationInstitutions();
    
    // Собираем уникальные города
    final uniqueCities = data.map((e) => e.city).toSet().toList()..sort();
    
    if (mounted) {
      setState(() {
        allInstitutions = data;
        cities = ['ВСЕ', ...uniqueCities];
        applyFilter();
        isLoading = false;
      });
    }
  }

  void applyFilter() {
    if (selectedCity == 'ВСЕ') {
      visibleInstitutions = List.from(allInstitutions);
    } else {
      visibleInstitutions = allInstitutions.where((e) => e.city == selectedCity).toList();
    }
  }

  void onCityChanged(String city) {
    setState(() {
      selectedCity = city;
      applyFilter();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          "ОБРАЗОВАНИЕ",
          style: GoogleFonts.unbounded(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: isLoading 
          ? const Center(child: DanceLoader(color: Color(0xFFCCFF00)))
          : Column(
              children: [
                // Фильтр городов
                Container(
                  height: 50,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: cities.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return buildCityChip(cities[index]);
                    },
                  ),
                ),
                
                // Список ВУЗов
                Expanded(
                  child: visibleInstitutions.isEmpty
                      ? Center(child: Text("Ничего не найдено", style: GoogleFonts.manrope(color: Colors.grey)))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: visibleInstitutions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            return buildEduCard(visibleInstitutions[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget buildCityChip(String city) {
    final isSelected = selectedCity == city;
    final color = isSelected ? Colors.black : Colors.white;
    final bgColor = isSelected ? const Color(0xFFCCFF00) : const Color(0xFF1A1A1A);
    
    return InkWell(
      onTap: () => onCityChanged(city),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? bgColor : const Color(0xFF333333)),
        ),
        child: Text(
          city.toUpperCase(),
          style: GoogleFonts.unbounded(color: color, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget buildEduCard(EducationInstitution item) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Картинка
          if (item.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                item.imageUrl,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(height: 140, color: const Color(0xFF1A1A1A)),
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Тип (Академия/Институт)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2AABEE).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4)
                      ),
                      child: Text(
                        item.type.toUpperCase(),
                        style: GoogleFonts.manrope(color: const Color(0xFF2AABEE), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.city,
                      style: GoogleFonts.manrope(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Название
                Text(
                  item.name,
                  style: GoogleFonts.unbounded(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                
                // Программы (теги)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: item.programs.take(3).map((prog) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF222222),
                        borderRadius: BorderRadius.circular(4)
                      ),
                      child: Text(
                        prog,
                        style: GoogleFonts.manrope(color: Colors.white70, fontSize: 11),
                      ),
                    );
                  }).toList(),
                ),
                
                const SizedBox(height: 16),
                
                // Кнопка Сайт
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (item.siteUrl.isNotEmpty) {
                        try {
                          await launchUrl(Uri.parse(item.siteUrl), mode: LaunchMode.externalApplication);
                        } catch (_) {}
                      }
                    },
                    icon: const Icon(Icons.public, size: 16, color: Color(0xFFCCFF00)),
                    label: Text("ПЕРЕЙТИ НА САЙТ", style: GoogleFonts.unbounded(color: Colors.white, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF333333)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
