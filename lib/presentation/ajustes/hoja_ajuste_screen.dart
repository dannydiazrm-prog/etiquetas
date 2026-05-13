import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/data/data_master.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/breakpoints.dart';

class HojaAjusteScreen extends StatefulWidget {
  const HojaAjusteScreen({super.key});

  @override
  State<HojaAjusteScreen> createState() => _HojaAjusteScreenState();
}

class _HojaAjusteScreenState extends State<HojaAjusteScreen> {
  final _busquedaController = TextEditingController();
  List<Map<String, dynamic>> _resultados = [];
  bool _buscando = false;
  bool _buscado = false;
  Map<String, dynamic>? _retiroSeleccionado;

  // Formulario
  final _cantidadController = TextEditingController();
  String? _motivo;
  final _otroController = TextEditingController();
  bool _guardando = false;
  String _error = '';

  final List<String> _motivos = [
    'Mojado',
    'Roto',
    'Defecto de impresión',
    'Otro',
  ];

  @override
  void dispose() {
    _busquedaController.dispose();
    _cantidadController.dispose();
    _otroController.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final texto = _busquedaController.text.trim();
    if (texto.isEmpty) return;

    setState(() {
      _buscando = true;
      _buscado = false;
      _retiroSeleccionado = null;
      _error = '';
    });

    try {
      final textoUpper = texto.toUpperCase();
      final textoLower = texto.toLowerCase();

      // Buscar todos los retiros y filtrar localmente por lote o compañero
      final todos = await DataMaster().obtenerRetiros();

      final ids = <String>{};
      final docs = <Map<String, dynamic>>[];

      for (final doc in todos) {
        final lote = (doc['lote'] ?? '').toString().toUpperCase();
        final companero = (doc['companero'] ?? '').toString().toLowerCase();
        final id = doc['id'] as String? ?? '';

        if ((lote == textoUpper || companero.contains(textoLower)) &&
            ids.add(id)) {
          docs.add(doc);
        }
      }

      // Ordenar por fecha descendente
      docs.sort((a, b) {
        final fechaA =
            DateTime.tryParse(a['fecha'] as String? ?? '') ?? DateTime(2000);
        final fechaB =
            DateTime.tryParse(b['fecha'] as String? ?? '') ?? DateTime(2000);
        return fechaB.compareTo(fechaA);
      });

      setState(() {
        _resultados = docs;
        _buscando = false;
        _buscado = true;
      });
    } catch (e) {
      setState(() {
        _buscando = false;
        _buscado = true;
        _resultados = [];
        _error = 'Error al buscar: $e';
      });
    }
  }

  Future<void> _confirmar() async {
    final cantidad = int.tryParse(_cantidadController.text.trim());
    if (cantidad == null || cantidad <= 0) {
      setState(() => _error = 'Ingresa una cantidad válida');
      return;
    }
    if (_motivo == null) {
      setState(() => _error = 'Selecciona un motivo');
      return;
    }
    if (_motivo == 'Otro' && _otroController.text.trim().isEmpty) {
      setState(() => _error = 'Describe el motivo');
      return;
    }

    final data = _retiroSeleccionado!;
    final productoId = data['productoId'] as String;

    // Verificar stock en el destino del retiro
    final producto = await DataMaster().obtenerProductoPorId(productoId);
    final destinoId = data['destinoId'] as String? ?? '';
    final stockPorDestino =
        Map<String, dynamic>.from(producto?['stockPorDestino'] ?? {});
    final stockEnDestino =
        (stockPorDestino[destinoId] as num?)?.toInt() ?? 0;

    if (cantidad > stockEnDestino) {
      setState(() =>
          _error = 'Stock insuficiente en este destino: $stockEnDestino unidades');
      return;
    }
	
    setState(() {
      _guardando = true;
      _error = '';
    });

    try {
      final motivoFinal =
          _motivo == 'Otro' ? _otroController.text.trim() : _motivo!;

      await DataMaster().registrarHojaAjuste(
        productoId: productoId,
        retiroId: data['id'] as String,
        cantidad: cantidad,
        motivo: motivoFinal,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ajuste registrado correctamente'),
            backgroundColor: AppColors.primary,
          ),
        );
        context.go('/ajustes');
      }
    } catch (e) {
      setState(() => _error = 'Error al guardar: $e');
    }

    if (mounted) setState(() => _guardando = false);
  }

  String _formatFechaHora(String? fechaStr) {
    if (fechaStr == null) return '-';
    final fecha = DateTime.tryParse(fechaStr);
    if (fecha == null) return '-';
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
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
                child: _retiroSeleccionado == null
                    ? _buildBusqueda()
                    : _buildFormulario(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusqueda() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BUSCAR RETIRO ORIGINAL',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Buscá por número de lote o nombre del compañero',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _busquedaController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: '',
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.primary),
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
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_error.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red),
            ),
            child: Text(
              _error,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (_buscado && _resultados.isEmpty && _error.isEmpty)
          const Center(
            child: Text(
              'No se encontraron retiros',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ..._resultados.map((data) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() {
                _retiroSeleccionado = data;
                _error = '';
              }),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                              _buildTag(
                                  '📦 Lote: ${data['lote'] ?? ''}'),
                              _buildTag(
                                  '👤 ${data['companero'] ?? ''}'),
                              _buildTag(
                                  '📤 ${data['cantidadEntregada'] ?? 0} entregadas'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatFechaHora(data['fecha'] as String?),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFormulario() {
    final data = _retiroSeleccionado!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RETIRO SELECCIONADO',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['productoNombre'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildTagBlanco('📦 ${data['lote'] ?? ''}'),
                        _buildTagBlanco('👤 ${data['companero'] ?? ''}'),
                        _buildTagBlanco(
                            '📤 ${data['cantidadEntregada'] ?? 0} entregadas'),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() {
                  _retiroSeleccionado = null;
                  _error = '';
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'CANTIDAD A REPONER',
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
            hintText: 'Ej: 100',
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
        const SizedBox(height: 24),

        const Text(
          'MOTIVO',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _motivos.map((m) {
            final seleccionado = _motivo == m;
            return GestureDetector(
              onTap: () => setState(() => _motivo = m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: seleccionado ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Text(
                  m,
                  style: TextStyle(
                    color:
                        seleccionado ? Colors.white : AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_motivo == 'Otro') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _otroController,
            decoration: InputDecoration(
              hintText: 'Describe el motivo',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ],
        const SizedBox(height: 32),

        if (_error.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red),
            ),
            child: Text(
              _error,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _guardando ? null : _confirmar,
            child: _guardando
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'CONFIRMAR AJUSTE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
          ),
        ),
      ],
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

  Widget _buildTagBlanco(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
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
            onPressed: () => context.go('/ajustes'),
          ),
          const SizedBox(width: 8),
          Text(
            'HOJA DE AJUSTE',
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
