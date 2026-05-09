import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/breakpoints.dart';

class GestionAjustesScreen extends StatefulWidget {
  const GestionAjustesScreen({super.key});

  @override
  State<GestionAjustesScreen> createState() => _GestionAjustesScreenState();
}

class _GestionAjustesScreenState extends State<GestionAjustesScreen> {
  final _nombreController = TextEditingController();
  DateTime? _desde;
  DateTime? _hasta;
  List<QueryDocumentSnapshot> _resultados = [];
  bool _buscando = false;
  bool _buscado = false;

  @override
  void initState() {
    super.initState();
    final ahora = DateTime.now();
    _desde = DateTime(ahora.year, ahora.month, ahora.day);
    _hasta = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);
  }

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

    Query query = FirebaseFirestore.instance
        .collection('ajustes')
        .orderBy('fecha', descending: true);

    if (_desde != null) {
      query = query.where('fecha',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_desde!));
    }
    if (_hasta != null) {
      query = query.where('fecha',
          isLessThanOrEqualTo: Timestamp.fromDate(_hasta!));
    }

    final snapshot = await query.get();
    List<QueryDocumentSnapshot> docs = snapshot.docs;

    final nombre = _nombreController.text.trim().toLowerCase();
    if (nombre.isNotEmpty) {
      docs = docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return (data['productoNombre'] ?? '')
            .toString()
            .toLowerCase()
            .contains(nombre);
      }).toList();
    }

    setState(() {
      _resultados = docs;
      _buscando = false;
      _buscado = true;
    });
  }

  Future<void> _confirmarBorrado(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final productoId = data['productoId'] as String?;
    final fechaAjuste = data['fecha'] as Timestamp?;
    final tipoAjuste = data['tipoAjuste'] as String? ?? 'entrada';

    if (productoId == null || fechaAjuste == null) return;

    // Solo bloquear si es entrada y hubo retiros después
    if (tipoAjuste == 'entrada') {
      final retiros = await FirebaseFirestore.instance
          .collection('retiros')
          .where('productoId', isEqualTo: productoId)
          .where('fecha', isGreaterThanOrEqualTo: fechaAjuste)
          .get();

      if (retiros.docs.isNotEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.block, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'NO SE PUEDE BORRAR',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              content: Text(
                'Este producto tiene ${retiros.docs.length} retiro${retiros.docs.length != 1 ? 's' : ''} registrado${retiros.docs.length != 1 ? 's' : ''} después de este ajuste. No se puede borrar para mantener la integridad del inventario.',
                style: const TextStyle(fontSize: 14),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'ENTENDIDO',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    // Proceder con confirmación normal
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'CONFIRMAR BORRADO',
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
              '${data['productoNombre'] ?? ''}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text('Tipo de ajuste: $tipoAjuste'),
            Text('Cantidad: ${data['cantidad'] ?? 0}'),
            Text('Stock anterior: ${data['stockAnterior'] ?? '-'}'),
            Text('Stock nuevo: ${data['stockNuevo'] ?? '-'}'),
            const SizedBox(height: 12),
            const Text(
              'El stock volverá al valor anterior al ajuste. Esta acción es irreversible.',
              style: TextStyle(color: Colors.red, fontSize: 12),
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
              'BORRAR',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmado != true) return;
    await _borrarAjuste(doc);
  }

  Future<void> _borrarAjuste(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final productoId = data['productoId'] as String?;
    final stockAnterior = (data['stockAnterior'] as num?)?.toInt();

    if (productoId == null || stockAnterior == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Revertir stock al valor anterior
      batch.update(
        FirebaseFirestore.instance.collection('productos').doc(productoId),
        {'stockActual': stockAnterior},
      );

      batch.delete(
        FirebaseFirestore.instance.collection('ajustes').doc(doc.id),
      );

      await batch.commit();

      setState(() => _resultados.remove(doc));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ajuste eliminado y stock revertido'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
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

  Future<void> _editarAjuste(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final cantidadOriginal = (data['cantidad'] as num?)?.toInt() ?? 0;
    final stockAnterior = (data['stockAnterior'] as num?)?.toInt() ?? 0;
    final tipoAjuste = data['tipoAjuste'] as String? ?? 'entrada';
    final cantidadCtrl =
        TextEditingController(text: cantidadOriginal.toString());

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'EDITAR AJUSTE',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${data['productoNombre'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Tipo: $tipoAjuste',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              'NUEVA CANTIDAD',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: cantidadCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'GUARDAR',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    final nuevaCantidad = int.tryParse(cantidadCtrl.text.trim());
    if (nuevaCantidad == null || nuevaCantidad <= 0) return;

    final productoId = data['productoId'] as String?;
    if (productoId == null) return;

    try {
      // Recalcular stock nuevo según tipo de ajuste
      final nuevoStockNuevo = tipoAjuste == 'entrada'
          ? stockAnterior + nuevaCantidad
          : stockAnterior - nuevaCantidad;

      final batch = FirebaseFirestore.instance.batch();

      batch.update(
        FirebaseFirestore.instance.collection('productos').doc(productoId),
        {'stockActual': nuevoStockNuevo.clamp(0, double.infinity).toInt()},
      );

      batch.update(
        FirebaseFirestore.instance.collection('ajustes').doc(doc.id),
        {
          'cantidad': nuevaCantidad,
          'stockNuevo': nuevoStockNuevo.clamp(0, double.infinity).toInt(),
        },
      );

      await batch.commit();
      _buscar();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ajuste actualizado y stock corregido'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
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

  String _formatFecha(DateTime? fecha) {
    if (fecha == null) return 'Seleccionar';
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '-';
    final fecha = ts.toDate();
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _seleccionarFecha(bool esDesde) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (fecha != null) {
      setState(() {
        if (esDesde) {
          _desde = DateTime(fecha.year, fecha.month, fecha.day);
        } else {
          _hasta = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59);
        }
      });
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
                              'Al borrar un ajuste el stock se revierte al valor anterior.',
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
                    TextField(
                      controller: _nombreController,
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre de producto...',
                        prefixIcon: const Icon(Icons.search,
                            color: AppColors.primary),
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSelectorFecha(
                            label: 'Desde',
                            fecha: _desde,
                            onTap: () => _seleccionarFecha(true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSelectorFecha(
                            label: 'Hasta',
                            fecha: _hasta,
                            onTap: () => _seleccionarFecha(false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                    if (_buscado) ...[
                      Text(
                        '${_resultados.length} ajuste${_resultados.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_resultados.isEmpty)
                        const Center(
                          child: Text(
                            'No se encontraron ajustes',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ..._resultados.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final tipoAjuste =
                            data['tipoAjuste'] as String? ?? 'entrada';
                        final esEntrada = tipoAjuste == 'entrada';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
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
                                      data['productoNombre'] ?? '',
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
                                          esEntrada
                                              ? '+${data['cantidad'] ?? 0}'
                                              : '-${data['cantidad'] ?? 0}',
                                          color: esEntrada
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                        _buildTag(
                                            '${data['stockAnterior'] ?? 0} → ${data['stockNuevo'] ?? 0}'),
                                        if (data['motivo'] != null &&
                                            (data['motivo'] as String)
                                                .isNotEmpty)
                                          _buildTag(data['motivo']),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTimestamp(
                                          data['fecha'] as Timestamp?),
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        color: AppColors.primary),
                                    onPressed: () => _editarAjuste(doc),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    onPressed: () =>
                                        _confirmarBorrado(doc),
                                  ),
                                ],
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

  Widget _buildSelectorFecha({
    required String label,
    required DateTime? fecha,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatFecha(fecha),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
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
            'AJUSTES',
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