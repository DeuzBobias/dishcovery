import 'original_tracker.dart';
export 'original_tracker.dart';
import 'package:flutter/material.dart';
import 'data.dart';
import 'nutrition.dart';
import 'ui.dart';
import 'android_api.dart';

class WellnessSetup extends StatefulWidget {
  final KitchenStore s;
  const WellnessSetup(this.s, {super.key});
  @override
  State<WellnessSetup> createState() => _WellnessSetupState();
}

class _WellnessSetupState extends State<WellnessSetup> {
  late String purpose = widget.s.wellness['purpose'] ?? 'Recipes';
  late final fields = {
    for (final k in ['age', 'height', 'weight'])
      k: TextEditingController(text: widget.s.wellness[k]?.toString() ?? ''),
  };
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your goals')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('What brings you to Dishcovery?', style: serif(28)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final p in ['Fitness', 'Recipes', 'Community'])
                ChoiceChip(
                  label: Text(p),
                  selected: purpose == p,
                  onSelected: (_) => setState(() => purpose = p),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Optional measurements stay on this device. Targets are set by you.',
          ),
          for (final k in fields.keys)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: TextFormField(
                controller: fields[k],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: {
                    'age': 'Age (years)',
                    'height': 'Height (cm)',
                    'weight': 'Weight (kg)',
                  }[k],
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final n = double.tryParse(v);
                  return n == null ||
                          !n.isFinite ||
                          n <= 0 ||
                          n >
                              ({
                                'age': 120,
                                'height': 300,
                                'weight': 500,
                              }[k]!) ||
                          (k == 'age' && n != n.roundToDouble())
                      ? 'Enter a valid positive ${k == 'age' ? 'whole number' : 'number'}'
                      : null;
                },
              ),
            ),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              widget.s.wellness = {
                'purpose': purpose,
                'complete': true,
                for (final k in fields.keys)
                  k: double.tryParse(fields[k]!.text),
              };
              await widget.s.save();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save goals'),
          ),
        ],
      ),
    ),
  );
}

class NutritionCard extends StatelessWidget {
  final Recipe r;
  final KitchenStore s;
  const NutritionCard(this.r, this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    final n = r.nutrition;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nutrition per serving', style: serif(23)),
            Text(
              n == null
                  ? 'Nutrition not added'
                  : macroKeys
                        .map(
                          (k) =>
                              '$k: ${n[k]} ${k == 'calories' ? 'kcal' : 'g'}',
                        )
                        .join(' · '),
            ),
            const Text(
              'Estimates vary with ingredients and portions. Swaps are not recalculated.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            for (final i in r.ingredients)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '$i — ${r.ingredientFacts[i]?['calories'] ?? 'Unknown'} kcal for the listed amount',
                ),
              ),
            if (s.wellness['purpose'] == 'Fitness' && validNutrition(n))
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Log this meal'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TrackerScreen(s, initialRecipe: r),
                  ),
                ),
              ),
            if (r.own)
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeNutritionEditor(r, s),
                  ),
                ),
                child: const Text('Edit ingredient nutrition and costs'),
              ),
          ],
        ),
      ),
    );
  }
}

class BudgetPanel extends StatefulWidget {
  final KitchenStore s;
  final void Function(Recipe) open;
  const BudgetPanel(this.s, this.open, {super.key});
  @override
  State<BudgetPanel> createState() => _BudgetPanelState();
}

class _BudgetPanelState extends State<BudgetPanel> {
  final budget = TextEditingController(),
      servings = TextEditingController(text: '3');
  bool usePantry = false;
  double? amount;
  int portions = 3;
  @override
  void dispose() {
    budget.dispose();
    servings.dispose();
    super.dispose();
  }

  Future<void> prices(Recipe r) async {
    final old = widget.s.prices[r.id] as Map? ?? {};
    final cs = {
      for (final i in r.ingredients)
        i: TextEditingController(text: old[i]?.toString() ?? ''),
    };
    final form = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ingredient prices in pesos'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Cost for each original recipe amount. Blank restores the reference.',
                  ),
                  for (final i in r.ingredients)
                    TextFormField(
                      controller: cs[i],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: i,
                        prefixText: '₱ ',
                        hintText:
                            '${r.ingredientFacts[i]?['cost'] ?? 'Unknown'}',
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? null
                          : double.tryParse(v) == null ||
                                !double.parse(v).isFinite ||
                                double.parse(v) < 0 ||
                                double.parse(v) > 100000
                          ? 'Enter 0–100000'
                          : null,
                    ),
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
              widget.s.prices[r.id] = {
                for (final i in r.ingredients)
                  if (cs[i]!.text.isNotEmpty) i: double.parse(cs[i]!.text),
              };
              await widget.s.save();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    for (final c in cs.values) {
      c.dispose();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final results = amount == null
        ? <Map<String, dynamic>>[]
        : budgetResults(
            widget.s.recipes.map((r) => r.toJson()).toList(),
            budget: amount!,
            servings: portions,
            pantry: widget.s.pantry,
            allergies: widget.s.allergies,
            prices: widget.s.prices,
            usePantry: usePantry,
          );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xfffff7f8),
        border: Border.all(color: const Color(0xfff5dce1)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label('SMART PANTRY · PHILIPPINE PESO'),
            gap(10),
            Text('Good food, within your budget.', style: serif(22)),
            const SizedBox(height: 12),
            TextField(
              controller: budget,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Your budget (₱)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: servings,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Servings to make'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: usePantry,
              onChanged: (v) => setState(() => usePantry = v!),
              title: const Text(
                'Use my pantry — I have enough of each listed item',
              ),
            ),
            const Text(
              'Ingredient-use estimates, not a complete grocery bill. Whole packs, delivery and fuel cost extra. Retail references checked 15 Oct 2026; other prices are planning allowances.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            FilledButton(
              onPressed: () {
                final b = double.tryParse(budget.text);
                final n = int.tryParse(servings.text);
                if (b == null ||
                    !b.isFinite ||
                    b < 0 ||
                    b > 100000 ||
                    n == null ||
                    n < 1 ||
                    n > 100) {
                  toast(
                    context,
                    'Enter a budget from ₱0–100000 and 1–100 servings.',
                  );
                  return;
                }
                setState(() {
                  amount = b;
                  portions = n;
                });
              },
              child: const Text('Find meals within budget'),
            ),
            if (amount != null) ...[
              Text(
                '${results.where((x) => x['fits'] == true).length} affordable matches',
              ),
              const Text(
                'Rank: protein up to 60 points at 30g per serving; fruit/vegetable variety up to 40 at 3 ingredients. This is not a complete nutrition assessment.',
                style: TextStyle(fontSize: 12),
              ),
              for (final x in results)
                Card(
                  child: ExpansionTile(
                    title: Text(x['recipe']['title']),
                    subtitle: Text(
                      x['cost'] == null
                          ? 'Missing prices'
                          : '${peso(x['cost'])} for $portions servings · ${x['fits'] == true ? 'Within budget' : 'Above budget'}',
                    ),
                    children: [
                      for (final i in x['items'])
                        ListTile(
                          title: Text(i['name']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${i['have'] == true ? 'From pantry. ' : ''}${i['basis']}',
                              ),
                              if (i['source'] != null)
                                TextButton(
                                  onPressed: () =>
                                      AndroidApi.openUrl(i['source']),
                                  child: const Text('Retail reference'),
                                ),
                            ],
                          ),
                          trailing: Text(
                            i['cost'] == null ? 'Unknown' : peso(i['cost']),
                          ),
                        ),
                      if (x['cost'] != null)
                        Text(
                          'Per serving: ${peso(x['cost'] / portions)} · Remaining: ${peso(amount! - x['cost'])}',
                        ),
                      TextButton(
                        onPressed: () =>
                            widget.open(Recipe.fromJson(x['recipe'])),
                        child: const Text('View recipe'),
                      ),
                      TextButton(
                        onPressed: () => prices(Recipe.fromJson(x['recipe'])),
                        child: const Text('Adjust prices'),
                      ),
                    ],
                  ),
                ),
              TextButton(
                onPressed: () => setState(() => amount = null),
                child: const Text('Clear budget results'),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class RecipeNutritionEditor extends StatefulWidget {
  final Recipe r;
  final KitchenStore s;
  const RecipeNutritionEditor(this.r, this.s, {super.key});
  @override
  State<RecipeNutritionEditor> createState() => _RecipeNutritionEditorState();
}

class _RecipeNutritionEditorState extends State<RecipeNutritionEditor> {
  late final macros = {
    for (final k in macroKeys)
      k: TextEditingController(text: widget.r.nutrition?[k]?.toString() ?? ''),
  };
  late final calories = {
    for (final i in widget.r.ingredients)
      i: TextEditingController(
        text: widget.r.ingredientFacts[i]?['calories']?.toString() ?? '',
      ),
  };
  late final costs = {
    for (final i in widget.r.ingredients)
      i: TextEditingController(
        text: widget.r.ingredientFacts[i]?['cost']?.toString() ?? '',
      ),
  };
  late final groups = {
    for (final i in widget.r.ingredients)
      i: widget.r.ingredientFacts[i]?['group'] ?? 'Other',
  };
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    for (final c in [...macros.values, ...calories.values, ...costs.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(String label, TextEditingController c) => TextFormField(
    controller: c,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(labelText: label),
    validator: (v) {
      if (v == null || v.isEmpty) return null;
      final n = double.tryParse(v);
      return n == null || !n.isFinite || n < 0 || n > 10000
          ? 'Enter 0–10000'
          : null;
    },
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nutrition and ingredient costs')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Macros are per serving. Ingredient calories and costs cover the full listed recipe amount. Blank means unknown.',
          ),
          for (final k in macroKeys) field('$k per serving', macros[k]!),
          for (final i in widget.r.ingredients) ...[
            const SizedBox(height: 20),
            Text(i, style: const TextStyle(fontWeight: FontWeight.bold)),
            field('Calories (kcal)', calories[i]!),
            field('Cost (₱)', costs[i]!),
            DropdownButtonFormField<String>(
              initialValue: groups[i],
              items: [
                for (final g in [
                  'Vegetable',
                  'Fruit',
                  'Protein',
                  'Grain',
                  'Other',
                ])
                  DropdownMenuItem(value: g, child: Text(g)),
              ],
              onChanged: (v) => groups[i] = v!,
            ),
          ],
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              final known = calories.values.every((c) => c.text.isNotEmpty);
              final values = {
                for (final k in macroKeys) k: double.tryParse(macros[k]!.text),
              };
              if (known) {
                values['calories'] =
                    calories.values.fold<double>(
                      0,
                      (s, c) => s + double.parse(c.text),
                    ) /
                    widget.r.servings;
              }
              final any = macros.values.any((c) => c.text.isNotEmpty);
              if (any && !validNutrition(values)) {
                toast(
                  context,
                  'Complete all macros, or leave the nutrition block blank.',
                );
                return;
              }
              final facts = {
                for (final i in widget.r.ingredients)
                  i: {
                    'calories': double.tryParse(calories[i]!.text),
                    'cost': double.tryParse(costs[i]!.text),
                    'group': groups[i],
                  },
              };
              widget.s.put(
                Recipe.fromJson({
                  ...widget.r.toJson(),
                  'nutrition': any ? values : null,
                  'ingredientFacts': facts,
                }),
              );
              await widget.s.save();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save nutrition'),
          ),
        ],
      ),
    ),
  );
}
