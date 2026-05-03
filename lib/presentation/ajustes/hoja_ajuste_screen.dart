import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class HojaAjusteScreen extends StatelessWidget {
  const HojaAjusteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('HOJA DE AJUSTE'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/ajustes'),
        ),
      ),
      body: const Center(child: Text('Próximamente...')),
    );
  }
}