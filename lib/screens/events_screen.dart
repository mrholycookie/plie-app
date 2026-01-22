import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:add_2_calendar/add_2_calendar.dart' as calendar;
import 'package:intl/intl.dart';

import '../services/config_service.dart';
import '../models/event.dart';
import '../widgets/dance_loader.dart';
import '../widgets/common_widgets.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> with AutomaticKeepAliveClientMixin {
  bool isLoading = true;
  List<Event> allEvents = [];
  List<Event> visibleEvents = [];
  
  // Фильтры по городам
  List<String> cities = ['ВСЕ'];
  String selectedCity = 'МОСКВА'; // По умолчанию Москва
  
  // Календарь
  DateTime _selectedMonth = DateTime.now();
  Set<DateTime> _eventDates = {};
  bool _isCalendarExpanded = false; // По умолчанию свернут
  
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
    final data = ConfigService.getEvents();
    
    // Фильтруем только будущие события
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final futureEvents = data.where((event) {
      if (event.startDate == null) return false;
      final eventDate = DateTime(event.startDate!.year, event.startDate!.month, event.startDate!.day);
      return eventDate.isAfter(today) || eventDate.isAtSameMomentAs(today);
    }).toList();
    
    // Собираем города из событий
    final uniqueCities = futureEvents
        .where((e) => e.city.isNotEmpty)
        .map((e) => e.city.toUpperCase())
        .toSet()
        .toList()
      ..sort();
    
    // Собираем даты для календаря (только будущие)
    final eventDatesSet = <DateTime>{};
    for (var event in futureEvents) {
      for (var date in event.eventDates) {
        final normalizedDate = DateTime(date.year, date.month, date.day);
        // Добавляем только будущие или сегодняшние даты
        if (normalizedDate.isAfter(today) || normalizedDate.isAtSameMomentAs(today)) {
          eventDatesSet.add(normalizedDate);
        }
      }
    }

    if (mounted) {
      setState(() {
        allEvents = futureEvents;
        _eventDates = eventDatesSet;
        cities = ['ВСЕ', ...uniqueCities];
        
        // Если Москвы нет в списке, ставим ВСЕ
        if (!cities.contains('МОСКВА')) {
          selectedCity = 'ВСЕ';
        }
        
        _selectedMonth = DateTime.now(); // Всегда начинаем с текущего месяца
        applyFilter();
        isLoading = false;
      });
    }
  }

  void applyFilter() {
    visibleEvents = allEvents.where((Event e) {
      if (selectedCity == 'ВСЕ') return true;
      return e.city == selectedCity;
    }).toList();
    
    // Сортируем по дате (ближайшие сверху)
    visibleEvents.sort((Event a, Event b) {
      final aDate = a.startDate ?? DateTime.now().add(const Duration(days: 365));
      final bDate = b.startDate ?? DateTime.now().add(const Duration(days: 365));
      return aDate.compareTo(bDate);
    });
  }

  void onCityChanged(String city) {
    setState(() {
      selectedCity = city;
      applyFilter();
    });
    _scrollToTop();
  }

  Future<void> _pickCity() async {
    await _pickFromBottomSheet(
      title: 'Выбрать город',
      options: cities,
      selectedValue: selectedCity,
      onSelected: onCityChanged,
    );
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

            return PopScope(
              onPopInvoked: (didPop) {
                if (didPop) {
                  controller.dispose();
                }
              },
              child: SafeArea(
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

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  bool _canGoToPreviousMonth() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month);
    return selectedMonth.isAfter(currentMonth);
  }

  Future<void> _addToCalendar(Event event) async {
    if (event.startDate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('У события не указана дата'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    try {
      // Форматируем даты для Intent
      final startDate = event.startDate!;
      final endDate = event.endDate ?? startDate.add(const Duration(hours: 2));
      
      // Создаем событие для календаря
      final eventToAdd = calendar.Event(
        title: event.title,
        description: event.description.isNotEmpty 
            ? event.description 
            : '${event.place}\n${event.price.isNotEmpty ? "Цена: ${event.price}" : ""}',
        location: event.place,
        startDate: startDate,
        endDate: endDate,
        allDay: false,
      );
      
      // Пытаемся добавить через пакет
      final result = await calendar.Add2Calendar.addEvent2Cal(eventToAdd);
      
      if (mounted) {
        if (result) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Событие добавлено в календарь'),
              backgroundColor: Color(0xFFCCFF00),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // Если пакет не сработал, пробуем через прямой Intent
          await _addToCalendarViaIntent(event, startDate, endDate);
        }
      }
    } catch (e) {
      debugPrint('Ошибка добавления в календарь: $e');
      // Пробуем альтернативный способ через Intent
      try {
        await _addToCalendarViaIntent(
          event, 
          event.startDate!, 
          event.endDate ?? event.startDate!.add(const Duration(hours: 2))
        );
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Не удалось открыть календарь. Установите приложение календаря.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _addToCalendarViaIntent(Event event, DateTime startDate, DateTime endDate) async {
    // Альтернативный способ через прямой Intent (для Android)
    // Форматируем даты в миллисекундах с начала эпохи
    final startMillis = startDate.millisecondsSinceEpoch;
    final endMillis = endDate.millisecondsSinceEpoch;
    
    // Формируем описание события
    final description = event.description.isNotEmpty 
        ? event.description 
        : '${event.place}${event.price.isNotEmpty ? "\nЦена: ${event.price}" : ""}';
    
    // Создаем Intent для Android
    final uri = Uri.parse(
      'content://com.android.calendar/time/${startMillis}'
    );
    
    // Пробуем открыть через url_launcher как fallback
    try {
      // Для Android используем специальный формат
      final androidUri = Uri.parse(
        'https://calendar.google.com/calendar/render?action=TEMPLATE'
        '&text=${Uri.encodeComponent(event.title)}'
        '&dates=${startDate.toUtc().toIso8601String().replaceAll(RegExp(r'[:\-]'), '').split('.')[0]}Z'
        '/${endDate.toUtc().toIso8601String().replaceAll(RegExp(r'[:\-]'), '').split('.')[0]}Z'
        '&details=${Uri.encodeComponent(description)}'
        '&location=${Uri.encodeComponent(event.place)}'
      );
      
      final launched = await launchUrl(
        androidUri,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось открыть календарь. Установите приложение календаря.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Ошибка открытия календаря через Intent: $e');
      rethrow;
    }
  }

  Widget _buildCalendar() {
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final firstWeekday = firstDay.weekday;
    final daysInMonth = lastDay.day;
    
    final monthNames = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];
    
    final weekDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    
    // Подсчитываем количество событий в текущем месяце
    final eventsInMonth = _eventDates.where((date) => 
      date.year == _selectedMonth.year && date.month == _selectedMonth.month
    ).length;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Column(
        children: [
          // Заголовок календаря (кликабельный для сворачивания)
          InkWell(
            onTap: () {
              setState(() {
                _isCalendarExpanded = !_isCalendarExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isCalendarExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}',
                        style: GoogleFonts.unbounded(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (eventsInMonth > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCCFF00),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            eventsInMonth.toString(),
                            style: GoogleFonts.manrope(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_isCalendarExpanded)
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.chevron_left,
                            color: _canGoToPreviousMonth() ? Colors.white : Colors.grey[700],
                            size: 20,
                          ),
                          onPressed: _canGoToPreviousMonth() ? () {
                            setState(() {
                              _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                            });
                          } : null,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                          onPressed: () {
                            setState(() {
                              _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          
          // Календарная сетка (показывается только если развернут)
          if (_isCalendarExpanded) ...[
            const Divider(height: 1, color: Color(0xFF222222)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Дни недели
                  Row(
                    children: weekDays.map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: GoogleFonts.manrope(
                            color: Colors.grey[600],
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 8),
                  // Календарная сетка
                  ...List.generate(6, (weekIndex) {
                    return Row(
                      children: List.generate(7, (dayIndex) {
                        final dayNumber = weekIndex * 7 + dayIndex - firstWeekday + 2;
                        if (dayNumber < 1 || dayNumber > daysInMonth) {
                          return Expanded(child: Container());
                        }
                        
                        final currentDate = DateTime(_selectedMonth.year, _selectedMonth.month, dayNumber);
                        final normalizedDate = DateTime(currentDate.year, currentDate.month, currentDate.day);
                        final hasEvent = _eventDates.contains(normalizedDate);
                        final isToday = normalizedDate.year == DateTime.now().year &&
                                       normalizedDate.month == DateTime.now().month &&
                                       normalizedDate.day == DateTime.now().day;
                        
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            height: 36,
                            decoration: BoxDecoration(
                              color: isToday ? const Color(0xFF333333) : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                              border: isToday ? Border.all(color: const Color(0xFFCCFF00), width: 1) : null,
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Число дня
                                Text(
                                  dayNumber.toString(),
                                  style: GoogleFonts.manrope(
                                    color: isToday ? const Color(0xFFCCFF00) : Colors.white,
                                    fontSize: 12,
                                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                // Точка для дней с событиями
                                if (hasEvent)
                                  Positioned(
                                    bottom: 4,
                                    child: Container(
                                      width: 4,
                                      height: 4,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFCCFF00),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }


  String _formatEventDate(Event event) {
    if (event.eventDates.isEmpty) return event.dates;
    
    if (event.eventDates.length == 1) {
      final date = event.eventDates.first;
      return DateFormat('d MMMM, EEEE', 'ru').format(date);
    } else {
      final first = event.eventDates.first;
      final last = event.eventDates.last;
      return '${DateFormat('d MMM', 'ru').format(first)} - ${DateFormat('d MMM', 'ru').format(last)}';
    }
  }

  Widget _buildEventCard(Event event) {
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
          if (event.imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: Image.network(
                event.imageUrl!,
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ErrorImagePlaceholder(
                  icon: FontAwesomeIcons.calendar,
                  height: 240,
                ),
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Дата
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: const Color(0xFFCCFF00)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _formatEventDate(event),
                        style: GoogleFonts.manrope(
                          color: const Color(0xFFCCFF00),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Название
                Text(
                  event.title,
                  style: GoogleFonts.unbounded(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Место
                if (event.place.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.place,
                          style: GoogleFonts.manrope(
                            color: Colors.grey[400],
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                
                // Цена
                if (event.price.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.price,
                    style: GoogleFonts.manrope(
                      color: Colors.grey[500],
                      fontSize: 11,
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Кнопки: Добавить в календарь + Подробнее
                Row(
                  children: [
                    if (event.startDate != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _addToCalendar(event),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFCCFF00)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          child: Text(
                            "В КАЛЕНДАРЬ",
                            style: GoogleFonts.unbounded(
                              color: const Color(0xFFCCFF00),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    if (event.startDate != null && event.siteUrl.isNotEmpty)
                      const SizedBox(width: 8),
                    if (event.siteUrl.isNotEmpty)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            try {
                              await launchUrl(
                                Uri.parse(event.siteUrl),
                                mode: LaunchMode.externalApplication,
                              );
                            } catch (_) {}
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF333333)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          child: Text(
                            "ПОДРОБНЕЕ",
                            style: GoogleFonts.unbounded(
                              color: Colors.white,
                              fontSize: 11,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const CommonAppBar(title: "АФИША"),
      body: isLoading
          ? const Center(child: DanceLoader(color: Color(0xFFCCFF00)))
          : Column(
              children: [
                // Фильтры по городам
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilterButton(
                          label: selectedCity == 'ВСЕ' ? 'ГОРОД' : selectedCity,
                          onPressed: _pickCity,
                          isAccent: selectedCity != 'ВСЕ',
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Календарь
                _buildCalendar(),
                
                const SizedBox(height: 8),
                
                // Список событий
                Expanded(
                  child: visibleEvents.isEmpty
                      ? const EmptyState(message: "Событий не найдено")
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: visibleEvents.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            return _buildEventCard(visibleEvents[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
