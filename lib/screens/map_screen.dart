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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.displayLocation,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
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
                ),
                child: const Text('ПОДРОБНЕЕ'),
              ),
            ),
          ],
        ),
      ),
    );
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

    // Создаем маркеры с иконкой из FontAwesome
    final markers = _allItems.map((item) {
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
      body: FlutterMap(
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
            markers: markers,
          ),
        ],
      ),
    );
  }
}

