import 'sync_screen.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'auth_callback.dart';
import 'android_api.dart';
import 'package:flutter/material.dart';
import 'data.dart';
import 'ui.dart';
import 'account_flow.dart';
import 'recipe_screens.dart';
import 'fitness_screens.dart';
import 'backup_screen.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'nutrition.dart';
import 'main.dart' show AssistantScreen;

const burgundy = Color(0xff602c38);
const categories = [
  'Filipino',
  'Quick & easy',
  'Plant-based',
  'Breakfast',
  'Baking',
];
const allergensList = [
  'Gluten',
  'Shellfish',
  'Nuts',
  'Eggs',
  'Soy',
  'Milk',
  'Sesame',
  'Fish',
];
TextStyle type(
  double size, {
  Color color = ink,
  FontWeight weight = FontWeight.w400,
}) => TextStyle(
  fontFamily: 'DM Sans',
  fontSize: size,
  color: color,
  fontWeight: weight,
  letterSpacing: size >= 20 ? -.6 : 0,
  height: 1.25,
);
Widget brand([double size = 32]) => Text(
  'Dishcovery',
  style: TextStyle(
    fontFamily: 'Lobster',
    fontSize: size,
    color: green,
    letterSpacing: -1,
  ),
);
Future<T?> present<T>(BuildContext c, Widget page) => Navigator.of(c).push<T>(
  PageRouteBuilder(
    pageBuilder: (_, a, b) => page,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (_, a, b, child) => FadeTransition(
      opacity: Tween<double>(
        begin: .4,
        end: 1,
      ).animate(CurvedAnimation(parent: a, curve: Curves.ease)),
      child: AnimatedBuilder(
        animation: a,
        child: child,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, 5 * (1 - Curves.ease.transform(a.value))),
          child: child,
        ),
      ),
    ),
  ),
);
PreferredSizeWidget pageHeader(
  BuildContext c,
  String title, {
  Widget? action,
}) => AppBar(
  toolbarHeight: 83,
  centerTitle: true,
  backgroundColor: Colors.white,
  surfaceTintColor: Colors.transparent,
  title: Text(
    title,
    style: type(19, color: burgundy, weight: FontWeight.w700),
  ),
  leading: IconButton(
    tooltip: 'Go back',
    onPressed: () => Navigator.maybePop(c),
    style: IconButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      side: const BorderSide(color: Color(0xffd9cbd0)),
    ),
    icon: const Icon(Icons.arrow_back, size: 20),
  ),
  actions: [?action],
);
Widget primary(String title, VoidCallback? action) => PressFeedback(
  child: SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: action,
      style: FilledButton.styleFrom(
        backgroundColor: green,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      child: Text(
        title,
        style: type(14, color: Colors.white, weight: FontWeight.w600),
      ),
    ),
  ),
);

class PressFeedback extends StatefulWidget {
  final Widget child;
  const PressFeedback({required this.child, super.key});
  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  bool pressed = false;
  @override
  Widget build(BuildContext c) => Listener(
    onPointerDown: (_) => setState(() => pressed = true),
    onPointerUp: (_) => setState(() => pressed = false),
    onPointerCancel: (_) => setState(() => pressed = false),
    child: AnimatedScale(
      scale: pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.ease,
      child: widget.child,
    ),
  );
}

Widget fieldLabel(String text, Widget field) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 9),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        text,
        style: type(12, color: burgundy, weight: FontWeight.w600),
      ),
      gap(9),
      field,
    ],
  ),
);
InputDecoration inputBox({String? hint, Widget? suffix}) => InputDecoration(
  hintText: hint,
  suffixIcon: suffix,
  filled: true,
  fillColor: const Color(0xfff8f8f8),
  contentPadding: const EdgeInsets.all(15),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: const BorderSide(color: line),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: const BorderSide(color: line),
  ),
);

class FaithfulApp extends StatefulWidget {
  final KitchenStore store;
  const FaithfulApp(this.store, {super.key});
  @override
  State<FaithfulApp> createState() => _FaithfulAppState();
}

class _FaithfulAppState extends State<FaithfulApp> with WidgetsBindingObserver {
  StreamSubscription<Uri>? links;
  int confirmationReturn = 0;
  Uri? lastLink;

  void receivedLink(Uri uri) {
    if (!mounted || uri == lastLink) return;
    final message = confirmationMessage(uri);
    if (message == null) return;
    lastLink = uri;
    // Keep an already signed-in account intact; do not import URL sessions.
    setState(() => confirmationReturn++);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) toast(context, message);
    });
  }

  Future<void> initialLink() async {
    try {
      final uri = await AppLinks().getInitialLink();
      if (uri != null) receivedLink(uri);
    } catch (_) {
      // Regular login remains available when no Android link is provided.
    }
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.cloud?.addListener(changed);
    if (widget.store.cloud?.configured ?? false) {
      links = AppLinks().uriLinkStream.listen(receivedLink, onError: (_) {});
      initialLink();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.store.cloud?.removeListener(changed);
    links?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.store.cloud?.sync();
  }

  bool get signed =>
      (widget.store.cloud == null || widget.store.cloud!.signedIn) &&
      (widget.store.prefs.getBool('session_active') ?? false);
  @override
  Widget build(BuildContext c) => signed
      ? OriginalShell(
          widget.store,
          onLogout: () async {
            await widget.store.prefs.setBool('session_active', false);
            await AndroidApi.cancelTimer();
            await widget.store.cloud?.signOut();
            if (mounted) setState(() {});
          },
        )
      : AccountFlow(
          widget.store,
          confirmationReturn: confirmationReturn,
          onReady: () async {
            await widget.store.prefs.setBool('session_active', true);
            if (mounted) setState(() {});
          },
        );
}

class OriginalShell extends StatefulWidget {
  final KitchenStore s;
  final VoidCallback onLogout;
  const OriginalShell(this.s, {required this.onLogout, super.key});
  @override
  State<OriginalShell> createState() => _OriginalShellState();
}

class _OriginalShellState extends State<OriginalShell> {
  KitchenStore get s => widget.s;
  int page = 0;
  String category = 'All';
  bool savedTab = false;
  @override
  void initState() {
    super.initState();
    s.addListener(refresh);
  }

  void refresh() {
    if (mounted) {
      setState(() {
        if (s.requestedTab != null) {
          page = s.requestedTab!;
          s.requestedTab = null;
        }
      });
    }
  }

  @override
  void dispose() {
    s.removeListener(refresh);
    super.dispose();
  }

  void open(Recipe r) => present(context, RecipeDetails(r, s));
  Future<void> search() async {
    final destination = await present<int>(context, OriginalSearch(s));
    if (mounted && destination != null) setState(() => page = destination);
  }

  void assistant() => present(
    context,
    Scaffold(
      appBar: pageHeader(context, 'Kitchen assistant'),
      body: AssistantScreen(s),
    ),
  );
  Widget heading(String name, {Widget? action}) => Padding(
    padding: const EdgeInsets.only(top: 25, bottom: 15),
    child: Row(
      children: [
        Expanded(
          child: Text(name, style: type(18, weight: FontWeight.w700)),
        ),
        ?action,
      ],
    ),
  );
  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 83,
            child: Row(
              children: [
                IconButton(
                  tooltip: page == 0 ? 'Profile settings' : 'Go back',
                  onPressed: () => setState(() => page = page == 0 ? 4 : 0),
                  icon: Icon(page == 0 ? Icons.menu : Icons.arrow_back),
                ),
                Expanded(
                  child: Center(
                    child: page == 0
                        ? brand()
                        : Text(
                            [
                              '',
                              'Recipes',
                              '',
                              'Activity',
                              'Profile Settings',
                            ][page],
                            style: type(
                              19,
                              color: burgundy,
                              weight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                IconButton(
                  tooltip: page == 0
                      ? 'Kitchen assistant'
                      : page == 1
                      ? 'Create recipe'
                      : 'Settings',
                  onPressed: page == 0
                      ? assistant
                      : page == 1
                      ? () => present(context, RecipeEditor(s))
                      : settings,
                  icon: Icon(
                    page == 0
                        ? Icons.auto_awesome_outlined
                        : page == 1
                        ? Icons.add
                        : Icons.settings_outlined,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: OriginalPageEnter(
              key: ValueKey(page),
              child: SingleChildScrollView(
                key: ValueKey(page),
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 34),
                child: page == 0
                    ? home()
                    : page == 1
                    ? recipes()
                    : page == 3
                    ? activity()
                    : profile(),
              ),
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: OriginalNavigation(
      page: page,
      onSelect: (i) {
        if (i == 2) {
          present(context, RecipeEditor(s));
        } else {
          setState(() => page = i);
        }
      },
    ),
  );

  Widget home() {
    final chosen = s.recipes
        .where((r) => category == 'All' || r.category == category)
        .take(4)
        .toList();
    final n = dayTotals(s.foodLog, dayKey(DateTime.now()));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: search,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            height: 49,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xfff5f4f6),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: muted),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Find your next favorite dish…',
                    style: type(12, color: muted),
                  ),
                ),
                const Icon(Icons.tune, color: muted, size: 20),
              ],
            ),
          ),
        ),
        gap(22),
        label('WELCOME TO YOUR KITCHEN'),
        gap(6),
        Text(
          'What’s cooking, ${s.name.split(' ').first}?',
          style: type(27, weight: FontWeight.w700),
        ),
        gap(8),
        Text(
          'A little inspiration for your everyday.',
          style: type(12, color: muted),
        ),
        gap(22),
        if (s.wellness['purpose'] == 'Fitness') ...[
          InkWell(
            onTap: () => present(context, TrackerScreen(s)),
            child: Surface(
              color: const Color(0xfffff7f8),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label("TODAY’S FOOD LOG"),
                  gap(14),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: n['calories']!.toStringAsFixed(0),
                          style: type(
                            32,
                            color: burgundy,
                            weight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: '  kcal logged',
                          style: type(12, color: burgundy),
                        ),
                      ],
                    ),
                  ),
                  gap(8),
                  Text(
                    'Protein ${n['protein']!.toStringAsFixed(0)}g · Carbs ${n['carbs']!.toStringAsFixed(0)}g · Fat ${n['fat']!.toStringAsFixed(0)}g',
                    style: type(11, color: muted),
                  ),
                  gap(12),
                  Row(
                    children: [
                      Text('Track your day', style: type(14, color: ink)),
                      const SizedBox(width: 8),
                      const Icon(Icons.add, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
          gap(20),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: Stack(
            children: [
              FoodImage('assets/chicken.jpg', height: 228),
              Container(
                height: 228,
                color: Colors.black.withValues(alpha: .42),
              ),
              Positioned(
                left: 24,
                bottom: 24,
                right: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .92),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        'TODAY’S DISHCOVERY',
                        style: type(10, color: const Color(0xff704e38)),
                      ),
                    ),
                    gap(10),
                    Text(
                      'A taste of home,\nmade by you.',
                      style: type(
                        25,
                        color: Colors.white,
                        weight: FontWeight.w700,
                      ),
                    ),
                    gap(10),
                    Text(
                      '40 min · Filipino favorite',
                      style: type(11, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 20,
                bottom: 23,
                child: IconButton.filled(
                  tooltip: 'View calamansi herb chicken',
                  onPressed: () =>
                      open(s.recipes.firstWhere((r) => r.id == 'chicken')),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: burgundy,
                  ),
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ],
          ),
        ),
        heading(
          'For you',
          action: TextButton(
            onPressed: search,
            child: const Text('Explore all'),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final cat in ['All', ...categories])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    showCheckmark: false,
                    label: Text(
                      cat,
                      style: type(
                        12,
                        color: category == cat ? Colors.white : burgundy,
                      ),
                    ),
                    selected: category == cat,
                    selectedColor: green,
                    backgroundColor: const Color(0xfff6f5f7),
                    side: BorderSide.none,
                    onSelected: (_) => setState(() => category = cat),
                  ),
                ),
            ],
          ),
        ),
        gap(12),
        OriginalGrid(chosen, s, open),
        gap(25),
        InkWell(
          onTap: search,
          child: Surface(
            color: const Color(0xfffff6f6),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.kitchen_outlined, color: green, size: 32),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good food starts with what you have.',
                        style: type(16, weight: FontWeight.w700),
                      ),
                      gap(6),
                      Text(
                        'Find a little magic in your pantry.',
                        style: type(12, color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        heading(
          'From the community',
          action: Text('Sample feed', style: type(10, color: muted)),
        ),
        for (final r in s.recipes.take(3)) feed(r),
        gap(18),
        Center(
          child: Text(
            'Made with a pinch of curiosity.',
            style: type(11, color: muted),
          ),
        ),
      ],
    );
  }

  Widget feed(Recipe r) => Container(
    margin: const EdgeInsets.only(bottom: 19),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: pale,
            child: Text(r.author[0], style: type(12, color: burgundy)),
          ),
          title: Text(r.author, style: type(12, weight: FontWeight.w700)),
          subtitle: Text(
            '${r.own ? 'Your original' : 'Sample community'} recipe · ${r.category}',
            style: type(10, color: muted),
          ),
          onTap: () => present(context, PersonPage(s, r.author)),
        ),
        InkWell(onTap: () => open(r), child: FoodImage(r.image, height: 190)),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.title, style: type(15, weight: FontWeight.w700)),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Like ${r.title}',
                    onPressed: () => s.like(r),
                    icon: Icon(
                      s.liked.contains(r.id)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: s.liked.contains(r.id) ? green : burgundy,
                      size: 19,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Save ${r.title}',
                    onPressed: () => s.bookmark(r),
                    icon: Icon(
                      s.saved.contains(r.id)
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      size: 19,
                    ),
                  ),
                  Text('${r.minutes} min', style: type(11, color: muted)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => open(r),
                    child: Text('View recipe', style: type(11, color: green)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget recipes() {
    final list = savedTab
        ? s.recipes.where((r) => s.saved.contains(r.id)).toList()
        : s.own;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => setState(() => savedTab = false),
                child: Text(
                  'Own (${s.own.length})',
                  style: type(
                    14,
                    color: savedTab ? muted : green,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: () => setState(() => savedTab = true),
                child: Text(
                  'Bookmarked',
                  style: type(
                    14,
                    color: savedTab ? green : muted,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const Divider(),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Column(
              children: [
                const Center(
                  child: Icon(Icons.menu_book_outlined, size: 54, color: green),
                ),
                gap(20),
                Text(
                  savedTab
                      ? 'Your favorites belong here.'
                      : 'Your cookbook starts here.',
                  style: type(20, weight: FontWeight.w700),
                ),
                gap(18),
                primary(
                  savedTab ? 'Discover recipes' : 'Create recipe',
                  savedTab ? search : () => present(context, RecipeEditor(s)),
                ),
              ],
            ),
          ),
        for (final r in list)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: () => open(r),
                    child: FoodImage(r.image, height: 190),
                  ),
                ),
                gap(14),
                Text(r.title, style: type(18, weight: FontWeight.w700)),
                gap(8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${r.minutes} min · ${r.level}\n${r.servings} servings',
                        style: type(12, color: muted),
                      ),
                    ),
                    if (r.own)
                      IconButton(
                        tooltip: 'Edit recipe',
                        onPressed: () =>
                            present(context, RecipeEditor(s, recipe: r)),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                  ],
                ),
                gap(14),
                primary('Cook now!', () => open(r)),
              ],
            ),
          ),
      ],
    );
  }

  Widget activity() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      gap(20),
      Text('Your kitchen activity', style: type(24, weight: FontWeight.w700)),
      gap(20),
      if (s.activity.isEmpty)
        Text(
          'A little quiet here. Save a recipe, follow a cook, or make something delicious.',
          style: type(13, color: muted),
        ),
      for (final a in s.activity)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(
            backgroundColor: pale,
            child: Icon(Icons.restaurant, color: green),
          ),
          title: Text(a, style: type(13)),
        ),
    ],
  );
  Widget profile() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      gap(25),
      Center(
        child: CircleAvatar(
          radius: 41,
          backgroundColor: pale,
          child: s.avatar.isNotEmpty
              ? ClipOval(child: FoodImage(s.avatar, height: 82))
              : Text(
                  s.name.isEmpty ? 'A' : s.name[0],
                  style: type(26, color: burgundy, weight: FontWeight.w700),
                ),
        ),
      ),
      gap(14),
      Center(
        child: Text(s.name, style: type(19, weight: FontWeight.w700)),
      ),
      gap(5),
      Center(
        child: Text(
          'Your personal cooking space',
          style: type(12, color: muted),
        ),
      ),
      gap(25),
      Surface(
        color: const Color(0xfffff6f6),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          children: [
            for (final stat in [
              (s.own.length, 'Recipes'),
              (s.saved.length, 'Bookmarked'),
              (s.cooked, 'Dishes cooked'),
            ])
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${stat.$1}',
                      style: type(20, color: burgundy, weight: FontWeight.w700),
                    ),
                    Text(stat.$2, style: type(10, color: muted)),
                  ],
                ),
              ),
          ],
        ),
      ),
      heading('Profile'),
      if (s.wellness['purpose'] == 'Fitness')
        setting(
          'Daily food tracker',
          Icons.monitor_heart_outlined,
          () => present(context, TrackerScreen(s)),
        ),
      setting('Personal Data', Icons.person_outline, personalData),
      if (s.cloud != null)
        setting(
          'Account & cloud sync',
          Icons.cloud_outlined,
          () => present(context, SyncScreen(s)),
        ),
      setting(
        'Goals & cooking preferences',
        Icons.tune,
        () => present(context, OriginalOnboarding(s)),
        trailing: '${s.wellness['purpose']}',
      ),
      Surface(
        color: const Color(0xfffff7f8),
        padding: const EdgeInsets.all(18),
        child: Text(
          'Your starting point\n${s.wellness['age'] ?? '—'} years · ${s.wellness['height'] ?? '—'} cm · ${s.wellness['weight'] ?? '—'} kg\nOptional profile details · edit in Goals & cooking preferences',
          style: type(12, color: burgundy),
        ),
      ),
      setting('Settings', Icons.settings_outlined, settings),
      setting('Notifications', Icons.notifications_none, settings),
      heading('Your kitchen'),
      setting(
        'Smart Pantry',
        Icons.kitchen_outlined,
        search,
        trailing: '${s.pantry.length} items',
      ),
      setting('Kitchen assistant', Icons.auto_awesome_outlined, assistant),
      heading('Support'),
      setting(
        'Help Center',
        Icons.help_outline,
        () => showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('A little help in your kitchen'),
            content: const Text(
              'Create and save recipes, match your pantry, compare ingredient costs in pesos, and track meals from your fitness profile. Your kitchen is saved locally and can sync with your account. The community feed currently contains sample content.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Got it'),
              ),
            ],
          ),
        ),
      ),
      setting(
        'Export my kitchen',
        Icons.file_download_outlined,
        () => present(context, BackupScreen(s)),
      ),
      setting(
        'Reset my kitchen',
        Icons.delete_outline,
        () => showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Reset my kitchen?'),
            content: const Text(
              'This clears your kitchen and syncs the reset to your account. Export a backup first to keep a copy.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(c);
                  await s.reset();
                  widget.onLogout();
                },
                child: const Text('Delete'),
              ),
            ],
          ),
        ),
      ),
      gap(30),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: widget.onLogout,
          child: const Text('Sign out'),
        ),
      ),
      gap(18),
      Center(
        child: Text(
          'Dishcovery\nYour everyday kitchen companion.',
          textAlign: TextAlign.center,
          style: type(11, color: muted),
        ),
      ),
    ],
  );
  Widget setting(
    String title,
    IconData icon,
    VoidCallback action, {
    String? trailing,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: burgundy, size: 22),
    title: Text(title, style: type(13)),
    trailing: trailing == null
        ? const Icon(Icons.chevron_right, size: 18)
        : Text(trailing, style: type(11, color: muted)),
    onTap: action,
  );
  Future<void> personalData() async {
    final name = TextEditingController(text: s.name),
        bio = TextEditingController(text: s.bio);
    var avatar = s.avatar;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: const Text('Personal data'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                fieldLabel(
                  'Name',
                  TextField(controller: name, decoration: inputBox()),
                ),
                fieldLabel(
                  'Bio',
                  TextField(
                    controller: bio,
                    maxLines: 3,
                    decoration: inputBox(),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                        withData: true,
                      );
                      if (result == null) return;
                      final f = result.files.single;
                      if (f.bytes == null || f.size > 3 * 1024 * 1024) {
                        if (c.mounted) {
                          toast(c, 'Choose a photo smaller than 3 MB.');
                        }
                        return;
                      }
                      update(
                        () => avatar =
                            'data:image/${f.extension};base64,${base64Encode(f.bytes!)}',
                      );
                    } catch (_) {
                      if (c.mounted) toast(c, 'Could not open photo.');
                    }
                  },
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Profile photo'),
                ),
                if (avatar.isNotEmpty)
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: ClipOval(child: FoodImage(avatar)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) {
                  toast(c, 'Enter your name.');
                  return;
                }
                s.name = name.text.trim();
                s.bio = bio.text.trim();
                s.avatar = avatar;
                await s.save();
                if (c.mounted) Navigator.pop(c);
              },
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }

  void settings() => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, update) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Settings', style: type(20, weight: FontWeight.w700)),
            SwitchListTile(
              title: const Text('Kitchen activity notifications'),
              value: s.notifications,
              onChanged: (v) async {
                if (v) {
                  try {
                    await AndroidApi.requestNotifications();
                  } catch (_) {
                    if (c.mounted) {
                      toast(c, 'Enable notifications in Android settings.');
                    }
                  }
                }
                s.notifications = v;
                s.save();
                update(() {});
              },
            ),
            ListTile(
              title: const Text('Send test notification'),
              onTap: () async {
                if (!s.notifications) {
                  toast(c, 'Turn on kitchen notifications first.');
                  return;
                }
                try {
                  await AndroidApi.notification(
                    'Notifications are ready for your kitchen.',
                  );
                  if (c.mounted) toast(c, 'Test notification sent');
                } catch (_) {
                  if (c.mounted) {
                    toast(
                      c,
                      'Allow Dishcovery notifications in Android settings, then try again.',
                    );
                  }
                }
              },
            ),
            ListTile(
              title: const Text('Backup & restore'),
              onTap: () {
                Navigator.pop(c);
                present(context, BackupScreen(s));
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class OriginalGrid extends StatelessWidget {
  final List<Recipe> recipes;
  final KitchenStore s;
  final void Function(Recipe) open;
  const OriginalGrid(this.recipes, this.s, this.open, {super.key});
  @override
  Widget build(BuildContext c) => LayoutBuilder(
    builder: (c, box) => Wrap(
      spacing: 15,
      runSpacing: 15,
      children: [
        for (final r in recipes)
          SizedBox(
            width: (box.maxWidth - 15) / 2,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                border: Border.all(color: line),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Stack(
                children: [
                  InkWell(
                    onTap: () => open(r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FoodImage(r.image, height: 136),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.title,
                                style: type(13, weight: FontWeight.w700),
                              ),
                              gap(7),
                              Text(
                                '${r.minutes} min · ${r.level}',
                                style: type(10, color: muted),
                              ),
                              if (r.nutrition != null) ...[
                                gap(7),
                                Text(
                                  'Est. ${r.nutrition!['calories']} kcal · ${r.nutrition!['protein']}g protein / serving',
                                  style: type(
                                    10,
                                    color: const Color(0xff9c4257),
                                  ),
                                ),
                              ],
                              if (s.warnings(r).isNotEmpty)
                                Text(
                                  'Contains ${s.warnings(r).join(', ')}',
                                  style: type(
                                    10,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: SizedBox(
                      width: 31,
                      height: 31,
                      child: IconButton(
                        tooltip: 'Save ${r.title}',
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                        ),
                        onPressed: () => s.bookmark(r),
                        icon: Icon(
                          s.saved.contains(r.id)
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          size: 19,
                          color: burgundy,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class OriginalSearch extends StatefulWidget {
  final KitchenStore s;
  const OriginalSearch(this.s, {super.key});
  @override
  State<OriginalSearch> createState() => _OriginalSearchState();
}

class _OriginalSearchState extends State<OriginalSearch> {
  String q = '', tab = 'Smart Pantry';
  KitchenStore get s => widget.s;
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
    super.dispose();
  }

  void open(Recipe r) => present(context, RecipeDetails(r, s));
  @override
  Widget build(BuildContext c) {
    final list = s.search(q, 'All recipes');
    list.sort((a, b) => s.match(b).compareTo(s.match(a)));
    return Scaffold(
      bottomNavigationBar: OriginalNavigation(
        page: -1,
        onSelect: (i) {
          if (i == 2) {
            present(context, RecipeEditor(s));
          } else {
            Navigator.pop(context, i);
          }
        },
      ),
      appBar: pageHeader(
        c,
        'Discover',
        action: IconButton(
          tooltip: 'Ask the assistant',
          onPressed: () => present(
            c,
            Scaffold(
              appBar: pageHeader(c, 'Kitchen assistant'),
              body: AssistantScreen(s),
            ),
          ),
          icon: const Icon(Icons.auto_awesome_outlined),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: inputBox(
                hint: 'Search recipes, ingredients or people',
                suffix: const Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => q = v),
            ),
            gap(25),
            Text('Category', style: type(18, weight: FontWeight.w700)),
            gap(15),
            Wrap(
              spacing: 8,
              children: [
                for (final name in ['Smart Pantry', 'Food', 'People'])
                  ChoiceChip(
                    label: Text(name),
                    selected: tab == name,
                    onSelected: (_) => setState(() => tab = name),
                  ),
              ],
            ),
            gap(20),
            if (tab == 'Smart Pantry') ...[
              Wrap(
                spacing: 8,
                children: [
                  for (final p in s.pantry)
                    InputChip(
                      label: Text(p),
                      onDeleted: () {
                        s.pantry.remove(p);
                        s.save();
                      },
                    ),
                  ActionChip(
                    label: const Text('Add ingredient'),
                    avatar: const Icon(Icons.add, size: 18),
                    onPressed: add,
                  ),
                ],
              ),
              BudgetPanel(s, open),
              gap(20),
              Text(
                'What you can make',
                style: type(20, weight: FontWeight.w700),
              ),
              gap(8),
              Text(
                '${s.pantry.length} ingredients',
                style: type(12, color: muted),
              ),
              for (final r in list)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: InkWell(
                    onTap: () => open(r),
                    child: Surface(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.title,
                            style: type(15, weight: FontWeight.w700),
                          ),
                          gap(8),
                          Text(
                            '${r.ingredients.where(s.hasIngredient).length} of ${r.ingredients.length} ingredients in your pantry',
                            style: type(12, color: muted),
                          ),
                          gap(8),
                          Text(
                            r.ingredients.every(s.hasIngredient)
                                ? 'You have all listed ingredients'
                                : 'Still need: ${r.ingredients.where((i) => !s.hasIngredient(i)).join(', ')}',
                            style: type(11, color: muted),
                          ),
                          gap(12),
                          LinearProgressIndicator(
                            value: s.match(r),
                            color: green,
                            backgroundColor: pale,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Text(
                'Pantry matches compare names. Check that you have enough of each ingredient.',
                style: type(11, color: muted),
              ),
            ] else if (tab == 'Food')
              OriginalGrid(list, s, open)
            else ...[
              for (final name
                  in s.recipes
                      .map((r) => r.author)
                      .toSet()
                      .where((n) => n.toLowerCase().contains(q.toLowerCase())))
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: pale,
                    child: Text(name[0]),
                  ),
                  title: Text(name),
                  subtitle: const Text('Sample community cook'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => present(c, PersonPage(s, name)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> add() async {
    final input = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add ingredient'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: inputBox(hint: 'e.g. Onion'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, input.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name != null &&
        name.isNotEmpty &&
        !s.pantry.any((p) => p.toLowerCase() == name.toLowerCase())) {
      s.pantry.add(name);
      await s.save();
    }
  }
}

class PersonPage extends StatelessWidget {
  final KitchenStore s;
  final String name;
  const PersonPage(this.s, this.name, {super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: pageHeader(c, name),
    body: ListenableBuilder(
      listenable: s,
      builder: (c, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            CircleAvatar(
              radius: 41,
              backgroundColor: pale,
              child: Text(name[0], style: type(26, color: burgundy)),
            ),
            gap(14),
            Text(name, style: type(24, weight: FontWeight.w700)),
            gap(10),
            Text('Sample community cook', style: type(12, color: muted)),
            gap(20),
            primary(s.following.contains(name) ? 'Following' : 'Follow', () {
              s.following.contains(name)
                  ? s.following.remove(name)
                  : s.following.add(name);
              s.log('You updated your follow preference for $name.');
              s.save();
            }),
            gap(25),
            OriginalGrid(
              s.recipes.where((r) => r.author == name).toList(),
              s,
              (r) => present(c, RecipeDetails(r, s)),
            ),
          ],
        ),
      ),
    ),
  );
}

class OriginalNavigation extends StatelessWidget {
  final int page;
  final ValueChanged<int> onSelect;
  const OriginalNavigation({
    required this.page,
    required this.onSelect,
    super.key,
  });
  @override
  Widget build(BuildContext c) => SafeArea(
    top: false,
    child: Container(
      height: 71,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: line)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < 5; i++)
            Expanded(
              child: Semantics(
                selected: page == i,
                button: true,
                child: InkWell(
                  onTap: () => onSelect(i),
                  child: SizedBox(
                    height: 71,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        if (i == 2)
                          Positioned(
                            top: -17,
                            child: Container(
                              width: 63,
                              height: 63,
                              decoration: BoxDecoration(
                                color: green,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 5,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: green.withValues(alpha: .25),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.restaurant,
                                color: Colors.white,
                                size: 27,
                              ),
                            ),
                          )
                        else
                          Positioned(
                            top: 12,
                            child: Icon(
                              [
                                Icons.home,
                                Icons.bookmark_border,
                                Icons.restaurant,
                                Icons.notifications_none,
                                Icons.person_outline,
                              ][i],
                              color: page == i ? green : muted,
                              size: 24,
                            ),
                          ),
                        Positioned(
                          bottom: 10,
                          child: Text(
                            [
                              'Home',
                              'Recipes',
                              'Create',
                              'Activity',
                              'Profile',
                            ][i],
                            style: type(
                              10,
                              color: page == i ? green : muted,
                              weight: page == i
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// The original CSS enter keyframe: 220ms ease, opacity .4 to 1, translateY 5px to 0.
class OriginalPageEnter extends StatefulWidget {
  final Widget child;
  const OriginalPageEnter({required this.child, super.key});
  @override
  State<OriginalPageEnter> createState() => _OriginalPageEnterState();
}

class _OriginalPageEnterState extends State<OriginalPageEnter>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: widget.child,
    builder: (_, child) {
      final progress = Curves.ease.transform(controller.value);
      return Opacity(
        opacity: .4 + .6 * progress,
        child: Transform.translate(
          offset: Offset(0, 5 * (1 - progress)),
          child: child,
        ),
      );
    },
  );
}
