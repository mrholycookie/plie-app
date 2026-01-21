import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'feeds_screen.dart';
import 'vk_shorts_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;
  final List<Widget> pages = [const NewsListWithKeepAlive(), const VkShortsScreen()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => checkWelcome());
  }

  Future<void> checkWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    final bool dontShow = prefs.getBool('dontShowWelcome_v153') ?? false; // Новая версия ключа
    if (!dontShow && mounted) showWelcomeSheet();
  }

  void showWelcomeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) => const WelcomeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(top: BorderSide(color: Color(0xFF222222))),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                buildNavItem(0, FontAwesomeIcons.newspaper, "НОВОСТИ"),
                buildNavItem(1, FontAwesomeIcons.film, "КЛИПЫ"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildNavItem(int index, IconData icon, String label) {
    final bool isSelected = currentIndex == index;
    final Color color = isSelected ? const Color(0xFFCCFF00) : Colors.grey[700]!;
    return InkWell(
      onTap: () => setState(() => currentIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFCCFF00).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            FaIcon(icon, color: color, size: 20),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.unbounded(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

class WelcomeSheet extends StatefulWidget {
  const WelcomeSheet({super.key});
  @override
  State<WelcomeSheet> createState() => _WelcomeSheetState();
}

class _WelcomeSheetState extends State<WelcomeSheet> {
  bool doNotShowAgain = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("PLIÉ", style: GoogleFonts.unbounded(fontWeight: FontWeight.w900, fontSize: 28, color: const Color(0xFFCCFF00))),
          const SizedBox(height: 20),
          // Обновил текст версии
          Text("Мы только запустились и очень надеемся на вашу поддержку и оценку, будем стараться становиться лучше с каждым новым обновлением.", style: GoogleFonts.manrope(color: Colors.grey[400], height: 1.6, fontSize: 15)),
          const SizedBox(height: 30),
          GestureDetector(
            onTap: () => setState(() => doNotShowAgain = !doNotShowAgain),
            child: Row(children: [
              Icon(doNotShowAgain ? Icons.check_box : Icons.check_box_outline_blank, color: const Color(0xFFCCFF00), size: 20),
              const SizedBox(width: 10),
              Text("Больше не показывать", style: GoogleFonts.manrope(color: Colors.grey[500], fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () async {
                if (doNotShowAgain) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('dontShowWelcome_v153', true);
                }
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
              child: Text("ПОЕХАЛИ", style: GoogleFonts.unbounded(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
