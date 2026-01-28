import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';

import 'feeds_screen.dart';
import 'vk_shorts_screen.dart';
import 'studios_education_screen.dart';
// import 'events_screen.dart'; // Временно скрыто до версии 1.7.7+25

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _widgetOptions = <Widget>[
    const NewsListWithKeepAlive(),
    const VkShortsScreen(),
    const StudiosEducationScreen(),
    // const EventsScreen(), // Временно скрыто до версии 1.7.7+25
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light); 

    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF222222), width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.black,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: GoogleFonts.unbounded(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: GoogleFonts.unbounded(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          selectedItemColor: const Color(0xFFCCFF00),
          unselectedItemColor: Colors.grey[600],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(FontAwesomeIcons.newspaper, size: 20),
              ),
              label: 'НОВОСТИ',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(FontAwesomeIcons.play, size: 20),
              ),
              label: 'КЛИПЫ',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(FontAwesomeIcons.building, size: 20),
              ),
              label: 'ОБУЧЕНИЕ',
            ),
            // BottomNavigationBarItem( // Временно скрыто до версии 1.7.7+25
            //   icon: Padding(
            //     padding: EdgeInsets.only(bottom: 4),
            //     child: Icon(FontAwesomeIcons.calendarDays, size: 20),
            //   ),
            //   label: 'АФИША',
            // ),
          ],
        ),
      ),
    );
  }
}
