import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("INFO", style: GoogleFonts.unbounded(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            
            // Заголовок PLIÉ
            Text("PLIÉ", style: GoogleFonts.unbounded(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
            Text("v1.6.4", style: GoogleFonts.manrope(color: const Color(0xFFCCFF00), fontSize: 16, fontWeight: FontWeight.bold)),
            
            const SizedBox(height: 40),
            
            _buildInfoCard(
              "О Проекте",
              "PLIÉ собирает самые актуальные новости из мира танца, театра и перформанса. Мы объединяем VK, Telegram и ведущие мировые издания в одной ленте.",
            ),
            
            const SizedBox(height: 20),
            
            _buildInfoCard(
              "Обратная связь",
              "Нашли ошибку или хотите добавить свой ресурс? Напишите нам.",
            ),

            const SizedBox(height: 30),
            
            // Квадратная кнопка связи
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  launchUrl(Uri.parse('https://t.me/trentlane'), mode: LaunchMode.externalApplication);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFF00),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const FaIcon(FontAwesomeIcons.telegram, color: Colors.black, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        "СВЯЗАТЬСЯ С РАЗРАБОТЧИКОМ", 
                        style: GoogleFonts.unbounded(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            Center(child: Text("© 2026 PLIÉ", style: GoogleFonts.manrope(color: Colors.grey[800], fontSize: 12))),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.unbounded(color: const Color(0xFFCCFF00), fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(content, style: GoogleFonts.manrope(color: Colors.grey[300], height: 1.5, fontSize: 14)),
        ],
      ),
    );
  }
}
