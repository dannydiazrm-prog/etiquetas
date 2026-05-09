import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/breakpoints.dart';

class EliminarProductoScreen extends StatefulWidget {
  const EliminarProductoScreen({super.key});

  @override
  State<EliminarProductoScreen> createState() => _EliminarProductoScreenState();
}

class _EliminarProductoScreenState extends State<EliminarProductoScreen> {
  final _nombreController = TextEditingController();
  List<QueryDocumentSnapshot> _resultados = [];
  bool _buscando = false;
  bool _buscado = false;
  bool _eliminando = false;

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final nombre = _nombreController.text.trim().toLowerCase();
    if (nombre.isEmpty) return;

    setState(() {
      _buscando = true;
      _buscado = false;
    });

    final snapshot = await FirebaseFirestore.instance
        .collection('productos')
        .get();

    final docs = snapshot.docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return (data['nombre'] ?? '')
          .toString()
          .toLowerCase()
          .contains(nombre);
    }).toList();

    setState(() {
      _resultados = docs;
      _buscando = false;
      _buscado = true;
    });
  }

  Future<void> _confirmarEliminacion(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    final confirmado1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'ELIMINAR PRODUCTO',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['nombre'] ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text('Tipo: ${data['tipo'] ?? '-'}'),
            Text('Idioma: ${data['idioma'] ?? '-'}'),
            Text('Stock actual: ${data['stockActual'] ?? 0}'),
            const SizedBox(height: 12),
            const Text(
              'Se eliminarán el producto y TODOS sus registros: recepciones, retiros y ajustes. Esta acción es completamente irreversible.',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'CONTINUAR',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmado1 != true) return;

    // Segunda confirmación
    final confirmado2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '¿ESTÁS SEGURO?',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          'Vas a eliminar "${data['nombre']}" y todo su historial. No hay vuelta atrás.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'ELIMINAR TODO',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmado2 != true) return;
    await _eliminarProductoCompleto(doc);
  }

  Future<void> _eliminarProductoCompleto(QueryDocumentSnapshot doc) async {
    setState(() => _eliminando = true);

    try {
      final productoId = doc.id;
      final batch = FirebaseFirestore.instance.batch();

      // Borrar recepciones
      final recepciones = await FirebaseFirestore.instance
          .collection('recepciones')
          .where('productoId', isEqualTo: productoId)
          .get();
      for (final r in recepciones.docs) {
        batch.delete(r.reference);
      }

      // Borrar retiros
      final retiros = await FirebaseFirestore.instance
          .collection('retiros')
          .where('productoId', isEqualTo: productoId)
          .get();
      for (final r in retiros.docs) {
        batch.delete(r.reference);
      }

      // Borrar ajustes
      final ajustes = await FirebaseFirestore.instance
          .collection('ajustes')
          .where('productoId', isEqualTo: productoId)
          .get();
      for (final a in ajustes.docs) {
        batch.delete(a.reference);
      }

      // Borrar producto
      batch.delete(
        FirebaseFirestore.instance.collection('productos').doc(productoId),
      );

      // Limpiar prefijos huérfanos
      final prefijosUsados = recepciones.docs
          .map((r) {
            final codigo = (r.data()['codigo'] ?? '').toString();
            return codigo.length >= 2 ? codigo.substring(0, 2) : null;
          })
          .whereType<String>()
          .toSet();

      for (final prefijo in prefijosUsados) {
        final otrasRecepciones = await FirebaseFirestore.instance
            .collection('recepciones')
            .where('productoId', isNotEqualTo: productoId)
            .get();

        final quedanConPrefijo = otrasRecepciones.docs.any((d) {
          final c = (d.data()['codigo'] ?? '').toString();
          return c.startsWith(prefijo);
        });

        if (!quedanConPrefijo) {
          batch.update(
            FirebaseFirestore.instance
                .collection('config')
                .doc('prefijos'),
            {'usados': FieldValue.arrayRemove([prefijo])},
          );
        }
      }

      await batch.commit();

      setState(() {
        _resultados.remove(doc);
        _eliminando = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto y todo su historial eliminados'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      setState(() => _eliminando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.red.withOpacity(0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Esta acción elimina el producto y TODO su historial. Es irreversible.',
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nombreController,
                            decoration: InputDecoration(
                              hintText: 'Buscar producto por nombre...',
                              prefixIcon: const Icon(Icons.search,
                                  color: AppColors.primary),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.primary),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.primary, width: 2),
                              ),
                            ),
                            onSubmitted: (_) => _buscar(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _buscando ? null : _buscar,
                            child: _buscando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'BUSCAR',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_eliminando)
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: Colors.red),
                            SizedBox(height: 8),
                            Text(
                              'Eliminando...',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    if (_buscado && !_eliminando) ...[
                      Text(
                        '${_resultados.length} producto${_resultados.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_resultados.isEmpty)
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
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
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
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        _buildTag(data['tipo'] ?? ''),
                                        _buildTag(data['idioma'] ?? ''),
                                        _buildTag(
                                          'Stock: ${data['stockActual'] ?? 0}',
                                          color: (data['stockActual'] ?? 0) > 0
                                              ? Colors.orange
                                              : AppColors.primary,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_forever,
                                    color: Colors.red, size: 28),
                                onPressed: () =>
                                    _confirmarEliminacion(doc),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
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
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 8),
          Text(
            'ELIMINAR PRODUCTO',
            style: TextStyle(
              color: Colors.white,
              fontSize: Breakpoints.isMobile(context) ? 18 : 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}