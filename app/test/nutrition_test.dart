import 'package:flutter_test/flutter_test.dart';
import 'package:dishcovery/data.dart';
import 'package:dishcovery/nutrition.dart';
import 'package:dishcovery/fitness_screens.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Catalog contains 15 recipes and complete ingredient nutrition', () {
    expect(seedRecipes.length, 15);
    for (final r in seedRecipes) {
      expect(validNutrition(r.nutrition), true);
      final sum = r.ingredients.fold<double>(
        0,
        (s, i) => s + (r.ingredientFacts[i]['calories'] as num),
      );
      expect(r.nutrition!['calories'], closeTo(sum / r.servings, .06));
    }
  });
  test('Pantry matches plural words and reports oil separately', () {
    final r = seedRecipes.firstWhere((r) => r.id == 'egg-fried-rice');
    expect(
      r.ingredients
          .where(
            (i) => ingredientMatches(i, ['egg', 'rice', 'garlic', 'onions']),
          )
          .length,
      4,
    );
    expect(ingredientMatches('1 tbsp olive oil', ['Oil']), false);
    expect(ingredientMatches('2 cups rice', ['ice']), false);
  });
  test('Budget boundaries, source costs, overrides and allergies', () {
    final r = seedRecipes.firstWhere((r) => r.id == 'chicken').toJson();
    List<Map<String, dynamic>> run(
      double b, {
      Map<String, dynamic> prices = const {},
      List<String> allergies = const [],
    }) => budgetResults(
      [r],
      budget: b,
      servings: 3,
      pantry: [],
      allergies: allergies,
      prices: prices,
    );
    expect(run(144.52).single['fits'], true);
    expect(run(144.51).single['fits'], false);
    expect(run(500).single['cost'], closeTo(144.52, .001));
    expect(
      run(
        500,
        prices: {
          'chicken': {'500 g chicken thighs': 150},
        },
      ).single['cost'],
      closeTo(184.52, .001),
    );
    r['allergens'] = ['Eggs'];
    expect(run(500, allergies: ['Eggs']), isEmpty);
  });
  test('Unknown price is not zero and pantry deductions are explicit', () {
    final r = seedRecipes.first.toJson();
    r['ingredientFacts'] = {};
    final out = budgetResults(
      [r],
      budget: 500,
      servings: 2,
      pantry: [],
      allergies: [],
      prices: {},
    );
    expect(out.single['cost'], null);
    expect(out.single['fits'], false);
  });
  test('Daily totals scale snapshots and exclude removed and other dates', () {
    final n = {'calories': 200, 'protein': 10, 'carbs': 20, 'fat': 8};
    final logs = [
      {'date': '2026-10-15', 'servings': 1.5, 'nutrition': n},
      {'date': '2026-10-15', 'servings': 2, 'nutrition': n, 'deleted': true},
      {'date': '2026-10-14', 'servings': 1, 'nutrition': n},
    ];
    expect(dayTotals(logs, '2026-10-15')['calories'], 300);
    expect(dayTotals(logs, '2026-10-15')['protein'], 15);
    expect(validNutrition({'calories': 0}), false);
    expect(
      validNutrition({'calories': 0, 'protein': 0, 'carbs': 0, 'fat': 0}),
      true,
    );
  });
  test('Fitness and pricing records persist independently', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final s = KitchenStore(p);
    s.wellness = {'purpose': 'Fitness', 'height': 170, 'complete': true};
    s.targets = {'calories': 2000};
    s.foodLog = [
      {
        'id': '1',
        'date': '2026-10-15',
        'servings': 1,
        'name': 'Meal',
        'meal': 'Lunch',
        'nutrition': {'calories': 100, 'protein': 1, 'carbs': 2, 'fat': 3},
      },
    ];
    s.prices = {
      'chicken': {'500 g chicken thighs': 150},
    };
    await s.save();
    final restored = KitchenStore(p);
    expect(restored.wellness['height'], 170);
    expect(restored.targets['calories'], 2000);
    expect(restored.foodLog.single['id'], '1');
    expect(restored.prices['chicken']['500 g chicken thighs'], 150);
  });
  testWidgets('Fitness and budget screens fit a phone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final s = KitchenStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(home: TrackerScreen(s)));
    await tester.pumpAndSettle();
    expect(find.text('Daily food tracker'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Log food'));
    await tester.tap(find.text('Log food'));
    await tester.pumpAndSettle();
    expect(find.text('Add to daily log'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: BudgetPanel(s, (_) {})),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '200');
    await tester.ensureVisible(find.text('Find meals within budget'));
    await tester.tap(find.text('Find meals within budget'));
    await tester.pumpAndSettle();
    expect(find.text('Calamansi herb chicken'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
