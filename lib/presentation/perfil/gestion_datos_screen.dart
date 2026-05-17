import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/breakpoints.dart';

class GestionDatosScreen extends StatefulWidget {
  const GestionDatosScreen({super.key});

  @override
  State<GestionDatosScreen> createState() => _GestionDatosScreenState();
}

class _GestionDatosScreenState extends State<GestionDatosScreen> {
  int _tapCount = 0;
  bool _mostrarCargaInicial = false;

  void _onHeaderTap() {
    _tapCount++;
    if (_tapCount >= 5) {
      setState(() => _mostrarCargaInicial = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.red.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Zona de administración. Las acciones aquí son irreversibles.',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildOpcion(
                        context,
                        titulo: 'Historial de Recepciones',
                        descripcion:
                            'Editá o eliminá recepciones. Al borrar, el stock se ajusta automáticamente.',
                        icono: Icons.input,
                        ruta: '/perfil/gestion/recepciones',
                      ),
                      const SizedBox(height: 16),
                      _buildOpcion(
                        context,
                        titulo: 'Historial de Ajustes',
                        descripcion:
                            'Editá o eliminá ajustes. Al borrar, el stock se revierte al valor anterior.',
                        icono: Icons.tune,
                        ruta: '/perfil/gestion/ajustes',
                      ),
                      const SizedBox(height: 16),
                      _buildOpcion(
                        context,
                        titulo: 'Eliminar Producto Completo',
                        descripcion:
                            'Eliminá un producto y todo su historial. Acción irreversible.',
                        icono: Icons.delete_forever,
                        ruta: '/perfil/gestion/eliminar-producto',
                        peligroso: true,
                      ),
                      // Botón oculto — aparece solo después de 5 taps en el header
                      if (_mostrarCargaInicial) ...[
                        const SizedBox(height: 16),
                        _buildOpcion(
                          context,
                          titulo: 'Carga Inicial de Stock',
                          descripcion:
                              'Cargá el stock existente sin que aparezca en el historial de recepciones.',
                          icono: Icons.inventory_2_outlined,
                          ruta: '/perfil/gestion/carga-inicial',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpcion(
    BuildContext context, {
    required String titulo,
    required String descripcion,
    required IconData icono,
    required String ruta,
    bool peligroso = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push(ruta),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: peligroso
                ? Colors.red.withValues(alpha: 0.5)
                : AppColors.primary.withValues(alpha: 0.3),
            width: peligroso ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: peligroso
                    ? Colors.red.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icono,
                color: peligroso ? Colors.red : AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      color: peligroso ? Colors.red : AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descripcion,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: peligroso ? Colors.red : AppColors.primary,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return GestureDetector(
      onTap: _onHeaderTap,
      child: Container(
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
              onPressed: () => context.pop(),
            ),
            const SizedBox(width: 8),
            Text(
              'GESTIÓN DE DATOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: Breakpoints.isMobile(context) ? 20 : 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
