import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Account-scoped SQLite key/value storage. JSON preserves existing backups.
class SqliteStore {
  final Database db;
  String scope = 'signed-out';
  Map<String, dynamic> cache = {};
  void Function()? onChange;
  SqliteStore(this.db);
  static Future<SqliteStore> open() async {
    final db = await openDatabase(
      '${await getDatabasesPath()}/dishcovery.db',
      version: 1,
      onCreate: (db, v) async {
        await db.execute(
          'CREATE TABLE entries (owner TEXT NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY(owner,key))',
        );
      },
    );
    final store = SqliteStore(db);
    await store.switchAccount('signed-out');
    return store;
  }

  Future<void> switchAccount(String owner) async {
    scope = owner;
    final rows = await db.query(
      'entries',
      where: 'owner = ?',
      whereArgs: [owner],
    );
    cache = {
      for (final row in rows)
        row['key'] as String: jsonDecode(row['value'] as String),
    };
  }

  String? getString(String key) => cache[key] as String?;
  bool? getBool(String key) => cache[key] as bool?;
  Future<bool> setString(String key, String value) => write(key, value);
  Future<bool> setBool(String key, bool value) => write(key, value);
  static bool synced(String key) =>
      key == 'kitchen_v1' || key.startsWith('recipe_draft_');
  Future<bool> write(String key, dynamic value) async {
    final owner = scope;
    await db.transaction((tx) async {
      await tx.insert('entries', {
        'owner': owner,
        'key': key,
        'value': jsonEncode(value),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (synced(key)) {
        await tx.insert('entries', {
          'owner': owner,
          'key': 'sync_dirty',
          'value': 'true',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    if (scope == owner) {
      cache[key] = value;
      if (synced(key)) {
        cache['sync_dirty'] = true;
        onChange?.call();
      }
    }
    return true;
  }

  Future<bool> remove(String key) async {
    final owner = scope;
    await db.transaction((tx) async {
      await tx.delete(
        'entries',
        where: 'owner=? AND key=?',
        whereArgs: [owner, key],
      );
      if (synced(key)) {
        await tx.insert('entries', {
          'owner': owner,
          'key': 'sync_dirty',
          'value': 'true',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    if (scope == owner) {
      cache.remove(key);
      if (synced(key)) {
        cache['sync_dirty'] = true;
        onChange?.call();
      }
    }
    return true;
  }

  Map<String, dynamic> snapshot() =>
      Map.fromEntries(cache.entries.where((e) => synced(e.key)));
  Future<void> acknowledge(Map<String, dynamic> uploaded) async {
    await db.transaction((tx) async {
      final rows = await tx.query(
        'entries',
        where: 'owner=?',
        whereArgs: [scope],
      );
      final actual = {
        for (final row in rows)
          if (synced(row['key'] as String))
            row['key'] as String: jsonDecode(row['value'] as String),
      };
      if (actual.length == uploaded.length &&
          actual.entries.every((e) => uploaded[e.key] == e.value)) {
        await tx.insert('entries', {
          'owner': scope,
          'key': 'sync_dirty',
          'value': 'false',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        cache['sync_dirty'] = false;
      }
    });
  }

  Future<void> acceptCloud(
    Map<String, dynamic> values,
    int revision, {
    bool force = false,
  }) async {
    await db.transaction((tx) async {
      final pending = await tx.query(
        'entries',
        where: 'owner=? AND key=?',
        whereArgs: [scope, 'sync_dirty'],
      );
      if (!force && pending.isNotEmpty && pending.first['value'] == 'true') {
        return;
      }
      for (final key in cache.keys.where(synced).toList()) {
        await tx.delete(
          'entries',
          where: 'owner=? AND key=?',
          whereArgs: [scope, key],
        );
      }
      for (final e in {
        ...Map.fromEntries(
          values.entries.where((e) => synced(e.key) && e.value is String),
        ),
        'sync_revision': revision.toString(),
        'sync_dirty': false,
      }.entries) {
        await tx.insert('entries', {
          'owner': scope,
          'key': e.key,
          'value': jsonEncode(e.value),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    await switchAccount(scope);
  }

  Future<void> preserveLegacy(SharedPreferences old) async {
    final rows = await db.query(
      'entries',
      where: 'owner=?',
      whereArgs: ['legacy'],
      limit: 1,
    );
    if (rows.isNotEmpty) return;
    await db.transaction((tx) async {
      for (final key in old.getKeys().where(synced)) {
        await tx.insert('entries', {
          'owner': 'legacy',
          'key': key,
          'value': jsonEncode(old.get(key)),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }
}
