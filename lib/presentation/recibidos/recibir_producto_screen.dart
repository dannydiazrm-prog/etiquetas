import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/breakpoints.dart';

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
  List<QueryDocumentSnapshot> _resultados = [];
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

  Future<void> _buscar() async {
    setState(() {
      _buscando = true;
      _buscado = false;
      _expandidoId = null;
    });

    Query query = FirebaseFirestore.instance.collection('productos');

    if (_etiquetas && !_prospectos) {
      query = query.where('tipo', isEqualTo: 'Etiqueta');
    } else if (_prospectos && !_etiquetas) {
      query = query.where('tipo', isEqualTo: 'Prospecto');
    }

    if (_espanol && !_ingles) {
      query = query.where('idioma', isEqualTo: 'ES');
    } else if (_ingles && !_espanol) {
      query = query.where('idioma', isEqualTo: 'EN');
    }

    final snapshot = await query.get();
    List<QueryDocumentSnapshot> docs = snapshot.docs;

    final nombre = _nombreController.text.trim().toLowerCase();
    if (nombre.isNotEmpty) {
      docs = docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return (data['nombre'] ?? '').toString().toLowerCase().contains(nombre);
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

    final snapshot = await FirebaseFirestore.instance
        .collection('destinos')
        .orderBy('creadoEn')
        .get();

    final destinosFirestore = snapshot.docs.map((d) {
      return {'id': d.id, 'nombre': d.data()['nombre'] ?? ''};
    }).toList();

    setState(() {
      _destinos = [...destinosDefecto, ...destinosFirestore];
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

  String _calcularPrefijo(Map<String, dynamic> data) {
    final destinosHabilitados = _destinosSeleccionados.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    if (data['tipo'] == 'Prospecto') return '65';
    if (destinosHabilitados.contains('todos') ||
        destinosHabilitados.contains('local')) return '67';
    if (destinosHabilitados.isNotEmpty) return '68';
    return '??';
  }

  Future<void> _confirmar(QueryDocumentSnapshot doc) async {
    final cantidad = int.tryParse(_cantidadController.text.trim());
    final codigoSufijo = _codigoController.text.trim();

    if (cantidad == null || cantidad <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresá una cantidad válida'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (codigoSufijo.isEmpty ||
        codigoSufijo.length != 3 ||
        int.tryParse(codigoSufijo) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresá los 3 dígitos del código'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final data = doc.data() as Map<String, dynamic>;
      final destinosHabilitados = _destinosSeleccionados.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      final prefijo = _calcularPrefijo(data);
      final codigoCompleto = '$prefijo$codigoSufijo';

      final stockPorDestino = Map<String, dynamic>.from(
        data['stockPorDestino'] ?? {},
      );

      String destinoClave;
      if (destinosHabilitados.contains('todos')) {
        destinoClave = 'todos';
      } else if (destinosHabilitados.isNotEmpty) {
        destinoClave = destinosHabilitados.first;
      } else {
        destinoClave = 'todos';
      }

      final stockActualDestino =
          (stockPorDestino[destinoClave] ?? 0) as int;
      stockPorDestino[destinoClave] = stockActualDestino + cantidad;

      final nuevoStockTotal = stockPorDestino.values
          .fold<int>(0, (sum, v) => sum + (v as int));

      final destinosActuales =
          List<String>.from(data['destinos'] ?? []);
      for (final d in destinosHabilitados) {
        if (!destinosActuales.contains(d)) {
          destinosActuales.add(d);
        }
      }

      final batch = FirebaseFirestore.instance.batch();

      batch.update(
        FirebaseFirestore.instance.collection('productos').doc(doc.id),
        {
          'stockActual': nuevoStockTotal,
          'stockPorDestino': stockPorDestino,
          'destinos': destinosActuales,
        },
      );

      batch.set(
        FirebaseFirestore.instance.collection('recepciones').doc(),
        {
          'productoId': doc.id,
          'productoNombre': data['nombre'],
          'tipo': data['tipo'],
          'idioma': data['idioma'],
          'cantidad': cantidad,
          'codigo': codigoCompleto,
          'destinoClave': destinoClave,
          'destinos': destinosHabilitados,
          'fecha': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      setState(() {
        _expandidoId = null;
        _guardando = false;
        _codigoController.clear();
      });

      _buscar();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recepción registrada — Código: $codigoCompleto'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      setState(() => _guardando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar. Intentá de nuevo.'),
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
                      final data = doc.data() as Map<String, dynamic>;
                      final expandido = _expandidoId == doc.id;
                      return _buildProductoItem(doc, data, expandido);
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
    QueryDocumentSnapshot doc,
    Map<String, dynamic> data,
    bool expandido,
  ) {
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
            onTap: () => _expandir(doc.id, data),
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
                                'Stock: ${data['stockActual'] ?? 0}'),
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
                    'CÓDIGO',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 18),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                        child: Text(
                          _calcularPrefijo(data),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _codigoController,
                          keyboardType: TextInputType.number,
                          maxLength: 3,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: '123',
                            counterText: '',
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                              borderSide:
                                  BorderSide(color: AppColors.primary),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                              borderSide: BorderSide(
                                  color: AppColors.primary, width: 2),
                            ),
                          ),
                        ),
                      ),
                    ],
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
                  ..._destinos.map((d) {
                    final id = d['id'] as String;
                    final nombre = d['nombre'] as String;
                    final activo = _destinosSeleccionados[id] ?? false;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: activo
                            ? AppColors.primary.withOpacity(0.05)
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: activo
                              ? AppColors.primary
                              : Colors.grey.shade300,
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
                            () => _destinosSeleccionados[id] = v),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _guardando ? null : () => _confirmar(doc),
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
            hintText: 'Buscar por nombre...',
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
            _buildChip(
                'Inglés', _ingles, (v) => setState(() => _ingles = v)),
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
            onPressed: () => context.go('/recibidos'),
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