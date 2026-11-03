import 'dart:convert';
import 'package:flutter/material.dart';
import 'data.dart';
import 'faithful_app.dart';
import 'ui.dart';

class SyncScreen extends StatelessWidget {
  final KitchenStore store;
  const SyncScreen(this.store, {super.key});
  @override
  Widget build(BuildContext context) {
    final cloud = store.cloud!;
    return Scaffold(
      appBar: pageHeader(context, 'Account & cloud sync'),
      body: ListenableBuilder(
        listenable: cloud,
        builder: (c, _) => ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Text(
              cloud.client?.auth.currentUser?.email ?? 'Not signed in',
              style: type(18),
            ),
            gap(),
            Text(
              cloud.configured
                  ? cloud.status
                  : 'Account service has not been configured.',
            ),
            gap(),
            const Text(
              'Your kitchen is stored in SQLite on this device. Account sync includes your recipes, preferences, food log and drafts.',
            ),
            gap(),
            TextButton(
              onPressed: cloud.busy
                  ? null
                  : () async {
                      final yes = await showDialog<bool>(
                        context: c,
                        builder: (d) => AlertDialog(
                          title: const Text('Import earlier device data?'),
                          content: const Text(
                            'This replaces your current kitchen with data saved by the earlier app on this phone. Only import it if that data is yours.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(d, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(d, true),
                              child: const Text('Import'),
                            ),
                          ],
                        ),
                      );
                      if (yes != true) return;
                      try {
                        final rows = await cloud.local.db.query(
                          'entries',
                          where: 'owner=? AND key=?',
                          whereArgs: ['legacy', 'kitchen_v1'],
                        );
                        if (rows.isEmpty) {
                          if (c.mounted) {
                            toast(
                              c,
                              'No earlier kitchen found on this device.',
                            );
                          }
                          return;
                        }
                        await cloud.local.write(
                          'legacy_import_backup',
                          cloud.local.getString('kitchen_v1') ?? '{}',
                        );
                        await cloud.local.setString(
                          'kitchen_v1',
                          jsonDecode(rows.first['value'] as String) as String,
                        );
                        store.reload();
                        if (c.mounted) toast(c, 'Earlier kitchen imported.');
                      } catch (_) {
                        if (c.mounted) {
                          toast(c, 'Could not import the earlier kitchen.');
                        }
                      }
                    },
              child: const Text('Import earlier device data'),
            ),
            FilledButton.icon(
              onPressed: cloud.busy || !cloud.signedIn
                  ? null
                  : () async {
                      await cloud.sync();
                      if (c.mounted) toast(c, cloud.status);
                    },
              icon: const Icon(Icons.sync),
              label: Text(cloud.busy ? 'Syncing…' : 'Sync now'),
            ),
            if (cloud.conflict) ...[
              gap(),
              const Text(
                'Both devices have changes. Choose which complete kitchen to keep.',
              ),
              for (final useCloud in [true, false])
                TextButton(
                  onPressed: cloud.busy
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: c,
                            builder: (d) => AlertDialog(
                              title: Text(
                                useCloud
                                    ? 'Use cloud copy?'
                                    : 'Use this device copy?',
                              ),
                              content: const Text(
                                'This replaces the other kitchen copy. Continue only after reviewing your changes.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(d, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(d, true),
                                  child: const Text('Continue'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                          try {
                            await cloud.resolve(useCloud);
                            if (c.mounted) toast(c, cloud.status);
                          } catch (_) {
                            if (c.mounted) {
                              toast(c, 'Could not resolve sync. Try again.');
                            }
                          }
                        },
                  child: Text(
                    useCloud ? 'Use cloud copy' : 'Use this device copy',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
