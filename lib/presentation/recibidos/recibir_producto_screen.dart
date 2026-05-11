import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/breakpoints.dart';
import '../../core/data/data_master.dart';

class RecibirProductoScreen extends StatefulWidget {
  const RecibirProductoScreen({super.key});

  @override
  State<RecibirProductoScreen> createState() => _RecibirProductoScreenState();
}

class _RecibirProductoScreenState extends State<RecibirProductoScreen> {
  final _nombreController = TextEditingController();
  bool _etiquetas = false;
  bool _prospectos = false;
  bool _espanol = false;
  bool _ingles = false;
  List<Map<String, dynamic>> _resultados = [];
  bool _buscando = false;
  bool _buscado = false;
  String? _expandidoId;

  final _cantidadController = TextEditingController();
  final _codigoController = TextEditingController();
  List<Map<String, dynamic>> _destinos = [];
  Map<String, bool> _destinosSeleccionados = {};
  bool _guardando = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _cantidadController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  String _docId(Map<String, dynamic> d) =>
      d['firestoreId']?.toString() ?? d['id']?.toString() ?? '';

  Future<void> _buscar() async {
    setState(() {
      _buscando = true;
      _buscado = false;
      _expandidoId = null;
    });

    List<Map<String, dynamic>> docs = await DataMaster().obtenerProductos();

    if (_etiquetas && !_prospectos) {
      docs = docs.where((d) => d['tipo'] == 'Etiqueta').toList();
    } else if (_prospectos && !_etiquetas) {
      docs = docs.where((d) => d['tipo'] == 'Prospecto').toList();
    }

    if (_espanol && !_ingles) {
      docs = docs.where((d) => d['idioma'] == 'ES').toList();
    } else if (_ingles && !_espanol) {
      docs = docs.where((d) => d['idioma'] == 'EN').toList();
    }

    final nombre = _nombreController.text.trim().toLowerCase();
    if (nombre.isNotEmpty) {
      docs = docs.where((d) {
        return (d['nombre'] ?? '').toString().toLowerCase().contains(nombre);
      }).toList();
    }

    setState(() {
      _resultados = docs;
      _buscando = false;
      _buscado = true;
    });
  }

  Future<void> _cargarDestinos() async {
    final destinosDefecto = [
      {'id': 'todos', 'nombre': 'Todos'},
      {'id': 'local', 'nombre': 'Local'},
    ];

    final destinosFirestore = await DataMaster().obtenerDestinos();
    final destinosExtra = destinosFirestore
        .where((d) => d['nombre'] != 'Todos' && d['nombre'] != 'Local')
        .map((d) => {'id': _docId(d), 'nombre': d['nombre'] ?? ''})
        .toList();

    setState(() {
      _destinos = [...destinosDefecto, ...destinosExtra];
      _destinosSeleccionados = {
        for (var d in _destinos) d['id'] as String: false
      };
    });
  }

  Future<void> _expandir(String id, Map<String, dynamic> data) async {
    if (_expandidoId == id) {
      setState(() => _expandidoId = null);
      return;
    }
    _cantidadController.clear();
    _codigoController.clear();
    await _cargarDestinos();

    setState(() {
      _expandidoId = id;
      for (var d in _destinos) {
        _destinosSeleccionados[d['id'] as String] = false;
      }
    });
  }

  Future<void> _confirmar(Map<String, dynamic> data) async {
    final cantidad = int.tryParse(_cantidadController.text.trim());
    final codigo = _codigoController.text.trim();

    if (cantidad == null || cantidad <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa una cantidad válida'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (codigo.isEmpty || codigo.length != 5 || int.tryParse(codigo) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa los 5 dígitos del código'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final destinosHabilitados = _destinosSeleccionados.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (destinosHabilitados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos un destino'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final productoId = _docId(data);

      final String destinoClave;
      if (destinosHabilitados.contains('todos')) {
        destinoClave = 'todos';
      } else {
        destinoClave = destinosHabilitados.first;
      }

      final stockPorDestino = Map<String, dynamic>.from(
        data['stockPorDestino'] ?? {},
      );
      final stockActualDestino =
          (stockPorDestino[destinoClave] as num?)?.toInt() ?? 0;
      stockPorDestino[destinoClave] = stockActualDestino + cantidad;

      final nuevoStockTotal = stockPorDestino.values
          .fold<int>(0, (sum, v) => sum + ((v as num).toInt()));

      final destinosActuales = List<String>.from(data['destinos'] ?? []);
      for (final d in destinosHabilitados) {
        if (!destinosActuales.contains(d)) {
          destinosActuales.add(d);
        }
      }

      await DataMaster().registrarRecepcion(
        productoId: productoId,
        productoNombre: data['nombre'] ?? '',
        tipo: data['tipo'] ?? '',
        idioma: data['idioma'] ?? '',
        cantidad: cantidad,
        codigo: codigo,
        destinoClave: destinoClave,
        destinos: destinosHabilitados,
        nuevoStock: nuevoStockTotal,
        stockPorDestino: stockPorDestino,
        destinosProducto: destinosActuales,
      );

      setState(() {
        _expandidoId = null;
        _guardando = false;
        _codigoController.clear();
      });

      _buscar();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recepción registrada — Código: $codigo'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      setState(() => _guardando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar. Intenta de nuevo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFiltros(),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _buscando ? null : _buscar,
                        icon: const Icon(Icons.search),
                        label: const Text(
                          'BUSCAR',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_buscando)
                      const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      ),
                    if (_buscado && _resultados.isEmpty)
                      const Center(
                        child: Text(
                          'No se encontraron productos',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ..._resultados.map((doc) {
                      final expandido = _expandidoId == _docId(doc);
                      return _buildProductoItem(doc, expandido);
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductoItem(
    Map<String, dynamic> data,
    bool expandido,
  ) {
    final id = _docId(data);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: expandido
              ? AppColors.primary
              : AppColors.primary.withOpacity(0.3),
          width: expandido ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _expandir(id, data),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['nombre'] ?? '',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildTag(data['tipo'] ?? ''),
                            const SizedBox(width: 8),
                            _buildTag(data['idioma'] ?? ''),
                            const SizedBox(width: 8),
                            _buildTag(
                                'Stock: ${(data['stockActual'] as num?)?.toInt() ?? 0}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expandido ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          if (expandido) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CANTIDAD A RECIBIR',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _cantidadController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Ej: 5000',
                      filled: true,
                      fillColor: Colors.grey[50],
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
                  const Text(
                    'CÓDIGO (5 DÍGITOS)',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _codigoController,
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    decoration: InputDecoration(
                      hintText: 'Ej: 65123',
                      counterText: '',
                      filled: true,
                      fillColor: Colors.grey[50],
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
                  const Text(
                    'DESTINOS HABILITADOS',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: ExpansionTile(
                      title: Text(
                        _destinosSeleccionados.entries.any((e) => e.value)
                            ? _destinos
                                .where((d) =>
                                    _destinosSeleccionados[
                                            d['id'] as String] ==
                                        true)
                                .map((d) => d['nombre'] as String)
                                .join(', ')
                            : 'Selecciona los destinos',
                        style: TextStyle(
                          color: _destinosSeleccionados.entries
                                  .any((e) => e.value)
                              ? AppColors.primary
                              : Colors.grey[500],
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      iconColor: AppColors.primary,
                      collapsedIconColor: AppColors.primary,
                      children: _destinos.map((d) {
                        final dId = d['id'] as String;
                        final nombre = d['nombre'] as String;
                        final activo =
                            _destinosSeleccionados[dId] ?? false;
                        return Container(
                          decoration: BoxDecoration(
                            color: activo
                                ? AppColors.primary.withOpacity(0.05)
                                : Colors.white,
                            border: Border(
                              top: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: SwitchListTile(
                            value: activo,
                            activeColor: AppColors.primary,
                            title: Text(
                              nombre,
                              style: TextStyle(
                                color: activo
                                    ? AppColors.primary
                                    : Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onChanged: (v) => setState(
                                () => _destinosSeleccionados[dId] = v),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed:
                          _guardando ? null : () => _confirmar(data),
                      child: _guardando
                          ? const CircularProgressIndicator(
                              color: Colors.white)
                          : const Text(
                              'CONFIRMAR RECEPCIÓN',
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
          ],
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FILTROS',
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
          decoration: InputDecoration(
            hintText: 'Buscar por nombre',
            prefixIcon:
                const Icon(Icons.search, color: AppColors.primary),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildChip('Etiquetas', _etiquetas,
                (v) => setState(() => _etiquetas = v)),
            _buildChip('Prospectos', _prospectos,
                (v) => setState(() => _prospectos = v)),
            _buildChip('Español', _espanol,
                (v) => setState(() => _espanol = v)),
            _buildChip('Ingles', _ingles,
                (v) => setState(() => _ingles = v)),
          ],
        ),
      ],
    );
  }

  Widget _buildChip(String label, bool seleccionado, Function(bool) onTap) {
    return GestureDetector(
      onTap: () => onTap(!seleccionado),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: seleccionado ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: seleccionado ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
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
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 8),
          Text(
            'RECIBIR PRODUCTO',
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
