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
        seedColor: Paper.ink,
        surface: Paper.background,
      ),
      scaffoldBackgroundColor: Paper.background,
      useMaterial3: true,
    );
    return MaterialApp(
      title: 'Kibrit Ülkesi',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: GoogleFonts.patrickHandTextTheme(base.textTheme).apply(
          bodyColor: Paper.ink,
          displayColor: Paper.ink,
        ),
      ),
      home: const MenuScreen(),
    );
  }
}
