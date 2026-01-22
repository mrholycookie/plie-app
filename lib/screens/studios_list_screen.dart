import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/config_service.dart';
import '../models/dance_studio.dart';
import '../widgets/dance_loader.dart';

class StudiosListScreen extends StatefulWidget {
  const StudiosListScreen({super.key});

  @override
  State<StudiosListScreen> createState() => _StudiosListScreenState();
}

class _StudiosListScreenState extends State<StudiosListScreen> with AutomaticKeepAliveClientMixin {
  bool isLoading = true;
  List<DanceStudio> allStudios = [];
  List<DanceStudio> visibleStudios = [];
  
  // Города
  List<String> cities = ['ВСЕ'];
  String selectedCity = 'МОСКВА'; // По умолчанию Москва, так логичнее для студий

  // Стили
  List<String> allStyles = ['ВСЕ СТИЛИ'];
  String selectedStyle = 'ВСЕ СТИЛИ';
  
  // Метро
  List<String> allMetros = ['ВСЕ МЕТРО'];
  String selectedMetro = 'ВСЕ МЕТРО';
  
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    await ConfigService.ready;
    final data = ConfigService.getStudios();
    
    // Собираем города
    final uniqueCities = data.map((e) => e.city.toUpperCase()).toSet().toList()..sort();
    
    // Собираем все уникальные стили
    final uniqueStyles = <String>{};
    for (var s in data) {
      uniqueStyles.addAll(s.styles.map((e) => e.toUpperCase()));
    }
    final sortedStyles = uniqueStyles.toList()..sort();
    
    // Собираем все уникальные метро
    final uniqueMetros = data
        .where((s) => s.metro.isNotEmpty)
        .map((e) => e.metro.toUpperCase())
        .toSet()
        .toList()
      ..sort();

    if (mounted) {
      setState(() {
        allStudios = data;
        cities = ['ВСЕ', ...uniqueCities];
        allStyles = ['ВСЕ СТИЛИ', ...sortedStyles];
        allMetros = ['ВСЕ МЕТРО', ...uniqueMetros];
        
        // Если Москвы нет в списке, ставим ВСЕ
        if (!cities.contains('МОСКВА')) selectedCity = 'ВСЕ';
        
        applyFilter();
        isLoading = false;
      });
    }
  }

  void resetFiltersToAll() {
    setState(() {
      selectedCity = 'ВСЕ';
      selectedStyle = 'ВСЕ СТИЛИ';
      selectedMetro = 'ВСЕ МЕТРО';
      applyFilter();
    });
    _scrollToTop();
  }

  void applyFilter() {
    visibleStudios = allStudios.where((s) {
      bool cityMatch = (selectedCity == 'ВСЕ') || (s.city.toUpperCase() == selectedCity);
      bool styleMatch = (selectedStyle == 'ВСЕ СТИЛИ') || (s.styles.any((st) => st.toUpperCase() == selectedStyle));
      bool metroMatch = (selectedMetro == 'ВСЕ МЕТРО') || (s.metro.toUpperCase() == selectedMetro);
      return cityMatch && styleMatch && metroMatch;
    }).toList();
  }

  void onCityChanged(String city) {
    setState(() {
      selectedCity = city;
      // При смене города сбрасываем метро
      if (city == 'ВСЕ') {
        selectedMetro = 'ВСЕ МЕТРО';
      }
      applyFilter();
    });
    _scrollToTop();
  }

  void onStyleChanged(String style) {
    setState(() {
      selectedStyle = style;
      applyFilter();
    });
    _scrollToTop();
  }
  
  void onMetroChanged(String metro) {
    setState(() {
      selectedMetro = metro;
      applyFilter();
    });
    _scrollToTop();
  }
  
  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> _pickFromBottomSheet({
    required String title,
    required List<String> options,
    required String selectedValue,
    required void Function(String) onSelected,
  }) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final controller = TextEditingController();
        String query = '';
        List<String> filtered = options;

        return StatefulBuilder(
          builder: (context, setModalState) {
            void applyQuery(String q) {
              query = q.trim().toUpperCase();
              filtered = options
                  .where((o) => o.toUpperCase().contains(query))
                  .toList();
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.78,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: GoogleFonts.unbounded(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        onChanged: (v) => setModalState(() => applyQuery(v)),
                        style: GoogleFonts.manrope(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Поиск',
                          hintStyle: GoogleFonts.manrope(color: Colors.grey),
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF1A1A1A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF222222)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF222222)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCCFF00)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'Ничего не найдено',
                                  style: GoogleFonts.manrope(color: Colors.grey),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF222222)),
                                itemBuilder: (context, index) {
                                  final value = filtered[index];
                                  final isSelected = value == selectedValue;
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      value,
                                      style: GoogleFonts.unbounded(
                                        color: isSelected ? const Color(0xFFCCFF00) : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check, color: Color(0xFFCCFF00), size: 18)
                                        : null,
                                    onTap: () => Navigator.of(context).pop(value),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      onSelected(result);
    }
  }

  Future<void> _pickCity() async {
    await _pickFromBottomSheet(
      title: 'Выбрать город',
      options: cities,
      selectedValue: selectedCity,
      onSelected: onCityChanged,
    );
  }

  Future<void> _pickStyle() async {
    await _pickFromBottomSheet(
      title: 'Выбрать стиль',
      options: allStyles,
      selectedValue: selectedStyle,
      onSelected: onStyleChanged,
    );
  }
  
  Future<void> _pickMetro() async {
    // Фильтруем метро только для выбранного города
    List<String> metrosToShow = allMetros;
    if (selectedCity != 'ВСЕ') {
      final metrosInCity = allStudios
          .where((s) => s.city.toUpperCase() == selectedCity && s.metro.isNotEmpty)
          .map((e) => e.metro.toUpperCase())
          .toSet()
          .toList()
        ..sort();
      metrosToShow = ['ВСЕ МЕТРО', ...metrosInCity];
    }
    
    await _pickFromBottomSheet(
      title: 'Выбрать метро',
      options: metrosToShow,
      selectedValue: selectedMetro,
      onSelected: onMetroChanged,
    );
  }

  Widget _buildFilterButton({
    required String label,
    required VoidCallback onPressed,
    bool isAccent = false,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: isAccent ? const Color(0xFFCCFF00) : const Color(0xFF333333)),
        backgroundColor: const Color(0xFF111111),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.unbounded(
          color: isAccent ? const Color(0xFFCCFF00) : Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          "СТУДИИ ТАНЦА",
          style: GoogleFonts.unbounded(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: isLoading 
          ? const Center(child: DanceLoader(color: Color(0xFFCCFF00)))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildFilterButton(
                              label: 'ВСЕ',
                              onPressed: resetFiltersToAll,
                              isAccent: selectedCity == 'ВСЕ' && selectedStyle == 'ВСЕ СТИЛИ' && selectedMetro == 'ВСЕ МЕТРО',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFilterButton(
                              label: selectedCity == 'ВСЕ' ? 'ГОРОД' : selectedCity,
                              onPressed: _pickCity,
                              isAccent: selectedCity != 'ВСЕ',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFilterButton(
                              label: selectedStyle == 'ВСЕ СТИЛИ' ? 'СТИЛЬ' : selectedStyle,
                              onPressed: _pickStyle,
                              isAccent: selectedStyle != 'ВСЕ СТИЛИ',
                            ),
                          ),
                        ],
                      ),
                      if (selectedCity != 'ВСЕ') ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildFilterButton(
                                label: selectedMetro == 'ВСЕ МЕТРО' ? 'МЕТРО' : selectedMetro,
                                onPressed: _pickMetro,
                                isAccent: selectedMetro != 'ВСЕ МЕТРО',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                // 3. Список
                Expanded(
                  child: visibleStudios.isEmpty
                      ? Center(child: Text("Студий не найдено", style: GoogleFonts.manrope(color: Colors.grey)))
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: visibleStudios.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            return buildStudioCard(visibleStudios[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget buildStudioCard(DanceStudio item) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Картинка
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: Image.network(
              item.imageUrl,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 140, 
                color: const Color(0xFF1A1A1A),
                child: Center(
                  child: Icon(FontAwesomeIcons.music, color: Colors.grey[800], size: 40)
                ),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Метро + Город
                Row(
                  children: [
                    Icon(Icons.location_on, size: 12, color: const Color(0xFFCCFF00)),
                    const SizedBox(width: 4),
                    Text(
                      "м. ${item.metro}",
                      style: GoogleFonts.manrope(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.city,
                      style: GoogleFonts.manrope(color: Colors.grey, fontSize: 11),
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
                
                // Стили (теги)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: item.styles.take(5).map((style) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF222222),
                        borderRadius: BorderRadius.circular(2)
                      ),
                      child: Text(
                        style,
                        style: GoogleFonts.manrope(color: Colors.white70, fontSize: 10),
                      ),
                    );
                  }).toList(),
                ),
                
                const SizedBox(height: 16),
                
                // Кнопки: Сайт + Карта
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                           if (item.siteUrl.isNotEmpty) {
                              try {
                                await launchUrl(Uri.parse(item.siteUrl), mode: LaunchMode.externalApplication);
                              } catch (_) {}
                           }
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF333333)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))
                        ),
                        child: Text("САЙТ", style: GoogleFonts.unbounded(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                           // Открыть карту с поиском по названию и адресу
                           try {
                             // Формируем поисковый запрос: название + город + метро
                             final searchQuery = Uri.encodeComponent('${item.name} ${item.city} м.${item.metro}');
                             Uri mapUrl;
                             
                             if (item.coords != null && item.coords!.length == 2) {
                               // Если есть координаты, используем их + поиск для точности
                               final lat = item.coords![0];
                               final lng = item.coords![1];
                               mapUrl = Uri.parse("https://yandex.ru/maps/?pt=$lng,$lat&z=15&text=$searchQuery");
                             } else {
                               // Если координат нет, используем только поиск
                               mapUrl = Uri.parse("https://yandex.ru/maps/?text=$searchQuery");
                             }
                             
                             await launchUrl(mapUrl, mode: LaunchMode.externalApplication);
                           } catch (_) {}
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFCCFF00)), // Лаймовая обводка
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))
                        ),
                        child: Text("КАРТА", style: GoogleFonts.unbounded(color: const Color(0xFFCCFF00), fontSize: 11)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
