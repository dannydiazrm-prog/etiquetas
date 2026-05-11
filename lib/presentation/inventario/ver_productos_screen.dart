import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/breakpoints.dart';
import '../../core/data/data_master.dart';

class VerProductosScreen extends StatefulWidget {
  const VerProductosScreen({super.key});

  @override
  State<VerProductosScreen> createState() => _VerProductosScreenState();
}

class _VerProductosScreenState extends State<VerProductosScreen> {
  final _nombreController = TextEditingController();
  bool _conStock = false;
  bool _sinStock = false;
  bool _prospectos = false;
  bool _etiquetas = false;
  bool _ingles = false;
  bool _espanol = false;
  Set<String> _prefijosSeleccionados = {};
  List<String> _prefijosUsados = [];
  List<Map<String, dynamic>> _resultados = [];
  bool _buscando = false;
  bool _buscado = false;
  Map<String, Map<String, int>> _stockPorCodigo = {};
  List<String> _prefijosActivos = [];

  @override
  void initState() {
    super.initState();
    _cargarPrefijos();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _cargarPrefijos() async {
    final config = await DataMaster().obtenerConfig('prefijos');
    final usados = (config?['usados'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList()
      ..sort();
    if (mounted) setState(() => _prefijosUsados = usados);
  }

  Future<Map<String, Map<String, int>>> _obtenerStockPorCodigo(
    List<String> prefijos,
  ) async {
    final Map<String, Map<String, int>> resultado = {};
    final recepciones = await DataMaster().obtenerRecepciones();

    for (final data in recepciones) {
      final codigo = (data['codigo'] ?? '').toString();
      final productoId = data['productoId']?.toString();
      final cantidad = (data['cantidad'] as num?)?.toInt() ?? 0;

      if (productoId == null || codigo.length < 2) continue;

      final prefijo = codigo.substring(0, 2);
      if (!prefijos.contains(prefijo)) continue;

      resultado.putIfAbsent(productoId, () => {});
      resultado[productoId]![prefijo] =
          (resultado[productoId]![prefijo] ?? 0) + cantidad;
    }

    return resultado;
  }

  String _docId(Map<String, dynamic> d) =>
      d['firestoreId']?.toString() ?? d['id']?.toString() ?? '';

  Future<void> _buscar() async {
    setState(() {
      _buscando = true;
      _buscado = false;
    });

    List<Map<String, dynamic>> docs = await DataMaster().obtenerProductos();

    // Filtro tipo
    if (_etiquetas && !_prospectos) {
      docs = docs.where((d) => d['tipo'] == 'Etiqueta').toList();
    } else if (_prospectos && !_etiquetas) {
      docs = docs.where((d) => d['tipo'] == 'Prospecto').toList();
    }

    // Filtro idioma
    if (_espanol && !_ingles) {
      docs = docs.where((d) => d['idioma'] == 'ES').toList();
    } else if (_ingles && !_espanol) {
      docs = docs.where((d) => d['idioma'] == 'EN').toList();
    }

    // Filtro nombre
    final nombre = _nombreController.text.trim().toLowerCase();
    if (nombre.isNotEmpty) {
      docs = docs.where((d) {
        return (d['nombre'] ?? '').toString().toLowerCase().contains(nombre);
      }).toList();
    }

    // Filtro stock
    if (_conStock && !_sinStock) {
      docs = docs
          .where((d) => ((d['stockActual'] as num?)?.toInt() ?? 0) > 0)
          .toList();
    } else if (_sinStock && !_conStock) {
      docs = docs
          .where((d) => ((d['stockActual'] as num?)?.toInt() ?? 0) == 0)
          .toList();
    }

    final prefijosActivos = _prefijosSeleccionados.toList();

    if (prefijosActivos.isNotEmpty) {
      final stockPorCodigo = await _obtenerStockPorCodigo(prefijosActivos);
      final idsConCodigo = stockPorCodigo.keys.toSet();
      docs = docs.where((d) => idsConCodigo.contains(_docId(d))).toList();
      setState(() {
        _resultados = docs;
        _stockPorCodigo = stockPorCodigo;
        _prefijosActivos = prefijosActivos;
        _buscando = false;
        _buscado = true;
      });
    } else {
      setState(() {
        _resultados = docs;
        _stockPorCodigo = {};
        _prefijosActivos = [];
        _buscando = false;
        _buscado = true;
      });
    }
  }

  Future<void> _eliminar(Map<String, dynamic> data) async {
    final stock = (data['stockActual'] as num?)?.toInt() ?? 0;

    if (stock > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede eliminar, el producto tiene stock'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final pinIngresado = await _pedirPin();
    if (pinIngresado == null) return;

    final pinConfig = await DataMaster().obtenerConfig('pin');
    final pinGuardado = pinConfig?['valor']?.toString() ?? '';

    if (pinIngresado != pinGuardado) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN incorrecto'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final id = _docId(data);
    await DataMaster().eliminarProducto(id: id);

    setState(() => _resultados.removeWhere((d) => _docId(d) == id));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto eliminado'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<String?> _pedirPin() async {
    String pin = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ingresa tu pin'),
        content: TextField(
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: InputDecoration(
            hintText: '****',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            counterText: '',
          ),
          onChanged: (v) => pin = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            onPressed: () => Navigator.pop(ctx, pin),
            child: const Text(
              'Confirmar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editar(Map<String, dynamic> data) async {
    final nombreCtrl = TextEditingController(text: data['nombre'] ?? '');
    String tipo = data['tipo'] ?? 'Etiqueta';
    String idioma = data['idioma'] ?? 'ES';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text(
            'EDITAR PRODUCTO',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nombre',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                const SizedBox(height: 8),
                TextField(
                  controller: nombreCtrl,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Tipo',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                const SizedBox(height: 8),
                Row(
                  children: ['Etiqueta', 'Prospecto'].map((t) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setStateDialog(() => tipo = t),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: tipo == t
                                  ? AppColors.primary
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary),
                            ),
                            child: Center(
                              child: Text(
                                t,
                                style: TextStyle(
                                  color: tipo == t
                                      ? Colors.white
                                      : AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Idioma',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    {'label': 'ESPAÑOL', 'value': 'ES'},
                    {'label': 'INGLÉS', 'value': 'EN'},
                  ].map((i) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () =>
                              setStateDialog(() => idioma = i['value']!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: idioma == i['value']
                                  ? AppColors.primary
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary),
                            ),
                            child: Center(
                              child: Text(
                                i['label']!,
                                style: TextStyle(
                                  color: idioma == i['value']
                                      ? Colors.white
                                      : AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () async {
                await DataMaster().actualizarProducto(
                  id: _docId(data),
                  nombre: nombreCtrl.text.trim(),
                  tipo: tipo,
                  idioma: idioma,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _buscar();
              },
              child: const Text(
                'GUARDAR',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
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
                          color: AppColors.primary,
                        ),
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
                    ..._resultados.map((doc) => _buildProductoItem(doc)),
                  ],
                ),
              ),
            ),
          ),
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
            prefixIcon: const Icon(Icons.search, color: AppColors.primary),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary),
          ),
          child: ExpansionTile(
            title: const Text(
              'Tipo e idioma',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            iconColor: AppColors.primary,
            collapsedIconColor: AppColors.primary,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChip('Con stock', _conStock,
                        (v) => setState(() => _conStock = v)),
                    _buildChip('Sin stock', _sinStock,
                        (v) => setState(() => _sinStock = v)),
                    _buildChip('Etiquetas', _etiquetas,
                        (v) => setState(() => _etiquetas = v)),
                    _buildChip('Prospectos', _prospectos,
                        (v) => setState(() => _prospectos = v)),
                    _buildChip('Español', _espanol,
                        (v) => setState(() => _espanol = v)),
                    _buildChip('Inglés', _ingles,
                        (v) => setState(() => _ingles = v)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary),
          ),
          child: ExpansionTile(
            title: Text(
              _prefijosSeleccionados.isEmpty
                  ? 'Código'
                  : 'Código: ${(_prefijosSeleccionados.toList()..sort()).join(', ')}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            iconColor: AppColors.primary,
            collapsedIconColor: AppColors.primary,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _prefijosUsados.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _prefijosUsados.map((p) {
                          final seleccionado =
                              _prefijosSeleccionados.contains(p);
                          return _buildChip(
                            'Código $p',
                            seleccionado,
                            (v) => setState(() {
                              if (v) {
                                _prefijosSeleccionados.add(p);
                              } else {
                                _prefijosSeleccionados.remove(p);
                              }
                            }),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
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

  Widget _buildProductoItem(Map<String, dynamic> data) {
    final id = _docId(data);

    int stockMostrar;
    String? etiquetaCodigo;

    if (_prefijosActivos.isNotEmpty && _stockPorCodigo.containsKey(id)) {
      stockMostrar =
          _stockPorCodigo[id]!.values.fold(0, (sum, v) => sum + v);
      etiquetaCodigo = _prefijosActivos.join(', ');
    } else {
      stockMostrar = (data['stockActual'] as num?)?.toInt() ?? 0;
      etiquetaCodigo = null;
    }

    final bajominimo = stockMostrar < 1000;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: bajominimo
              ? Colors.orange
              : AppColors.primary.withOpacity(0.3),
          width: bajominimo ? 2 : 1,
        ),
      ),
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
                    if (etiquetaCodigo != null)
                      _buildTag('Cód. $etiquetaCodigo'),
                    if (etiquetaCodigo != null) const SizedBox(width: 8),
                    _buildTag(
                      'Stock: $stockMostrar',
                      color: bajominimo ? Colors.orange : AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: () => _editar(data),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _eliminar(data),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (color ?? AppColors.primary).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color ?? AppColors.primary,
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
            onPressed: () => context.go('/inventario/toma'),
          ),
          const SizedBox(width: 8),
          Text(
            'VER PRODUCTOS',
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
