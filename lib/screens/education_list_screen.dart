import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/config_service.dart';
import '../models/education_institution.dart';
import '../widgets/dance_loader.dart';
import '../widgets/common_widgets.dart';

class EducationListScreen extends StatefulWidget {
  const EducationListScreen({super.key});

  @override
  State<EducationListScreen> createState() => _EducationListScreenState();
}

class _EducationListScreenState extends State<EducationListScreen> with AutomaticKeepAliveClientMixin {
  bool isLoading = true;
  List<EducationInstitution> allInstitutions = [];
  List<EducationInstitution> visibleInstitutions = [];
  
  // Ключ - город, Значение - количество
  Map<String, int> cityCounts = {}; 
  List<String> sortedCities = ['ВСЕ'];
  String selectedCity = 'ВСЕ';
  
  // Приоритет сортировки городов (верхний регистр для унификации)
  final List<String> priorityCities = ['МОСКВА', 'САНКТ-ПЕТЕРБУРГ'];
  
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    loadData();
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    await ConfigService.ready;
    final data = ConfigService.getEducationInstitutions();
    
    // 1. Считаем количество для каждого города
    final counts = <String, int>{};
    final uniqueCitiesSet = <String>{};
    
    for (var item in data) {
      final city = item.city.toUpperCase(); // Нормализуем регистр
      counts[city] = (counts[city] ?? 0) + 1;
      uniqueCitiesSet.add(city);
    }
    
    // 2. Сортируем города: Сначала Приоритетные, потом остальные по алфавиту
    final otherCities = uniqueCitiesSet.toList()
      ..removeWhere((c) => priorityCities.contains(c));
    otherCities.sort(); // Алфавит

    final resultCities = <String>['ВСЕ'];
    
    // Добавляем приоритетные, если они реально есть в данных
    for (var p in priorityCities) {
      if (uniqueCitiesSet.contains(p)) {
        resultCities.add(p);
      }
    }
    resultCities.addAll(otherCities);
    
    if (mounted) {
      setState(() {
        allInstitutions = data;
        cityCounts = counts;
        sortedCities = resultCities;
        applyFilter();
        isLoading = false;
      });
    }
  }

  void applyFilter() {
    if (selectedCity == 'ВСЕ') {
      visibleInstitutions = List.from(allInstitutions);
    } else {
      visibleInstitutions = allInstitutions
          .where((e) => e.city.toUpperCase() == selectedCity)
          .toList();
    }
  }

  void onCityChanged(String city) {
    setState(() {
      selectedCity = city;
      applyFilter();
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const CommonAppBar(title: "ОБРАЗОВАНИЕ"),
      body: isLoading 
          ? const Center(child: DanceLoader(color: Color(0xFFCCFF00)))
          : Column(
              children: [
                Container(
                  height: 50,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sortedCities.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return buildCityChip(sortedCities[index]);
                    },
                  ),
                ),
                
                Expanded(
                  child: visibleInstitutions.isEmpty
                      ? const EmptyState()
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: visibleInstitutions.length + 1, // +1 для информационного сообщения
                          separatorBuilder: (_, index) {
                            // Первый разделитель больше, чтобы отделить сообщение от карточек
                            if (index == 0) return const SizedBox(height: 12);
                            return const SizedBox(height: 16);
                          },
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return const AddItemBanner(
                                title: "ВАШЕ УЧЕБНОЕ ЗАВЕДЕНИЕ НЕ В СПИСКЕ?",
                                description: "Напишите нам, и мы добавим ваше учебное заведение в каталог",
                                emailSubject: "Добавление учебного заведения в каталог",
                              );
                            }
                            return buildEduCard(visibleInstitutions[index - 1]);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget buildCityChip(String city) {
    final isSelected = selectedCity == city;
    final bgColor = isSelected ? const Color(0xFFCCFF00) : const Color(0xFF1A1A1A);
    final textColor = isSelected ? Colors.black : Colors.white;
    final countColor = isSelected ? Colors.black.withOpacity(0.6) : Colors.grey;

    // Получаем количество
    int count = 0;
    if (city == 'ВСЕ') {
      count = allInstitutions.length;
    } else {
      count = cityCounts[city] ?? 0;
    }
    
    return InkWell(
      onTap: () => onCityChanged(city),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? bgColor : const Color(0xFF333333)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              city,
              style: GoogleFonts.unbounded(color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 6),
            Text(
              count.toString(),
              style: GoogleFonts.manrope(color: countColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }


  Widget buildEduCard(EducationInstitution item) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: Image.network(
              item.imageUrl,
              height: 240,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ErrorImagePlaceholder(
                icon: FontAwesomeIcons.graduationCap,
                height: 240,
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2AABEE).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2)
                      ),
                      child: Text(
                        item.type.toUpperCase(),
                        style: GoogleFonts.manrope(color: const Color(0xFF2AABEE), fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (item.metro.isNotEmpty) ...[
                      Icon(
                        FontAwesomeIcons.locationDot,
                        size: 10,
                        color: const Color(0xFFCCFF00),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.metro.join(', '),
                        style: GoogleFonts.manrope(color: const Color(0xFFCCFF00), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      item.city,
                      style: GoogleFonts.manrope(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                Text(
                  item.name,
                  style: GoogleFonts.unbounded(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: item.programs.take(4).map((prog) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF222222),
                        borderRadius: BorderRadius.circular(2)
                      ),
                      child: Text(
                        prog,
                        style: GoogleFonts.manrope(color: Colors.white70, fontSize: 10),
                      ),
                    );
                  }).toList(),
                ),
                
                const SizedBox(height: 16),
                
                SizedBox(
                  width: double.infinity,
                  child: SiteButton(url: item.siteUrl),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
