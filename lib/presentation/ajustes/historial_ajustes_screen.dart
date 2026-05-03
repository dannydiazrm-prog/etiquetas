import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class HistorialAjustesScreen extends StatelessWidget {
  const HistorialAjustesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('HISTORIAL DE AJUSTES'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/ajustes'),
        ),
      ),
      body: const Center(child: Text('Próximamente...')),
    );
  }
}