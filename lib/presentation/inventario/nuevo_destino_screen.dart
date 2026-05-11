import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/breakpoints.dart';
import '../../core/data/data_master.dart';

class NuevoDestinoScreen extends StatefulWidget {
  const NuevoDestinoScreen({super.key});

  @override
  State<NuevoDestinoScreen> createState() => _NuevoDestinoScreenState();
}

class _NuevoDestinoScreenState extends State<NuevoDestinoScreen> {
  final _nombreController = TextEditingController();
  bool _loading = false;
  String _error = '';
  List<Map<String, dynamic>> _destinos = [];

  final List<Map<String, dynamic>> _destinosDefecto = [
    {'nombre': 'Todos', 'editable': false},
    {'nombre': 'Local', 'editable': false},
  ];

  @override
  void initState() {
    super.initState();
    _cargarDestinos();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _cargarDestinos() async {
    final lista = await DataMaster().obtenerDestinos();
    if (mounted) {
      setState(() => _destinos = lista
          .where((d) =>
              d['nombre'] != 'Todos' && d['nombre'] != 'Local')
          .toList());
    }
  }

  Future<void> _guardar() async {
    final nombre = _nombreController.text.trim();

    if (nombre.isEmpty) {
      setState(() => _error = 'Ingresa el nombre del destino');
      return;
    }

    if (nombre.toLowerCase() == 'todos' ||
        nombre.toLowerCase() == 'local') {
      setState(() => _error = 'Ese nombre está reservado');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      await DataMaster().crearDestino(nombre: nombre);

      if (mounted) {
        _nombreController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Destino creado correctamente'),
            backgroundColor: AppColors.primary,
          ),
        );
        await _cargarDestinos();
      }
    } catch (e) {
      setState(() => _error = 'Error al guardar. Intentá de nuevo.');
    }

    setState(() => _loading = false);
  }

  Future<void> _eliminar(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar destino'),
        content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await DataMaster().eliminarDestino(id: id);
      await _cargarDestinos();
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
                      const Text(
                        'NUEVO DESTINO',
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
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Ej: Fondilac, Riegos Modernos',
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
                      const SizedBox(height: 16),
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
                                  'GUARDAR DESTINO',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'DESTINOS EXISTENTES',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._destinosDefecto.map((d) => _buildDestinoItem(
                            nombre: d['nombre'],
                            editable: false,
                          )),
                      ..._destinos.map((d) => _buildDestinoItem(
                            nombre: d['nombre'] ?? '',
                            editable: true,
                            onEliminar: () => _eliminar(
                                d['firestoreId'] ?? d['id']?.toString() ?? ''),
                          )),
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

  Widget _buildDestinoItem({
    required String nombre,
    required bool editable,
    VoidCallback? onEliminar,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.flag_outlined,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nombre,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          if (!editable)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'DEFAULT',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (editable && onEliminar != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onEliminar,
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
            'DESTINOS',
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
