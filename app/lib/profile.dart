import 'package:flutter/material.dart';

import 'data.dart';
import 'ui.dart';

class ProfileSetup extends StatefulWidget {
  final KitchenStore store;
  const ProfileSetup(this.store, {super.key});
  @override
  State<ProfileSetup> createState() => _ProfileSetupState();
}

class _ProfileSetupState extends State<ProfileSetup> {
  late final name = TextEditingController(
    text: widget.store.name == 'Home cook' ? '' : widget.store.name,
  );
  late final bio = TextEditingController(text: widget.store.bio);
  late String skill = widget.store.skill;
  late Set<String> cuisines = widget.store.cuisines.toSet(),
      allergies = widget.store.allergies.toSet();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    name.dispose();
    bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Make yourself at home'),
      backgroundColor: cream,
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label('YOUR KITCHEN, YOUR WAY'),
                gap(14),
                Text('Good food starts with you.', style: serif(40)),
                gap(12),
                const Text(
                  'A few little details help make Dishcovery feel like home.',
                  style: TextStyle(color: muted),
                ),
                gap(30),
                Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What should we call you?', style: serif(24)),
                      gap(18),
                      TextFormField(
                        controller: name,
                        maxLength: 40,
                        decoration: const InputDecoration(
                          labelText: 'Your name',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter your name'
                            : null,
                      ),
                      gap(10),
                      TextFormField(
                        controller: bio,
                        maxLength: 160,
                        decoration: const InputDecoration(
                          labelText: 'A little about your kitchen',
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                gap(20),
                Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Find your cooking rhythm', style: serif(24)),
                      gap(8),
                      const Text(
                        'We’ll mark recipe difficulty so you can find your pace.',
                        style: TextStyle(color: muted),
                      ),
                      gap(18),
                      for (final entry in [
                        (
                          'Beginner',
                          'Starting simple, one delicious step at a time.',
                          Icons.spa_outlined,
                        ),
                        (
                          'Intermediate',
                          'Comfortable cooking, curious to try more.',
                          Icons.restaurant_outlined,
                        ),
                        (
                          'Professional',
                          'Ready for a little culinary adventure.',
                          Icons.workspace_premium_outlined,
                        ),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: skill == entry.$1 ? green : line,
                              ),
                            ),
                            tileColor: skill == entry.$1 ? pale : Colors.white,
                            leading: Icon(entry.$3, color: green),
                            title: Text(entry.$1),
                            subtitle: Text(
                              entry.$2,
                              style: const TextStyle(
                                fontSize: 12,
                                color: muted,
                              ),
                            ),
                            trailing: skill == entry.$1
                                ? const Icon(Icons.check_circle, color: green)
                                : const Icon(
                                    Icons.circle_outlined,
                                    color: line,
                                  ),
                            onTap: () => setState(() => skill = entry.$1),
                          ),
                        ),
                    ],
                  ),
                ),
                gap(20),
                Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What do you love to eat?', style: serif(24)),
                      gap(8),
                      const Text(
                        'Choose your favorites, or leave them open to everything.',
                        style: TextStyle(color: muted),
                      ),
                      gap(18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final c in [
                            'Filipino',
                            'Quick & easy',
                            'Plant-based',
                            'Breakfast',
                            'Baking',
                          ])
                            FilterChip(
                              label: Text(c),
                              selected: cuisines.contains(c),
                              onSelected: (v) => setState(
                                () => v ? cuisines.add(c) : cuisines.remove(c),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                gap(20),
                Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Anything to look out for?', style: serif(24)),
                      gap(8),
                      const Text(
                        'Flag recipes with these declared allergens. Always check labels and preparation conditions.',
                        style: TextStyle(color: muted, height: 1.6),
                      ),
                      gap(18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final a in [
                            'Gluten',
                            'Shellfish',
                            'Nuts',
                            'Eggs',
                            'Soy',
                            'Milk',
                            'Sesame',
                            'Fish',
                          ])
                            FilterChip(
                              label: Text(a),
                              selected: allergies.contains(a),
                              onSelected: (v) => setState(
                                () =>
                                    v ? allergies.add(a) : allergies.remove(a),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                gap(24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      if (!form.currentState!.validate()) return;
                      final s = widget.store;
                      s.name = name.text.trim();
                      s.bio = bio.text.trim();
                      s.skill = skill;
                      s.cuisines = cuisines.toList();
                      s.allergies = allergies.toList();
                      s.onboarded = true;
                      await s.save();
                      if (context.mounted) {
                        Navigator.pop(context);
                        toast(
                          context,
                          'Your kitchen is now a little more you.',
                        );
                      }
                    },
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    iconAlignment: IconAlignment.end,
                    label: const Text('Save my preferences'),
                  ),
                ),
                gap(30),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
