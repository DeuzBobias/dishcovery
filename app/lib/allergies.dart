import 'package:flutter/material.dart';

String normalizeAllergy(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
List<String> allergyWarnings(
  List<String> selected,
  List<String> declared,
  List<String> ingredients,
) {
  final text = ingredients.join(' ').toLowerCase();
  return selected.where((a) {
    final n = normalizeAllergy(a);
    return n.isNotEmpty &&
        (declared.any((d) => normalizeAllergy(d) == n) ||
            RegExp(
              r'\b' + RegExp.escape(n) + r'\b',
              caseSensitive: false,
            ).hasMatch(text));
  }).toList();
}

class CustomAllergies extends StatefulWidget {
  final Set<String> values;
  final VoidCallback onChanged;
  const CustomAllergies({
    super.key,
    required this.values,
    required this.onChanged,
  });
  @override
  State<CustomAllergies> createState() => _CustomAllergiesState();
}

class _CustomAllergiesState extends State<CustomAllergies> {
  final input = TextEditingController();
  String? error;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void add() {
    final value = input.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty || value.length > 60) {
      setState(() => error = 'Enter an allergy using 1–60 characters.');
      return;
    }
    if (widget.values.any(
      (v) => normalizeAllergy(v) == normalizeAllergy(value),
    )) {
      setState(() => error = 'This allergy is already added.');
      return;
    }
    widget.values.add(value);
    input.clear();
    setState(() => error = null);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12),
      TextField(
        controller: input,
        maxLength: 60,
        decoration: InputDecoration(
          labelText: 'Add another allergy',
          hintText: 'For example, celery',
          errorText: error,
        ),
        onSubmitted: (_) => add(),
      ),
      TextButton.icon(
        onPressed: add,
        icon: const Icon(Icons.add),
        label: const Text('Add allergy'),
      ),
      Wrap(
        spacing: 6,
        children: [
          for (final value in widget.values)
            InputChip(
              label: Text(value),
              onDeleted: () {
                widget.values.remove(value);
                widget.onChanged();
                setState(() {});
              },
            ),
        ],
      ),
      const Text(
        'Matching checks declared allergens and ingredient names. Always check labels; hidden ingredients and cross-contact may not be detected.',
        style: TextStyle(fontSize: 12),
      ),
    ],
  );
}
