import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../services/config_service.dart';
import '../models/place_item.dart';
import 'detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with AutomaticKeepAliveClientMixin {
  final MapController _mapController = MapController();
  List<PlaceItem> _allItems = [];
  bool _isLoading = true;
  LatLng? _currentUserLocation; // Текущее местоположение пользователя

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await ConfigService.ready;
    final studios = ConfigService.getStudios();
    final education = ConfigService.getEducationInstitutions();

    final items = <PlaceItem>[];
    items.addAll(studios.map((s) => PlaceItem.studio(s)));
    items.addAll(education.map((e) => PlaceItem.education(e)));

    // Фильтруем только элементы с координатами
    final itemsWithCoords = items
        .where((item) => item.coords != null && item.coords!.length >= 2)
        .toList();

    if (mounted) {
      setState(() {
        _allItems = itemsWithCoords;
        _isLoading = false;
      });

      // Определяем город и центрируем карту
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _detectCityAndCenterMap();
      });
    }
  }

  Future<void> _detectCityAndCenterMap() async {
    String? detectedCity;
    
    // Пробуем определить город по геолокации
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse || 
            permission == LocationPermission.always) {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
          );

          List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );

          if (placemarks.isNotEmpty) {
            final placemark = placemarks.first;
            detectedCity = (placemark.locality ?? placemark.subAdministrativeArea ?? '').toUpperCase();
            debugPrint('Определен город по геолокации: $detectedCity');
          }
        }
      }
    } catch (e) {
      debugPrint('Ошибка определения города: $e');
    }

    // Центрируем карту на выбранном городе или на всех элементах
    if (mounted) {
      _centerMapOnCity(detectedCity);
    }
  }

  // Приближает карту к местоположению пользователя с заданным радиусом (в метрах)
  // Использует вычисление зума на основе радиуса для точного контроля области видимости
  void _zoomToUserLocation(LatLng location, {double radiusMeters = 500}) {
    // Вычисляем зум на основе радиуса
    // Формула: zoom = log2(earthCircumference / (radius * 2))
    // Где earthCircumference ≈ 40075017 метров
    // Для радиуса 500м получаем примерно зум 15-16
    final earthCircumference = 40075017.0; // Окружность Земли в метрах
    final diameter = radiusMeters * 2;
    final zoom = math.log(earthCircumference / diameter) / math.ln2;
    
    // Ограничиваем зум разумными значениями (от 10 до 18)
    final clampedZoom = zoom.clamp(10.0, 18.0);
    
    debugPrint('Приближение карты: радиус=$radiusMeters м, зум=${clampedZoom.toStringAsFixed(2)}');
    
    // Центрируем карту на местоположении с вычисленным зумом
    _mapController.move(location, clampedZoom);
  }

  void _centerMapOnCity(String? city) {
    List<PlaceItem> itemsToShow = _allItems;
    
    // Если город определен, фильтруем элементы этого города
    if (city != null) {
      itemsToShow = _allItems
          .where((item) => item.city.toUpperCase() == city)
          .toList();
    }

    if (itemsToShow.isEmpty) {
      // Если нет элементов для выбранного города, показываем все
      itemsToShow = _allItems;
    }

    if (itemsToShow.isEmpty) return;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (var item in itemsToShow) {
      if (item.coords != null && item.coords!.length >= 2) {
        final lat = item.coords![0];
        final lng = item.coords![1];
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
      }
    }

    if (minLat == double.infinity) return;

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


  void _showMarkerInfo(PlaceItem item) {
    // Сразу открываем детальный экран, как в разделе "Смотреть все студии"
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailScreen(item: item),
      ),
    );
  }

  Future<void> _refreshLocation() async {
    // Показываем индикатор загрузки
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Определение местоположения...'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFFCCFF00),
      ),
    );

    try {
      // Проверяем разрешения
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Геолокация отключена'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Разрешение на геолокацию отклонено'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Разрешение на геолокацию отклонено навсегда'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Получаем текущую позицию с высокой точностью
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      debugPrint('Текущая позиция: ${position.latitude}, ${position.longitude}');

      if (mounted) {
        setState(() {
          _currentUserLocation = LatLng(position.latitude, position.longitude);
        });

        // Приближаем карту к текущему местоположению
        // Используем радиус в метрах для создания области видимости
        _zoomToUserLocation(_currentUserLocation!, radiusMeters: 500);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Местоположение определено'),
            duration: Duration(seconds: 1),
            backgroundColor: Color(0xFFCCFF00),
          ),
        );
      }
    } catch (e) {
      debugPrint('Ошибка определения местоположения: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFCCFF00),
          ),
        ),
      );
    }

    if (_allItems.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: const Text(
            'КАРТА',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: const Center(
          child: Text(
            'Нет элементов с координатами',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    // Создаем маркеры для студий и вузов
    final itemMarkers = _allItems.map((item) {
      final lat = item.coords![0];
      final lng = item.coords![1];

      return Marker(
        point: LatLng(lat, lng),
        width: 32,
        height: 32,
        child: GestureDetector(
          onTap: () {
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

    // Добавляем маркер текущего местоположения пользователя, если он определен
    final allMarkers = <Marker>[...itemMarkers];
    if (_currentUserLocation != null) {
      allMarkers.add(
        Marker(
          point: _currentUserLocation!,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFCCFF00),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              FontAwesomeIcons.locationDot,
              color: Colors.black,
              size: 20,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'КАРТА',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(55.7558, 37.6173), // Москва по умолчанию (будет переопределено после загрузки)
              initialZoom: 10.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.dancejournal.app',
              ),
              MarkerLayer(
                markers: allMarkers,
              ),
            ],
          ),
          // Кнопка уточнения геолокации
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: _refreshLocation,
              backgroundColor: const Color(0xFFCCFF00),
              child: const Icon(
                FontAwesomeIcons.locationCrosshairs,
                color: Colors.black,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

