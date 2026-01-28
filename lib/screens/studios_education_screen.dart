import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/config_service.dart';
import '../models/place_item.dart';
import '../models/dance_studio.dart';
import '../models/education_institution.dart';
import '../widgets/dance_loader.dart';
import '../widgets/common_widgets.dart';
import 'detail_screen.dart';

class StudiosEducationScreen extends StatefulWidget {
  const StudiosEducationScreen({super.key});

  @override
  State<StudiosEducationScreen> createState() => _StudiosEducationScreenState();
}

class _StudiosEducationScreenState extends State<StudiosEducationScreen>
    with AutomaticKeepAliveClientMixin {
  bool isLoading = true;
  List<DanceStudio> allStudios = [];
  List<EducationInstitution> allEducation = [];

  List<DanceStudio> filteredStudios = [];
  List<EducationInstitution> filteredEducation = [];

  Map<String, int> cityCounts = {};
  List<String> sortedCities = ['ВСЕ'];
  String selectedCity = 'МОСКВА'; // По умолчанию Москва
  String _citySearchQuery = '';
  bool _showCitySearch = false;

  final List<String> priorityCities = ['МОСКВА', 'САНКТ-ПЕТЕРБУРГ'];
  final ScrollController _scrollController = ScrollController();
  PageController? _studiosPageController;
  PageController? _educationPageController;

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
    _studiosPageController?.dispose();
    _educationPageController?.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    await ConfigService.ready;
    final studios = ConfigService.getStudios();
    final education = ConfigService.getEducationInstitutions();

    // Считаем количество для каждого города
    final counts = <String, int>{};
    final uniqueCitiesSet = <String>{};

    for (var studio in studios) {
      final city = studio.city.toUpperCase();
      counts[city] = (counts[city] ?? 0) + 1;
      uniqueCitiesSet.add(city);
    }

    for (var edu in education) {
      final city = edu.city.toUpperCase();
      counts[city] = (counts[city] ?? 0) + 1;
      uniqueCitiesSet.add(city);
    }

    // Сортируем города
    final otherCities = uniqueCitiesSet.toList()
      ..removeWhere((c) => priorityCities.contains(c));
    otherCities.sort();

    final resultCities = <String>['ВСЕ'];
    for (var p in priorityCities) {
      if (uniqueCitiesSet.contains(p)) {
        resultCities.add(p);
      }
    }
    resultCities.addAll(otherCities);

    if (mounted) {
      setState(() {
        allStudios = studios;
        allEducation = education;
        cityCounts = counts;
        sortedCities = resultCities;
        applyFilter();
        isLoading = false;
      });
    }
    // На случай если экран был восстановлен из кэша и контроллеры остались на старой позиции.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_studiosPageController != null && _studiosPageController!.hasClients) {
        _studiosPageController!.jumpToPage(0);
      }
      if (_educationPageController != null && _educationPageController!.hasClients) {
        _educationPageController!.jumpToPage(0);
      }
    });
  }

  void applyFilter() {
    if (selectedCity == 'ВСЕ') {
      filteredStudios = List.from(allStudios);
      filteredEducation = List.from(allEducation);
    } else {
      filteredStudios = allStudios
          .where((s) => s.city.toUpperCase() == selectedCity)
          .toList();
      filteredEducation = allEducation
          .where((e) => e.city.toUpperCase() == selectedCity)
          .toList();
    }
  }

  void onCityChanged(String? city) {
    if (city == null) return;
    setState(() {
      selectedCity = city;
      applyFilter();
    });
    // Сбрасываем слайдеры на первую карточку, чтобы PageView не оставался на старой странице
    // после изменения фильтра (когда элементов может стать меньше).
    if (_studiosPageController != null && _studiosPageController!.hasClients) {
      _studiosPageController!.jumpToPage(0);
    }
    if (_educationPageController != null && _educationPageController!.hasClients) {
      _educationPageController!.jumpToPage(0);
    }
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const CommonAppBar(title: "ОБУЧЕНИЕ"),
      body: isLoading
          ? const Center(child: DanceLoader(color: Color(0xFFCCFF00)))
          : Column(
              children: [
                // Выпадающий список для выбора города с поиском
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: _buildCitySelector(),
                ),

                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Секция студий
                      if (filteredStudios.isNotEmpty) ...[
                        _buildStudiosSection(),
                        const SizedBox(height: 32),
                      ],
                      // Секция образования
                      if (filteredEducation.isNotEmpty) ...[
                        _buildEducationSection(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStudiosSection() {
    final sliderStudios = filteredStudios.take(5).toList();
    final hasMoreStudios = filteredStudios.length > 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок
        Text(
          'СТУДИИ',
          style: GoogleFonts.unbounded(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        // Горизонтальный скролл студий
        if (sliderStudios.isNotEmpty) ...[
          SizedBox(
            height: 200,
            child: _buildSnapScrollList(
              controllerKey: 'studios',
              items: sliderStudios,
              itemBuilder: (item) => PlaceItem.studio(item),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Кнопка "Смотреть все" для студий
        if (hasMoreStudios)
          Center(
            child: TextButton(
              onPressed: () {
                _showAllItems(
                    filteredStudios.map((s) => PlaceItem.studio(s)).toList(),
                    'СТУДИИ');
              },
              child: Text(
                'СМОТРЕТЬ ВСЕ СТУДИИ',
                style: GoogleFonts.unbounded(
                  color: const Color(0xFFCCFF00),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEducationSection() {
    final sliderEducation = filteredEducation.take(5).toList();
    final hasMoreEducation = filteredEducation.length > 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок
        Text(
          'ОБРАЗОВАНИЕ',
          style: GoogleFonts.unbounded(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        // Горизонтальный скролл образования
        if (sliderEducation.isNotEmpty) ...[
          SizedBox(
            height: 200,
            child: _buildSnapScrollList(
              controllerKey: 'education',
              items: sliderEducation,
              itemBuilder: (item) => PlaceItem.education(item),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Кнопка "Смотреть все" для образования
        if (hasMoreEducation)
          Center(
            child: TextButton(
              onPressed: () {
                _showAllItems(
                    filteredEducation
                        .map((e) => PlaceItem.education(e))
                        .toList(),
                    'ОБРАЗОВАНИЕ');
              },
              child: Text(
                'СМОТРЕТЬ ВСЕ ОБРАЗОВАНИЕ',
                style: GoogleFonts.unbounded(
                  color: const Color(0xFFCCFF00),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showAllItems(List<PlaceItem> items, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AllItemsScreen(items: items, title: title),
      ),
    );
  }

  Widget _buildCitySelector() {
    final filteredCities = _citySearchQuery.isEmpty
        ? sortedCities
        : sortedCities
            .where((city) =>
                city.toLowerCase().contains(_citySearchQuery.toLowerCase()))
            .toList();

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _showCitySearch = !_showCitySearch;
              if (!_showCitySearch) {
                _citySearchQuery = '';
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF333333)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.search,
                        color: Color(0xFFCCFF00), size: 20),
                    const SizedBox(width: 12),
                    Text(
                      selectedCity,
                      style: GoogleFonts.unbounded(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCFF00),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          (selectedCity == 'ВСЕ'
                                  ? allStudios.length + allEducation.length
                                  : cityCounts[selectedCity] ?? 0)
                              .toString(),
                          style: GoogleFonts.unbounded(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Icon(
                  _showCitySearch ? Icons.expand_less : Icons.expand_more,
                  color: const Color(0xFFCCFF00),
                ),
              ],
            ),
          ),
        ),
        if (_showCitySearch) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF333333)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Поле поиска
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    autofocus: true,
                    style:
                        GoogleFonts.manrope(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Поиск города...',
                      hintStyle: GoogleFonts.manrope(
                          color: Colors.grey[600], fontSize: 14),
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFFCCFF00)),
                      filled: true,
                      fillColor: const Color(0xFF111111),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFF333333)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFF333333)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                            color: Color(0xFFCCFF00), width: 1),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _citySearchQuery = value;
                      });
                    },
                  ),
                ),
                // Список городов с ограничением высоты
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filteredCities.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey[800]),
                    itemBuilder: (context, index) {
                      final city = filteredCities[index];
                      final count = city == 'ВСЕ'
                          ? allStudios.length + allEducation.length
                          : cityCounts[city] ?? 0;
                      final isSelected = selectedCity == city;

                      return InkWell(
                        onTap: () {
                          onCityChanged(city);
                          setState(() {
                            _showCitySearch = false;
                            _citySearchQuery = '';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          color: isSelected
                              ? const Color(0xFFCCFF00).withOpacity(0.1)
                              : Colors.transparent,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                city,
                                style: GoogleFonts.unbounded(
                                  color: isSelected
                                      ? const Color(0xFFCCFF00)
                                      : Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCCFF00),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Center(
                                  child: Text(
                                    count.toString(),
                                    style: GoogleFonts.unbounded(
                                      color: Colors.black,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSnapScrollList<T>({
    required String controllerKey,
    required List<T> items,
    required PlaceItem Function(T) itemBuilder,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth =
        screenWidth * 0.75; // 75% ширины для видимости соседней карточки
    const separatorWidth = 12.0;
    final pageWidth = cardWidth + separatorWidth;
    final viewportFraction = pageWidth / screenWidth;

    // Получаем или создаем контроллер
    PageController pageController;
    if (controllerKey == 'studios') {
      _studiosPageController ??=
          PageController(viewportFraction: viewportFraction);
      pageController = _studiosPageController!;
    } else {
      _educationPageController ??=
          PageController(viewportFraction: viewportFraction);
      pageController = _educationPageController!;
    }

    return PageView.builder(
      controller: pageController,
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      padEnds: false,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(
            left: index == 0 ? 16.0 : separatorWidth / 2,
            right: index == items.length - 1 ? 8.0 : separatorWidth / 2,
          ),
          child: SizedBox(
            width: cardWidth,
            child:
                _buildOverviewCard(itemBuilder(items[index]), isSlider: true),
          ),
        );
      },
    );
  }

  Widget _buildOverviewCard(PlaceItem item, {bool isSlider = false}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailScreen(item: item),
          ),
        );
      },
      child: Container(
        height: isSlider ? 200 : 160,
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF222222)),
        ),
        child: Stack(
          children: [
            // Картинка
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF1A1A1A),
                  child: Center(
                    child: Icon(
                      item.type == PlaceType.studio
                          ? FontAwesomeIcons.music
                          : FontAwesomeIcons.graduationCap,
                      color: Colors.grey,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
            // Градиент для читаемости текста
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),
            // Контент
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Бейдж типа
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.type == PlaceType.studio
                          ? const Color(0xFFCCFF00).withOpacity(0.9)
                          : const Color(0xFF2AABEE).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      item.typeLabel,
                      style: GoogleFonts.manrope(
                        color: Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Название
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.unbounded(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Метро
                  Row(
                    children: [
                      const Icon(
                        FontAwesomeIcons.locationDot,
                        size: 10,
                        color: Color(0xFFCCFF00),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.displayLocation,
                        style: GoogleFonts.manrope(
                          color: const Color(0xFFCCFF00),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

// Экран со всеми элементами
class _AllItemsScreen extends StatefulWidget {
  final List<PlaceItem> items;
  final String title;

  const _AllItemsScreen({required this.items, required this.title});

  @override
  State<_AllItemsScreen> createState() => _AllItemsScreenState();
}

class _AllItemsScreenState extends State<_AllItemsScreen> {
  bool _showMap = false;
  final MapController _mapController = MapController();
  late final List<PlaceItem> _itemsWithCoords;
  bool _schematicTiles = false;

  @override
  void initState() {
    super.initState();
    // Фильтруем только элементы с координатами для карты
    _itemsWithCoords = widget.items
        .where((item) => item.coords != null && item.coords!.length >= 2)
        .toList();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

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
          widget.title,
          style: GoogleFonts.unbounded(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Переключатель список/карта
          if (_itemsWithCoords.isNotEmpty)
            IconButton(
              icon: Icon(
                _showMap ? Icons.list : Icons.map,
                color: const Color(0xFFCCFF00),
              ),
              onPressed: () {
                setState(() {
                  _showMap = !_showMap;
                });
                // Центрируем карту после переключения на карту
                if (_showMap && _itemsWithCoords.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _centerMapOnItems(_itemsWithCoords);
                  });
                }
              },
              tooltip: _showMap ? 'Показать список' : 'Показать карту',
            ),
        ],
      ),
      body: _showMap && _itemsWithCoords.isNotEmpty
          ? _buildMapView(_itemsWithCoords)
          : _buildListView(),
    );
  }

  void _centerMapOnItems(List<PlaceItem> items) {
    if (items.isEmpty) return;

    // Вычисляем центр всех координат
    double totalLat = 0;
    double totalLng = 0;
    int count = 0;

    for (var item in items) {
      if (item.coords != null && item.coords!.length >= 2) {
        totalLat += item.coords![0];
        totalLng += item.coords![1];
        count++;
      }
    }

    if (count > 0) {
      final center = LatLng(totalLat / count, totalLng / count);
      _mapController.move(center, 12.0);
    }
  }

  Widget _buildMapView(List<PlaceItem> items) {
    // Вычисляем границы для автоматического зума
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Нет элементов с координатами',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (var item in items) {
      if (item.coords != null && item.coords!.length >= 2) {
        final lat = item.coords![0];
        final lng = item.coords![1];
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
      }
    }

    // Вычисляем центр для начальной позиции
    final center = LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );

    // Вычисляем приблизительный зум на основе границ
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    double initialZoom = 12.0;
    if (maxDiff > 0.1) {
      initialZoom = 10.0;
    } else if (maxDiff > 0.05)
      initialZoom = 11.0;
    else if (maxDiff > 0.02)
      initialZoom = 12.0;
    else if (maxDiff > 0.01)
      initialZoom = 13.0;
    else
      initialZoom = 14.0;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: initialZoom,
            minZoom: 10.0,
            maxZoom: 18.0,
            onTap: (tapPosition, point) {
              // Закрываем открытые попапы при клике на карту
            },
          ),
          children: [
            TileLayer(
              // "Схематичная" подложка = более минималистичная тема (не схема метро),
              // просто другой стиль тайлов.
              urlTemplate: _schematicTiles
                  ? 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.dance_news.app',
              maxZoom: 19,
            ),
            MarkerLayer(
              markers: items.map((item) {
                if (item.coords == null || item.coords!.length < 2) {
                  return const Marker(
                    point: LatLng(0, 0),
                    child: SizedBox.shrink(),
                  );
                }

                final lat = item.coords![0];
                final lng = item.coords![1];

                return Marker(
                  point: LatLng(lat, lng),
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () {
                      _showMarkerInfo(item);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: item.type == PlaceType.studio
                            ? const Color(0xFFCCFF00)
                            : const Color(0xFF2AABEE),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      // Лого приложения вместо ноты
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Image.asset(
                          'assets/icon/icon_fg.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        Positioned(
          right: 12,
          top: 12,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  _schematicTiles = !_schematicTiles;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.layers,
                        color: Color(0xFFCCFF00), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _schematicTiles ? 'СХЕМА' : 'OSM',
                      style: GoogleFonts.unbounded(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showMarkerInfo(PlaceItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Индикатор для закрытия
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Бейдж типа
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: item.type == PlaceType.studio
                    ? const Color(0xFFCCFF00)
                    : const Color(0xFF2AABEE),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.typeLabel,
                style: GoogleFonts.manrope(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Название
            Text(
              item.name,
              style: GoogleFonts.unbounded(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Метро/Адрес
            Row(
              children: [
                const Icon(
                  FontAwesomeIcons.locationDot,
                  size: 14,
                  color: Color(0xFFCCFF00),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.displayLocation,
                    style: GoogleFonts.manrope(
                      color: const Color(0xFFCCFF00),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (item.address != null && item.address!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.address!,
                style: GoogleFonts.manrope(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Кнопка "Подробнее"
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailScreen(item: item),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCCFF00),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'ПОДРОБНЕЕ',
                  style: GoogleFonts.unbounded(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: widget.items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildCard(item, context),
              ))
          .toList(),
    );
  }

  Widget _buildCard(PlaceItem item, BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailScreen(item: item),
          ),
        );
      },
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF222222)),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF1A1A1A),
                  child: Center(
                    child: Icon(
                      item.type == PlaceType.studio
                          ? FontAwesomeIcons.music
                          : FontAwesomeIcons.graduationCap,
                      color: Colors.grey,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.type == PlaceType.studio
                          ? const Color(0xFFCCFF00).withOpacity(0.9)
                          : const Color(0xFF2AABEE).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      item.typeLabel,
                      style: GoogleFonts.manrope(
                        color: Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.unbounded(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        FontAwesomeIcons.locationDot,
                        size: 10,
                        color: Color(0xFFCCFF00),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.displayLocation,
                        style: GoogleFonts.manrope(
                          color: const Color(0xFFCCFF00),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
