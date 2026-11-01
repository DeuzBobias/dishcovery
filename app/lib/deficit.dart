// Estimates, not measured expenditure. Mifflin et al., AJCN 1990;
// https://doi.org/10.1093/ajcn/51.2.241
import 'nutrition.dart';

const activityFactors = <String, double>{
  'Mostly seated': 1.2,
  'Lightly active': 1.375,
  'Moderately active': 1.55,
  'Very active': 1.725,
};

Map<String, dynamic> calculateDeficitPlan({
  required double age,
  required double height,
  required double weight,
  required String coefficient,
  required String activity,
  required double reduction,
  required bool eligible,
  required String effectiveDate,
}) {
  if (!eligible ||
      !age.isFinite ||
      age < 18 ||
      age > 100 ||
      age != age.roundToDouble()) {
    throw const FormatException(
      'Automatic deficit estimates are for adults 18–100 only, outside pregnancy or breastfeeding.',
    );
  }
  if (!height.isFinite ||
      height < 100 ||
      height > 250 ||
      !weight.isFinite ||
      weight < 30 ||
      weight > 350) {
    throw const FormatException(
      'Enter height 100–250 cm and weight 30–350 kg.',
    );
  }
  if (weight / ((height / 100) * (height / 100)) < 18.5) {
    throw const FormatException(
      'A deficit estimate is not offered at this height and weight. You can continue logging meals without a deficit goal.',
    );
  }
  if (!['Male', 'Female'].contains(coefficient) ||
      !activityFactors.containsKey(activity) ||
      ![.10, .15, .20].contains(reduction)) {
    throw const FormatException(
      'Choose an equation coefficient, activity level and reduction.',
    );
  }
  final parsed = DateTime.tryParse(effectiveDate);
  if (parsed == null || dayKey(parsed) != effectiveDate) {
    throw const FormatException('Invalid plan date.');
  }
  final resting =
      10 * weight +
      6.25 * height -
      5 * age +
      (coefficient == 'Male' ? 5 : -161);
  final maintenance = (resting * activityFactors[activity]!).round();
  final target = (maintenance * (1 - reduction)).round();
  // Conservative product guardrail, not an individualized medical threshold.
  if (target < 1500) {
    throw const FormatException(
      'This estimate falls below our 1,500 kcal planning floor. Try a smaller reduction or use a target agreed with a qualified professional through Daily targets.',
    );
  }
  return {
    'effectiveDate': effectiveDate,
    'enabled': true,
    'age': age,
    'height': height,
    'weight': weight,
    'coefficient': coefficient,
    'activity': activity,
    'factor': activityFactors[activity],
    'reduction': reduction,
    'resting': resting.round(),
    'maintenance': maintenance,
    'target': target,
    'plannedDeficit': maintenance - target,
    'method': 'Mifflin-St Jeor v1',
  };
}

bool validDeficitPlan(Map<String, dynamic> p) {
  try {
    final date = DateTime.tryParse(p['effectiveDate'] as String);
    if (date == null ||
        dayKey(date) != p['effectiveDate'] ||
        p['enabled'] is! bool) {
      return false;
    }
    if (p['enabled'] == false) return true;
    final expected = calculateDeficitPlan(
      age: (p['age'] as num).toDouble(),
      height: (p['height'] as num).toDouble(),
      weight: (p['weight'] as num).toDouble(),
      coefficient: p['coefficient'],
      activity: p['activity'],
      reduction: (p['reduction'] as num).toDouble(),
      eligible: true,
      effectiveDate: p['effectiveDate'],
    );
    return [
      'maintenance',
      'target',
      'plannedDeficit',
    ].every((k) => p[k] == expected[k]);
  } catch (_) {
    return false;
  }
}

Map<String, dynamic>? deficitPlanFor(
  List<Map<String, dynamic>> plans,
  String date,
) {
  Map<String, dynamic>? selected;
  for (final p in plans) {
    if (!validDeficitPlan(p) ||
        (p['effectiveDate'] as String).compareTo(date) > 0) {
      continue;
    }
    if (selected == null ||
        (p['effectiveDate'] as String).compareTo(selected['effectiveDate']) >=
            0) {
      selected = p;
    }
  }
  return selected?['enabled'] == true ? selected : null;
}

// No entries or an unfinished log must never imply a successful calorie deficit.
double? estimatedBalance(
  Map<String, dynamic>? plan,
  List<Map<String, dynamic>> logs,
  String date,
  bool complete,
) {
  if (plan == null ||
      !complete ||
      !logs.any((l) => l['date'] == date && l['deleted'] != true)) {
    return null;
  }
  return (plan['maintenance'] as num).toDouble() -
      dayTotals(logs, date)['calories']!;
}
