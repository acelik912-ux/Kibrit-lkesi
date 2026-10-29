import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ui/menu_screen.dart';
import 'ui/paper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Telefonda defter dikey durur.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const KibritUlkeApp());
}

class KibritUlkeApp extends StatelessWidget {
  const KibritUlkeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Night.gold,
        brightness: Brightness.dark,
        primary: Night.gold,
        onPrimary: Night.deep,
        surface: Night.wood,
      ),
      scaffoldBackgroundColor: Night.deep,
      useMaterial3: true,
    );
    return MaterialApp(
      title: 'Kibrit Ülkesi',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: GoogleFonts.baloo2TextTheme(base.textTheme).apply(
          bodyColor: Night.text,
          displayColor: Night.text,
        ),
      ),
      home: const MenuScreen(),
    );
  }
}
