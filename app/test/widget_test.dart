import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:dishcovery/cloud_account.dart';
import 'package:dishcovery/local_store.dart';
import 'package:dishcovery/main.dart';
import 'package:dishcovery/data.dart';
import 'package:dishcovery/faithful_app.dart';
import 'package:dishcovery/account_flow.dart';
import 'package:dishcovery/recipe_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PendingSignupAuth extends Fake implements sb.GoTrueClient {
  @override
  Future<sb.AuthResponse> signUp({
    String? email,
    String? phone,
    required String password,
    String? emailRedirectTo,
    Map<String, dynamic>? data,
    String? captchaToken,
    sb.OtpChannel channel = sb.OtpChannel.sms,
  }) async {
    expect(emailRedirectTo, 'com.dishcovery.dishcovery://login-callback/');
    return sb.AuthResponse();
  }
}

class PendingSignupClient extends Fake implements sb.SupabaseClient {
  @override
  final auth = PendingSignupAuth();
}

class GuestLocalStore extends Fake implements SqliteStore {
  @override
  String scope = 'signed-out';
  @override
  void Function()? onChange;
}

Future<KitchenStore> fresh({bool signed = true, CloudAccount? cloud}) async {
  SharedPreferences.setMockInitialValues({'session_active': signed});
  final s = KitchenStore(await SharedPreferences.getInstance(), cloud: cloud);
  s.name = 'Alex';
  s.onboarded = true;
  s.wellness = {'purpose': 'Fitness', 'complete': true};
  return s;
}

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Future<void> click(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text).last);
  await t.tap(find.text(text).last);
  await t.pumpAndSettle();
}

Future<void> imagesReady(WidgetTester t) async {
  await t.runAsync(() async {
    for (final image in t.widgetList<Image>(find.byType(Image))) {
      await precacheImage(image.image, t.element(find.byType(MaterialApp)));
    }
  });
  await t.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Signup waits for confirmation and a warm email callback opens login',
    (t) async {
      phone(t);
      final s = await fresh(
        signed: false,
        cloud: CloudAccount(GuestLocalStore(), PendingSignupClient()),
      );
      Widget app(int returns) => MaterialApp(
        home: AccountFlow(
          s,
          confirmationReturn: returns,
          onReady: () => fail('Signup must wait for login'),
        ),
      );
      await t.pumpWidget(app(0));
      await click(t, 'Get started');
      final fields = find.byType(TextFormField);
      await t.enterText(fields.at(0), 'Cook');
      await t.enterText(fields.at(1), 'cook@example.com');
      await t.enterText(fields.at(2), 'test-password');
      await click(t, 'Create an Account  →');
      expect(find.text('Check your email'), findsOneWidget);
      await t.pumpWidget(app(1));
      await t.pumpAndSettle();
      expect(find.text('Welcome back.'), findsOneWidget);
      expect(find.text('cook@example.com'), findsOneWidget);
    },
  );
  testWidgets(
    'Explore without an account opens the local kitchen with a cloud account manager present',
    (t) async {
      phone(t);
      final local = GuestLocalStore();
      final cloud = CloudAccount(local, null)..ready = true;
      final s = await fresh(signed: false, cloud: cloud);
      await t.pumpWidget(DishcoveryApp(store: s));
      await click(t, 'Already have an account? Log in');
      await click(t, 'Explore without an account');
      expect(find.byType(OriginalShell), findsOneWidget);
      expect(cloud.signedIn, isFalse);
      local.scope = 'another-account';
      s.cloud!.ready = false;
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(DishcoveryApp(store: s));
      expect(find.byType(OriginalShell), findsNothing);
    },
  );
  testWidgets('Email return opens existing login without authenticating', (
    t,
  ) async {
    phone(t);
    final s = await fresh(signed: false);
    var signedIn = false;
    await t.pumpWidget(
      MaterialApp(
        home: AccountFlow(
          s,
          confirmationReturn: 1,
          onReady: () => signedIn = true,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Welcome back.'), findsOneWidget);
    expect(find.text('Resend confirmation email'), findsOneWidget);
    expect(signedIn, isFalse);
    await t.tap(find.text('Resend confirmation email'));
    await t.pump();
    expect(find.text('Enter your email address first.'), findsOneWidget);
  });
  setUpAll(() async {
    for (final pair in {
      'DM Sans': 'assets/DMSans.ttf',
      'Lobster': 'assets/Lobster.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final f = FontLoader(pair.key)..addFont(rootBundle.load(pair.value));
      await f.load();
    }
  });
  testWidgets('Original page enter finishes its five pixel fade in 220 ms', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(home: OriginalPageEnter(child: Text('Motion'))),
    );
    final root = find.byType(OriginalPageEnter);
    final opacity = find.descendant(of: root, matching: find.byType(Opacity));
    final translation = find.descendant(
      of: root,
      matching: find.byType(Transform),
    );
    expect(t.widget<Opacity>(opacity).opacity, .4);
    expect(t.widget<Transform>(translation).transform.storage[13], 5);
    await t.pump(const Duration(milliseconds: 110));
    expect(t.widget<Opacity>(opacity).opacity, inExclusiveRange(.4, 1));
    await t.pump(const Duration(milliseconds: 110));
    expect(t.widget<Opacity>(opacity).opacity, 1);
    expect(t.widget<Transform>(translation).transform.storage[13], 0);
  });
  testWidgets(
    'Original home navigation and two-column recipe cards fit phone',
    (t) async {
      phone(t);
      final s = await fresh();
      await t.pumpWidget(DishcoveryApp(store: s));
      await t.pumpAndSettle();
      expect(find.text('What’s cooking, Alex?'), findsOneWidget);
      expect(find.text('A taste of home,\nmade by you.'), findsOneWidget);
      await imagesReady(t);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/restored-home.png'),
      );
      for (final label in ['Recipes', 'Activity', 'Profile', 'Home']) {
        await click(t, label);
        expect(t.takeException(), isNull);
      }
      await click(t, 'Create');
      expect(find.text('Next: instructions'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Welcome and signup preserve fields, fonts and account validation',
    (t) async {
      phone(t);
      final s = await fresh(signed: false);
      await t.pumpWidget(DishcoveryApp(store: s));
      await t.pumpAndSettle();
      expect(find.text('Get started'), findsOneWidget);
      await imagesReady(t);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/restored-welcome.png'),
      );
      await click(t, 'Get started');
      expect(find.text('Your kitchen awaits.'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3));
      await imagesReady(t);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/restored-signup.png'),
      );
      await click(t, 'Create an Account  →');
      expect(find.text('Enter your name'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Six step onboarding saves purpose, optional measurements and preferences',
    (t) async {
      phone(t);
      final s = await fresh();
      await t.pumpWidget(MaterialApp(home: OriginalOnboarding(s)));
      await t.pumpAndSettle();
      await click(t, 'Fitness');
      await click(t, 'Continue');
      expect(find.text('Age (years)'), findsOneWidget);
      await click(t, 'Skip for now');
      await click(t, 'Continue');
      expect(find.text('Find your cooking rhythm.'), findsOneWidget);
      await click(t, 'Intermediate');
      await click(t, 'Continue');
      await click(t, 'Filipino');
      await click(t, 'Continue');
      await click(t, 'Eggs');
      await t.ensureVisible(
        find.widgetWithText(TextField, 'Add another allergy'),
      );
      await t.enterText(
        find.widgetWithText(TextField, 'Add another allergy'),
        'Celery',
      );
      await click(t, 'Add allergy');
      await click(t, 'Let’s get cooking');
      expect(s.skill, 'Intermediate');
      expect(s.allergies, containsAll(['Eggs', 'Celery']));
      expect(s.wellness['purpose'], 'Fitness');
      expect(s.wellness['height'], isNull);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Editor persists drafts, nutrition and ordered step timers', (
    t,
  ) async {
    phone(t);
    final s = await fresh();
    await t.pumpWidget(MaterialApp(home: RecipeEditor(s)));
    await t.pumpAndSettle();
    final fs = find.byType(TextFormField);
    await t.enterText(fs.at(0), 'Egg rice');
    final ingredientInput = t.widget<EditableText>(
      find.descendant(of: fs.at(8), matching: find.byType(EditableText)),
    );
    expect(ingredientInput.keyboardType, TextInputType.multiline);
    expect(ingredientInput.textInputAction, TextInputAction.newline);
    await t.enterText(fs.at(8), '2 eggs\n1 cup rice');
    await t.pumpAndSettle();
    expect(
      jsonDecode(s.prefs.getString('recipe_draft_new')!)['title'],
      'Egg rice',
    );
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    await t.pumpWidget(MaterialApp(home: RecipeEditor(s)));
    await t.pumpAndSettle();
    expect(find.text('Egg rice'), findsOneWidget);
    await click(t, 'Next: instructions');
    expect(find.text('Timer (seconds, 0 for none)'), findsOneWidget);
    await t.enterText(find.byType(TextFormField).first, 'Cook rice and eggs.');
    await t.enterText(find.byType(TextFormField).at(1), '60');
    await click(t, 'Save recipe');
    expect(s.own.single.title, 'Egg rice');
    expect(s.own.single.ingredients, ['2 eggs', '1 cup rice']);
    expect(s.own.single.timers['0'], 60);
    expect(s.prefs.getString('recipe_draft_new'), isNull);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Recipe details include checked ingredients, notes and guided cooking',
    (t) async {
      phone(t);
      final s = await fresh();
      await t.pumpWidget(
        MaterialApp(home: RecipeDetails(seedRecipes.first, s)),
      );
      await t.pumpAndSettle();
      expect(find.text('Cook now!'), findsOneWidget);
      await t.ensureVisible(find.byType(Checkbox).first);
      await t.tap(find.byType(Checkbox).first);
      await t.pumpAndSettle();
      expect(t.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);
      await click(t, 'Cook now!');
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Pantry search and community people are reachable', (t) async {
    phone(t);
    final s = await fresh();
    s.pantry = ['Eggs', 'Rice', 'Garlic', 'Onion'];
    await t.pumpWidget(MaterialApp(home: OriginalSearch(s)));
    await t.pumpAndSettle();
    expect(find.text('What you can make'), findsOneWidget);
    await click(t, 'People');
    expect(find.text('Clara Santos'), findsOneWidget);
    await click(t, 'Clara Santos');
    await click(t, 'Follow');
    expect(s.following, contains('Clara Santos'));
    expect(t.takeException(), isNull);
  });
  test(
    'Recipe edits retain nutrition, price facts, timers and bookmarks after reload',
    () async {
      final s = await fresh();
      final r = Recipe.fromJson({
        ...seedRecipes.first.toJson(),
        'id': 'own-test',
        'own': true,
        'timers': {'0': 120},
      });
      s.put(r);
      s.bookmark(r);
      await s.save();
      final reloaded = KitchenStore(s.prefs);
      expect(reloaded.own.single.timers['0'], 120);
      expect(reloaded.own.single.ingredientFacts, r.ingredientFacts);
      expect(reloaded.saved, contains('own-test'));
    },
  );
}
