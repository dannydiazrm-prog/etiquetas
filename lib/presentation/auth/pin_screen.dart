import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  String _error = '';
  bool _loading = false;

  void _onKey(String digit) {
    if (_pin.length < 4) {
      setState(() {
        _pin += digit;
        _error = '';
      });
      if (_pin.length == 4) _validarPin();
    }
  }

  void _borrar() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  Future<void> _validarPin() async {
    setState(() => _loading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('pin')
          .get();
      final pinGuardado = doc.data()?['valor'] ?? '';
      if (_pin == pinGuardado) {
        if (mounted) context.go('/');
      } else {
        setState(() {
          _error = 'PIN incorrecto';
          _pin = '';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de conexión';
        _pin = '';
      });
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/logo_galmedic.webp', height: 80),
                  const SizedBox(height: 16),
                  const Text(
                    'DEPÓSITO DE ETIQUETAS',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 48),
                  const Text(
                    'Ingresá tu PIN',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final lleno = i < _pin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: lleno ? AppColors.primary : Colors.transparent,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  if (_error.isNotEmpty)
                    Text(
                      _error,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  const SizedBox(height: 32),
                  _Teclado(onKey: _onKey, onBorrar: _borrar),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Teclado extends StatelessWidget {
  final Function(String) onKey;
  final VoidCallback onBorrar;

  const _Teclado({required this.onKey, required this.onBorrar});

  @override
  Widget build(BuildContext context) {
    final teclas = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'DEL'],
    ];

    return Column(
      children: teclas.map((fila) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: fila.map((tecla) {
            if (tecla.isEmpty) return const SizedBox(width: 80, height: 80);
            return Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: 72,
                height: 72,
                child: ElevatedButton(
                  onPressed: () =>
                      tecla == 'DEL' ? onBorrar() : onKey(tecla),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tecla == 'DEL'
                        ? AppColors.primary.withOpacity(0.6)
                        : AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    tecla,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}