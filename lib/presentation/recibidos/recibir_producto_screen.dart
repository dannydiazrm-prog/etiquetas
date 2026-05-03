import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class RecibirProductoScreen extends StatelessWidget {
  const RecibirProductoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('RECIBIR PRODUCTO'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/recibidos'),
        ),
      ),
      body: const Center(child: Text('Próximamente...')),
    );
  }
}