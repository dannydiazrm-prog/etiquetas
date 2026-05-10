import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/breakpoints.dart';

class RetiradosScreen extends StatelessWidget {
  const RetiradosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
      body: Column(
        children: [
          _Header(),
          Expanded(child: _Body()),
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
        left: 8,
        right: 16,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.go('/'),
          ),
          const SizedBox(width: 8),
          Text(
            'RETIRADOS',
            style: TextStyle(
              color: Colors.white,
              fontSize: Breakpoints.isMobile(context) ? 20 : 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final List<_MenuButton> buttons = const [
    _MenuButton(
      label: 'NUEVO RETIRO',
      route: '/retirados/nuevo',
      icon: Icons.output_outlined,
      descripcion: 'Registrar salida de etiqueta o prospecto',
    ),
    _MenuButton(
      label: 'PENDIENTES DE DEVOLUCIÓN',
      route: '/retirados/pendientes',
      icon: Icons.pending_actions_outlined,
      descripcion: 'Retiros abiertos sin devolver',
    ),
    _MenuButton(
      label: 'RETIROS DEL DÍA',
      route: '/retirados/del-dia',
      icon: Icons.today_outlined,
      descripcion: 'Informe de cierre de turno',
    ),
    _MenuButton(
      label: 'HISTORIAL POR LOTE',
      route: '/retirados/historial',
      icon: Icons.manage_search_outlined,
      descripcion: 'Trazabilidad por lote de producto final',
    ),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(button.icon, size: 28),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  button.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  button.descripcion,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
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
  final String descripcion;
  const _MenuButton({
    required this.label,
    required this.route,
    required this.icon,
    required this.descripcion,
  });
}