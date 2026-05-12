import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DataMaster {
  static final DataMaster _instance = DataMaster._internal();
  factory DataMaster() => _instance;
  DataMaster._internal();

  Database? _db;

  // ─────────────────────────────────────────
  // INICIALIZACIÓN
  // ─────────────────────────────────────────

  Future<void> init() async {
    _db ??= await _initDb();
  }

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'galmedic.db');
    return openDatabase(
      path,
      // Se subió la versión a 2 para permitir la nueva columna 'eliminado'
      version: 2, 
      onCreate: _crearTablas,
      // Esta función agrega la columna 'eliminado' sin borrar tus datos actuales
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE productos ADD COLUMN eliminado INTEGER NOT NULL DEFAULT 0');
        }
      },
    );
  }

  Future<void> _crearTablas(Database db, int version) async {
    await db.execute('''
      CREATE TABLE productos (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        tipo TEXT NOT NULL,
        idioma TEXT NOT NULL,
        stockActual INTEGER NOT NULL DEFAULT 0,
        stockPorDestino TEXT NOT NULL DEFAULT '{}',
        destinos TEXT NOT NULL DEFAULT '[]',
        creadoEn TEXT,
        sincronizado INTEGER NOT NULL DEFAULT 1,
        eliminado INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE destinos (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        editable INTEGER NOT NULL DEFAULT 1,
        creadoEn TEXT,
        sincronizado INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE retiros (
        id TEXT PRIMARY KEY,
        productoId TEXT NOT NULL,
        productoNombre TEXT NOT NULL,
        tipo TEXT,
        idioma TEXT,
        companero TEXT NOT NULL,
        lote TEXT NOT NULL,
        destino TEXT,
        destinoId TEXT,
        cantidadEstimada INTEGER NOT NULL,
        cantidadEntregada INTEGER NOT NULL,
        cantidadDevuelta INTEGER NOT NULL DEFAULT 0,
        consumoReal INTEGER,
        perdida INTEGER,
        motivoCierre TEXT,
        estado TEXT NOT NULL DEFAULT 'cerrado',
        fecha TEXT NOT NULL,
        fechaCierre TEXT,
        sincronizado INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE recepciones (
        id TEXT PRIMARY KEY,
        productoId TEXT NOT NULL,
        productoNombre TEXT NOT NULL,
        tipo TEXT,
        idioma TEXT,
        cantidad INTEGER NOT NULL,
        codigo TEXT NOT NULL,
        destinoClave TEXT NOT NULL,
        destinos TEXT NOT NULL DEFAULT '[]',
        fecha TEXT NOT NULL,
        sincronizado INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE ajustes (
        id TEXT PRIMARY KEY,
        tipo TEXT NOT NULL,
        tipoAjuste TEXT NOT NULL,
        productoId TEXT NOT NULL,
        productoNombre TEXT NOT NULL,
        tipoProducto TEXT,
        idioma TEXT,
        cantidad INTEGER NOT NULL,
        motivo TEXT,
        stockAnterior INTEGER,
        stockNuevo INTEGER,
        lote TEXT,
        companero TEXT,
        retiroId TEXT,
        fecha TEXT NOT NULL,
        sincronizado INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE config (
        clave TEXT PRIMARY KEY,
        valor TEXT NOT NULL
      )
    ''');
  }

  // ─────────────────────────────────────────
  // INICIALIZAR APP — descargar datos frescos
  // ─────────────────────────────────────────

  Future<void> inicializar() async {
    try {
      await _descargarProductos();
      await _descargarDestinos();
      await _descargarConfig();
    } catch (e) {
      // Sin internet, usa datos locales
    }
  }

  Future<void> _descargarProductos() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('productos').get();
    final database = await db;
    final batch = database.batch();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      batch.insert(
        'productos',
        {
          'id': doc.id,
          'nombre': data['nombre'] ?? '',
          'tipo': data['tipo'] ?? '',
          'idioma': data['idioma'] ?? '',
          'stockActual': data['stockActual'] ?? 0,
          'stockPorDestino': jsonEncode(data['stockPorDestino'] ?? {}),
          'destinos': jsonEncode(data['destinos'] ?? []),
          'creadoEn': data['creadoEn']?.toString(),
          'sincronizado': 1,
          'eliminado': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
  }

  Future<void> _descargarDestinos() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('destinos').get();
    final database = await db;
    final batch = database.batch();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      batch.insert(
        'destinos',
        {
          'id': doc.id,
          'nombre': data['nombre'] ?? '',
          'editable': data['editable'] == true ? 1 : 0,
          'creadoEn': data['creadoEn']?.toString(),
          'sincronizado': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
  }

  Future<void> _descargarConfig() async {
    final pinDoc = await FirebaseFirestore.instance
        .collection('config')
        .doc('pin')
        .get();
    if (pinDoc.exists) {
      await guardarConfig('pin', pinDoc.data()?['valor'] ?? '');
    }
    final prefijosDoc = await FirebaseFirestore.instance
        .collection('config')
        .doc('prefijos')
        .get();
    if (prefijosDoc.exists) {
      final usados = (prefijosDoc.data()?['usados'] ?? [])
          .map((e) => e.toString())
          .toList();
      await guardarConfig('prefijos_usados', jsonEncode(usados));
    }
  }

  // ─────────────────────────────────────────
  // CONFIG
  // ─────────────────────────────────────────

  Future<void> guardarConfig(String clave, String valor) async {
    final database = await db;
    await database.insert(
      'config',
      {'clave': clave, 'valor': valor},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> leerConfig(String clave) async {
    final database = await db;
    final rows = await database.query(
      'config',
      where: 'clave = ?',
      whereArgs: [clave],
    );
    if (rows.isEmpty) return null;
    return rows.first['valor'] as String?;
  }

  Future<String?> obtenerConfig(String clave) => leerConfig(clave);

  // ─────────────────────────────────────────
  // PRODUCTOS
  // ─────────────────────────────────────────

  Future<List<Map<String, dynamic>>> obtenerProductos({
    String? tipo,
    String? idioma,
    String? nombre,
  }) async {
    final database = await db;
    // Se agregó 'eliminado = 0' para que no se muestren productos borrados offline
    String where = 'eliminado = 0';
    List<dynamic> args = [];

    if (tipo != null) {
      where += ' AND tipo = ?';
      args.add(tipo);
    }
    if (idioma != null) {
      where += ' AND idioma = ?';
      args.add(idioma);
    }

    final rows = await database.query(
      'productos',
      where: where,
      whereArgs: args.isEmpty ? null : args,
    );

    List<Map<String, dynamic>> productos = rows.map((r) {
      final map = Map<String, dynamic>.from(r);
      map['stockPorDestino'] =
          jsonDecode(r['stockPorDestino'] as String? ?? '{}');
      map['destinos'] = jsonDecode(r['destinos'] as String? ?? '[]');
      return map;
    }).toList();

    if (nombre != null && nombre.isNotEmpty) {
      final nombreLower = nombre.toLowerCase();
      productos = productos
          .where((p) =>
              (p['nombre'] as String).toLowerCase().contains(nombreLower))
          .toList();
    }

    return productos;
  }

  Future<Map<String, dynamic>?> obtenerProductoPorId(String id) async {
    final database = await db;
    final rows = await database.query(
      'productos',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    final map = Map<String, dynamic>.from(rows.first);
    map['stockPorDestino'] =
        jsonDecode(map['stockPorDestino'] as String? ?? '{}');
    map['destinos'] = jsonDecode(map['destinos'] as String? ?? '[]');
    return map;
  }

  Future<String> crearProducto({
    required String nombre,
    required String tipo,
    required String idioma,
  }) async {
    final database = await db;
    final id = 'local_${DateTime.now().millisecondsSinceEpoch}';
    await database.insert('productos', {
      'id': id,
      'nombre': nombre,
      'tipo': tipo,
      'idioma': idioma,
      'stockActual': 0,
      'stockPorDestino': '{}',
      'destinos': '[]',
      'creadoEn': DateTime.now().toIso8601String(),
      'sincronizado': 0,
      'eliminado': 0,
    });
    return id;
  }

  Future<void> actualizarProducto({
    required String id,
    required String nombre,
    required String tipo,
    required String idioma,
  }) async {
    final database = await db;
    await database.update(
      'productos',
      {
        'nombre': nombre,
        'tipo': tipo,
        'idioma': idioma,
        'sincronizado': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> eliminarProducto({required String id}) async {
    final database = await db;
    // Ahora marca el producto como eliminado en lugar de borrarlo físicamente
    await database.update(
      'productos',
      {
        'eliminado': 1,
        'sincronizado': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> _actualizarStockProducto(
    Database database,
    String productoId,
    Map<String, dynamic> stockPorDestino,
    int stockTotal,
  ) async {
    await database.update(
      'productos',
      {
        'stockActual': stockTotal,
        'stockPorDestino': jsonEncode(stockPorDestino),
        'sincronizado': 0,
      },
      where: 'id = ?',
      whereArgs: [productoId],
    );
  }

  // ─────────────────────────────────────────
  // DESTINOS
  // ─────────────────────────────────────────

  Future<List<Map<String, dynamic>>> obtenerDestinos() async {
    final database = await db;
    return database.query('destinos', orderBy: 'nombre ASC');
  }

  Future<String> crearDestino({required String nombre}) async {
    final database = await db;
    final id = 'local_${DateTime.now().millisecondsSinceEpoch}';
    await database.insert('destinos', {
      'id': id,
      'nombre': nombre,
      'editable': 1,
      'creadoEn': DateTime.now().toIso8601String(),
      'sincronizado': 0,
    });
    return id;
  }

  Future<void> eliminarDestino({required String id}) async {
    final database = await db;
    await database.delete(
      'destinos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─────────────────────────────────────────
  // RECEPCIONES
  // ─────────────────────────────────────────

  Future<void> registrarRecepcion({
    required String productoId,
    required String productoNombre,
    required String tipo,
    required String idioma,
    required int cantidad,
    required String codigo,
    required String destinoClave,
    required List<String> destinos,
  }) async {
    final database = await db;
    final id = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final fecha = DateTime.now().toIso8601String();

    final producto = await obtenerProductoPorId(productoId);
    if (producto == null) return;

    final stockPorDestino =
        Map<String, dynamic>.from(producto['stockPorDestino'] ?? {});
    final stockActualDestino =
        (stockPorDestino[destinoClave] as num?)?.toInt() ?? 0;
    stockPorDestino[destinoClave] = stockActualDestino + cantidad;

    final nuevoStockTotal = stockPorDestino.values
        .fold<int>(0, (sum, v) => sum + ((v as num).toInt()));

    final destinosActuales =
        List<String>.from(producto['destinos'] ?? []);
    for (final d in destinos) {
      if (!destinosActuales.contains(d)) destinosActuales.add(d);
    }

    await database.transaction((txn) async {
      await txn.insert('recepciones', {
        'id': id,
        'productoId': productoId,
        'productoNombre': productoNombre,
        'tipo': tipo,
        'idioma': idioma,
        'cantidad': cantidad,
        'codigo': codigo,
        'destinoClave': destinoClave,
        'destinos': jsonEncode(destinos),
        'fecha': fecha,
        'sincronizado': 0,
      });

      await txn.update(
        'productos',
        {
          'stockActual': nuevoStockTotal,
          'stockPorDestino': jsonEncode(stockPorDestino),
          'destinos': jsonEncode(destinosActuales),
          'sincronizado': 0,
        },
        where: 'id = ?',
        whereArgs: [productoId],
      );
    });

    await _agregarPrefijo(codigo.substring(0, 2));
  }

  Future<List<Map<String, dynamic>>> obtenerRecepciones({
    DateTime? desde,
    DateTime? hasta,
    String? nombre,
  }) async {
    final database = await db;
    String where = '1=1';
    List<dynamic> args = [];

    if (desde != null) {
      where += ' AND fecha >= ?';
      args.add(desde.toIso8601String());
    }
    if (hasta != null) {
      where += ' AND fecha <= ?';
      args.add(hasta.toIso8601String());
    }

    final rows = await database.query(
      'recepciones',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'fecha DESC',
    );

    List<Map<String, dynamic>> resultado =
        rows.map((r) => Map<String, dynamic>.from(r)).toList();

    if (nombre != null && nombre.isNotEmpty) {
      final nombreLower = nombre.toLowerCase();
      resultado = resultado
          .where((r) => (r['productoNombre'] as String)
              .toLowerCase()
              .contains(nombreLower))
          .toList();
    }

    return resultado;
  }

  // ─────────────────────────────────────────
  // RETIROS
  // ─────────────────────────────────────────

  Future<bool> registrarRetiro({
    required String productoId,
    required String productoNombre,
    required String tipo,
    required String idioma,
    required String companero,
    required String lote,
    required String destino,
    required String destinoId,
    required int cantidadEstimada,
    required int cantidadEntregada,
  }) async {
    final database = await db;
    final producto = await obtenerProductoPorId(productoId);
    if (producto == null) return false;

    final stockPorDestino =
        Map<String, dynamic>.from(producto['stockPorDestino'] ?? {});
    final stockDisponible =
        (stockPorDestino[destinoId] as num?)?.toInt() ?? 0;

    if (cantidadEntregada > stockDisponible) return false;

    final hayPendiente = cantidadEntregada > cantidadEstimada;
    final id = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final fecha = DateTime.now().toIso8601String();

    stockPorDestino[destinoId] = stockDisponible - cantidadEntregada;
    final nuevoStockTotal = stockPorDestino.values
        .fold<int>(0, (sum, v) => sum + ((v as num).toInt()));

    await database.transaction((txn) async {
      await txn.insert('retiros', {
        'id': id,
        'productoId': productoId,
        'productoNombre': productoNombre,
        'tipo': tipo,
        'idioma': idioma,
        'companero': companero,
        'lote': lote,
        'destino': destino,
        'destinoId': destinoId,
        'cantidadEstimada': cantidadEstimada,
        'cantidadEntregada': cantidadEntregada,
        'cantidadDevuelta': 0,
        'consumoReal': hayPendiente ? null : cantidadEntregada,
        'perdida': hayPendiente ? null : 0,
        'motivoCierre': hayPendiente ? null : 'Entrega exacta o menor',
        'estado': hayPendiente ? 'pendiente' : 'cerrado',
        'fecha': fecha,
        'fechaCierre': hayPendiente ? null : fecha,
        'sincronizado': 0,
      });

      await txn.update(
        'productos',
        {
          'stockActual': nuevoStockTotal,
          'stockPorDestino': jsonEncode(stockPorDestino),
          'sincronizado': 0,
        },
        where: 'id = ?',
        whereArgs: [productoId],
      );
    });

    return true;
  }

  Future<List<Map<String, dynamic>>> obtenerRetiros({
    String? estado,
    String? lote,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final database = await db;
    String where = '1=1';
    List<dynamic> args = [];

    if (estado != null) {
      where += ' AND estado = ?';
      args.add(estado);
    }
    if (lote != null) {
      where += ' AND lote = ?';
      args.add(lote);
    }
    if (desde != null) {
      where += ' AND fecha >= ?';
      args.add(desde.toIso8601String());
    }
    if (hasta != null) {
      where += ' AND fecha <= ?';
      args.add(hasta.toIso8601String());
    }

    final rows = await database.query(
      'retiros',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'fecha DESC',
    );

    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> cerrarRetiro({
    required String retiroId,
    required String productoId,
    required String destinoId,
    required int cantidadDevuelta,
    required String motivoCierre,
  }) async {
    final database = await db;
    final producto = await obtenerProductoPorId(productoId);
    if (producto == null) return;

    final stockPorDestino =
        Map<String, dynamic>.from(producto['stockPorDestino'] ?? {});
    final stockActualDestino =
        (stockPorDestino[destinoId] as num?)?.toInt() ?? 0;
    stockPorDestino[destinoId] = stockActualDestino + cantidadDevuelta;

    final nuevoStockTotal = stockPorDestino.values
        .fold<int>(0, (sum, v) => sum + ((v as num).toInt()));

    final retiroRows = await database.query(
      'retiros',
      where: 'id = ?',
      whereArgs: [retiroId],
    );
    if (retiroRows.isEmpty) return;
    final retiro = retiroRows.first;
    final entregada = retiro['cantidadEntregada'] as int;
    final consumoReal = entregada - cantidadDevuelta;

    await database.transaction((txn) async {
      await txn.update(
        'retiros',
        {
          'cantidadDevuelta': cantidadDevuelta,
          'consumoReal': consumoReal,
          'perdida': cantidadDevuelta == 0 ? consumoReal : 0,
          'motivoCierre': motivoCierre,
          'estado': 'cerrado',
          'fechaCierre': DateTime.now().toIso8601String(),
          'sincronizado': 0,
        },
        where: 'id = ?',
        whereArgs: [retiroId],
      );

      await txn.update(
        'productos',
        {
          'stockActual': nuevoStockTotal,
          'stockPorDestino': jsonEncode(stockPorDestino),
          'sincronizado': 0,
        },
        where: 'id = ?',
        whereArgs: [productoId],
      );
    });
  }

  // ─────────────────────────────────────────
  // AJUSTES
  // ─────────────────────────────────────────

  Future<void> registrarAjuste({
    required String tipo,
    required String tipoAjuste,
    required String productoId,
    required String productoNombre,
    required String tipoProducto,
    required String idioma,
    required int cantidad,
    required String motivo,
    String? lote,
    String? companero,
    String? retiroId,
  }) async {
    final database = await db;
    final producto = await obtenerProductoPorId(productoId);
    if (producto == null) return;

    final stockAnterior = producto['stockActual'] as int;
    final nuevoStock = tipoAjuste == 'suma'
        ? stockAnterior + cantidad
        : (stockAnterior - cantidad).clamp(0, double.infinity).toInt();

    final id = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final fecha = DateTime.now().toIso8601String();

    await database.transaction((txn) async {
      await txn.insert('ajustes', {
        'id': id,
        'tipo': tipo,
        'tipoAjuste': tipoAjuste,
        'productoId': productoId,
        'productoNombre': productoNombre,
        'tipoProducto': tipoProducto,
        'idioma': idioma,
        'cantidad': cantidad,
        'motivo': motivo,
        'stockAnterior': stockAnterior,
        'stockNuevo': nuevoStock,
        'lote': lote,
        'companero': companero,
        'retiroId': retiroId,
        'fecha': fecha,
        'sincronizado': 0,
      });

      await txn.update(
        'productos',
        {
          'stockActual': nuevoStock,
          'sincronizado': 0,
        },
        where: 'id = ?',
        whereArgs: [productoId],
      );
    });
  }

  Future<List<Map<String, dynamic>>> obtenerAjustes({
    String? tipo,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final database = await db;
    String where = '1=1';
    List<dynamic> args = [];

    if (tipo != null) {
      where += ' AND tipo = ?';
      args.add(tipo);
    }
    if (desde != null) {
      where += ' AND fecha >= ?';
      args.add(desde.toIso8601String());
    }
    if (hasta != null) {
      where += ' AND fecha <= ?';
      args.add(hasta.toIso8601String());
    }

    final rows = await database.query(
      'ajustes',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'fecha DESC',
    );

    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // ─────────────────────────────────────────
  // PREFIJOS
  // ─────────────────────────────────────────

  Future<List<String>> obtenerPrefijosUsados() async {
    final valor = await leerConfig('prefijos_usados');
    if (valor == null) return [];
    return List<String>.from(jsonDecode(valor));
  }

  Future<void> _agregarPrefijo(String prefijo) async {
    final usados = await obtenerPrefijosUsados();
    if (!usados.contains(prefijo)) {
      usados.add(prefijo);
      usados.sort();
      await guardarConfig('prefijos_usados', jsonEncode(usados));
    }
  }

  // ─────────────────────────────────────────
  // SINCRONIZACIÓN
  // ─────────────────────────────────────────

  Future<int> contarPendientes() async {
    final database = await db;
    int total = 0;

    for (final tabla in [
      'retiros',
      'recepciones',
      'ajustes',
      'productos',
      'destinos'
    ]) {
      final result = await database.rawQuery(
        'SELECT COUNT(*) as count FROM $tabla WHERE sincronizado = 0',
      );
      total += (result.first['count'] as int?) ?? 0;
    }

    return total;
  }

  Future<void> sincronizar() async {
    await _sincronizarProductos();
    await _sincronizarDestinos();
    await _sincronizarRecepciones();
    await _sincronizarRetiros();
    await _sincronizarAjustes();
    await _sincronizarPrefijos();
  }

  Future<void> _sincronizarProductos() async {
    final database = await db;
    final pendientes = await database.query(
      'productos',
      where: 'sincronizado = 0',
    );

    for (final row in pendientes) {
      final id = row['id'] as String;

      // SI ESTÁ MARCADO COMO ELIMINADO
      if (row['eliminado'] == 1) {
        if (!id.startsWith('local_')) {
          await FirebaseFirestore.instance.collection('productos').doc(id).delete();
        }
        await database.delete('productos', where: 'id = ?', whereArgs: [id]);
        continue;
      }

      final data = {
        'nombre': row['nombre'],
        'tipo': row['tipo'],
        'idioma': row['idioma'],
        'stockActual': row['stockActual'],
        'stockPorDestino': jsonDecode(row['stockPorDestino'] as String),
        'destinos': jsonDecode(row['destinos'] as String),
      };

      if (id.startsWith('local_')) {
        final ref =
            FirebaseFirestore.instance.collection('productos').doc();
        await ref.set({...data, 'creadoEn': FieldValue.serverTimestamp()});
        await database.update(
          'productos',
          {'id': ref.id, 'sincronizado': 1},
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        await FirebaseFirestore.instance
            .collection('productos')
            .doc(id)
            .update(data);
        await database.update(
          'productos',
          {'sincronizado': 1},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }

  Future<void> _sincronizarDestinos() async {
    final database = await db;
    final pendientes = await database.query(
      'destinos',
      where: 'sincronizado = 0',
    );

    for (final row in pendientes) {
      final id = row['id'] as String;
      final data = {
        'nombre': row['nombre'],
        'editable': row['editable'] == 1,
      };

      if (id.startsWith('local_')) {
        final ref =
            FirebaseFirestore.instance.collection('destinos').doc();
        await ref.set({...data, 'creadoEn': FieldValue.serverTimestamp()});
        await database.update(
          'destinos',
          {'id': ref.id, 'sincronizado': 1},
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        await FirebaseFirestore.instance
            .collection('destinos')
            .doc(id)
            .update(data);
        await database.update(
          'destinos',
          {'sincronizado': 1},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }

  Future<void> _sincronizarRecepciones() async {
    final database = await db;
    final pendientes = await database.query(
      'recepciones',
      where: 'sincronizado = 0',
    );

    for (final row in pendientes) {
      final id = row['id'] as String;
      final ref = id.startsWith('local_')
          ? FirebaseFirestore.instance.collection('recepciones').doc()
          : FirebaseFirestore.instance.collection('recepciones').doc(id);

      await ref.set({
        'productoId': row['productoId'],
        'productoNombre': row['productoNombre'],
        'tipo': row['tipo'],
        'idioma': row['idioma'],
        'cantidad': row['cantidad'],
        'codigo': row['codigo'],
        'destinoClave': row['destinoClave'],
        'destinos': jsonDecode(row['destinos'] as String),
        'fecha': FieldValue.serverTimestamp(),
      });

      await database.update(
        'recepciones',
        {'sincronizado': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> _sincronizarRetiros() async {
    final database = await db;
    final pendientes = await database.query(
      'retiros',
      where: 'sincronizado = 0',
    );

    for (final row in pendientes) {
      final id = row['id'] as String;
      final ref = id.startsWith('local_')
          ? FirebaseFirestore.instance.collection('retiros').doc()
          : FirebaseFirestore.instance.collection('retiros').doc(id);

      await ref.set({
        'productoId': row['productoId'],
        'productoNombre': row['productoNombre'],
        'tipo': row['tipo'],
        'idioma': row['idioma'],
        'companero': row['companero'],
        'lote': row['lote'],
        'destino': row['destino'],
        'destinoId': row['destinoId'],
        'cantidadEstimada': row['cantidadEstimada'],
        'cantidadEntregada': row['cantidadEntregada'],
        'cantidadDevuelta': row['cantidadDevuelta'],
        'consumoReal': row['consumoReal'],
        'perdida': row['perdida'],
        'motivoCierre': row['motivoCierre'],
        'estado': row['estado'],
        'fecha': FieldValue.serverTimestamp(),
        'fechaCierre':
            row['fechaCierre'] != null ? FieldValue.serverTimestamp() : null,
      });

      await database.update(
        'retiros',
        {'sincronizado': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> _sincronizarAjustes() async {
    final database = await db;
    final pendientes = await database.query(
      'ajustes',
      where: 'sincronizado = 0',
    );

    for (final row in pendientes) {
      final id = row['id'] as String;
      final ref = id.startsWith('local_')
          ? FirebaseFirestore.instance.collection('ajustes').doc()
          : FirebaseFirestore.instance.collection('ajustes').doc(id);

      await ref.set({
        'tipo': row['tipo'],
        'tipoAjuste': row['tipoAjuste'],
        'productoId': row['productoId'],
        'productoNombre': row['productoNombre'],
        'tipoProducto': row['tipoProducto'],
        'idioma': row['idioma'],
        'cantidad': row['cantidad'],
        'motivo': row['motivo'],
        'stockAnterior': row['stockAnterior'],
        'stockNuevo': row['stockNuevo'],
        'lote': row['lote'],
        'companero': row['companero'],
        'retiroId': row['retiroId'],
        'fecha': FieldValue.serverTimestamp(),
      });

      await database.update(
        'ajustes',
        {'sincronizado': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> _sincronizarPrefijos() async {
    final usados = await obtenerPrefijosUsados();
    await FirebaseFirestore.instance
        .collection('config')
        .doc('prefijos')
        .update({'usados': usados});
  }

  // ─────────────────────────────────────────
  // GESTIÓN DE RECEPCIONES
  // ─────────────────────────────────────────

  Future<bool> eliminarRecepcion(String recepcionId) async {
    final database = await db;

    final rows = await database.query(
      'recepciones',
      where: 'id = ?',
      whereArgs: [recepcionId],
    );
    if (rows.isEmpty) return false;
    final recepcion = rows.first;

    final productoId = recepcion['productoId'] as String?;
    final cantidad = (recepcion['cantidad'] as num?)?.toInt() ?? 0;
    final destinoClave = recepcion['destinoClave'] as String? ?? 'todos';
    final codigo = (recepcion['codigo'] ?? '').toString();

    if (productoId == null) return false;

    final fechaRecepcion = recepcion['fecha'] as String?;
    final retirosPosteriores = await database.rawQuery(
      'SELECT COUNT(*) as count FROM retiros WHERE productoId = ? AND fecha >= ?',
      [productoId, fechaRecepcion ?? ''],
    );
    final cantidadRetiros =
        (retirosPosteriores.first['count'] as int?) ?? 0;
    if (cantidadRetiros > 0) return false;

    final producto = await obtenerProductoPorId(productoId);
    if (producto == null) return false;

    final stockPorDestino =
        Map<String, dynamic>.from(producto['stockPorDestino'] ?? {});
    final stockActualDestino =
        (stockPorDestino[destinoClave] as num?)?.toInt() ?? 0;
    stockPorDestino[destinoClave] =
        (stockActualDestino - cantidad).clamp(0, double.maxFinite).toInt();

    final nuevoStockTotal = stockPorDestino.values
        .fold<int>(0, (sum, v) => sum + ((v as num).toInt()));

    await database.transaction((txn) async {
      await txn.delete('recepciones',
          where: 'id = ?', whereArgs: [recepcionId]);
      await txn.update(
        'productos',
        {
          'stockActual': nuevoStockTotal,
          'stockPorDestino': jsonEncode(stockPorDestino),
          'sincronizado': 0,
        },
        where: 'id = ?',
        whereArgs: [productoId],
      );
    });

    if (codigo.length >= 2) {
      final prefijo = codigo.substring(0, 2);
      final otras = await database.query(
        'recepciones',
        where: 'productoId = ? AND id != ?',
        whereArgs: [productoId, recepcionId],
      );
      final quedanConPrefijo = otras
          .any((r) => (r['codigo'] as String? ?? '').startsWith(prefijo));
      if (!quedanConPrefijo) {
        final usados = await obtenerPrefijosUsados();
        usados.remove(prefijo);
        await guardarConfig('prefijos_usados', jsonEncode(usados));
      }
    }

    return true;
  }

  Future<bool> editarCantidadRecepcion({
    required String recepcionId,
    required int nuevaCantidad,
  }) async {
    final database = await db;

    final rows = await database.query(
      'recepciones',
      where: 'id = ?',
      whereArgs: [recepcionId],
    );
    if (rows.isEmpty) return false;
    final recepcion = rows.first;

    final productoId = recepcion['productoId'] as String?;
    final cantidadOriginal = (recepcion['cantidad'] as num?)?.toInt() ?? 0;
    final destinoClave = recepcion['destinoClave'] as String? ?? 'todos';

    if (productoId == null) return false;

    final diferencia = nuevaCantidad - cantidadOriginal;

    final producto = await obtenerProductoPorId(productoId);
    if (producto == null) return false;

    final stockPorDestino =
        Map<String, dynamic>.from(producto['stockPorDestino'] ?? {});
    final stockActualDestino =
        (stockPorDestino[destinoClave] as num?)?.toInt() ?? 0;
    stockPorDestino[destinoClave] =
        (stockActualDestino + diferencia).clamp(0, double.maxFinite).toInt();

    final nuevoStockTotal = stockPorDestino.values
        .fold<int>(0, (sum, v) => sum + ((v as num).toInt()));

    await database.transaction((txn) async {
      await txn.update(
        'recepciones',
        {'cantidad': nuevaCantidad},
        where: 'id = ?',
        whereArgs: [recepcionId],
      );
      await txn.update(
        'productos',
        {
          'stockActual': nuevoStockTotal,
          'stockPorDestino': jsonEncode(stockPorDestino),
          'sincronizado': 0,
        },
        where: 'id = ?',
        whereArgs: [productoId],
      );
    });

    return true;
  }

  // ─────────────────────────────────────────
  // GESTIÓN DE AJUSTES
  // ─────────────────────────────────────────

  Future<bool> eliminarAjuste(String ajusteId) async {
    final database = await db;

    final rows = await database.query(
      'ajustes',
      where: 'id = ?',
      whereArgs: [ajusteId],
    );
    if (rows.isEmpty) return false;
    final ajuste = rows.first;

    final productoId = ajuste['productoId'] as String?;
    final stockAnterior = (ajuste['stockAnterior'] as num?)?.toInt();
    final tipoAjuste = ajuste['tipoAjuste'] as String? ?? 'entrada';
    final fechaAjuste = ajuste['fecha'] as String?;

    if (productoId == null || stockAnterior == null) return false;

    if (tipoAjuste == 'entrada' || tipoAjuste == 'suma') {
      final retirosPosteriores = await database.rawQuery(
        'SELECT COUNT(*) as count FROM retiros WHERE productoId = ? AND fecha >= ?',
        [productoId, fechaAjuste ?? ''],
      );
      final cantidad =
          (retirosPosteriores.first['count'] as int?) ?? 0;
      if (cantidad > 0) return false;
    }

    await database.transaction((txn) async {
      await txn.delete('ajustes', where: 'id = ?', whereArgs: [ajusteId]);
      await txn.update(
        'productos',
        {'stockActual': stockAnterior, 'sincronizado': 0},
        where: 'id = ?',
        whereArgs: [productoId],
      );
    });

    return true;
  }

  Future<bool> editarCantidadAjuste({
    required String ajusteId,
    required int nuevaCantidad,
  }) async {
    final database = await db;

    final rows = await database.query(
      'ajustes',
      where: 'id = ?',
      whereArgs: [ajusteId],
    );
    if (rows.isEmpty) return false;
    final ajuste = rows.first;

    final productoId = ajuste['productoId'] as String?;
    final stockAnterior = (ajuste['stockAnterior'] as num?)?.toInt() ?? 0;
    final tipoAjuste = ajuste['tipoAjuste'] as String? ?? 'entrada';

    if (productoId == null) return false;

    final nuevoStock = (tipoAjuste == 'suma' || tipoAjuste == 'entrada')
        ? stockAnterior + nuevaCantidad
        : (stockAnterior - nuevaCantidad).clamp(0, double.maxFinite).toInt();

    await database.transaction((txn) async {
      await txn.update(
        'ajustes',
        {'cantidad': nuevaCantidad, 'stockNuevo': nuevoStock},
        where: 'id = ?',
        whereArgs: [ajusteId],
      );
      await txn.update(
        'productos',
        {'stockActual': nuevoStock, 'sincronizado': 0},
        where: 'id = ?',
        whereArgs: [productoId],
      );
    });

    return true;
  }

  // ─────────────────────────────────────────
  // ELIMINAR PRODUCTO COMPLETO
  // ─────────────────────────────────────────

  Future<void> eliminarProductoCompleto(String productoId) async {
    final database = await db;

    final recepciones = await database.query(
      'recepciones',
      where: 'productoId = ?',
      whereArgs: [productoId],
    );

    final prefijosUsados = recepciones
        .map((r) {
          final codigo = (r['codigo'] ?? '').toString();
          return codigo.length >= 2 ? codigo.substring(0, 2) : null;
        })
        .whereType<String>()
        .toSet();

    await database.transaction((txn) async {
      await txn.delete('recepciones',
          where: 'productoId = ?', whereArgs: [productoId]);
      await txn.delete('retiros',
          where: 'productoId = ?', whereArgs: [productoId]);
      await txn.delete('ajustes',
          where: 'productoId = ?', whereArgs: [productoId]);
      await txn.delete('productos',
          where: 'id = ?', whereArgs: [productoId]);
    });

    for (final prefijo in prefijosUsados) {
      final otras = await database.rawQuery(
        'SELECT COUNT(*) as count FROM recepciones WHERE codigo LIKE ?',
        ['$prefijo%'],
      );
      final quedan = (otras.first['count'] as int?) ?? 0;
      if (quedan == 0) {
        final usados = await obtenerPrefijosUsados();
        usados.remove(prefijo);
        await guardarConfig('prefijos_usados', jsonEncode(usados));
      }
    }
  }

  // ─────────────────────────────────────────
  // HOJA DE AJUSTE
  // ─────────────────────────────────────────

  Future<void> registrarHojaAjuste({
    required String productoId,
    required String retiroId,
    required int cantidad,
    required String motivo,
  }) async {
    final producto = await obtenerProductoPorId(productoId);
    if (producto == null) throw Exception('Producto no encontrado');

    final stockAnterior = (producto['stockActual'] as num).toInt();
    final nuevoStock =
        (stockAnterior - cantidad).clamp(0, double.maxFinite).toInt();

    final retiros = await obtenerRetiros();
    final retiro = retiros.firstWhere(
      (r) => r['id'] == retiroId,
      orElse: () => {},
    );

    final database = await db;
    final id = 'local_${DateTime.now().millisecondsSinceEpoch}';

    await database.transaction((txn) async {
      await txn.insert('ajustes', {
        'id': id,
        'tipo': 'hoja_ajuste',
        'tipoAjuste': 'resta',
        'productoId': productoId,
        'productoNombre': producto['nombre'],
        'tipoProducto': producto['tipo'],
        'idioma': producto['idioma'],
        'retiroId': retiroId,
        'lote': retiro['lote'] ?? '',
        'companero': retiro['companero'] ?? '',
        'cantidad': cantidad,
        'stockAnterior': stockAnterior,
        'stockNuevo': nuevoStock,
        'motivo': motivo,
        'fecha': DateTime.now().toIso8601String(),
        'sincronizado': 0,
      });
      await txn.update(
        'productos',
        {'stockActual': nuevoStock, 'sincronizado': 0},
        where: 'id = ?',
        whereArgs: [productoId],
      );
    });
  }

  Future<String> obtenerPin() async {
    // Se mejoró la lógica del PIN para que siempre devuelva un String y use 1234 de respaldo
    try {
      final snap = await FirebaseFirestore.instance
          .collection('config')
          .doc('pin')
          .get();
      if (snap.exists) {
        return snap.data()?['valor']?.toString() ?? '1234';
      }
    } catch (e) {
      // Si falla la red, intenta leer el PIN local si lo guardamos antes
      final pinLocal = await leerConfig('pin');
      if (pinLocal != null) return pinLocal;
    }
    return '1234'; 
  }
}
