import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/breakpoints.dart';
import '../../core/data/data_master.dart';

class NuevoRetiroScreen extends StatefulWidget {
  const NuevoRetiroScreen({super.key});

  @override
  State<NuevoRetiroScreen> createState() => _NuevoRetiroScreenState();
}

class _NuevoRetiroScreenState extends State<NuevoRetiroScreen> {
  // Paso 1: Búsqueda
  final _nombreController = TextEditingController();
  bool _etiquetas = false;
  bool _prospectos = false;
  bool _espanol = false;
  bool _ingles = false;
  List<Map<String, dynamic>> _resultados = [];
  bool _buscando = false;
  bool _buscado = false;

  // Paso 2: Formulario
  Map<String, dynamic>? _productoSeleccionado;
  final _companeroController = TextEditingController();
  final _loteController = TextEditingController();
  final _cantidadEstimadaController = TextEditingController();
  final _cantidadEntregadaController = TextEditingController();

  // Combinaciones de destinos por recepción
  List<Map<String, dynamic>> _combinaciones = [];
  Map<String, dynamic>? _combinacionSeleccionada;

  // Mapa de nombre por ID de destino
  Map<String, String> _nombresDestinos = {};

  bool _guardando = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _cargarNombresDestinos();
  }

  Future<void> _cargarNombresDestinos() async {
    final destinos = await DataMaster().obtenerDestinos();
    setState(() {
      _nombresDestinos = {
        for (final d in destinos) d['id'].toString(): d['nombre'].toString(),
      };
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _companeroController.dispose();
    _loteController.dispose();
    _cantidadEstimadaController.dispose();
    _cantidadEntregadaController.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    setState(() {
      _buscando = true;
      _buscado = false;
      _productoSeleccionado = null;
    });

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

    final nombre = _nombreController.text.trim().toLowerCase();
    if (nombre.isNotEmpty) {
      docs = docs.where((d) {
        return (d['nombre'] ?? '').toString().toLowerCase().contains(nombre);
      }).toList();
    }

    // Solo mostrar productos con stock
    docs = docs.where((d) => ((d['stockActual'] as num?)?.toInt() ?? 0) > 0).toList();

    setState(() {
      _resultados = docs;
      _buscando = false;
      _buscado = true;
    });
  }

  Future<void> _seleccionarProducto(Map<String, dynamic> data) async {
    // obtenerCombinacionesRecepcion ya filtra cantidadActual > 0
    final combinaciones = await DataMaster()
        .obtenerCombinacionesRecepcion(data['id'] as String);

    setState(() {
      _productoSeleccionado = data;
      _combinaciones = combinaciones;
      _combinacionSeleccionada = null;
      _companeroController.clear();
      _loteController.clear();
      _cantidadEstimadaController.clear();
      _cantidadEntregadaController.clear();
      _error = '';
    });
  }

  String _nombresCombinacion(List<String> ids) {
    final nombres = ids.map((id) => _nombresDestinos[id] ?? id).toList();
    return nombres.join(' · ');
  }

  Future<void> _confirmar() async {
    final companero = _companeroController.text.trim();
    final lote = _loteController.text.trim();
    final cantidadEstimada =
        int.tryParse(_cantidadEstimadaController.text.trim());
    final cantidadEntregada =
        int.tryParse(_cantidadEntregadaController.text.trim());

    if (companero.isEmpty) {
      setState(() => _error = 'Ingresa el nombre del que retira');
      return;
    }
    if (lote.isEmpty) {
      setState(() => _error = 'Ingresa el número de lote');
      return;
    }
    if (_combinacionSeleccionada == null) {
      setState(() => _error = 'Selecciona un grupo de destinos');
      return;
    }
    if (cantidadEstimada == null || cantidadEstimada <= 0) {
      setState(() => _error = 'Ingresa la cantidad estimada');
      return;
    }
    if (cantidadEntregada == null || cantidadEntregada <= 0) {
      setState(() => _error = 'Ingresa la cantidad entregada');
      return;
    }

    final data = _productoSeleccionado!;
    final stockDisponible = (data['stockActual'] as num?)?.toInt() ?? 0;

    if (cantidadEntregada > stockDisponible) {
      setState(() =>
          _error = 'Stock insuficiente. Stock disponible: $stockDisponible');
      return;
    }

    final destinosIds =
        List<String>.from(_combinacionSeleccionada!['destinosIds'] as List);
    final destinoId = destinosIds.first;
    final destinoNombre = _nombresCombinacion(destinosIds);
    final codigoRecepcion = _combinacionSeleccionada!['prefijo'] as String? ?? '';
    final recepcionIds = List<String>.from(
        _combinacionSeleccionada!['recepcionIds'] as List? ?? []);

    setState(() {
      _guardando = true;
      _error = '';
    });

    try {
      final hayPendiente = cantidadEntregada > cantidadEstimada;

      final ok = await DataMaster().registrarRetiro(
        productoId: data['id']?.toString() ?? '',
        productoNombre: data['nombre'] ?? '',
        tipo: data['tipo'] ?? '',
        idioma: data['idioma'] ?? '',
        companero: companero,
        lote: lote,
        destino: destinoNombre,
        destinoId: destinoId,
        cantidadEstimada: cantidadEstimada,
        cantidadEntregada: cantidadEntregada,
		recepcionIds: recepcionIds,
        codigoRecepcion: codigoRecepcion,
      );

      if (!ok) {
        setState(() => _error = 'Stock insuficiente. Verificá el inventario.');
        setState(() => _guardando = false);
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hayPendiente
                  ? 'Retiro registrado — quedó pendiente de devolución'
                  : 'Retiro registrado correctamente',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _error = 'Error al guardar: $e');
    }

    if (mounted) setState(() => _guardando = false);
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
                child: _productoSeleccionado == null
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
          'SELECCIONA EL PRODUCTO',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 16),
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
            _buildChip(
                'Español', _espanol, (v) => setState(() => _espanol = v)),
            _buildChip(
                'Inglés', _ingles, (v) => setState(() => _ingles = v)),
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
            child: CircularProgressIndicator(color: AppColors.primary),
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
        ..._resultados.map((data) {
          final stock = (data['stockActual'] as num?)?.toInt() ?? 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _seleccionarProducto(data),
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
                                color: stock < 1000
                                    ? Colors.orange
                                    : AppColors.primary,
                              ),
                            ],
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
    final data = _productoSeleccionado!;
    final estimadaPreview =
        int.tryParse(_cantidadEstimadaController.text.trim());
    final entregadaPreview =
        int.tryParse(_cantidadEntregadaController.text.trim());
    final quedaPendiente = estimadaPreview != null &&
        entregadaPreview != null &&
        entregadaPreview > estimadaPreview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Producto seleccionado
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
                      'PRODUCTO SELECCIONADO',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['nombre'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildTagBlanco(data['tipo'] ?? ''),
                        const SizedBox(width: 8),
                        _buildTagBlanco(data['idioma'] ?? ''),
                        const SizedBox(width: 8),
                        _buildTagBlanco(
                            'Stock: ${(data['stockActual'] as num?)?.toInt() ?? 0}'),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() {
                  _productoSeleccionado = null;
                  _combinaciones = [];
                  _combinacionSeleccionada = null;
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _buildLabel('COMPAÑERO'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _companeroController,
          hint: 'Nombre del compañero',
          capitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 20),

        _buildLabel('LOTE'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _loteController,
          hint: '',
          capitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 20),

        // Selector de combinación de destinos
        _buildLabel('GRUPO DE DESTINOS'),
        const SizedBox(height: 4),
        const Text(
          'Selecciona el grupo al que pertenece este retiro',
          style: TextStyle(color: AppColors.primary, fontSize: 11),
        ),
        const SizedBox(height: 12),
        if (_combinaciones.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red),
            ),
            child: const Text(
              'Este producto no tiene recepciones registradas.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          )
        else
          Column(
            children: _combinaciones.map((combinacion) {
              final ids =
                  List<String>.from(combinacion['destinosIds'] as List);
              final clave = combinacion['clave'] as String;
              final seleccionado =
                  _combinacionSeleccionada?['clave'] == clave;

              // cantidadActual viene directo de las recepciones
              final stockDisponible =
                  (combinacion['cantidadActual'] as num?)?.toInt() ?? 0;
              final prefijo = combinacion['prefijo'] as String? ?? '';

              return GestureDetector(
                onTap: () =>
                    setState(() => _combinacionSeleccionada = combinacion),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: seleccionado ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: seleccionado
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.3),
                      width: seleccionado ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nombresCombinacion(ids),
                              style: TextStyle(
                                color: seleccionado
                                    ? Colors.white
                                    : AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                             Text(
                              'Cód. $prefijo · Disponibles: $stockDisponible',
                              style: TextStyle(
                                color: seleccionado
                                    ? Colors.white70
                                    : Colors.grey[600],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (seleccionado)
                        const Icon(Icons.check_circle,
                            color: Colors.white, size: 20),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 20),

        _buildLabel('CANTIDAD DEL PRODUCTO'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _cantidadEstimadaController,
          hint: '',
          teclado: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),

        _buildLabel('CANTIDAD ENTREGADA'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _cantidadEntregadaController,
          hint: '',
          teclado: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),

        if (quedaPendiente) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: Row(
              children: [
                const Icon(Icons.pending_actions,
                    color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Quedarán ${entregadaPreview! - estimadaPreview!} unidades pendientes de devolución',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
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
                    'CONFIRMAR RETIRO',
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

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType teclado = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.sentences,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: teclado,
      textCapitalization: capitalization,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
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
    );
  }

  Widget _buildChip(
      String label, bool seleccionado, Function(bool) onTap) {
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

  Widget _buildTag(String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (color ?? AppColors.primary).withValues(alpha: 0.1),
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
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 8),
          Text(
            'NUEVO RETIRO',
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
