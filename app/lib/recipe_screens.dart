import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data.dart';
import 'ui.dart';
import 'android_api.dart';
import 'faithful_app.dart';
import 'fitness_screens.dart';
import 'original_editor.dart';
export 'original_editor.dart';

class RecipeDetails extends StatefulWidget {
  final Recipe recipe;
  final KitchenStore store;
  const RecipeDetails(this.recipe, this.store, {super.key});
  @override
  State<RecipeDetails> createState() => _RecipeDetailsState();
}

class _RecipeDetailsState extends State<RecipeDetails> {
  final checked = <String>{};
  final note = TextEditingController();
  bool publishing = false;
  KitchenStore get s => widget.store;
  Recipe get r => s.recipes.firstWhere(
    (r) => r.id == widget.recipe.id,
    orElse: () => widget.recipe,
  );
  @override
  void initState() {
    super.initState();
    s.addListener(refresh);
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    s.removeListener(refresh);
    note.dispose();
    super.dispose();
  }

  Widget title(String text) => Padding(
    padding: const EdgeInsets.only(top: 25, bottom: 15),
    child: Text(text, style: type(20, weight: FontWeight.w700)),
  );
  @override
  Widget build(BuildContext c) {
    final total = r.ingredients.fold<num>(
      0,
      (n, i) => n + (r.ingredientFacts[i]?['calories'] as num? ?? 0),
    );
    final known = r.ingredients.every(
      (i) => r.ingredientFacts[i]?['calories'] is num,
    );
    return Scaffold(
      appBar: pageHeader(
        c,
        'Recipe',
        action: IconButton(
          tooltip: 'Save recipe',
          onPressed: () => toggleBookmark(c, s, r),
          icon: Icon(
            s.saved.contains(r.id) ? Icons.bookmark : Icons.bookmark_border,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(23),
              child: FoodImage(r.image, height: 230),
            ),
            gap(24),
            label(r.category.toUpperCase()),
            gap(10),
            Text(r.title, style: type(27, weight: FontWeight.w700)),
            gap(12),
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: pale,
                  child: Text(r.author[0], style: type(12, color: burgundy)),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text('By ${r.author}', style: type(12, color: muted)),
                ),
                IconButton(
                  tooltip: 'Share recipe',
                  onPressed: () async {
                    try {
                      await AndroidApi.share(
                        '${r.title}\n${r.ingredients.join('\n')}\n${r.steps.join('\n')}',
                      );
                    } catch (_) {
                      if (c.mounted) {
                        toast(c, 'Sharing is unavailable on this device.');
                      }
                    }
                  },
                  icon: const Icon(Icons.ios_share, size: 20),
                ),
              ],
            ),
            gap(16),
            Text(
              r.description,
              style: type(13, color: muted).copyWith(height: 1.65),
            ),
            gap(22),
            Surface(
              color: const Color(0xfffff6f6),
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                children: [
                  for (final pair in [
                    ('${r.minutes} min', 'Total time'),
                    ('${r.servings} servings', 'At your table'),
                    (r.level, 'Cooking level'),
                  ])
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            pair.$1,
                            style: type(12, weight: FontWeight.w700),
                          ),
                          gap(5),
                          Text(pair.$2, style: type(10, color: muted)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            gap(22),
            if (r.nutrition != null)
              Surface(
                color: const Color(0xfffff7f8),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Nutrition',
                          style: type(20, weight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text('Per serving', style: type(11, color: muted)),
                      ],
                    ),
                    gap(16),
                    Row(
                      children: [
                        for (final pair in [
                          ('calories', 'Calories', 'kcal'),
                          ('protein', 'Protein', 'g'),
                          ('carbs', 'Carbs', 'g'),
                          ('fat', 'Fat', 'g'),
                        ])
                          Expanded(
                            child: Column(
                              children: [
                                FittedBox(
                                  child: Text(
                                    '${r.nutrition![pair.$1]} ${pair.$3}',
                                    style: type(
                                      21,
                                      color: burgundy,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                gap(4),
                                Text(pair.$2, style: type(11, color: muted)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    gap(14),
                    Text(
                      'Illustrative estimate for the sample recipe. Actual nutrition varies with ingredients and portions. Swaps are not recalculated.',
                      style: type(11, color: muted),
                    ),
                    if (s.wellness['purpose'] == 'Fitness') ...[
                      gap(16),
                      primary(
                        'Log this meal',
                        () => present(c, TrackerScreen(s, initialRecipe: r)),
                      ),
                    ],
                  ],
                ),
              ),
            if (s.warnings(r).isNotEmpty) ...[
              gap(16),
              Text(
                'Contains declared allergens: ${s.warnings(r).join(', ')}',
                style: type(12, color: Colors.orange.shade900),
              ),
            ],
            if (r.own && s.viewer != null)
              TextButton.icon(
                icon: const Icon(Icons.public),
                label: Text(publishing ? 'Posting…' : 'Post to community'),
                onPressed: publishing
                    ? null
                    : () async {
                        setState(() => publishing = true);
                        try {
                          await s.publishRecipe(r);
                          if (c.mounted) toast(c, 'Posted to community');
                        } catch (_) {
                          if (c.mounted) {
                            toast(
                              c,
                              'Could not post. Check your connection and try again.',
                            );
                          }
                        } finally {
                          if (mounted) setState(() => publishing = false);
                        }
                      },
              ),
            title('Ingredients'),
            Text('Check as you go', style: type(11, color: muted)),
            gap(10),
            Text(
              'Ingredient calories refer to the listed amounts for the full recipe. Illustrative estimates. ${known ? 'Total: $total kcal · ${(total / r.servings).toStringAsFixed(1)} kcal per serving.' : 'Some ingredient values are unknown.'}',
              style: type(11, color: muted),
            ),
            for (final ingredient in r.ingredients)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: checked.contains(ingredient),
                      onChanged: (v) => setState(
                        () => v == true
                            ? checked.add(ingredient)
                            : checked.remove(ingredient),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ingredient,
                            style: type(13).copyWith(
                              decoration: checked.contains(ingredient)
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          gap(5),
                          Text(
                            '${r.ingredientFacts[ingredient]?['calories'] ?? 'Unknown'} kcal for this amount',
                            style: type(11, color: const Color(0xff9c4257)),
                          ),
                        ],
                      ),
                    ),
                    if (r.swaps.containsKey(ingredient))
                      TextButton(
                        onPressed: () => showDialog(
                          context: c,
                          builder: (ctx) => AlertDialog(
                            title: const Text('A simple swap'),
                            content: Text(
                              '${r.swaps[ingredient]}\n\nCheck labels and allergens. Nutrition is not recalculated.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Got it'),
                              ),
                            ],
                          ),
                        ),
                        child: const Text('Swap'),
                      ),
                  ],
                ),
              ),
            title('Let’s bring it together'),
            for (int i = 0; i < r.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 21),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14.5,
                      backgroundColor: pale,
                      child: Text(
                        '${i + 1}',
                        style: type(12, color: green, weight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        r.steps[i],
                        style: type(13).copyWith(height: 1.8),
                      ),
                    ),
                  ],
                ),
              ),
            Surface(
              color: const Color(0xfffff6f6),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A little kitchen wisdom',
                    style: type(16, weight: FontWeight.w700),
                  ),
                  gap(10),
                  Text(r.tips, style: type(13, color: muted)),
                  gap(18),
                  Text(
                    'Tools you’ll need',
                    style: type(16, weight: FontWeight.w700),
                  ),
                  gap(10),
                  Text(r.tools, style: type(13, color: muted)),
                ],
              ),
            ),
            title('Your cooking notes'),
            Text(
              'Private notes, saved just for you.',
              style: type(12, color: muted),
            ),
            for (final text in s.comments[r.id] ?? [])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(text, style: type(13)),
              ),
            fieldLabel(
              'Remember a delicious tweak',
              TextField(controller: note, maxLines: 3, decoration: inputBox()),
            ),
            primary('Add note', () {
              if (note.text.trim().isEmpty) return;
              s.comments.putIfAbsent(r.id, () => []).add(note.text.trim());
              note.clear();
              s.save();
            }),
            if (r.own) ...[
              gap(20),
              primary(
                'Edit recipe',
                () => present(c, RecipeEditor(s, recipe: r)),
              ),
              TextButton(
                onPressed: () async {
                  final yes = await showDialog<bool>(
                    context: c,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete recipe?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (yes == true) {
                    try {
                      await s.withdrawRecipe(r);
                    } catch (_) {
                      if (c.mounted) {
                        toast(
                          c,
                          'Connect to the internet to remove the recipe from the community.',
                        );
                      }
                      return;
                    }
                    s.remove(r);
                    if (c.mounted) Navigator.pop(c);
                  }
                },
                child: const Text('Delete recipe'),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
          child: primary('Cook now!', () => present(c, CookingScreen(r, s))),
        ),
      ),
    );
  }
}

class CookingScreen extends StatefulWidget {
  final Recipe recipe;
  final KitchenStore store;
  const CookingScreen(this.recipe, this.store, {super.key});
  @override
  State<CookingScreen> createState() => _CookingScreenState();
}

class _CookingScreenState extends State<CookingScreen> {
  int step = 0, seconds = 300, initialSeconds = 300;
  Timer? timer;
  bool finished = false;
  DateTime? deadline;
  @override
  void initState() {
    super.initState();
    seconds = (widget.recipe.timers['0'] as num?)?.toInt() ?? 300;
    if (seconds <= 0) seconds = 300;
    initialSeconds = seconds;
    final raw = widget.store.prefs.getString('cooking_deadline');
    if (raw != null) {
      try {
        final v = jsonDecode(raw);
        if (v['recipeId'] == widget.recipe.id) {
          step = (v['step'] as int? ?? 0).clamp(
            0,
            widget.recipe.steps.length - 1,
          );
          deadline = DateTime.parse(v['deadline']);
          seconds = deadline!
              .difference(DateTime.now())
              .inSeconds
              .clamp(0, 86400);
          if (seconds > 0) {
            timer = Timer.periodic(const Duration(seconds: 1), (t) {
              if (!mounted) return;
              setState(
                () => seconds = deadline!
                    .difference(DateTime.now())
                    .inSeconds
                    .clamp(0, 86400),
              );
              if (seconds == 0) t.cancel();
            });
          }
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void changeStep(int next) {
    timer?.cancel();
    AndroidApi.cancelTimer();
    widget.store.prefs.remove('cooking_deadline');
    setState(() {
      step = next;
      seconds = (widget.recipe.timers['$next'] as num?)?.toInt() ?? 300;
      if (seconds <= 0) seconds = 300;
      initialSeconds = seconds;
    });
  }

  void toggleTimer() async {
    if (timer?.isActive ?? false) {
      await AndroidApi.cancelTimer();
      widget.store.prefs.remove('cooking_deadline');
      setState(() => timer?.cancel());
      return;
    }
    if (seconds == 0) return;
    try {
      if (widget.store.notifications) {
        await AndroidApi.timer(seconds, widget.recipe.title);
      }
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'Android reminder unavailable; keep the cooking screen open.',
        );
      }
    }
    deadline = DateTime.now().add(Duration(seconds: seconds));
    widget.store.prefs.setString(
      'cooking_deadline',
      jsonEncode({
        'recipeId': widget.recipe.id,
        'step': step,
        'deadline': deadline!.toIso8601String(),
      }),
    );
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(
        () => seconds = deadline!
            .difference(DateTime.now())
            .inSeconds
            .clamp(0, 86400),
      );
      if (seconds <= 0) {
        t.cancel();
        SystemSound.play(SystemSoundType.alert);
        toast(context, 'Your kitchen timer is done.');
      }
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cream,
        title: Text(r.title, style: const TextStyle(fontSize: 16)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: finished
                ? Column(
                    children: [
                      const CircleAvatar(
                        radius: 55,
                        backgroundColor: pale,
                        child: Icon(
                          Icons.celebration_outlined,
                          size: 55,
                          color: green,
                        ),
                      ),
                      gap(30),
                      Text(
                        'Made with a little love.',
                        style: serif(27),
                        textAlign: TextAlign.center,
                      ),
                      gap(18),
                      Text(
                        'You made ${r.title}.\nEnjoy every bite.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 17,
                          height: 1.8,
                        ),
                      ),
                      gap(30),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Back to the recipe'),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: FoodImage(r.image, height: 165),
                      ),
                      gap(20),
                      LinearProgressIndicator(
                        value: (step + 1) / r.steps.length,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(6),
                        backgroundColor: line,
                        color: green,
                      ),
                      gap(28),
                      Text(
                        'Step ${step + 1} of ${r.steps.length}',
                        style: const TextStyle(color: muted),
                      ),
                      gap(20),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          r.steps[step],
                          key: ValueKey(step),
                          style: type(
                            23,
                            color: burgundy,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      gap(35),
                      Surface(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.timer_outlined, color: green),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Your kitchen timer',
                                    style: serif(23),
                                  ),
                                ),
                              ],
                            ),
                            gap(20),
                            Text(
                              '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 3,
                              ),
                            ),
                            gap(16),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final min in [1, 5, 10, 15, 30])
                                  ChoiceChip(
                                    label: Text('$min min'),
                                    selected: initialSeconds == min * 60,
                                    onSelected: (_) {
                                      AndroidApi.cancelTimer();
                                      widget.store.prefs.remove(
                                        'cooking_deadline',
                                      );
                                      timer?.cancel();
                                      setState(() {
                                        seconds = min * 60;
                                        initialSeconds = seconds;
                                      });
                                    },
                                  ),
                              ],
                            ),
                            gap(20),
                            Wrap(
                              spacing: 12,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: toggleTimer,
                                  icon: Icon(
                                    timer?.isActive ?? false
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                  ),
                                  label: Text(
                                    timer?.isActive ?? false
                                        ? 'Pause'
                                        : 'Start timer',
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    AndroidApi.cancelTimer();
                                    widget.store.prefs.remove(
                                      'cooking_deadline',
                                    );
                                    timer?.cancel();
                                    setState(() => seconds = initialSeconds);
                                  },
                                  child: const Text('Reset'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      gap(30),
                      Wrap(
                        spacing: 18,
                        runSpacing: 12,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          OutlinedButton(
                            onPressed: step == 0
                                ? null
                                : () => changeStep(step - 1),
                            child: const Text('Previous'),
                          ),
                          FilledButton.icon(
                            onPressed: () {
                              if (step < r.steps.length - 1) {
                                changeStep(step + 1);
                              } else {
                                AndroidApi.cancelTimer();
                                widget.store.prefs.remove('cooking_deadline');
                                timer?.cancel();
                                widget.store.cooked++;
                                widget.store.log(
                                  'You cooked ${r.title}. Nicely done!',
                                );
                                widget.store.save();
                                setState(() => finished = true);
                              }
                            },
                            icon: Icon(
                              step == r.steps.length - 1
                                  ? Icons.check
                                  : Icons.arrow_forward,
                              size: 18,
                            ),
                            iconAlignment: IconAlignment.end,
                            label: Text(
                              step == r.steps.length - 1
                                  ? 'Finish cooking'
                                  : 'Next step',
                            ),
                          ),
                        ],
                      ),
                      gap(24),
                      ExpansionTile(
                        title: const Text('Keep your ingredients close'),
                        children: [
                          for (final i in r.ingredients)
                            ListTile(dense: true, title: Text(i)),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
