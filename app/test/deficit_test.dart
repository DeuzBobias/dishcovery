import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dishcovery/data.dart';
import 'package:dishcovery/deficit.dart';
import 'package:dishcovery/deficit_screens.dart';
import 'package:dishcovery/main.dart';
import 'package:dishcovery/fitness_screens.dart';
import 'widget_test.dart' show phone, imagesReady, click;

Map<String, dynamic> makePlan(String date, {double reduction = .10}) =>
    calculateDeficitPlan(
      age: 30,
      height: 180,
      weight: 80,
      coefficient: 'Male',
      activity: 'Mostly seated',
      reduction: reduction,
      eligible: true,
      effectiveDate: date,
    );
Map<String, dynamic> meal(String date, {bool deleted = false}) => {
  'id': 'meal',
  'name': 'Lunch',
  'date': date,
  'meal': 'Lunch',
  'servings': 1.5,
  'nutrition': {'calories': 500, 'protein': 20, 'carbs': 50, 'fat': 20},
  'deleted': deleted,
};
Future<KitchenStore> store() async {
  SharedPreferences.setMockInitialValues({'session_active': true});
  final s = KitchenStore(await SharedPreferences.getInstance());
  s.onboarded = true;
  s.name = 'Alex';
  s.wellness = {
    'purpose': 'Fitness',
    'complete': true,
    'age': 30,
    'height': 180,
    'weight': 80,
  };
  return s;
}

void main() {
  setUpAll(() async {
    for (final pair in {
      'DM Sans': 'assets/DMSans.ttf',
      'Lobster': 'assets/Lobster.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(pair.key)..addFont(rootBundle.load(pair.value));
      await loader.load();
    }
  });

  test('Mifflin calculation and modest reduction use documented units', () {
    final p = makePlan('2026-10-30');
    expect(p['resting'], 1780);
    expect(p['maintenance'], 2136);
    expect(p['target'], 1922);
    expect(p['plannedDeficit'], 214);
    expect(validDeficitPlan(p), isTrue);
    expect(validDeficitPlan({...p, 'target': 700}), isFalse);
  });
  test(
    'Personal plan rejects invalid input, minors, underweight and low targets',
    () {
      Map<String, dynamic> calculate({
        double age = 30,
        double height = 180,
        double weight = 80,
        bool eligible = true,
        double reduction = .10,
        String coefficient = 'Male',
      }) => calculateDeficitPlan(
        age: age,
        height: height,
        weight: weight,
        coefficient: coefficient,
        activity: 'Mostly seated',
        reduction: reduction,
        eligible: eligible,
        effectiveDate: '2026-10-30',
      );
      for (final fn in [
        () => calculate(age: 17),
        () => calculate(height: double.nan),
        () => calculate(weight: 45),
        () => calculate(eligible: false),
        () => calculate(reduction: .5),
        () => calculate(coefficient: ''),
        () =>
            calculate(age: 60, height: 155, weight: 55, coefficient: 'Female'),
      ]) {
        expect(fn, throwsFormatException);
      }
    },
  );
  test('Plan revisions and pauses preserve earlier dates', () {
    final plans = [
      makePlan('2026-10-20'),
      makePlan('2026-10-25', reduction: .15),
      {'effectiveDate': '2026-10-30', 'enabled': false},
    ];
    expect(deficitPlanFor(plans, '2026-10-19'), isNull);
    expect(deficitPlanFor(plans, '2026-10-22')!['target'], 1922);
    expect(deficitPlanFor(plans, '2026-10-26')!['target'], 1816);
    expect(deficitPlanFor(plans, '2026-10-30'), isNull);
  });
  test('Empty, removed or unfinished logs never report a deficit', () {
    final p = makePlan('2026-10-30');
    expect(estimatedBalance(p, [], '2026-10-30', true), isNull);
    expect(
      estimatedBalance(p, [meal('2026-10-30')], '2026-10-30', false),
      isNull,
    );
    expect(
      estimatedBalance(
        p,
        [meal('2026-10-30', deleted: true)],
        '2026-10-30',
        true,
      ),
      isNull,
    );
    expect(estimatedBalance(p, [meal('2026-10-30')], '2026-10-30', true), 1386);
    final m = meal('2026-10-30')..['servings'] = 5;
    expect(estimatedBalance(p, [m], '2026-10-30', true), -364);
  });
  test('Plans, completed days and macros survive reload and reset', () async {
    final s = await store();
    s.deficitPlans = [makePlan('2026-10-30')];
    s.completedFoodDays = {'2026-10-30': true};
    s.targets = {'protein': 90, 'calories': 2200};
    await s.save();
    final reloaded = KitchenStore(s.prefs);
    expect(reloaded.deficitPlans.single['target'], 1922);
    expect(reloaded.completedFoodDays['2026-10-30'], isTrue);
    expect(reloaded.targets['protein'], 90);
    await reloaded.reset();
    expect(reloaded.deficitPlans, isEmpty);
    expect(reloaded.completedFoodDays, isEmpty);
  });
  testWidgets(
    'Fitness plan setup calculates and saves without overwriting macros',
    (t) async {
      phone(t);
      final s = await store();
      s.targets = {'protein': 100, 'calories': 2200};
      await t.pumpWidget(DishcoveryApp(store: s));
      await t.pumpAndSettle();
      await click(t, 'Track your day');
      await click(t, 'Set up calorie plan');
      expect(find.byType(DeficitSetup), findsOneWidget);
      await t.ensureVisible(find.text('Choose a coefficient'));
      await t.tap(find.byType(DropdownButtonFormField<String>).first);
      await t.pumpAndSettle();
      await t.tap(find.text('Male').last);
      await t.pumpAndSettle();
      await t.ensureVisible(find.byType(CheckboxListTile));
      await t.tap(find.byType(CheckboxListTile));
      await t.pumpAndSettle();
      await click(t, 'Calculate estimate');
      expect(find.textContaining('Maintenance: 2136 kcal'), findsOneWidget);
      await click(t, 'Use this plan');
      expect(s.deficitPlans.single['target'], 1922);
      expect(s.targets['protein'], 100);
      expect(s.targets['calories'], 2200);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Tracker only offers deficit feature to Fitness and reopens edited days',
    (t) async {
      phone(t);
      final s = await store();
      const today = '2026-10-30';
      s.deficitPlans = [makePlan(today)];
      s.foodLog = [meal(today)];
      s.completedFoodDays[today] = true;
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: TrackerScreen(
            s,
            initialDate: DateTime(2026, 10, 30),
            now: () => DateTime(2026, 10, 30),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.text('Estimated logged-day deficit: 1386 kcal'),
        findsOneWidget,
      );
      await t.scrollUntilVisible(
        find.byTooltip('Remove'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(find.byTooltip('Remove'));
      await t.pumpAndSettle();
      expect(s.completedFoodDays[today], isFalse);
      await t.scrollUntilVisible(
        find.text('No food logged yet.'),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('No food logged yet.'), findsOneWidget);
      s.wellness = {'purpose': 'Recipes'};
      await s.save();
      await t.pumpAndSettle();
      expect(find.text('Your calorie deficit tracker'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Restored tracker and fitness plan render at phone width', (
    t,
  ) async {
    phone(t);
    final s = await store();
    s.wellness['purpose'] = 'Recipes';
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildDishcoveryTheme(),
        home: TrackerScreen(
          s,
          initialDate: DateTime(2026, 10, 30),
          now: () => DateTime(2026, 10, 30),
        ),
      ),
    );
    await t.pumpAndSettle();
    await imagesReady(t);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/tracker-restored-oct30.png'),
    );
    s.wellness['purpose'] = 'Fitness';
    s.deficitPlans = [makePlan('2026-10-30')];
    await s.save();
    await t.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/fitness-deficit-oct30.png'),
    );
    expect(t.takeException(), isNull);
  });
}
