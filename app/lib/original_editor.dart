import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'data.dart';
import 'ui.dart';
import 'faithful_app.dart';
import 'nutrition.dart';

class RecipeEditor extends StatefulWidget {
  final KitchenStore store;
  final Recipe? recipe;
  const RecipeEditor(this.store, {this.recipe, super.key});
  @override
  State<RecipeEditor> createState() => _RecipeEditorState();
}

class _RecipeEditorState extends State<RecipeEditor> {
  final form = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  final instructions = <TextEditingController>[];
  final timers = <TextEditingController>[];
  final facts = <String, Map<String, TextEditingController>>{};
  final groups = <String, String>{};
  int stage = 0;
  String category = 'Filipino', level = 'Beginner', image = 'assets/bowl.jpg';
  Set<String> allergens = {};
  bool saved = false;
  String get draftKey => 'recipe_draft_${widget.recipe?.id ?? 'new'}';
  TextEditingController ctrl(String key) =>
      controllers.putIfAbsent(key, () => TextEditingController());
  List<String> lines(String value) => value
      .split('\n')
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
      .toList();
  @override
  void initState() {
    super.initState();
    Map<String, dynamic> j = widget.recipe?.toJson() ?? {};
    final raw = widget.store.prefs.getString(draftKey);
    if (raw != null) {
      try {
        j = Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {}
    }
    category = j['category'] ?? category;
    level = j['level'] ?? level;
    image = j['image'] ?? image;
    allergens = Set<String>.from(j['allergens'] ?? []);
    for (final key in ['title', 'description', 'tools', 'tips']) {
      ctrl(key).text = j[key] ?? '';
    }
    ctrl('minutes').text = '${j['minutes'] ?? 20}';
    ctrl('servings').text = '${j['servings'] ?? 2}';
    ctrl('ingredients').text = (j['ingredients'] as List? ?? []).join('\n');
    ctrl('swaps').text = (j['swaps'] as Map? ?? {}).entries
        .map((e) => '${e.key} = ${e.value}')
        .join('\n');
    for (final key in macroKeys) {
      ctrl(key).text = '${j['nutrition']?[key] ?? ''}';
    }
    final list = List<String>.from(j['steps'] ?? ['']);
    for (var i = 0; i < list.length; i++) {
      instructions.add(TextEditingController(text: list[i]));
      timers.add(TextEditingController(text: '${j['timers']?['$i'] ?? 0}'));
    }
    if (instructions.isEmpty) {
      instructions.add(TextEditingController());
      timers.add(TextEditingController(text: '0'));
    }
    for (final i in lines(ctrl('ingredients').text)) {
      final f = j['ingredientFacts']?[i] ?? {};
      facts[i] = {
        'calories': TextEditingController(text: '${f['calories'] ?? ''}'),
        'cost': TextEditingController(text: '${f['cost'] ?? ''}'),
      };
      groups[i] = f['group'] ?? 'Other';
    }
    for (final c in [
      ...controllers.values,
      ...instructions,
      ...timers,
      ...facts.values.expand((m) => m.values),
    ]) {
      c.addListener(draft);
    }
    ctrl('ingredients').addListener(refreshIngredients);
  }

  void refreshIngredients() {
    for (final i in lines(ctrl('ingredients').text)) {
      if (!facts.containsKey(i)) {
        facts[i] = {
          'calories': TextEditingController(),
          'cost': TextEditingController(),
        };
        for (final c in facts[i]!.values) {
          c.addListener(draft);
        }
        groups[i] = 'Other';
      }
    }
    setState(() {});
  }

  Map<String, dynamic> snapshot() => {
    'id': widget.recipe?.id ?? 'local-${DateTime.now().microsecondsSinceEpoch}',
    'title': ctrl('title').text.trim(),
    'description': ctrl('description').text.trim(),
    'minutes': int.tryParse(ctrl('minutes').text) ?? 20,
    'servings': int.tryParse(ctrl('servings').text) ?? 2,
    'category': category,
    'level': level,
    'image': image,
    'author': widget.store.name,
    'own': true,
    'ingredients': lines(ctrl('ingredients').text),
    'steps': instructions.map((c) => c.text.trim()).toList(),
    'timers': {
      for (int i = 0; i < timers.length; i++)
        '$i': int.tryParse(timers[i].text) ?? 0,
    },
    'allergens': allergens.toList(),
    'tools': ctrl('tools').text,
    'tips': ctrl('tips').text,
    'swaps': {
      for (final line in lines(ctrl('swaps').text))
        if (line.contains('='))
          line.split('=').first.trim(): line
              .substring(line.indexOf('=') + 1)
              .replaceFirst(RegExp(r'^>'), '')
              .trim(),
    },
    'nutrition': macroKeys.every((k) => ctrl(k).text.isEmpty)
        ? null
        : {for (final k in macroKeys) k: num.tryParse(ctrl(k).text)},
    'ingredientFacts': {
      for (final i in lines(ctrl('ingredients').text))
        i: {
          'calories': num.tryParse(facts[i]?['calories']?.text ?? ''),
          'cost': num.tryParse(facts[i]?['cost']?.text ?? ''),
          'group': groups[i] ?? 'Other',
          'basis': 'User-entered estimate for the full recipe amount.',
          'source': null,
        },
    },
  };
  void draft() {
    if (!saved) widget.store.prefs.setString(draftKey, jsonEncode(snapshot()));
  }

  @override
  void dispose() {
    for (final c in [
      ...controllers.values,
      ...instructions,
      ...timers,
      ...facts.values.expand((m) => m.values),
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(
    String label,
    String key, {
    int maxLines = 1,
    bool required = false,
    bool number = false,
  }) => fieldLabel(
    label,
    TextFormField(
      controller: ctrl(key),
      maxLines: maxLines,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : maxLines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      textInputAction: maxLines > 1 ? TextInputAction.newline : null,
      decoration: inputBox(),
      validator: (v) {
        if (required && (v ?? '').trim().isEmpty) return 'Required';
        if (number && v != null && v.isNotEmpty) {
          final n = double.tryParse(v);
          if (n == null || !n.isFinite || n < 0 || n > 100000) {
            return 'Enter a valid non-negative number';
          }
          if ((key == 'servings' || key == 'minutes') &&
              (n < 1 || n != n.roundToDouble())) {
            return 'Enter a positive whole number';
          }
        }
        return null;
      },
    ),
  );
  Widget dropdown(
    String title,
    String value,
    List<String> options,
    ValueChanged<String> onChange,
  ) => fieldLabel(
    title,
    DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: inputBox(),
      items: options
          .map(
            (v) => DropdownMenuItem(
              value: v,
              child: Text(v, style: type(13)),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) {
          setState(() => onChange(v));
          draft();
        }
      },
    ),
  );
  Future<void> photo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null) return;
      final f = result.files.single;
      if (f.bytes == null || f.size > 3 * 1024 * 1024) {
        if (mounted) toast(context, 'Choose a photo smaller than 3 MB.');
        return;
      }
      setState(
        () => image =
            'data:image/${f.extension};base64,${base64Encode(f.bytes!)}',
      );
      draft();
    } catch (_) {
      if (mounted) toast(context, 'Could not open this photo.');
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (instructions.any((c) => c.text.trim().isEmpty)) {
      toast(context, 'Complete every instruction or remove empty steps.');
      return;
    }
    final j = snapshot();
    if (j['nutrition'] != null &&
        !validNutrition(Map<String, dynamic>.from(j['nutrition']))) {
      toast(
        context,
        'Enter all four nutrition values or leave them all blank.',
      );
      setState(() => stage = 0);
      return;
    }
    final ingredientFacts = Map<String, dynamic>.from(j['ingredientFacts']);
    if (j['nutrition'] != null &&
        ingredientFacts.isNotEmpty &&
        ingredientFacts.values.every((f) => f['calories'] is num)) {
      j['nutrition']['calories'] =
          ingredientFacts.values.fold<num>(0, (sum, f) => sum + f['calories']) /
          j['servings'];
    }
    for (final swap in lines(ctrl('swaps').text)) {
      if (!swap.contains('=') ||
          !lines(
            ctrl('ingredients').text,
          ).contains(swap.split('=').first.trim()) ||
          swap.split('=').last.trim().isEmpty) {
        toast(
          context,
          'Each swap must match an ingredient and include an alternative.',
        );
        setState(() => stage = 0);
        return;
      }
    }
    final r = Recipe.fromJson(j);
    widget.store.put(r);
    await widget.store.save();
    if (widget.store.storageError == null) {
      saved = true;
      await widget.store.prefs.remove(draftKey);
      if (mounted) Navigator.pop(context);
    } else if (mounted) {
      toast(context, widget.store.storageError!);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: pageHeader(
      c,
      stage == 0
          ? (widget.recipe == null ? 'Create Recipe' : 'Edit Recipe')
          : 'Instructions',
    ),
    body: OriginalPageEnter(
      key: ValueKey(stage),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label(
                stage == 0
                    ? 'THE GOOD INGREDIENTS  1 / 2'
                    : 'A LITTLE KITCHEN MAGIC  2 / 2',
              ),
              gap(20),
              if (stage == 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      FoodImage(image, height: 180),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: FilledButton.icon(
                          onPressed: photo,
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('Add photo'),
                        ),
                      ),
                    ],
                  ),
                ),
                gap(12),
                Row(
                  children: [
                    for (final asset in [
                      'bowl',
                      'salad',
                      'pasta',
                      'chicken',
                      'pancakes',
                      'bread',
                    ])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: InkWell(
                            onTap: () {
                              setState(() => image = 'assets/$asset.jpg');
                              draft();
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: FoodImage('assets/$asset.jpg', height: 44),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                field('Recipe name', 'title', required: true),
                field('A little about your dish', 'description', maxLines: 3),
                Row(
                  children: [
                    Expanded(
                      child: dropdown(
                        'Category',
                        category,
                        categories,
                        (v) => category = v,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: dropdown('Cooking level', level, [
                        'Beginner',
                        'Intermediate',
                        'Professional',
                      ], (v) => level = v),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: field(
                        'Total time (minutes)',
                        'minutes',
                        number: true,
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: field(
                        'Servings',
                        'servings',
                        number: true,
                        required: true,
                      ),
                    ),
                  ],
                ),
                gap(20),
                Surface(
                  color: const Color(0xfffff7f8),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nutrition per serving (optional)',
                        style: type(14, weight: FontWeight.w600),
                      ),
                      gap(10),
                      Text(
                        'Enter all four values from your recipe calculation or food labels. Leave all blank if unknown.',
                        style: type(11, color: muted),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: field(
                              'Calories (kcal)',
                              'calories',
                              number: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: field(
                              'Protein (g)',
                              'protein',
                              number: true,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: field(
                              'Carbohydrates (g)',
                              'carbs',
                              number: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: field('Fat (g)', 'fat', number: true),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                field(
                  'Ingredients · one per line',
                  'ingredients',
                  maxLines: 5,
                  required: true,
                ),
                gap(20),
                Text(
                  'Calories and cost per ingredient',
                  style: type(14, weight: FontWeight.w600),
                ),
                gap(10),
                Text(
                  'For each full recipe amount above, enter calories and its estimated ingredient cost in Philippine pesos. Blank means unknown.',
                  style: type(11, color: muted),
                ),
                for (final i in lines(ctrl('ingredients').text))
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i, style: type(13, weight: FontWeight.w600)),
                        Row(
                          children: [
                            for (final k in ['calories', 'cost'])
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: fieldLabel(
                                    k == 'cost'
                                        ? 'Cost (₱)'
                                        : 'Calories (kcal)',
                                    TextFormField(
                                      controller: facts[i]![k],
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: inputBox(hint: 'Unknown'),
                                      validator: (v) {
                                        if (v == null || v.isEmpty) return null;
                                        final n = double.tryParse(v);
                                        return n == null ||
                                                !n.isFinite ||
                                                n < 0 ||
                                                n > 100000
                                            ? 'Enter 0–100000'
                                            : null;
                                      },
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        dropdown('Food group', groups[i] ?? 'Other', [
                          'Other',
                          'Vegetable',
                          'Fruit',
                          'Protein',
                          'Grain',
                          'Dairy',
                        ], (v) => groups[i] = v),
                      ],
                    ),
                  ),
                gap(16),
                Text(
                  'When all ingredient calories and the recipe macros are entered, calories per serving are calculated from this breakdown. Swaps are not automatically recalculated.',
                  style: type(11, color: muted),
                ),
                field(
                  'Optional swaps · ingredient = alternative',
                  'swaps',
                  maxLines: 3,
                ),
                gap(12),
                Text(
                  'Declare allergens',
                  style: type(12, color: burgundy, weight: FontWeight.w600),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final a in allergensList)
                      FilterChip(
                        label: Text(a),
                        selected: allergens.contains(a),
                        onSelected: (v) {
                          setState(
                            () => v ? allergens.add(a) : allergens.remove(a),
                          );
                          draft();
                        },
                      ),
                  ],
                ),
                gap(20),
                primary('Next: instructions', () {
                  if (form.currentState!.validate()) {
                    draft();
                    setState(() => stage = 1);
                  }
                }),
              ] else ...[
                for (int i = 0; i < instructions.length; i++)
                  Padding(
                    key: ObjectKey(instructions[i]),
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 16, right: 8),
                          child: Text(
                            '${i + 1}',
                            style: type(14, color: burgundy),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              TextFormField(
                                controller: instructions[i],
                                maxLines: 3,
                                decoration: inputBox(
                                  hint: 'What happens in this step?',
                                ).copyWith(fillColor: const Color(0xffffe0e4)),
                                validator: (v) => (v ?? '').trim().isEmpty
                                    ? 'Describe this step'
                                    : null,
                              ),
                              fieldLabel(
                                'Timer (seconds, 0 for none)',
                                TextFormField(
                                  controller: timers[i],
                                  keyboardType: TextInputType.number,
                                  decoration: inputBox(),
                                  validator: (v) {
                                    final n = int.tryParse(v ?? '');
                                    return n == null || n < 0 || n > 86400
                                        ? 'Enter 0–86400 seconds'
                                        : null;
                                  },
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Move step up',
                                    onPressed: i == 0
                                        ? null
                                        : () {
                                            setState(() {
                                              final a = instructions.removeAt(
                                                    i,
                                                  ),
                                                  b = timers.removeAt(i);
                                              instructions.insert(i - 1, a);
                                              timers.insert(i - 1, b);
                                            });
                                            draft();
                                          },
                                    icon: const Icon(
                                      Icons.arrow_upward,
                                      size: 18,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Move step down',
                                    onPressed: i == instructions.length - 1
                                        ? null
                                        : () {
                                            setState(() {
                                              final a = instructions.removeAt(
                                                    i,
                                                  ),
                                                  b = timers.removeAt(i);
                                              instructions.insert(i + 1, a);
                                              timers.insert(i + 1, b);
                                            });
                                            draft();
                                          },
                                    icon: const Icon(
                                      Icons.arrow_downward,
                                      size: 18,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: 'Delete step',
                                    onPressed: instructions.length < 2
                                        ? null
                                        : () {
                                            final a = instructions.removeAt(i),
                                                b = timers.removeAt(i);
                                            a.removeListener(draft);
                                            b.removeListener(draft);
                                            setState(() {});
                                            draft();
                                          },
                                    icon: const Icon(Icons.close, size: 18),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                TextButton.icon(
                  onPressed: () {
                    final a = TextEditingController(),
                        b = TextEditingController(text: '0');
                    a.addListener(draft);
                    b.addListener(draft);
                    setState(() {
                      instructions.add(a);
                      timers.add(b);
                    });
                    draft();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add step'),
                ),
                field('Tools you’ll need', 'tools', maxLines: 2),
                field('Tips & tricks', 'tips', maxLines: 3),
                TextButton(
                  onPressed: () => setState(() => stage = 0),
                  child: const Text('Back to ingredients'),
                ),
                primary('Save recipe', save),
              ],
              gap(15),
              Center(
                child: TextButton(
                  onPressed: () async {
                    final discard = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Discard draft?'),
                        content: const Text(
                          'Your unsaved changes will be removed.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Keep editing'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Discard'),
                          ),
                        ],
                      ),
                    );
                    if (discard == true) {
                      saved = true;
                      await widget.store.prefs.remove(draftKey);
                      if (c.mounted) Navigator.pop(c);
                    }
                  },
                  child: const Text('Discard draft'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
