import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/breakpoints.dart';

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
  bool _prefijo65 = false;
  bool _prefijo67 = false;
  bool _prefijo68 = false;
  List<QueryDocumentSnapshot> _resultados = [];
  bool _buscando = false;
  bool _buscado = false;

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    setState(() {
      _buscando = true;
      _buscado = false;
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

    if (_conStock && !_sinStock) {
      docs = docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return (data['stockActual'] ?? 0) > 0;
      }).toList();
    } else if (_sinStock && !_conStock) {
      docs = docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return (data['stockActual'] ?? 0) == 0;
      }).toList();
    }

    if (_prefijo65 || _prefijo67 || _prefijo68) {
      docs = docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        final stockPorDestino = Map<String, dynamic>.from(
          data['stockPorDestino'] ?? {},
        );
        if (_prefijo65 && data['tipo'] == 'Prospecto') return true;
        if (_prefijo67 &&
            (stockPorDestino.containsKey('todos') ||
                stockPorDestino.containsKey('local'))) return true;
        if (_prefijo68 &&
            stockPorDestino.keys
                .any((k) => k != 'todos' && k != 'local')) return true;
        return false;
      }).toList();
    }

    setState(() {
      _resultados = docs;
      _buscando = false;
      _buscado = true;
    });
  }

  Future<void> _eliminar(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final stock = data['stockActual'] ?? 0;

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

    final pinDoc = await FirebaseFirestore.instance
        .collection('config')
        .doc('pin')
        .get();
    final pinGuardado = pinDoc.data()?['valor'] ?? '';

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

    await FirebaseFirestore.instance
        .collection('productos')
        .doc(doc.id)
        .delete();

    setState(() => _resultados.remove(doc));

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
        title: const Text('Ingresá tu PIN'),
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

  Future<void> _editar(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
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
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
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
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
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
                await FirebaseFirestore.instance
                    .collection('productos')
                    .doc(doc.id)
                    .update({
                  'nombre': nombreCtrl.text.trim(),
                  'tipo': tipo,
                  'idioma': idioma,
                });
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
            _buildChip(
                'Inglés', _ingles, (v) => setState(() => _ingles = v)),
            _buildChip('Código 65', _prefijo65,
                (v) => setState(() => _prefijo65 = v)),
            _buildChip('Código 67', _prefijo67,
                (v) => setState(() => _prefijo67 = v)),
            _buildChip('Código 68', _prefijo68,
                (v) => setState(() => _prefijo68 = v)),
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

  Widget _buildProductoItem(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final stock = data['stockActual'] ?? 0;
    final bajominimo = stock < 1000;

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
                    _buildTag(
                      'Stock: $stock',
                      color: bajominimo ? Colors.orange : AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: () => _editar(doc),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _eliminar(doc),
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
