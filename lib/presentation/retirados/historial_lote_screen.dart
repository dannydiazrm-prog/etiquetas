import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class HistorialLoteScreen extends StatelessWidget {
  const HistorialLoteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('HISTORIAL POR LOTE'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/retirados'),
        ),
      ),
      body: const Center(child: Text('Próximamente...')),
    );
  }
}