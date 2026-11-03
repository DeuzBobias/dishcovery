import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_store.dart';

class SecureSessionStorage extends LocalStorage {
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  final String key;
  SecureSessionStorage(this.key);
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;
  @override
  Future<String?> accessToken() => storage.read(key: key);
  @override
  Future<void> persistSession(String value) =>
      storage.write(key: key, value: value);
  @override
  Future<void> removePersistedSession() => storage.delete(key: key);
}

class CloudAccount extends ChangeNotifier {
  final SqliteStore local;
  final SupabaseClient? client;
  String status = 'Sign in to sync your kitchen';
  bool conflict = false, busy = false, ready = false;
  Timer? timer;
  Future<void>? running;
  VoidCallback? onReload;
  CloudAccount(this.local, this.client) {
    local.onChange = () => schedule();
  }
  bool get configured => client != null;
  bool get usingGuestKitchen =>
      ready && client?.auth.currentUser == null && local.scope == 'signed-out';
  bool get signedIn =>
      ready &&
      client?.auth.currentUser != null &&
      local.scope == client!.auth.currentUser!.id;
  Future<void> bind() async {
    await running;
    ready = false;
    notifyListeners();
    await local.switchAccount(client?.auth.currentUser?.id ?? 'signed-out');
    ready = true;
    onReload?.call();
    notifyListeners();
    await sync();
  }

  void schedule() {
    timer?.cancel();
    timer = Timer(const Duration(seconds: 2), sync);
  }

  Future<void> sync() {
    if (running != null) return running!;
    final task = _sync();
    running = task;
    return task.whenComplete(() => running = null);
  }

  Future<void> _sync() async {
    final user = client?.auth.currentUser;
    if (user == null || !ready || local.scope != user.id) return;
    busy = true;
    notifyListeners();
    final owner = user.id;
    try {
      final row = await client!
          .from('kitchens')
          .select()
          .eq('user_id', owner)
          .maybeSingle()
          .timeout(const Duration(seconds: 12));
      if (local.scope != owner) return;
      final revision = (row?['revision'] as num?)?.toInt() ?? 0;
      final base = int.tryParse(local.getString('sync_revision') ?? '0') ?? 0;
      final dirty = local.getBool('sync_dirty') ?? false;
      if (dirty && revision != base) {
        conflict = true;
        status = 'Changes on another device need your review';
        return;
      }
      if (dirty) {
        final snapshot = local.snapshot();
        final result = await client!
            .rpc(
              'save_kitchen',
              params: {'expected_revision': base, 'new_payload': snapshot},
            )
            .timeout(const Duration(seconds: 12));
        await local.write('sync_revision', result.toString());
        // Changes made during the upload remain pending.
        if (jsonEncode(snapshot) == jsonEncode(local.snapshot())) {
          await local.acknowledge(snapshot);
        } else {
          schedule();
        }
      } else if (row != null) {
        await local.acceptCloud(
          Map<String, dynamic>.from(row['payload']),
          revision,
        );
        onReload?.call();
      }
      conflict = false;
      status = 'Your kitchen is synced';
    } on PostgrestException catch (e) {
      if (e.code == '40001') {
        conflict = true;
        status = 'Changes on another device need your review';
      } else {
        status = 'Cloud sync unavailable. Changes remain saved on this device.';
      }
    } catch (_) {
      status = 'Offline or unable to sync. Changes remain on this device.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> resolve(bool useCloud) async {
    await running;
    final user = client?.auth.currentUser;
    if (user == null) return;
    final row = await client!
        .from('kitchens')
        .select()
        .eq('user_id', user.id)
        .single();
    // Keep a recovery copy before an explicit conflict choice.
    await local.write('conflict_backup', jsonEncode(local.snapshot()));
    if (useCloud) {
      await local.acceptCloud(
        Map<String, dynamic>.from(row['payload']),
        row['revision'] as int,
        force: true,
      );
      onReload?.call();
    } else {
      await local.write('sync_revision', '${row['revision']}');
    }
    conflict = false;
    await sync();
  }

  Future<void> signOut() async {
    timer?.cancel();
    await running;
    if (client?.auth.currentUser != null) {
      await client!.auth.signOut(scope: SignOutScope.local);
    }
    await bind();
  }

  @override
  void dispose() {
    timer?.cancel();
    local.onChange = null;
    super.dispose();
  }
}
