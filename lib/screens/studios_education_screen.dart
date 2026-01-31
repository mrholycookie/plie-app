import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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
    loadData().then((_) {
      // Определяем город после загрузки данных, чтобы список городов был заполнен
      _detectCityByLocation();
    });
  }

  Future<void> _detectCityByLocation() async {
    try {
      // Проверяем разрешения
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Геолокация отключена');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Разрешение на геолокацию отклонено');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Разрешение на геолокацию отклонено навсегда');
        return;
      }

      // Получаем текущую позицию
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      debugPrint('Позиция получена: ${position.latitude}, ${position.longitude}');

      // Получаем адрес по координатам
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final city = placemark.locality ?? placemark.subAdministrativeArea ?? '';
        
        if (city.isNotEmpty) {
          final cityUpper = city.toUpperCase();
          debugPrint('Определен город: $cityUpper');
          
          // Проверяем, есть ли такой город в списке доступных
          if (mounted && sortedCities.contains(cityUpper)) {
            setState(() {
              selectedCity = cityUpper;
              applyFilter();
            });
          } else if (mounted && sortedCities.isNotEmpty) {
            // Если города нет в списке, но есть другие города, можно показать уведомление
            debugPrint('Город $cityUpper не найден в списке доступных городов');
          }
        }
      }
    } catch (e) {
      debugPrint('Ошибка определения города по геолокации: $e');
      // Не показываем ошибку пользователю, просто используем город по умолчанию
    }
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
        try {
          _studiosPageController!.jumpToPage(0);
        } catch (e) {
          debugPrint('Ошибка сброса слайдера студий при загрузке: $e');
        }
      }
      if (_educationPageController != null && _educationPageController!.hasClients) {
        try {
          _educationPageController!.jumpToPage(0);
        } catch (e) {
          debugPrint('Ошибка сброса слайдера образования при загрузке: $e');
        }
      }
    });
  }

  void applyFilter() {
    if (selectedCity == 'ВСЕ') {
      filteredStudios = allStudios;
      filteredEducation = allEducation;
    } else {
      filteredStudios = allStudios
          .where((s) => s.city.toUpperCase() == selectedCity)
          .toList();
      filteredEducation = allEducation
          .where((e) => e.city.toUpperCase() == selectedCity)
          .toList();
    }
    // Сортируем студии по рейтингу (сначала с рейтингом, по убыванию, затем без рейтинга)
    filteredStudios.sort((a, b) {
      if (a.rating == null && b.rating == null) return 0;
      if (a.rating == null) return 1; // Без рейтинга в конец
      if (b.rating == null) return -1; // Без рейтинга в конец
      return b.rating!.compareTo(a.rating!); // По убыванию рейтинга
    });
  }

  void onCityChanged(String? city) {
    if (city == null) return;
    setState(() {
      selectedCity = city;
      applyFilter();
    });
    // Сбрасываем слайдеры на первую карточку после изменения фильтра
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_studiosPageController != null && _studiosPageController!.hasClients) {
        try {
          _studiosPageController!.jumpToPage(0);
        } catch (e) {
          debugPrint('Ошибка сброса слайдера студий: $e');
        }
      }
      if (_educationPageController != null && _educationPageController!.hasClients) {
        try {
          _educationPageController!.jumpToPage(0);
        } catch (e) {
          debugPrint('Ошибка сброса слайдера образования: $e');
        }
      }
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
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
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth =
        screenWidth * 0.75; // 75% ширины для видимости соседней карточки
    const separatorWidth = 12.0;
    final pageWidth = cardWidth + separatorWidth;
    final viewportFraction = pageWidth / screenWidth;

    // Получаем или создаем контроллер
    PageController pageController;
    if (controllerKey == 'studios') {
      // Пересоздаем контроллер если он не инициализирован или был disposed
      if (_studiosPageController == null || !_studiosPageController!.hasClients) {
        _studiosPageController?.dispose();
        _studiosPageController = PageController(viewportFraction: viewportFraction);
      }
      pageController = _studiosPageController!;
    } else {
      // Пересоздаем контроллер если он не инициализирован или был disposed
      if (_educationPageController == null || !_educationPageController!.hasClients) {
        _educationPageController?.dispose();
        _educationPageController = PageController(viewportFraction: viewportFraction);
      }
      pageController = _educationPageController!;
    }

    return PageView.builder(
      key: ValueKey('${controllerKey}_${items.length}'), // Ключ для пересоздания при изменении количества элементов
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
                  // Рейтинг (если есть)
                  if (item.rating != null) ...[
                    Row(
                      children: [
                        const Icon(
                          FontAwesomeIcons.star,
                          size: 10,
                          color: Color(0xFFCCFF00),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.rating!.toStringAsFixed(1),
                          style: GoogleFonts.manrope(
                            color: const Color(0xFFCCFF00),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
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
                debugPrint("Map/List toggle pressed. Current: $_showMap, Items: ${_itemsWithCoords.length}");
                setState(() {
                  _showMap = !_showMap;
                });
                debugPrint("After toggle: _showMap = $_showMap");
                // Центрируем карту после переключения на карту
                if (_showMap && _itemsWithCoords.isNotEmpty) {
                  debugPrint("Switching to map view, will center on ${_itemsWithCoords.length} items");
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

    // Вычисляем границы для автоматического зума
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

    if (minLat != double.infinity) {
      final center = LatLng(
        (minLat + maxLat) / 2,
        (minLng + maxLng) / 2,
      );
      
      // Вычисляем приблизительный зум
      final latDiff = maxLat - minLat;
      final lngDiff = maxLng - minLng;
      final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
      double zoom = 12.0;
      if (maxDiff > 0.1) {
        zoom = 10.0;
      } else if (maxDiff > 0.05) {
        zoom = 11.0;
      } else if (maxDiff > 0.02) {
        zoom = 12.0;
      } else if (maxDiff > 0.01) {
        zoom = 13.0;
      } else {
        zoom = 14.0;
      }

      _mapController.move(center, zoom);
    }
  }

  Widget _buildMapView(List<PlaceItem> items) {
    debugPrint("_buildMapView called with ${items.length} items");
    
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Нет элементов с координатами',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    // Вычисляем центр для начальной позиции
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

    final center = LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );

    // Вычисляем приблизительный зум
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    double zoom = 12.0;
    if (maxDiff > 0.1) {
      zoom = 10.0;
    } else if (maxDiff > 0.05) {
      zoom = 11.0;
    } else if (maxDiff > 0.02) {
      zoom = 12.0;
    } else if (maxDiff > 0.01) {
      zoom = 13.0;
    } else {
      zoom = 14.0;
    }

    // Создаем маркеры
    final markers = items
        .where((item) => item.coords != null && item.coords!.length >= 2)
        .map((item) {
      final lat = item.coords![0];
      final lng = item.coords![1];
      
      debugPrint("Creating marker for ${item.name} at $lat, $lng");
      
      return Marker(
        point: LatLng(lat, lng),
        width: 32,
        height: 32,
        child: GestureDetector(
          onTap: () {
            debugPrint("Marker tapped: ${item.name}");
            _showMarkerInfo(item);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              FontAwesomeIcons.locationPin,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      );
    }).toList();

    debugPrint("Created ${markers.length} markers");

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        onTap: (tapPosition, point) {
          debugPrint("Map tapped at: ${point.latitude}, ${point.longitude}");
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.dancejournal.app',
        ),
        MarkerLayer(
          markers: markers,
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
                  // Рейтинг (если есть)
                  if (item.rating != null) ...[
                    Row(
                      children: [
                        const Icon(
                          FontAwesomeIcons.star,
                          size: 10,
                          color: Color(0xFFCCFF00),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.rating!.toStringAsFixed(1),
                          style: GoogleFonts.manrope(
                            color: const Color(0xFFCCFF00),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
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

