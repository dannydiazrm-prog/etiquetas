import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/breakpoints.dart';

class NuevoProductoScreen extends StatefulWidget {
  const NuevoProductoScreen({super.key});

  @override
  State<NuevoProductoScreen> createState() => _NuevoProductoScreenState();
}

class _NuevoProductoScreenState extends State<NuevoProductoScreen> {
  final _nombreController = TextEditingController();
  String? _tipo;
  String? _idioma;
  bool _loading = false;
  String _error = '';

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombreController.text.trim();

    if (nombre.isEmpty) {
      setState(() => _error = 'Ingresá el nombre del producto');
      return;
    }
    if (_tipo == null) {
      setState(() => _error = 'Seleccioná el tipo');
      return;
    }
    if (_idioma == null) {
      setState(() => _error = 'Seleccioná el idioma');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      await FirebaseFirestore.instance.collection('productos').add({
        'nombre': nombre,
        'tipo': _tipo,
        'idioma': _idioma,
        'stockActual': 0,
        'stockMinimo': 1000,
        'destinos': [],
        'creadoEn': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto creado correctamente'),
            backgroundColor: AppColors.primary,
          ),
        );
        context.go('/inventario');
      }
    } catch (e) {
      setState(() => _error = 'Error al guardar. Intentá de nuevo.');
    }

    setState(() => _loading = false);
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
                      const Text(
                        'TIPO DE PRODUCTO',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildSelector(
                            label: 'ETIQUETA',
                            icon: Icons.label_outline,
                            seleccionado: _tipo == 'Etiqueta',
                            onTap: () => setState(() => _tipo = 'Etiqueta'),
                          ),
                          const SizedBox(width: 16),
                          _buildSelector(
                            label: 'PROSPECTO',
                            icon: Icons.description_outlined,
                            seleccionado: _tipo == 'Prospecto',
                            onTap: () => setState(() => _tipo = 'Prospecto'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'NOMBRE',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nombreController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'Ej: Oximed 50 ml',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.primary),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'IDIOMA',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildSelector(
                            label: 'ESPAÑOL',
                            icon: Icons.language,
                            seleccionado: _idioma == 'ES',
                            onTap: () => setState(() => _idioma = 'ES'),
                          ),
                          const SizedBox(width: 16),
                          _buildSelector(
                            label: 'INGLÉS',
                            icon: Icons.language,
                            seleccionado: _idioma == 'EN',
                            onTap: () => setState(() => _idioma = 'EN'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      if (_error.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red),
                          ),
                          child: Text(
                            _error,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _guardar,
                          child: _loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  'GUARDAR PRODUCTO',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                        ),
                      ),
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

  Widget _buildHeader(BuildContext context) {
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
            onPressed: () => context.go('/inventario'),
          ),
          const SizedBox(width: 8),
          Text(
            'NUEVO PRODUCTO',
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

  Widget _buildSelector({
    required String label,
    required IconData icon,
    required bool seleccionado,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 80,
          decoration: BoxDecoration(
            color: seleccionado ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary,
              width: seleccionado ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: seleccionado ? Colors.white : AppColors.primary,
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: seleccionado ? Colors.white : AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}