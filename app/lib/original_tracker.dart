import 'package:flutter/material.dart';
import 'data.dart';
import 'ui.dart';
import 'nutrition.dart';
import 'faithful_app.dart';
import 'recipe_screens.dart';
import 'deficit.dart';
import 'deficit_screens.dart';

class TrackerScreen extends StatefulWidget {
  final KitchenStore s;
  final Recipe? initialRecipe;
  final DateTime? initialDate;
  final DateTime Function()? now;
  const TrackerScreen(
    this.s, {
    this.initialRecipe,
    this.initialDate,
    this.now,
    super.key,
  });
  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  DateTime get today => widget.now?.call() ?? DateTime.now();
  late DateTime date = widget.initialDate ?? today;
  String get keyDate => dayKey(date);
  Map<String, dynamic>? get plan => widget.s.wellness['purpose'] == 'Fitness'
      ? deficitPlanFor(widget.s.deficitPlans, keyDate)
      : null;
  static const names = {
    'calories': 'Calories',
    'protein': 'Protein',
    'carbs': 'Carbs',
    'fat': 'Fat',
  };
  @override
  void initState() {
    super.initState();
    widget.s.addListener(refresh);
    if (widget.initialRecipe != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) edit(recipe: widget.initialRecipe);
      });
    }
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.s.removeListener(refresh);
    super.dispose();
  }

  Future<DateTime?> pickDate(BuildContext c, DateTime current) =>
      showDatePicker(
        context: c,
        initialDate: current,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
  Future<void> edit({Map<String, dynamic>? entry, Recipe? recipe}) async {
    final cs = {
      for (final k in ['name', 'servings', ...macroKeys])
        k: TextEditingController(
          text: k == 'name'
              ? (entry?['name'] ?? recipe?.title ?? '')
              : k == 'servings'
              ? '${entry?['servings'] ?? 1}'
              : '${entry?['nutrition']?[k] ?? recipe?.nutrition?[k] ?? ''}',
        ),
    };
    String meal = entry?['meal'] ?? 'Breakfast';
    String selected = recipe?.id ?? '';
    DateTime eaten = DateTime.tryParse(entry?['date'] ?? '') ?? date;
    final form = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Log food'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    fieldLabel(
                      'Choose a recipe or enter manually',
                      DropdownButtonFormField<String>(
                        initialValue: selected,
                        isExpanded: true,
                        decoration: inputBox(),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Enter food manually'),
                          ),
                          for (final r in widget.s.recipes.where(
                            (r) => validNutrition(r.nutrition),
                          ))
                            DropdownMenuItem(
                              value: r.id,
                              child: Text(
                                '${r.title} (estimate)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          selected = v!;
                          if (v.isNotEmpty) {
                            final r = widget.s.recipes.firstWhere(
                              (r) => r.id == v,
                            );
                            cs['name']!.text = r.title;
                            for (final k in macroKeys) {
                              cs[k]!.text = '${r.nutrition![k]}';
                            }
                          }
                          update(() {});
                        },
                      ),
                    ),
                    fieldLabel(
                      'Food name',
                      TextFormField(
                        controller: cs['name'],
                        decoration: inputBox(),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Enter a name' : null,
                      ),
                    ),
                    fieldLabel(
                      'Date eaten',
                      TextButton.icon(
                        onPressed: () async {
                          final d = await pickDate(ctx, eaten);
                          if (d != null && ctx.mounted) update(() => eaten = d);
                        },
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(dayKey(eaten)),
                      ),
                    ),
                    fieldLabel(
                      'Meal',
                      DropdownButtonFormField<String>(
                        initialValue: meal,
                        decoration: inputBox(),
                        items: ['Breakfast', 'Lunch', 'Dinner', 'Snack']
                            .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)),
                            )
                            .toList(),
                        onChanged: (v) => meal = v!,
                      ),
                    ),
                    for (final k in ['servings', ...macroKeys]) ...[
                      if (k == 'calories') ...[
                        gap(16),
                        Text(
                          'Nutrition for one serving',
                          style: type(14, weight: FontWeight.w700),
                        ),
                        gap(8),
                        Text(
                          'Totals multiply these values by servings eaten. Use your food labels or recipe calculation.',
                          style: type(11, color: muted),
                        ),
                      ],
                      fieldLabel(
                        k == 'servings'
                            ? 'Servings eaten'
                            : '${names[k]} (${k == 'calories' ? 'kcal' : 'g'})',
                        TextFormField(
                          controller: cs[k],
                          decoration: inputBox(),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            return n == null ||
                                    !n.isFinite ||
                                    n < 0 ||
                                    n > 10000 ||
                                    (k == 'servings' && (n <= 0 || n > 100))
                                ? 'Enter a valid amount'
                                : null;
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!form.currentState!.validate()) return;
                final item = {
                  'id':
                      entry?['id'] ??
                      DateTime.now().microsecondsSinceEpoch.toString(),
                  'name': cs['name']!.text.trim(),
                  'date': dayKey(eaten),
                  'meal': meal,
                  'servings': double.parse(cs['servings']!.text),
                  'nutrition': {
                    for (final k in macroKeys) k: double.parse(cs[k]!.text),
                  },
                  'deleted': false,
                };
                if (entry != null) {
                  widget.s.completedFoodDays[entry['date']] = false;
                }
                widget.s.completedFoodDays[dayKey(eaten)] = false;
                widget.s.foodLog.removeWhere((x) => x['id'] == item['id']);
                widget.s.foodLog.add(item);
                await widget.s.save();
                if (ctx.mounted) {
                  if (widget.s.storageError == null) {
                    Navigator.pop(ctx);
                  } else {
                    toast(ctx, widget.s.storageError!);
                  }
                }
              },
              child: Text(entry == null ? 'Add to daily log' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final c in cs.values) {
      c.dispose();
    }
    if (mounted) refresh();
  }

  Future<void> targets() async {
    final active = plan;
    final cs = {
      for (final k in macroKeys)
        k: TextEditingController(
          text:
              '${k == 'calories' && active != null ? active['target'] : widget.s.targets[k] ?? ''}',
        ),
    };
    final form = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daily targets'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  active == null
                      ? 'Optional goals you choose. Blank means no target.'
                      : 'Calories come from your active personal plan. Pause or edit that plan to change them. Macro targets stay yours.',
                  style: type(12, color: muted),
                ),
                for (final k in macroKeys)
                  fieldLabel(
                    '${names[k]} (${k == 'calories' ? 'kcal' : 'g'})',
                    TextFormField(
                      controller: cs[k],
                      enabled: k != 'calories' || active == null,
                      keyboardType: TextInputType.number,
                      decoration: inputBox(),
                      validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        final n = double.tryParse(v);
                        return n == null || !n.isFinite || n <= 0 || n > 10000
                            ? 'Enter a positive target up to 10000'
                            : null;
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              widget.s.targets = {
                if (active != null && widget.s.targets['calories'] != null)
                  'calories': widget.s.targets['calories'],
                for (final k in macroKeys)
                  if ((k != 'calories' || active == null) &&
                      cs[k]!.text.isNotEmpty)
                    k: double.parse(cs[k]!.text),
              };
              await widget.s.save();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final c in cs.values) {
      c.dispose();
    }
  }

  Widget section(String title, Widget action) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 15),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: type(18, weight: FontWeight.w700)),
        ),
        action,
      ],
    ),
  );
  Widget entryTile(Map<String, dynamic> l) {
    final n = l['nutrition'];
    final factor = l['servings'] as num;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Surface(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l['name'],
                    style: type(14, weight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: l['deleted'] == true ? 'Restore' : 'Remove',
                  onPressed: () async {
                    l['deleted'] = l['deleted'] != true;
                    widget.s.completedFoodDays[keyDate] = false;
                    await widget.s.save();
                  },
                  icon: Icon(
                    l['deleted'] == true ? Icons.restore : Icons.delete_outline,
                    size: 20,
                  ),
                ),
              ],
            ),
            Text(
              '${((n['calories'] as num) * factor).toStringAsFixed(1)} kcal · ${l['servings']} servings',
              style: type(13),
            ),
            gap(6),
            Text(
              'Protein ${((n['protein'] as num) * factor).toStringAsFixed(1)}g · Carbs ${((n['carbs'] as num) * factor).toStringAsFixed(1)}g · Fat ${((n['fat'] as num) * factor).toStringAsFixed(1)}g',
              style: type(10, color: muted),
            ),
            if (l['deleted'] != true)
              TextButton(
                onPressed: () => edit(entry: l),
                child: const Text('Edit'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final totals = dayTotals(widget.s.foodLog, keyDate);
    final entries = widget.s.foodLog
        .where((l) => l['date'] == keyDate && l['deleted'] != true)
        .toList();
    final removed = widget.s.foodLog
        .where((l) => l['date'] == keyDate && l['deleted'] == true)
        .toList();
    return Scaffold(
      appBar: pageHeader(
        c,
        'Daily food tracker',
        action: IconButton(
          tooltip: 'Edit daily targets',
          onPressed: targets,
          icon: const Icon(Icons.tune),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
        children: [
          Text(
            'A little awareness, one meal at a time.',
            style: type(12, color: muted),
          ),
          gap(18),
          Row(
            children: [
              Expanded(
                child: fieldLabel(
                  'Log date',
                  InkWell(
                    onTap: () async {
                      final d = await pickDate(c, date);
                      if (d != null && mounted) setState(() => date = d);
                    },
                    borderRadius: BorderRadius.circular(15),
                    child: InputDecorator(
                      decoration: inputBox(),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                              style: type(13),
                            ),
                          ),
                          const Icon(Icons.calendar_today_outlined, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              TextButton(
                onPressed: () => setState(() => date = today),
                style: TextButton.styleFrom(
                  backgroundColor: pale,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text('Today'),
              ),
            ],
          ),
          gap(10),
          if (widget.s.wellness['purpose'] == 'Fitness')
            DeficitCard(widget.s, date, today: today, onChanged: refresh),
          Surface(
            color: const Color(0xfffff7f8),
            borderColor: const Color(0xfff5dce1),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your daily progress',
                        style: type(18, weight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: targets,
                      child: Text('Set targets', style: type(12, color: green)),
                    ),
                  ],
                ),
                gap(10),
                Text(
                  plan == null
                      ? 'Your own targets, applied to each day. Leave any target blank to track totals only.'
                      : 'Calories use the personal plan saved for this date. Your macro targets are unchanged.',
                  style: type(11, color: muted),
                ),
                for (final k in macroKeys)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Builder(
                      builder: (c) {
                        final target = k == 'calories' && plan != null
                            ? plan!['target']
                            : widget.s.targets[k];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    names[k]!,
                                    style: type(13, weight: FontWeight.w600),
                                  ),
                                ),
                                Text(
                                  '${totals[k]!.toStringAsFixed(totals[k] == totals[k]!.roundToDouble() ? 0 : 1)} ${k == 'calories' ? 'kcal' : 'g'}',
                                  style: type(13),
                                ),
                              ],
                            ),
                            if (target is num && target > 0) ...[
                              gap(9),
                              LinearProgressIndicator(
                                value: (totals[k]! / target).clamp(0.0, 1.0),
                                minHeight: 8,
                                color: green,
                                backgroundColor: pale,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              gap(9),
                              Text(
                                '${(target - totals[k]!).abs().toStringAsFixed(1)} ${totals[k]! > target ? 'above target' : 'remaining'}',
                                style: type(11, color: muted),
                              ),
                            ] else ...[
                              gap(6),
                              Text(
                                'No target set',
                                style: type(11, color: muted),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          section(
            'What you ate',
            FilledButton.icon(
              onPressed: () => edit(),
              icon: const Icon(Icons.add),
              label: const Text('Log food'),
            ),
          ),
          if (entries.isEmpty)
            CustomPaint(
              painter: const _DashedEmptyBorder(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    Text(
                      'Your day starts here.',
                      style: type(14, weight: FontWeight.w700),
                    ),
                    gap(12),
                    Text(
                      'No food logged for this date. Add a recipe or enter a meal below.',
                      textAlign: TextAlign.center,
                      style: type(13, color: muted),
                    ),
                    gap(18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: pale,
                          foregroundColor: burgundy,
                        ),
                        onPressed: () => edit(),
                        icon: const Icon(Icons.add),
                        label: const Text('Log your first food'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          for (final meal in ['Breakfast', 'Lunch', 'Dinner', 'Snack'])
            if (entries.any((l) => l['meal'] == meal)) ...[
              gap(24),
              Text(
                meal,
                style: type(
                  14,
                  color: const Color(0xffa24a60),
                  weight: FontWeight.w700,
                ),
              ),
              gap(10),
              for (final l in entries.where((l) => l['meal'] == meal))
                entryTile(l),
            ],
          if (removed.isNotEmpty)
            ExpansionTile(
              title: Text(
                'Removed food (${removed.length})',
                style: type(12, color: muted),
              ),
              children: [for (final l in removed) entryTile(l)],
            ),
          gap(24),
          Text(
            'Totals use the servings you log. Sample recipe nutrition is illustrative; custom values are entered by you. Personal calorie estimates are optional; macro targets remain user-set.',
            style: type(11, color: muted),
          ),
          if (widget.s.storageError != null)
            Text(
              widget.s.storageError!,
              style: const TextStyle(color: Colors.red),
            ),
        ],
      ),
      bottomNavigationBar: OriginalNavigation(
        page: 0,
        onSelect: (i) {
          if (i == 2) {
            present(c, RecipeEditor(widget.s));
          } else {
            widget.s.navigate(i);
            Navigator.popUntil(c, (r) => r.isFirst);
          }
        },
      ),
    );
  }
}

class _DashedEmptyBorder extends CustomPainter {
  const _DashedEmptyBorder();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      );
    final paint = Paint()
      ..color = const Color(0xffe9bdc8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 6) {
        canvas.drawPath(metric.extractPath(start, start + 3), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedEmptyBorder oldDelegate) => false;
}
