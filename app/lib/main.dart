import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_store.dart';
import 'cloud_account.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data.dart';
import 'ui.dart';
import 'faithful_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final local = await SqliteStore.open();
  await local.preserveLegacy(prefs);
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  SupabaseClient? client;
  if (url.isNotEmpty && key.isNotEmpty) {
    await Supabase.initialize(
      url: url,
      publishableKey: key,
      authOptions: FlutterAuthClientOptions(
        // Email links return to password login, without replacing an existing
        // account session or requiring a PKCE verifier on another phone.
        detectSessionInUri: false,
        localStorage: SecureSessionStorage(
          'dishcovery.session.${Uri.parse(url).host}',
        ),
      ),
    );
    client = Supabase.instance.client;
  }
  final cloud = CloudAccount(local, client);
  final store = KitchenStore(local, cloud: cloud);
  await cloud.bind();
  runApp(DishcoveryApp(store: store));
}

class DishcoveryApp extends StatelessWidget {
  final KitchenStore store;
  const DishcoveryApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dishcovery',
    debugShowCheckedModeBanner: false,
    theme: buildDishcoveryTheme(),
    home: FaithfulApp(store),
  );
}

class AssistantScreen extends StatefulWidget {
  final KitchenStore store;
  const AssistantScreen(this.store, {super.key});
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final messages = <({bool user, String text})>[];
  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void send(String text) {
    if (text.trim().isEmpty) return;
    final q = text.toLowerCase();
    final s = widget.store;
    String answer;
    if (q.contains('pantry') || q.contains('cook') || q.contains('suggest')) {
      final recipes = [...s.recipes]
        ..sort((a, b) => s.match(b).compareTo(s.match(a)));
      final r = recipes.first;
      answer =
          'Based on your pantry, try ${r.title}. You have ${r.ingredients.where(s.hasIngredient).length} of ${r.ingredients.length} ingredients.\n\nStill needed: ${r.ingredients.where((i) => !s.hasIngredient(i)).join(', ')}.\n\nOpen Smart pantry to see all matches.';
    } else if (q.contains('save') || q.contains('bookmark')) {
      answer =
          'Tap the bookmark on any recipe card. You’ll find it in Recipes → Bookmarked, even after restarting the app.';
    } else if (q.contains('swap') || q.contains('allerg')) {
      answer =
          'Open a recipe and tap Swap next to an ingredient to see its alternative. Add your allergies in Profile to show recipe flags. Always check ingredient labels; a substitution does not guarantee an allergen-free dish.';
    } else if (q.contains('create') || q.contains('recipe')) {
      answer =
          'Choose Create recipe, add ingredients, then arrange your instructions in the second step, and save. Your creation stays in Recipes → Own. You can edit it or add a photo at any time.';
    } else if (q.contains('tip') || q.contains('beginner')) {
      answer =
          'Before you start, read the whole recipe, measure your ingredients, and set out your tools. Taste as you go. Use Cook now for one instruction at a time and a built-in timer.';
    } else {
      answer =
          'I’m an offline guide with a small set of cooking and app tips. Try asking about your pantry, ingredient swaps, saving recipes, or getting started. Open-ended AI chat needs a connected service.';
    }
    setState(() {
      messages.add((user: true, text: text.trim()));
      messages.add((user: false, text: answer));
      input.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 850),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                controller: scroll,
                children: [
                  if (messages.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 35),
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 40,
                            backgroundColor: pale,
                            child: Icon(
                              Icons.auto_awesome,
                              color: green,
                              size: 36,
                            ),
                          ),
                          gap(22),
                          Text(
                            'A little help, a lot of possibility.',
                            style: serif(23),
                          ),
                          gap(14),
                          const Text(
                            'Your offline guide to recipes, pantry matches,\nand getting comfortable in the kitchen.',
                            style: TextStyle(color: muted),
                          ),
                          gap(30),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final q in [
                                'What can I cook?',
                                'Ingredient swaps',
                                'Beginner tips',
                                'How do I save a recipe?',
                              ])
                                ActionChip(
                                  label: Text(q),
                                  onPressed: () => send(q),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  for (final m in messages)
                    Align(
                      alignment: m.user
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 620),
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: m.user ? green : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: m.user ? green : line),
                        ),
                        child: Text(
                          m.text,
                          style: TextStyle(
                            color: m.user ? Colors.white : ink,
                            height: 1.7,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            gap(12),
            TextField(
              controller: input,
              onSubmitted: send,
              decoration: InputDecoration(
                hintText: 'Ask your kitchen companion...',
                suffixIcon: IconButton(
                  tooltip: 'Send message',
                  onPressed: () => send(input.text),
                  icon: const Icon(Icons.arrow_upward_rounded, color: green),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

ThemeData buildDishcoveryTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'DM Sans',
  splashFactory: NoSplash.splashFactory,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontFamily: 'DM Sans',
      fontSize: 19,
      color: burgundy,
      fontWeight: FontWeight.w700,
    ),
  ),
  scaffoldBackgroundColor: cream,
  colorScheme: ColorScheme.fromSeed(
    seedColor: green,
    primary: green,
    surface: cream,
  ),
  textTheme: ThemeData.light().textTheme.apply(
    fontFamily: 'DM Sans',
    bodyColor: ink,
    displayColor: ink,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: line),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
  ),
  dividerTheme: const DividerThemeData(color: line),
);
