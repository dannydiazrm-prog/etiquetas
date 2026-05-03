import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // Solo portrait en mobile, libre en tablet/desktop
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    const ProviderScope(
      child: GalmedicApp(),
    ),
  );
}

class GalmedicApp extends StatelessWidget {
  const GalmedicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Depósito de Etiquetas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0c6246),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFF93b289),
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: const DashboardPlaceholder(),
    );
  }
}

// Placeholder temporal hasta crear dashboard_screen.dart
class DashboardPlaceholder extends StatelessWidget {
  const DashboardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Galmedic App',
          style: GoogleFonts.inter(
            fontSize: 24,
            color: const Color(0xFF0c6246),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}