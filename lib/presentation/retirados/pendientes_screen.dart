import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/breakpoints.dart';

class PendientesScreen extends StatefulWidget {
  const PendientesScreen({super.key});

  @override
  State<PendientesScreen> createState() => _PendientesScreenState();
}

class _PendientesScreenState extends State<PendientesScreen> {
  bool _cerrando = false;

  bool _tienePendiente(Map<String, dynamic> data) {
    final entregada = (data['cantidadEntregada'] ?? 0) as num;
    final estimada = (data['cantidadEstimada'] ?? 0) as num;
    return entregada > estimada;
  }

  int _cantidadPendiente(Map<String, dynamic> data) {
    final entregada = (data['cantidadEntregada'] ?? 0) as num;
    final estimada = (data['cantidadEstimada'] ?? 0) as num;
    return (entregada - estimada).toInt();
  }

  Future<void> _cerrarConDevolucion(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final pendiente = _cantidadPendiente(data);
    final cantidadCtrl = TextEditingController();
    String error = '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text(
            'CERRAR CON DEVOLUCIÓN',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pendiente de devolución: $pendiente unidades',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Cantidad devuelta',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: cantidadCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Ej: $pendiente',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  error,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
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
                final cantidad = int.tryParse(cantidadCtrl.text.trim());
                if (cantidad == null || cantidad <= 0) {
                  setStateDialog(() => error = 'Ingresá una cantidad válida');
                  return;
                }
                if (cantidad > pendiente) {
                  setStateDialog(() =>
                      error = 'No puede ser mayor al pendiente ($pendiente)');
                  return;
                }

                Navigator.pop(ctx);
                setState(() => _cerrando = true);

                try {
                  final entregada =
                      (data['cantidadEntregada'] ?? 0) as num;
                  final devuelta = cantidad;
                  final consumoReal = entregada.toInt() - devuelta;
                  final perdida = pendiente - devuelta;

                  // Devolver stock al depósito
                  final productoRef = FirebaseFirestore.instance
    .collection('productos')
    .doc(data['productoId']);
final productoDoc = await productoRef.get();
final productoData = productoDoc.data() as Map<String, dynamic>;
final stockActual =
    ((productoData['stockActual'] ?? 0) as num).toInt();
final stockPorDestino = Map<String, dynamic>.from(
  productoData['stockPorDestino'] ?? {},
);

// Devolver al destino original del retiro
final destinoId = data['destinoId'] as String? ?? 'todos';
final stockActualDestino =
    (stockPorDestino[destinoId] as num?)?.toInt() ?? 0;
stockPorDestino[destinoId] = stockActualDestino + devuelta;

final batch = FirebaseFirestore.instance.batch();

batch.update(productoRef, {
  'stockActual': stockActual + devuelta,
  'stockPorDestino': stockPorDestino,
});

                  batch.update(
                    FirebaseFirestore.instance
                        .collection('retiros')
                        .doc(doc.id),
                    {
                      'cantidadDevuelta': devuelta,
                      'consumoReal': consumoReal,
                      'perdida': perdida,
                      'motivoCierre': perdida > 0
                          ? 'Devolución parcial'
                          : 'Devolución total',
                      'estado': 'cerrado',
                      'fechaCierre': FieldValue.serverTimestamp(),
                    },
                  );

                  await batch.commit();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vale cerrado correctamente'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al cerrar el vale: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }

                if (mounted) setState(() => _cerrando = false);
              },
              child: const Text(
                'CONFIRMAR',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cerrarSinDevolucion(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    String? motivoSeleccionado;
    final motivos = [
      'Pérdida normal del proceso',
      'Quedó en producción',
      'Otro',
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text(
            'CERRAR SIN DEVOLUCIÓN',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seleccioná el motivo:',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...motivos.map((motivo) => GestureDetector(
                    onTap: () =>
                        setStateDialog(() => motivoSeleccionado = motivo),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: motivoSeleccionado == motivo
                            ? AppColors.primary
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: Text(
                        motivo,
                        style: TextStyle(
                          color: motivoSeleccionado == motivo
                              ? Colors.white
                              : AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )),
            ],
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
              onPressed: motivoSeleccionado == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      setState(() => _cerrando = true);

                      try {
                        final entregada =
                            (data['cantidadEntregada'] ?? 0) as num;
                        final pendiente = _cantidadPendiente(data);

                        final batch = FirebaseFirestore.instance.batch();

                        batch.update(
                          FirebaseFirestore.instance
                              .collection('retiros')
                              .doc(doc.id),
                          {
                            'cantidadDevuelta': 0,
                            'consumoReal': entregada.toInt(),
                            'perdida': pendiente,
                            'motivoCierre': motivoSeleccionado,
                            'estado': 'cerrado',
                            'fechaCierre': FieldValue.serverTimestamp(),
                          },
                        );

                        await batch.commit();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Vale cerrado correctamente'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error al cerrar el vale: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }

                      if (mounted) setState(() => _cerrando = false);
                    },
              child: const Text(
                'CONFIRMAR',
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
            child: _cerrando
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    // ─── CORRECCIÓN PRINCIPAL ───────────────────────────────
                    // Se quitó el .orderBy() del lado de Firestore para evitar
                    // que falle por falta de índice compuesto. El ordenamiento
                    // se hace en el cliente después de filtrar.
                    // Si preferís usar .orderBy() en Firestore, creá el índice
                    // compuesto en la consola: estado (ASC) + fecha (DESC).
                    // ────────────────────────────────────────────────────────
                    stream: FirebaseFirestore.instance
                        .collection('retiros')
                        .where('estado', isEqualTo: 'pendiente')
                        .snapshots(),
                    builder: (context, snapshot) {
                      // ── Muestra el error real en pantalla ──────────────────
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red, size: 48),
                                const SizedBox(height: 16),
                                const Text(
                                  'Error al cargar pendientes',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${snapshot.error}',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      // ───────────────────────────────────────────────────────

                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];

                      // Filtrar los que realmente tienen pendiente
                      final pendientes = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return _tienePendiente(data);
                      }).toList();

                      // Ordenar por fecha descendente en el cliente
                      pendientes.sort((a, b) {
                        final dataA = a.data() as Map<String, dynamic>;
                        final dataB = b.data() as Map<String, dynamic>;
                        final fechaA =
                            (dataA['fecha'] as Timestamp?)?.toDate() ??
                                DateTime(2000);
                        final fechaB =
                            (dataB['fecha'] as Timestamp?)?.toDate() ??
                                DateTime(2000);
                        return fechaB.compareTo(fechaA);
                      });

                      if (pendientes.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                color: AppColors.primary,
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Sin pendientes',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'No hay devoluciones pendientes',
                                style: TextStyle(
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: pendientes.length,
                        itemBuilder: (context, index) {
                          final doc = pendientes[index];
                          final data =
                              doc.data() as Map<String, dynamic>;
                          final pendiente = _cantidadPendiente(data);
                          final fecha =
                              (data['fecha'] as Timestamp?)?.toDate();
                          final fechaStr = fecha != null
                              ? '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}'
                              : '-';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.pending_actions,
                                      color: Colors.orange,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        data['productoNombre'] ?? '',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.orange),
                                      ),
                                      child: Text(
                                        '$pendiente pendientes',
                                        style: const TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    _buildTag(
                                        '👤 ${data['companero'] ?? ''}'),
                                    _buildTag(
                                        '📦 Lote: ${data['lote'] ?? ''}'),
                                    _buildTag(
                                        '🌍 ${data['destino'] ?? ''}'),
                                    _buildTag(
                                        '📤 Entregadas: ${data['cantidadEntregada'] ?? 0}'),
                                    _buildTag(
                                        '🎯 Estimadas: ${data['cantidadEstimada'] ?? 0}'),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  fechaStr,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _cerrarSinDevolucion(doc),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                              color: Colors.red),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text(
                                          'SIN DEVOLUCIÓN',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            _cerrarConDevolucion(doc),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppColors.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text(
                                          'CON DEVOLUCIÓN',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
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
            onPressed: () => context.go('/retirados'),
          ),
          const SizedBox(width: 8),
          Text(
            'PENDIENTES DE DEVOLUCIÓN',
            style: TextStyle(
              color: Colors.white,
              fontSize: Breakpoints.isMobile(context) ? 16 : 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
