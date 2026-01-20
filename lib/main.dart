import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:appmetrica_plugin/appmetrica_plugin.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 1. Импорт dotenv

import 'screens/main_screen.dart';
import 'services/config_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Сначала загружаем ключи (до любых других сервисов)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: .env file not found or empty. Keys might be missing.");
  }

  // 3. Инициализация AppMetrica с ключом из файла .env
  try {
    // Берем ключ из переменной, или пустую строку (чтобы не упало, если забыли добавить)
    final metricaKey = dotenv.env['APPMETRICA_KEY'] ?? '';
    
    if (metricaKey.isNotEmpty) {
      await AppMetrica.activate(
        AppMetricaConfig(metricaKey),
      );
    } else {
      debugPrint("AppMetrica skipped: Key not found in .env");
    }
  } catch (e) {
    print("Metrica init error: $e");
  }

  await initializeDateFormatting('ru', null);
  
  // В твоем старом коде было loadConfig. 
  // Если ты используешь мой ConfigService из предыдущего сообщения, 
  // убедись, что метод называется так же. 
  // Например, если там fetchConfig, то: await ConfigService.fetchConfig();
  // Оставил как у тебя было:
  await ConfigService.loadConfig(); 

  // Настройка статус-бара: Прозрачный, белые иконки (для темного фона)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PLIÉ',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black, // Absolute Black
        primaryColor: const Color(0xFFE0E0E0),

        // Типографика 5.0
        textTheme: TextTheme(
          // Заголовки - Unbounded (широкий, модный)
          displayLarge: GoogleFonts.unbounded(fontWeight: FontWeight.bold, color: Colors.white),
          headlineSmall: GoogleFonts.unbounded(fontWeight: FontWeight.w600, color: Colors.white),
          titleLarge: GoogleFonts.unbounded(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 18),

          // Основной текст - Manrope (читабельный гротеск)
          bodyLarge: GoogleFonts.manrope(color: const Color(0xFFE0E0E0), fontSize: 16),
          bodyMedium: GoogleFonts.manrope(color: const Color(0xFFB0B0B0), fontSize: 14),
          labelSmall: GoogleFonts.manrope(color: Colors.grey, fontSize: 11),
        ),

        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          secondary: Color(0xFFCCFF00), // Acid Lime (акцент)
          surface: Color(0xFF161616),   // Цвет карточек (Dark Gray)
          background: Colors.black,
        ),

        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: GoogleFonts.unbounded(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.0
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),

        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
