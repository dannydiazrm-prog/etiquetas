import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/breakpoints.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _Header(),
          Expanded(
            child: _Body(),
          ),
          _Footer(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      color: AppColors.primary,
      padding: EdgeInsets.only(
        top: topPadding + 12,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/logo_galmedic.webp',
            height: 60,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'DEPÓSITO DE ETIQUETAS',
              style: TextStyle(
                color: Colors.white,
                fontSize: Breakpoints.isMobile(context) ? 20 : 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          IconButton(
            onPressed: () => context.push('/perfil'),
            icon: const CircleAvatar(
              backgroundColor: Colors.black,
              child: Icon(Icons.person, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final List<_MenuButton> buttons = const [
    _MenuButton(label: 'RETIRADOS', route: '/retirados', icon: Icons.output),
    _MenuButton(label: 'RECIBIDOS', route: '/recibidos', icon: Icons.input),
    _MenuButton(label: 'HOJA DE AJUSTES', route: '/ajustes', icon: Icons.tune),
    _MenuButton(label: 'INVENTARIO', route: '/inventario', icon: Icons.inventory_2),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = !Breakpoints.isMobile(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: isWide
          ? GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              childAspectRatio: 2.8,
              children: buttons.map((b) => _buildButton(context, b)).toList(),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: buttons
                  .map((b) => Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _buildButton(context, b),
                      ))
                  .toList(),
            ),
    );
  }

  Widget _buildButton(BuildContext context, _MenuButton button) {
    return SizedBox(
      width: double.infinity,
      height: 80,
      child: ElevatedButton(
        onPressed: () => context.push(button.route),
        child: Text(
          button.label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

class _MenuButton {
  final String label;
  final String route;
  final IconData icon;
  const _MenuButton({
    required this.label,
    required this.route,
    required this.icon,
  });
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      color: AppColors.primary,
      padding: EdgeInsets.only(
        bottom: bottomPadding + 12,
        top: 12,
        left: 24,
        right: 24,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text(
            '04/2026',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            'VERSIÓN 1.0',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}