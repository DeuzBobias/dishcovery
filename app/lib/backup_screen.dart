import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'data.dart';
import 'nutrition.dart';
import 'deficit.dart';
import 'ui.dart';

class BackupScreen extends StatefulWidget {
  final KitchenStore s;
  const BackupScreen(this.s, {super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  String message =
      'Export a backup to Android Documents or restore a saved backup.';
  Future<void> export() async {
    try {
      final bytes = Uint8List.fromList(
        utf8.encode(jsonEncode(widget.s.toJson())),
      );
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Dishcovery backup',
        fileName: 'dishcovery-backup.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );
      if (mounted) {
        setState(
          () => message = path == null ? 'Export cancelled.' : 'Backup saved.',
        );
      }
    } catch (_) {
      if (mounted) setState(() => message = 'Could not save the backup.');
    }
  }

  Future<void> restore() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null) return;
      final bytes = result.files.single.bytes;
      if (bytes == null || bytes.length > 10000000) {
        throw const FormatException();
      }
      final j = Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)));
      if (j['name'] is! String || j['own'] is! List || j['pantry'] is! List) {
        throw const FormatException();
      }
      for (final r in j['own']) {
        final recipe = Recipe.fromJson(Map<String, dynamic>.from(r));
        if (recipe.servings < 1 ||
            recipe.ingredients.isEmpty ||
            recipe.steps.isEmpty) {
          throw const FormatException();
        }
      }
      for (final l in j['foodLog'] ?? []) {
        if (l['servings'] is! num ||
            l['servings'] <= 0 ||
            !validNutrition(Map<String, dynamic>.from(l['nutrition'])) ||
            DateTime.tryParse(l['date']) == null) {
          throw const FormatException();
        }
      }
      for (final t in (j['targets'] as Map? ?? {}).values) {
        if (t is! num || !t.isFinite || t <= 0) throw const FormatException();
      }
      for (final p in j['deficitPlans'] ?? []) {
        if (!validDeficitPlan(Map<String, dynamic>.from(p))) {
          throw const FormatException();
        }
      }
      if (j['completedFoodDays'] != null &&
          (j['completedFoodDays'] is! Map ||
              (j['completedFoodDays'] as Map).values.any((v) => v is! bool))) {
        throw const FormatException();
      }
      if (!mounted) return;
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore this backup?'),
          content: const Text(
            'This replaces your current local kitchen. Export it first if you want to keep it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (yes != true) return;
      final old = widget.s.prefs.getString('kitchen_v1');
      await widget.s.prefs.setString('kitchen_v1', jsonEncode(j));
      final check = KitchenStore(widget.s.prefs);
      if (check.storageError != null) {
        if (old != null) await widget.s.prefs.setString('kitchen_v1', old);
        throw const FormatException();
      }
      widget.s.reload();
      if (mounted) setState(() => message = 'Backup restored.');
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'Invalid or unreadable backup. Your kitchen was not replaced.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Backup and restore')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(message),
        gap(20),
        FilledButton.icon(
          onPressed: export,
          icon: const Icon(Icons.save_alt),
          label: const Text('Export backup file'),
        ),
        TextButton.icon(
          onPressed: restore,
          icon: const Icon(Icons.file_open),
          label: const Text('Import backup file'),
        ),
      ],
    ),
  );
}
