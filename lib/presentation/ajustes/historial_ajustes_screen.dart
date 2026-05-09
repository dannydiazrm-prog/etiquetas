import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/breakpoints.dart';

class HistorialAjustesScreen extends StatefulWidget {
  const HistorialAjustesScreen({super.key});

  @override
  State<HistorialAjustesScreen> createState() =>
      _HistorialAjustesScreenState();
}

class _HistorialAjustesScreenState extends State<HistorialAjustesScreen> {
  bool _hojaAjuste = false;
  bool _ajusteInventario = false;
  DateTime? _desde;
  DateTime? _hasta;
  List<QueryDocumentSnapshot> _resultados = [];
  bool _buscando = false;
  bool _buscado = false;
  bool _generando = false;

  @override
  void initState() {
    super.initState();
    _cargarHoy();
  }

  Future<void> _cargarHoy() async {
    final ahora = DateTime.now();
    setState(() {
      _desde = DateTime(ahora.year, ahora.month, ahora.day);
      _hasta = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);
      _buscando = true;
    });
    await _ejecutarBusqueda();
  }

  Future<void> _ejecutarBusqueda() async {
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

    if (_hojaAjuste && !_ajusteInventario) {
      docs = docs
          .where((d) =>
              (d.data() as Map<String, dynamic>)['tipo'] == 'hoja_ajuste')
          .toList();
    } else if (_ajusteInventario && !_hojaAjuste) {
      docs = docs
          .where((d) =>
              (d.data() as Map<String, dynamic>)['tipo'] ==
              'ajuste_inventario')
          .toList();
    }

    setState(() {
      _resultados = docs;
      _buscando = false;
      _buscado = true;
    });
  }

  Future<void> _seleccionarFecha(bool esDesde) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (fecha != null) {
      setState(() {
        if (esDesde) {
          _desde = DateTime(fecha.year, fecha.month, fecha.day);
        } else {
          _hasta =
              DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59);
        }
      });
    }
  }

  String _formatFecha(DateTime? fecha) {
    if (fecha == null) return 'Seleccionar';
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  String _formatFechaHora(Timestamp? ts) {
    if (ts == null) return '-';
    final fecha = ts.toDate();
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  String _labelTipo(String tipo) {
    if (tipo == 'hoja_ajuste') return 'Hoja de Ajuste';
    if (tipo == 'ajuste_inventario') return 'Ajuste de Inventario';
    return tipo;
  }

  Future<void> _generarPDF() async {
    setState(() => _generando = true);

    try {
      final pdf = pw.Document();
      final fecha = DateTime.now();
      final fechaStr = _formatFecha(fecha);

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
                'HISTORIAL DE AJUSTES',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColor.fromHex('#0c6246'),
                ),
              ),
              pw.Divider(color: PdfColor.fromHex('#0c6246')),
              pw.SizedBox(height: 8),
            ],
          ),
          build: (context) => [
            if (_resultados.isEmpty)
              pw.Center(
                child: pw.Text(
                  'No se encontraron ajustes',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColor.fromHex('#0c6246'),
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.5),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(0.8),
                  4: const pw.FlexColumnWidth(1),
                  5: const pw.FlexColumnWidth(1.5),
                  6: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#0c6246'),
                    ),
                    children: [
                      'TIPO',
                      'PRODUCTO',
                      'AJUSTE',
                      'CANT.',
                      'MOTIVO',
                      'COMPAÑERO',
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
                    final tipoAjuste = data['tipoAjuste'] ?? '-';
                    return pw.TableRow(
                      children: [
                        _labelTipo(data['tipo'] ?? ''),
                        data['productoNombre'] ?? '',
                        tipoAjuste == 'suma' ? '+' : '-',
                        (data['cantidad'] ?? 0).toString(),
                        data['motivo'] ?? '',
                        data['companero'] ?? '-',
                        _formatFechaHora(data['fecha'] as Timestamp?),
                      ]
                          .map((v) => pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(
                                  v,
                                  style:
                                      const pw.TextStyle(fontSize: 9),
                                ),
                              ))
                          .toList(),
                    );
                  }),
                ],
              ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Total de ajustes: ${_resultados.length}',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#0c6246'),
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'ajustes_$fechaStr.pdf',
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
                      'FILTROS',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChip(
                          'Hoja de Ajuste',
                          _hojaAjuste,
                          (v) => setState(() => _hojaAjuste = v),
                        ),
                        _buildChip(
                          'Ajuste de Inventario',
                          _ajusteInventario,
                          (v) => setState(() => _ajusteInventario = v),
                        ),
                      ],
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
                        onPressed: _buscando
                            ? null
                            : () {
                                setState(() => _buscando = true);
                                _ejecutarBusqueda();
                              },
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_resultados.length} ajuste${_resultados.length != 1 ? 's' : ''}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (_resultados.isNotEmpty)
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
                        final data =
                            doc.data() as Map<String, dynamic>;
                        final tipo = data['tipo'] ?? '';
                        final tipoAjuste =
                            data['tipoAjuste'] ?? '';
                        final esInventario =
                            tipo == 'ajuste_inventario';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: esInventario
                                  ? (tipoAjuste == 'suma'
                                      ? Colors.green
                                      : Colors.red)
                                  : Colors.orange,
                              width: 2,
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
                                      color: esInventario
                                          ? (tipoAjuste == 'suma'
                                              ? Colors.green
                                                  .withOpacity(0.1)
                                              : Colors.red
                                                  .withOpacity(0.1))
                                          : Colors.orange
                                              .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                      border: Border.all(
                                        color: esInventario
                                            ? (tipoAjuste == 'suma'
                                                ? Colors.green
                                                : Colors.red)
                                            : Colors.orange,
                                      ),
                                    ),
                                    child: Text(
                                      esInventario
                                          ? (tipoAjuste == 'suma'
                                              ? '+ SUMA'
                                              : '- RESTA')
                                          : 'REPOSICIÓN',
                                      style: TextStyle(
                                        color: esInventario
                                            ? (tipoAjuste == 'suma'
                                                ? Colors.green
                                                : Colors.red)
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
                                  _buildTag(
                                      _labelTipo(tipo)),
                                  _buildTag(
                                      '📦 ${data['cantidad'] ?? 0} unidades'),
                                  _buildTag(
                                      '📝 ${data['motivo'] ?? ''}'),
                                  if (data['companero'] != null)
                                    _buildTag(
                                        '👤 ${data['companero']}'),
                                  if (data['lote'] != null)
                                    _buildTag(
                                        '🔖 ${data['lote']}'),
                                  if (esInventario &&
                                      data['stockAnterior'] != null)
                                    _buildTag(
                                        '📊 ${data['stockAnterior']} → ${data['stockNuevo']}'),
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
      String label, bool seleccionado, Function(bool) onTap) {
    return GestureDetector(
      onTap: () => onTap(!seleccionado),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _buildSelectorFecha({
    required String label,
    required DateTime? fecha,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            onPressed: () => context.go('/ajustes'),
          ),
          const SizedBox(width: 8),
          Text(
            'HISTORIAL DE AJUSTES',
            style: TextStyle(
              color: Colors.white,
              fontSize: Breakpoints.isMobile(context) ? 18 : 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}