import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/breakpoints.dart';

class HistorialLoteScreen extends StatefulWidget {
  const HistorialLoteScreen({super.key});

  @override
  State<HistorialLoteScreen> createState() => _HistorialLoteScreenState();
}

class _HistorialLoteScreenState extends State<HistorialLoteScreen> {
  final _loteController = TextEditingController();
  List<QueryDocumentSnapshot> _resultados = [];
  bool _buscando = false;
  bool _buscado = false;
  bool _generando = false;

  @override
  void dispose() {
    _loteController.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final lote = _loteController.text.trim();
    if (lote.isEmpty) return;

    setState(() {
      _buscando = true;
      _buscado = false;
    });

    final snapshot = await FirebaseFirestore.instance
    .collection('retiros')
    .where('lote', isEqualTo: lote)
    .get();

final docs = snapshot.docs..sort((a, b) {
  final fechaA = (a.data() as Map<String, dynamic>)['fecha'] as Timestamp?;
  final fechaB = (b.data() as Map<String, dynamic>)['fecha'] as Timestamp?;
  if (fechaA == null || fechaB == null) return 0;
  return fechaA.compareTo(fechaB);
});

    setState(() {
  _resultados = docs;
  _buscando = false;
  _buscado = true;
});

  String _formatFechaHora(Timestamp? ts) {
    if (ts == null) return '-';
    final fecha = ts.toDate();
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  String _formatFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  Future<void> _generarPDF() async {
    setState(() => _generando = true);

    try {
      final pdf = pw.Document();
      final fecha = DateTime.now();
      final fechaStr = _formatFecha(fecha);
      final lote = _loteController.text.trim();

      // Totales
      int totalEntregado = 0;
      int totalConsumido = 0;
      int totalDevuelto = 0;
      for (final doc in _resultados) {
        final data = doc.data() as Map<String, dynamic>;
        totalEntregado += (data['cantidadEntregada'] ?? 0) as int;
        totalConsumido += (data['consumoReal'] ?? data['cantidadEntregada'] ?? 0) as int;
        totalDevuelto += (data['cantidadDevuelta'] ?? 0) as int;
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'DEPÓSITO DE ETIQUETAS - GALMEDIC',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#0c6246'),
                    ),
                  ),
                  pw.Text(
                    fechaStr,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'TRAZABILIDAD - LOTE: $lote',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#0c6246'),
                ),
              ),
              pw.Divider(color: PdfColor.fromHex('#0c6246')),
              pw.SizedBox(height: 8),
            ],
          ),
          build: (context) => [
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColor.fromHex('#0c6246'),
                width: 0.5,
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(0.8),
                3: const pw.FlexColumnWidth(1.2),
                4: const pw.FlexColumnWidth(1.2),
                5: const pw.FlexColumnWidth(1.2),
                6: const pw.FlexColumnWidth(1),
                7: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#0c6246'),
                  ),
                  children: [
                    'PRODUCTO',
                    'TIPO',
                    'ID',
                    'COMPAÑERO',
                    'ENTREGADO',
                    'CONSUMIDO',
                    'DEVUELTO',
                    'FECHA',
                  ]
                      .map((h) => pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              h,
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ))
                      .toList(),
                ),
                ..._resultados.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final consumoReal = data['consumoReal'] ??
                      data['cantidadEntregada'] ?? 0;
                  final estado = data['estado'] ?? 'pendiente';
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: estado == 'cerrado'
                          ? PdfColors.white
                          : PdfColor.fromHex('#FFF3E0'),
                    ),
                    children: [
                      data['productoNombre'] ?? '',
                      data['tipo'] ?? '',
                      data['idioma'] ?? '',
                      data['companero'] ?? '',
                      (data['cantidadEntregada'] ?? 0).toString(),
                      consumoReal.toString(),
                      (data['cantidadDevuelta'] ?? 0).toString(),
                      _formatFechaHora(data['fecha'] as Timestamp?),
                    ]
                        .map((v) => pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                v,
                                style: const pw.TextStyle(fontSize: 9),
                              ),
                            ))
                        .toList(),
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColor.fromHex('#0c6246'),
                ),
                borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'RESUMEN DEL LOTE',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#0c6246'),
                      fontSize: 11,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                      'Total movimientos: ${_resultados.length}',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Total entregado: $totalEntregado unidades',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Total consumido: $totalConsumido unidades',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Total devuelto: $totalDevuelto unidades',
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'lote_${lote}_$fechaStr.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _generando = false);
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
                    const Text(
                      'BUSCAR POR LOTE',
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
                        Expanded(
                          child: TextField(
                            controller: _loteController,
                            textCapitalization:
                                TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: '',
                              prefixIcon: const Icon(
                                  Icons.search,
                                  color: AppColors.primary),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.primary),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.primary,
                                    width: 2),
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
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_buscado) ...[
                      if (_resultados.isEmpty)
                        const Center(
                          child: Text(
                            'No se encontraron movimientos para ese lote',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else ...[
                        // Resumen
                        _buildResumen(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_resultados.length} movimiento${_resultados.length != 1 ? 's' : ''}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed:
                                  _generando ? null : _generarPDF,
                              icon: const Icon(
                                  Icons.picture_as_pdf_outlined,
                                  size: 18),
                              label: _generando
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('PDF'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._resultados.map((doc) {
                          final data =
                              doc.data() as Map<String, dynamic>;
                          final estado =
                              data['estado'] ?? 'pendiente';
                          final consumoReal = data['consumoReal'] ??
                              data['cantidadEntregada'] ??
                              0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: estado == 'cerrado'
                                    ? AppColors.primary
                                        .withOpacity(0.3)
                                    : Colors.orange,
                                width: estado == 'cerrado' ? 1 : 2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
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
                                              horizontal: 8,
                                              vertical: 4),
                                      decoration: BoxDecoration(
                                        color: estado == 'cerrado'
                                            ? Colors.green
                                                .withOpacity(0.1)
                                            : Colors.orange
                                                .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                          color: estado == 'cerrado'
                                              ? Colors.green
                                              : Colors.orange,
                                        ),
                                      ),
                                      child: Text(
                                        estado == 'cerrado'
                                            ? 'CERRADO'
                                            : 'PENDIENTE',
                                        style: TextStyle(
                                          color: estado == 'cerrado'
                                              ? Colors.green
                                              : Colors.orange,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
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
                                    _buildTag(data['tipo'] ?? ''),
                                    _buildTag(data['idioma'] ?? ''),
                                    _buildTag(
                                        '🌍 ${data['destino'] ?? ''}'),
                                    _buildTag(
                                        '👤 ${data['companero'] ?? ''}'),
                                    _buildTag(
                                        '📤 Entregado: ${data['cantidadEntregada'] ?? 0}'),
                                    _buildTag(
                                        '✅ Consumido: $consumoReal'),
                                    if (estado == 'cerrado')
                                      _buildTag(
                                          '↩️ Devuelto: ${data['cantidadDevuelta'] ?? 0}'),
                                    if (data['motivoCierre'] != null)
                                      _buildTag(
                                          '📝 ${data['motivoCierre']}'),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatFechaHora(
                                      data['fecha'] as Timestamp?),
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
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

  Widget _buildResumen() {
    int totalEntregado = 0;
    int totalConsumido = 0;
    int totalDevuelto = 0;
    int cerrados = 0;
    int pendientes = 0;

    for (final doc in _resultados) {
      final data = doc.data() as Map<String, dynamic>;
      totalEntregado += (data['cantidadEntregada'] ?? 0) as int;
      totalConsumido += (data['consumoReal'] ??
          data['cantidadEntregada'] ?? 0) as int;
      totalDevuelto += (data['cantidadDevuelta'] ?? 0) as int;
      if (data['estado'] == 'cerrado') {
        cerrados++;
      } else {
        pendientes++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LOTE: ${_loteController.text.trim()}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildResumenItem(
                    'ENTREGADO', totalEntregado.toString()),
              ),
              Expanded(
                child: _buildResumenItem(
                    'CONSUMIDO', totalConsumido.toString()),
              ),
              Expanded(
                child: _buildResumenItem(
                    'DEVUELTO', totalDevuelto.toString()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildResumenItem(
                    'CERRADOS', cerrados.toString()),
              ),
              Expanded(
                child: _buildResumenItem(
                    'PENDIENTES', pendientes.toString()),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumenItem(String label, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          valor,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
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
            'HISTORIAL POR LOTE',
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