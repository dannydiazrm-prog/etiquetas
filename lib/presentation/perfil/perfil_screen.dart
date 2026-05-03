import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/breakpoints.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _pinActualController = TextEditingController();
  final _pinNuevoController = TextEditingController();
  final _pinConfirmController = TextEditingController();
  String _mensaje = '';
  bool _loading = false;
  bool _ocultarActual = true;
  bool _ocultarNuevo = true;
  bool _ocultarConfirm = true;

  @override
  void dispose() {
    _pinActualController.dispose();
    _pinNuevoController.dispose();
    _pinConfirmController.dispose();
    super.dispose();
  }

  Future<void> _cambiarPin() async {
    final actual = _pinActualController.text.trim();
    final nuevo = _pinNuevoController.text.trim();
    final confirm = _pinConfirmController.text.trim();

    if (actual.isEmpty || nuevo.isEmpty || confirm.isEmpty) {
      setState(() => _mensaje = 'Completá todos los campos');
      return;
    }
    if (nuevo.length != 4 || int.tryParse(nuevo) == null) {
      setState(() => _mensaje = 'El PIN debe ser de 4 dígitos');
      return;
    }
    if (nuevo != confirm) {
      setState(() => _mensaje = 'Los PINs nuevos no coinciden');
      return;
    }

    setState(() => _loading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('pin')
          .get();
      final pinGuardado = doc.data()?['valor'] ?? '';

      if (actual != pinGuardado) {
        setState(() => _mensaje = 'PIN actual incorrecto');
      } else {
        await FirebaseFirestore.instance
            .collection('config')
            .doc('pin')
            .update({'valor': nuevo});
        setState(() => _mensaje = 'PIN actualizado correctamente');
        _pinActualController.clear();
        _pinNuevoController.clear();
        _pinConfirmController.clear();
      }
    } catch (e) {
      setState(() => _mensaje = 'Error de conexión');
    }

    setState(() => _loading = false);
  }

  void _cerrarSesion() {
    context.go('/pin');
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
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CAMBIAR PIN',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildCampoPin(
                        controller: _pinActualController,
                        label: 'PIN actual',
                        ocultar: _ocultarActual,
                        onToggle: () => setState(
                            () => _ocultarActual = !_ocultarActual),
                      ),
                      const SizedBox(height: 16),
                      _buildCampoPin(
                        controller: _pinNuevoController,
                        label: 'PIN nuevo',
                        ocultar: _ocultarNuevo,
                        onToggle: () => setState(
                            () => _ocultarNuevo = !_ocultarNuevo),
                      ),
                      const SizedBox(height: 16),
                      _buildCampoPin(
                        controller: _pinConfirmController,
                        label: 'Confirmar PIN nuevo',
                        ocultar: _ocultarConfirm,
                        onToggle: () => setState(
                            () => _ocultarConfirm = !_ocultarConfirm),
                      ),
                      const SizedBox(height: 24),
                      if (_mensaje.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _mensaje.contains('correctamente')
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _mensaje.contains('correctamente')
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                          child: Text(
                            _mensaje,
                            style: TextStyle(
                              color: _mensaje.contains('correctamente')
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _cambiarPin,
                          child: _loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  'GUARDAR NUEVO PIN',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 48),
                      const Divider(),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: _cerrarSesion,
                          icon: const Icon(Icons.logout,
                              color: AppColors.primary),
                          label: const Text(
                            'CERRAR SESIÓN',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
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
            onPressed: () => context.go('/'),
          ),
          const SizedBox(width: 8),
          Text(
            'PERFIL',
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

  Widget _buildCampoPin({
    required TextEditingController controller,
    required String label,
    required bool ocultar,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: ocultar,
      keyboardType: TextInputType.number,
      maxLength: 4,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.primary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            ocultar ? Icons.visibility_off : Icons.visibility,
            color: AppColors.primary,
          ),
          onPressed: onToggle,
        ),
        counterText: '',
      ),
    );
  }
}