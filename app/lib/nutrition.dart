import 'allergies.dart';

const macroKeys = ['calories', 'protein', 'carbs', 'fat'];
String peso(num n) => '₱${n.toStringAsFixed(2)}';
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
bool validNutrition(Map<String, dynamic>? n) =>
    n != null &&
    macroKeys.every(
      (k) =>
          n[k] is num && (n[k] as num).isFinite && n[k] >= 0 && n[k] <= 10000,
    );
List<String> ingredientWords(String s) {
  const aliases = {
    'eggs': 'egg',
    'onions': 'onion',
    'tomatoes': 'tomato',
    'carrots': 'carrot',
    'potatoes': 'potato',
  };
  return s
      .toLowerCase()
      .replaceAll(RegExp('[^a-z ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .map((s) => aliases[s] ?? s)
      .toList();
}

bool ingredientMatches(String ingredient, List<String> pantry) {
  final words = ingredientWords(ingredient);
  return pantry.any((p) {
    final pw = ingredientWords(p);
    if (words.contains('oil') &&
        (words.contains('olive') || words.contains('sesame')) &&
        !pw.any((w) => w == 'olive' || w == 'sesame')) {
      return false;
    }
    return pw.isNotEmpty && pw.every(words.contains);
  });
}

Map<String, double> dayTotals(List<Map<String, dynamic>> logs, String date) {
  final out = {for (final k in macroKeys) k: 0.0};
  for (final l in logs) {
    if (l['date'] != date || l['deleted'] == true) continue;
    final n = Map<String, dynamic>.from(l['nutrition']);
    for (final k in macroKeys) {
      out[k] = out[k]! + (n[k] as num).toDouble() * (l['servings'] as num);
    }
  }
  return out;
}

String scaledAmount(String name, double factor) => name.replaceFirstMapped(
  RegExp(r'^(\d+(?:\.\d+)?[¼½¾]?|[¼½¾])'),
  (m) {
    final s = m[0]!;
    const f = {'¼': .25, '½': .5, '¾': .75};
    final n =
        (double.tryParse(s.replaceAll(RegExp('[¼½¾]'), '')) ?? 0) +
        (f[s.substring(s.length - 1)] ?? 0);
    return (n * factor).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  },
);
List<Map<String, dynamic>> budgetResults(
  List<Map<String, dynamic>> recipes, {
  required double budget,
  required int servings,
  required List<String> pantry,
  required List<String> allergies,
  required Map<String, dynamic> prices,
  bool usePantry = false,
}) {
  final results = <Map<String, dynamic>>[];
  for (final r in recipes) {
    if (allergyWarnings(
      allergies,
      List<String>.from(r['allergens'] ?? []),
      List<String>.from(r['ingredients'] ?? []),
    ).isNotEmpty) {
      continue;
    }
    final factor = servings / (r['servings'] as num);
    final facts = r['ingredientFacts'] as Map;
    final overrides = prices[r['id']] as Map? ?? {};
    final items = <Map<String, dynamic>>[];
    for (final name in (r['ingredients'] as List).cast<String>()) {
      final f = facts[name] as Map? ?? {};
      final base = overrides[name] ?? f['cost'];
      final have = usePantry && ingredientMatches(name, pantry);
      final value = base is num
          ? ((base * factor * 100 - 1e-7).ceil().clamp(0, 100000000) / 100)
          : null;
      items.add({
        'name': scaledAmount(name, factor),
        'original': name,
        'cost': have ? 0.0 : value,
        'value': value,
        'have': have,
        'basis': overrides.containsKey(name)
            ? 'Your saved estimate for the original amount.'
            : f['basis'] ?? 'Creator estimate.',
        'source': overrides.containsKey(name) ? null : f['source'],
      });
    }
    final known = items.every((i) => i['cost'] != null);
    final cost = known
        ? items.fold<double>(0, (sum, i) => sum + (i['cost'] as num))
        : null;
    final n = r['nutrition'] as Map?;
    final protein = (n?['protein'] as num?)?.toDouble() ?? 0;
    final plants = (r['ingredients'] as List)
        .where(
          (i) =>
              ['Vegetable', 'Fruit'].contains((facts[i] as Map?)?['group']) &&
              !RegExp(
                r'^\d*\s*(cloves?|tsp|tbsp)\b',
                caseSensitive: false,
              ).hasMatch(i),
        )
        .length;
    final score =
        60 * (protein / 30).clamp(0, 1) + 40 * (plants / 3).clamp(0, 1);
    results.add({
      'recipe': r,
      'items': items,
      'cost': cost,
      'score': score,
      'fits': cost != null && (cost * 100).round() <= (budget * 100).round(),
    });
  }
  results.sort((a, b) {
    if (a['fits'] != b['fits']) return a['fits'] == true ? -1 : 1;
    final score = (b['score'] as num).compareTo(a['score'] as num);
    return score != 0
        ? score
        : ((a['cost'] as num?) ?? double.infinity).compareTo(
            (b['cost'] as num?) ?? double.infinity,
          );
  });
  return results;
}
