import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/breakpoints.dart';

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
  List<QueryDocumentSnapshot> _resultados = [];
  bool _buscando = false;
  bool _buscado = false;

  // Paso 2: Formulario
  QueryDocumentSnapshot? _productoSeleccionado;
  final _companeroController = TextEditingController();
  final _loteController = TextEditingController();
  final _cantidadEstimadaController = TextEditingController();
  final _cantidadEntregadaController = TextEditingController();
  String? _destinoSeleccionado;
  List<String> _destinosDisponibles = [];
  bool _guardando = false;
  String _error = '';

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

    Query query = FirebaseFirestore.instance.collection('productos');

    if (_etiquetas && !_prospectos) {
      query = query.where('tipo', isEqualTo: 'Etiqueta');
    } else if (_prospectos && !_etiquetas) {
      query = query.where('tipo', isEqualTo: 'Prospecto');
    }

    if (_espanol && !_ingles) {
      query = query.where('idioma', isEqualTo: 'ES');
    } else if (_ingles && !_espanol) {
      query = query.where('idioma', isEqualTo: 'IN');
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

    setState(() {
      _resultados = docs;
      _buscando = false;
      _buscado = true;
    });
  }

  Future<void> _seleccionarProducto(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final destinos = List<String>.from(data['destinos'] ?? []);

    // Obtener nombres de destinos
    List<String> nombresDestinos = [];

    for (final id in destinos) {
      if (id == 'todos') {
        nombresDestinos.add('Todos');
      } else if (id == 'local') {
        nombresDestinos.add('Local');
      } else {
        final destinoDoc = await FirebaseFirestore.instance
            .collection('destinos')
            .doc(id)
            .get();
        if (destinoDoc.exists) {
          nombresDestinos.add(destinoDoc.data()?['nombre'] ?? id);
        }
      }
    }

    setState(() {
      _productoSeleccionado = doc;
      _destinosDisponibles = nombresDestinos;
      _destinoSeleccionado = null;
      _companeroController.clear();
      _loteController.clear();
      _cantidadEstimadaController.clear();
      _cantidadEntregadaController.clear();
      _error = '';
    });
  }

  Future<void> _confirmar() async {
    final companero = _companeroController.text.trim();
    final lote = _loteController.text.trim();
    final cantidadEstimada =
        int.tryParse(_cantidadEstimadaController.text.trim());
    final cantidadEntregada =
        int.tryParse(_cantidadEntregadaController.text.trim());

    if (companero.isEmpty) {
      setState(() => _error = 'Ingresá el nombre del que retira');
      return;
    }
    if (lote.isEmpty) {
      setState(() => _error = 'Ingresá el número de lote');
      return;
    }
    if (_destinoSeleccionado == null) {
      setState(() => _error = 'Seleccioná un destino');
      return;
    }
    if (cantidadEstimada == null || cantidadEstimada <= 0) {
      setState(() => _error = 'Ingresá la cantidad estimada');
      return;
    }
    if (cantidadEntregada == null || cantidadEntregada <= 0) {
      setState(() => _error = 'Ingresá la cantidad entregada');
      return;
    }

    final data =
        _productoSeleccionado!.data() as Map<String, dynamic>;
    final stockActual = data['stockActual'] ?? 0;

    if (cantidadEntregada > stockActual) {
      setState(
          () => _error = 'Stock insuficiente. Stock actual: $stockActual');
      return;
    }

    setState(() {
      _guardando = true;
      _error = '';
    });

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Actualizar stock
      batch.update(
        FirebaseFirestore.instance
            .collection('productos')
            .doc(_productoSeleccionado!.id),
        {'stockActual': stockActual - cantidadEntregada},
      );

      // Registrar retiro
      final retiroRef =
          FirebaseFirestore.instance.collection('retiros').doc();
      batch.set(retiroRef, {
        'productoId': _productoSeleccionado!.id,
        'productoNombre': data['nombre'],
        'tipo': data['tipo'],
        'idioma': data['idioma'],
        'companero': companero,
        'lote': lote,
        'destino': _destinoSeleccionado,
        'cantidadEstimada': cantidadEstimada,
        'cantidadEntregada': cantidadEntregada,
        'cantidadDevuelta': 0,
        'consumoReal': null,
        'estado': 'pendiente',
        'fecha': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Retiro registrado correctamente'),
            backgroundColor: AppColors.primary,
          ),
        );
        context.go('/retirados');
      }
    } catch (e) {
      setState(() => _error = 'Error al guardar. Intentá de nuevo.');
    }

    setState(() => _guardando = false);
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
          'SELECCIONÁ EL PRODUCTO',
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
              borderSide: const BorderSide(
                  color: AppColors.primary, width: 2),
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
            _buildChip('Español', _espanol,
                (v) => setState(() => _espanol = v)),
            _buildChip('Inglés', _ingles,
                (v) => setState(() => _ingles = v)),
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
            child:
                CircularProgressIndicator(color: AppColors.primary),
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
        ..._resultados.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final stock = data['stockActual'] ?? 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _seleccionarProducto(doc),
              child: Container(
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
    final data =
        _productoSeleccionado!.data() as Map<String, dynamic>;

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
                            'Stock: ${data['stockActual'] ?? 0}'),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () =>
                    setState(() => _productoSeleccionado = null),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Compañero
        _buildLabel('EL QUE RETIRA'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _companeroController,
          hint: 'Nombre',
          capitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 20),

        // Lote
        _buildLabel('LOTE'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _loteController,
          hint: '',
          capitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 20),

        // Destino
        _buildLabel('DESTINO'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _destinosDisponibles.map((destino) {
            final seleccionado = _destinoSeleccionado == destino;
            return GestureDetector(
              onTap: () =>
                  setState(() => _destinoSeleccionado = destino),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: seleccionado
                      ? AppColors.primary
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Text(
                  destino,
                  style: TextStyle(
                    color: seleccionado
                        ? Colors.white
                        : AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Cantidad estimada
        _buildLabel('CANTIDAD DEL PRODUCTO'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _cantidadEstimadaController,
          hint: '',
          teclado: TextInputType.number,
        ),
        const SizedBox(height: 20),

        // Cantidad entregada
        _buildLabel('CANTIDAD ENTREGADA'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _cantidadEntregadaController,
          hint: '',
          teclado: TextInputType.number,
        ),
        const SizedBox(height: 32),

        if (_error.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
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
                ? const CircularProgressIndicator(
                    color: Colors.white)
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
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      keyboardType: teclado,
      textCapitalization: capitalization,
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

  Widget _buildTagBlanco(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
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
            onPressed: () => context.go('/retirados'),
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