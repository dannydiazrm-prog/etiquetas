import 'package:go_router/go_router.dart';
import '../../presentation/auth/pin_screen.dart';
import '../../presentation/perfil/perfil_screen.dart';
import '../../presentation/dashboard/dashboard_screen.dart';
import '../../presentation/retirados/retirados_screen.dart';
import '../../presentation/retirados/nuevo_retiro_screen.dart';
import '../../presentation/retirados/pendientes_screen.dart';
import '../../presentation/retirados/retiros_del_dia_screen.dart';
import '../../presentation/retirados/historial_lote_screen.dart';
import '../../presentation/recibidos/recibidos_screen.dart';
import '../../presentation/recibidos/recibir_producto_screen.dart';
import '../../presentation/recibidos/historial_recepciones_screen.dart';
import '../../presentation/ajustes/ajustes_screen.dart';
import '../../presentation/ajustes/hoja_ajuste_screen.dart';
import '../../presentation/ajustes/ajuste_inventario_screen.dart';
import '../../presentation/ajustes/historial_ajustes_screen.dart';
import '../../presentation/inventario/inventario_screen.dart';
import '../../presentation/inventario/nuevo_producto_screen.dart';
import '../../presentation/inventario/nuevo_destino_screen.dart';
import '../../presentation/inventario/toma_inventario_screen.dart';
import '../../presentation/inventario/ver_productos_screen.dart';
import '../../presentation/inventario/reportes_screen.dart';
import '../../presentation/inventario/control_stock_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/pin',
  routes: [
    GoRoute(
      path: '/pin',
      builder: (context, state) => const PinScreen(),
    ),
    GoRoute(
      path: '/perfil',
      builder: (context, state) => const PerfilScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/retirados',
      builder: (context, state) => const RetiradosScreen(),
    ),
    GoRoute(
      path: '/retirados/nuevo',
      builder: (context, state) => const NuevoRetiroScreen(),
    ),
    GoRoute(
      path: '/retirados/pendientes',
      builder: (context, state) => const PendientesScreen(),
    ),
    GoRoute(
      path: '/retirados/del-dia',
      builder: (context, state) => const RetirosDiaScreen(),
    ),
    GoRoute(
      path: '/retirados/historial',
      builder: (context, state) => const HistorialLoteScreen(),
    ),
    GoRoute(
      path: '/recibidos',
      builder: (context, state) => const RecibidosScreen(),
    ),
    GoRoute(
      path: '/recibidos/nuevo',
      builder: (context, state) => const RecibirProductoScreen(),
    ),
    GoRoute(
      path: '/recibidos/historial',
      builder: (context, state) => const HistorialRecepcionesScreen(),
    ),
    GoRoute(
      path: '/ajustes',
      builder: (context, state) => const AjustesScreen(),
    ),
    GoRoute(
      path: '/ajustes/novedad',
      builder: (context, state) => const HojaAjusteScreen(),
    ),
    GoRoute(
      path: '/ajustes/inventario',
      builder: (context, state) => const AjusteInventarioScreen(),
    ),
    GoRoute(
      path: '/ajustes/historial',
      builder: (context, state) => const HistorialAjustesScreen(),
    ),
    GoRoute(
      path: '/inventario',
      builder: (context, state) => const InventarioScreen(),
    ),
    GoRoute(
      path: '/inventario/nuevo-producto',
      builder: (context, state) => const NuevoProductoScreen(),
    ),
    GoRoute(
      path: '/inventario/nuevo-destino',
      builder: (context, state) => const NuevoDestinoScreen(),
    ),
    GoRoute(
      path: '/inventario/toma',
      builder: (context, state) => const TomaInventarioScreen(),
    ),
    GoRoute(
      path: '/inventario/toma/productos',
      builder: (context, state) => const VerProductosScreen(),
    ),
    GoRoute(
      path: '/inventario/toma/reportes',
      builder: (context, state) => const ReportesScreen(),
    ),
    GoRoute(
      path: '/inventario/stock',
      builder: (context, state) => const ControlStockScreen(),
    ),
  ],
);