import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/breakpoints.dart';
import '../../core/data/data_master.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  bool _conStock = false;
  bool _sinStock = false;
  bool _prospectos = false;
  bool _etiquetas = false;
  bool _ingles = false;
  bool _espanol = false;
  Set<String> _prefijosSeleccionados = {};
  List<String> _prefijosUsados = [];
  bool _cargandoPrefijos = true;
  bool _generando = false;

  @override
  void initState() {
    super.initState();
    _cargarPrefijos();
  }

  Future<void> _cargarPrefijos() async {
    setState(() => _cargandoPrefijos = true);
    final usados = await DataMaster().obtenerPrefijosUsados();
    if (mounted) {
      setState(() {
        _prefijosUsados = usados;
        _cargandoPrefijos = false;
      });
    }
  }

  Future<Map<String, Map<String, int>>> _obtenerStockPorCodigo(
    List<String> prefijos,
  ) async {
    return DataMaster().obtenerStockRealPorPrefijo(prefijos);
  }

  Future<void> _generarPDF() async {
    setState(() => _generando = true);

    try {
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

      if (_conStock && !_sinStock) {
        docs = docs.where((d) {
          return ((d['stockActual'] as num?)?.toInt() ?? 0) > 0;
        }).toList();
      } else if (_sinStock && !_conStock) {
        docs = docs.where((d) {
          return ((d['stockActual'] as num?)?.toInt() ?? 0) == 0;
        }).toList();
      }

      final prefijosActivos = _prefijosSeleccionados.toList();
      Map<String, Map<String, int>> stockPorCodigo = {};

      if (prefijosActivos.isNotEmpty) {
        stockPorCodigo = await _obtenerStockPorCodigo(prefijosActivos);
        final idsConCodigo = stockPorCodigo.keys.toSet();
        docs = docs.where((d) {
          final id = d['id']?.toString() ?? '';
          return idsConCodigo.contains(id);
        }).toList();
      }

      final pdf = pw.Document();
      final fecha = DateTime.now();
      final fechaStr =
          '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
      final horaStr =
          '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

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
                    '$fechaStr $horaStr',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'REPORTE DE INVENTARIO',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColor.fromHex('#0c6246'),
                ),
              ),
              if (prefijosActivos.isNotEmpty)
                pw.Text(
                  'Filtro código: ${prefijosActivos.map((p) => 'Cód. $p').join(', ')}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColor.fromHex('#0c6246'),
                  ),
                ),
              pw.Divider(color: PdfColor.fromHex('#0c6246')),
              pw.SizedBox(height: 8),
            ],
          ),
          build: (context) => [
            if (docs.isEmpty)
              pw.Center(
                child: pw.Text(
                  'No se encontraron productos con los filtros aplicados',
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
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#0c6246'),
                    ),
                    children: [
                      'NOMBRE',
                      'TIPO',
                      'IDIOMA',
                      'STOCK',
                      'CONTEO',
                    ]
                        .map(
                          (h) => pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              h,
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  ...docs.map((data) {
                    final docId = data['id']?.toString() ?? '';
                    int stockMostrar;
                    if (prefijosActivos.isNotEmpty &&
                        stockPorCodigo.containsKey(docId)) {
                      stockMostrar = prefijosActivos.fold(
                          0,
                          (sum, p) =>
                              sum + (stockPorCodigo[docId]![p] ?? 0));
                    } else {
                      stockMostrar =
                          (data['stockActual'] as num?)?.toInt() ?? 0;
                    }
                    final bajominimo = stockMostrar < 1000;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: bajominimo
                            ? PdfColor.fromHex('#FFF3E0')
                            : PdfColors.white,
                      ),
                      children: [
                        data['nombre'] ?? '',
                        data['tipo'] ?? '',
                        data['idioma'] ?? '',
                        stockMostrar.toString(),
                        '',
                      ]
                          .map(
                            (v) => pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                v,
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  color: bajominimo
                                      ? PdfColor.fromHex('#E65100')
                                      : PdfColors.black,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  }),
                ],
              ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Total de productos: ${docs.length}',
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
        name: 'inventario_$fechaStr.pdf',
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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
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
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: _cargandoPrefijos
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : _prefijosUsados.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'No hay códigos registrados',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        )
                                      : Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children:
                                              _prefijosUsados.map((p) {
                                            final seleccionado =
                                                _prefijosSeleccionados
                                                    .contains(p);
                                            return _buildChip(
                                              'Código $p',
                                              seleccionado,
                                              (v) => setState(() {
                                                if (v) {
                                                  _prefijosSeleccionados
                                                      .add(p);
                                                } else {
                                                  _prefijosSeleccionados
                                                      .remove(p);
                                                }
                                              }),
                                            );
                                          }).toList(),
                                        ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _generando ? null : _generarPDF,
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: _generando
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'GENERAR PDF',
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
              ),
            ),
          ),
        ],
      ),
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
            'REPORTES',
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
