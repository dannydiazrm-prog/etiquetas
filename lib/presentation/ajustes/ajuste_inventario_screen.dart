import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class AjusteInventarioScreen extends StatelessWidget {
  const AjusteInventarioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('AJUSTE DE INVENTARIO'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/ajustes'),
        ),
      ),
      body: const Center(child: Text('Próximamente...')),
    );
  }
}