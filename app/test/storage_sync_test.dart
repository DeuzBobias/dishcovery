import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dishcovery/local_store.dart';
import 'package:dishcovery/allergies.dart';
import 'package:dishcovery/data.dart';

void main() {
  sqfliteFfiInit();
  late SqliteStore local;
  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
      'CREATE TABLE entries (owner TEXT NOT NULL,key TEXT NOT NULL,value TEXT NOT NULL,PRIMARY KEY(owner,key))',
    );
    local = SqliteStore(db);
    await local.switchAccount('alice');
  });
  tearDown(() async => local.db.close());
  test('SQLite isolates kitchen and drafts between accounts', () async {
    await local.setString(
      'kitchen_v1',
      jsonEncode({
        'name': 'Alice',
        'allergies': ['Celery'],
      }),
    );
    await local.setString('recipe_draft_new', 'draft');
    await local.switchAccount('bob');
    expect(local.getString('kitchen_v1'), isNull);
    expect(local.getString('recipe_draft_new'), isNull);
    final store = KitchenStore(local);
    expect(store.name, 'Home cook');
    await local.setString('kitchen_v1', jsonEncode({'name': 'Bob'}));
    await local.switchAccount('alice');
    store.reload();
    expect(store.name, 'Alice');
    expect(store.allergies, ['Celery']);
  });
  test('Sync acknowledgement cannot clear newer local edits', () async {
    await local.setString('kitchen_v1', 'old');
    final sent = local.snapshot();
    await local.setString('kitchen_v1', 'new');
    await local.acknowledge(sent);
    expect(local.getBool('sync_dirty'), true);
    await local.acknowledge(local.snapshot());
    expect(local.getBool('sync_dirty'), false);
  });
  test('Cloud pull never replaces pending local writes', () async {
    await local.setString('kitchen_v1', 'local');
    await local.acceptCloud({'kitchen_v1': 'remote'}, 2);
    expect(local.getString('kitchen_v1'), 'local');
    await local.acceptCloud(
      {'kitchen_v1': 'remote', 'session_active': true},
      2,
      force: true,
    );
    expect(local.getString('kitchen_v1'), 'remote');
    expect(local.getBool('session_active'), isNull);
    expect(local.getString('sync_revision'), '2');
    expect(local.getBool('sync_dirty'), false);
  });
  test('Deleting a draft leaves a durable pending sync marker', () async {
    await local.setString('recipe_draft_new', 'draft');
    await local.acknowledge(local.snapshot());
    await local.remove('recipe_draft_new');
    await local.switchAccount('alice');
    expect(local.getBool('sync_dirty'), true);
    expect(local.snapshot(), isEmpty);
  });
  test(
    'Old data is preserved separately without migrating passwords',
    () async {
      SharedPreferences.setMockInitialValues({
        'kitchen_v1': 'old kitchen',
        'local_accounts': 'secret',
        'session_active': true,
      });
      await local.preserveLegacy(await SharedPreferences.getInstance());
      expect(local.getString('kitchen_v1'), isNull);
      await local.switchAccount('legacy');
      expect(local.getString('kitchen_v1'), 'old kitchen');
      expect(local.getString('local_accounts'), isNull);
    },
  );
  test('Custom allergy matching ignores case and avoids partial words', () {
    expect(allergyWarnings([' CELERY ', 'nuts'], ['Nuts'], ['1 cup celery']), [
      ' CELERY ',
      'nuts',
    ]);
    expect(allergyWarnings(['egg'], [], ['eggplant']), isEmpty);
  });
}
