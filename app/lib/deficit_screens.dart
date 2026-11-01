import 'package:flutter/material.dart';
import 'data.dart';
import 'deficit.dart';
import 'nutrition.dart';
import 'ui.dart';
import 'faithful_app.dart';
import 'android_api.dart';

class DeficitSetup extends StatefulWidget {
  final KitchenStore s;
  const DeficitSetup(this.s, {super.key});
  @override
  State<DeficitSetup> createState() => _DeficitSetupState();
}

class _DeficitSetupState extends State<DeficitSetup> {
  final form = GlobalKey<FormState>();
  late final previous = deficitPlanFor(
    widget.s.deficitPlans,
    dayKey(DateTime.now()),
  );
  late final age = TextEditingController(
    text: '${widget.s.wellness['age'] ?? previous?['age'] ?? ''}',
  );
  late final height = TextEditingController(
    text: '${widget.s.wellness['height'] ?? previous?['height'] ?? ''}',
  );
  late final weight = TextEditingController(
    text: '${widget.s.wellness['weight'] ?? previous?['weight'] ?? ''}',
  );
  late String? coefficient = previous?['coefficient'];
  late String activity = previous?['activity'] ?? 'Mostly seated';
  late double reduction = (previous?['reduction'] as num?)?.toDouble() ?? .10;
  bool eligible = false;
  String? error;
  Map<String, dynamic>? preview;
  @override
  void dispose() {
    age.dispose();
    height.dispose();
    weight.dispose();
    super.dispose();
  }

  void invalidate() {
    setState(() {
      preview = null;
      error = null;
    });
  }

  void calculate() {
    if (!form.currentState!.validate()) return;
    try {
      final plan = calculateDeficitPlan(
        age: double.parse(age.text),
        height: double.parse(height.text),
        weight: double.parse(weight.text),
        coefficient: coefficient ?? '',
        activity: activity,
        reduction: reduction,
        eligible: eligible,
        effectiveDate: dayKey(DateTime.now()),
      );
      setState(() {
        preview = plan;
        error = null;
      });
    } on FormatException catch (e) {
      setState(() {
        error = e.message;
        preview = null;
      });
    }
  }

  Future<void> save() async {
    if (preview == null) return;
    final date = dayKey(DateTime.now());
    final plan = {...preview!, 'effectiveDate': date};
    widget.s.deficitPlans.removeWhere((p) => p['effectiveDate'] == date);
    widget.s.deficitPlans.add(plan);
    widget.s.wellness = {
      ...widget.s.wellness,
      'age': plan['age'],
      'height': plan['height'],
      'weight': plan['weight'],
    };
    await widget.s.save();
    if (mounted) {
      if (widget.s.storageError == null) {
        Navigator.pop(context);
      } else {
        setState(() => error = widget.s.storageError);
      }
    }
  }

  Widget number(String title, TextEditingController c) => fieldLabel(
    title,
    TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: inputBox(),
      onChanged: (_) => invalidate(),
      validator: (v) {
        final n = double.tryParse(v ?? '');
        return n == null || !n.isFinite ? 'Enter a valid number' : null;
      },
    ),
  );
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: pageHeader(c, 'Personal calorie plan'),
    body: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label('FITNESS · PERSONALIZED ESTIMATE'),
            gap(12),
            Text(
              'A little guidance for your day.',
              style: type(27, weight: FontWeight.w700),
            ),
            gap(12),
            Text(
              'Estimate daily maintenance calories, then choose a modest reduction. Your measurements stay on this device.',
              style: type(13, color: muted),
            ),
            gap(20),
            number('Age (years)', age),
            number('Height (cm)', height),
            number('Weight (kg)', weight),
            fieldLabel(
              'Sex coefficient used by the equation',
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: coefficient,
                decoration: inputBox(hint: 'Choose a coefficient'),
                items: ['Male', 'Female']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) {
                  coefficient = v;
                  invalidate();
                },
                validator: (v) => v == null ? 'Choose a coefficient' : null,
              ),
            ),
            Text(
              'The original equation has two sex-based coefficients. This is not a gender-identity setting. If neither suits your needs, use a clinician-agreed target in Daily targets instead.',
              style: type(11, color: muted),
            ),
            fieldLabel(
              'Usual activity',
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: activity,
                decoration: inputBox(),
                items: activityFactors.keys
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) {
                  activity = v!;
                  invalidate();
                },
              ),
            ),
            Text(
              'Mostly seated: little exercise. Light: 1–3 exercise days/week. Moderate: 3–5. Very active: 6–7. These are rough multipliers; work and daily movement matter too.',
              style: type(11, color: muted),
            ),
            fieldLabel(
              'Planned reduction from maintenance',
              DropdownButtonFormField<double>(
                isExpanded: true,
                initialValue: reduction,
                decoration: inputBox(),
                items: [.10, .15, .20]
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text('${(v * 100).round()}%'),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  reduction = v!;
                  invalidate();
                },
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: eligible,
              onChanged: (v) {
                eligible = v == true;
                invalidate();
              },
              title: Text(
                'I am 18 or older and not pregnant or breastfeeding.',
                style: type(12),
              ),
            ),
            Text(
              'Estimates are not medical advice. If weight loss is not appropriate for you, or you have a medical condition or a history of disordered eating, use professional guidance. No weight-loss deadline or exercise calorie bonus is calculated.',
              style: type(11, color: muted),
            ),
            gap(18),
            primary('Calculate estimate', calculate),
            if (error != null) ...[
              gap(14),
              Text(error!, style: type(12, color: const Color(0xffa12d44))),
            ],
            if (preview != null) ...[
              gap(20),
              Surface(
                color: const Color(0xfffff7f8),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your daily estimate',
                      style: type(18, weight: FontWeight.w700),
                    ),
                    gap(12),
                    Text(
                      'Maintenance: ${preview!['maintenance']} kcal\nPlanned deficit: ${preview!['plannedDeficit']} kcal\nFood target: ${preview!['target']} kcal',
                      style: type(14).copyWith(height: 1.8),
                    ),
                    gap(12),
                    Text(
                      'Starts today. Earlier days keep their saved plan. This replaces the calorie target while active; your macro targets stay unchanged.',
                      style: type(11, color: muted),
                    ),
                    gap(18),
                    primary('Use this plan', save),
                  ],
                ),
              ),
            ],
            gap(20),
            Text(
              'Method: Mifflin–St Jeor resting-energy estimate × activity factor. Target = maintenance × (1 − reduction). The 1,500 kcal minimum is an app guardrail, not a personalized medical recommendation.',
              style: type(11, color: muted),
            ),
            Wrap(
              children: [
                TextButton(
                  onPressed: () => AndroidApi.openUrl(
                    'https://doi.org/10.1093/ajcn/51.2.241',
                  ),
                  child: const Text('Equation source'),
                ),
                TextButton(
                  onPressed: () =>
                      AndroidApi.openUrl('https://www.niddk.nih.gov/bwp'),
                  child: const Text('About calorie planning'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class DeficitCard extends StatelessWidget {
  final KitchenStore s;
  final DateTime date;
  final DateTime? today;
  final VoidCallback onChanged;
  const DeficitCard(
    this.s,
    this.date, {
    required this.onChanged,
    this.today,
    super.key,
  });
  @override
  Widget build(BuildContext c) {
    if (s.wellness['purpose'] != 'Fitness') return const SizedBox.shrink();
    final key = dayKey(date), today = dayKey(this.today ?? DateTime.now());
    final plan = deficitPlanFor(s.deficitPlans, key);
    final total = dayTotals(s.foodLog, key)['calories']!;
    final complete = s.completedFoodDays[key] == true;
    final logged = s.foodLog.any(
      (l) => l['date'] == key && l['deleted'] != true,
    );
    final balance = estimatedBalance(plan, s.foodLog, key, complete);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Surface(
        color: const Color(0xfffff7f8),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your calorie deficit tracker',
              style: type(18, weight: FontWeight.w700),
            ),
            gap(12),
            if (plan == null) ...[
              Text(
                key == today
                    ? 'Create an optional plan using your age, height, weight and activity.'
                    : 'No personalized plan was active for this date.',
                style: type(12, color: muted),
              ),
              gap(14),
              primary('Set up calorie plan', () async {
                await present(c, DeficitSetup(s));
                onChanged();
              }),
            ] else ...[
              Text(
                'Estimated maintenance  ${plan['maintenance']} kcal',
                style: type(13),
              ),
              gap(8),
              Text(
                'Planned deficit  ${plan['plannedDeficit']} kcal',
                style: type(13),
              ),
              gap(8),
              Text(
                'Daily food target  ${plan['target']} kcal',
                style: type(15, weight: FontWeight.w700),
              ),
              gap(14),
              Text(
                !logged
                    ? 'No food logged yet.'
                    : total <= plan['target']
                    ? '${(plan['target'] - total).round()} kcal left to your food target'
                    : '${(total - plan['target']).round()} kcal above your food target',
                style: type(13, color: burgundy),
              ),
              gap(10),
              Text(
                balance == null
                    ? 'Complete your food log before viewing the estimated daily balance.'
                    : balance >= 0
                    ? 'Estimated logged-day deficit: ${balance.round()} kcal'
                    : 'Estimated logged-day surplus: ${(-balance).round()} kcal',
                style: type(12),
              ),
              if (balance != null && balance > plan['plannedDeficit']) ...[
                gap(8),
                Text(
                  'A larger deficit is not a better score. Check for missing meals and aim for your planned intake.',
                  style: type(11, color: muted),
                ),
              ],
              gap(8),
              Text(
                'This compares a full-day expenditure estimate with logged food. It does not measure calories burned or confirm weight loss.',
                style: type(11, color: muted),
              ),
              if (logged && key.compareTo(today) <= 0)
                TextButton.icon(
                  onPressed: () async {
                    s.completedFoodDays[key] = !complete;
                    await s.save();
                    onChanged();
                  },
                  icon: Icon(
                    complete ? Icons.check_circle : Icons.check_circle_outline,
                  ),
                  label: Text(
                    complete ? 'Reopen food log' : 'Mark day complete',
                  ),
                ),
              if (key == today)
                Wrap(
                  children: [
                    TextButton(
                      onPressed: () async {
                        await present(c, DeficitSetup(s));
                        onChanged();
                      },
                      child: const Text('Edit plan'),
                    ),
                    TextButton(
                      onPressed: () async {
                        s.deficitPlans.removeWhere(
                          (p) => p['effectiveDate'] == today,
                        );
                        s.deficitPlans.add({
                          'effectiveDate': today,
                          'enabled': false,
                        });
                        await s.save();
                        onChanged();
                      },
                      child: const Text('Pause plan'),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
