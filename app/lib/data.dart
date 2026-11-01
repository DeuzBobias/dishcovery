import 'android_api.dart';
import 'dart:convert';
import 'catalog.dart';
import 'nutrition.dart';
import 'deficit.dart';

import 'package:flutter/foundation.dart';
import 'cloud_account.dart';
import 'allergies.dart';

class Recipe {
  final String id,
      title,
      description,
      category,
      author,
      image,
      level,
      tools,
      tips;
  final int minutes, servings;
  final List<String> ingredients, steps, allergens;
  final Map<String, String> swaps;
  final Map<String, dynamic> timers;
  final bool own;
  final Map<String, dynamic>? nutrition;
  final Map<String, dynamic> ingredientFacts;
  Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.author,
    required this.image,
    required this.minutes,
    required this.ingredients,
    required this.steps,
    this.servings = 2,
    this.nutrition,
    this.ingredientFacts = const {},
    this.level = 'Beginner',
    this.allergens = const [],
    this.swaps = const {},
    this.timers = const {},
    this.own = false,
    this.tools = 'Knife, chopping board, pan',
    this.tips = 'Taste as you go and adjust the seasoning to your liking.',
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'author': author,
    'image': image,
    'minutes': minutes,
    'ingredients': ingredients,
    'steps': steps,
    'servings': servings,
    'level': level,
    'allergens': allergens,
    'swaps': swaps,
    'timers': timers,
    'own': own,
    'tools': tools,
    'tips': tips,
    'nutrition': nutrition,
    'ingredientFacts': ingredientFacts,
  };
  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
    nutrition: j['nutrition'] == null
        ? null
        : Map<String, dynamic>.from(j['nutrition']),
    ingredientFacts: Map<String, dynamic>.from(j['ingredientFacts'] ?? {}),
    id: j['id'],
    title: j['title'],
    description: j['description'],
    category: j['category'],
    author: j['author'],
    image: j['image'],
    minutes: j['minutes'],
    ingredients: List<String>.from(j['ingredients']),
    steps: List<String>.from(j['steps']),
    servings: j['servings'] ?? 2,
    level: j['level'] ?? 'Beginner',
    allergens: List<String>.from(j['allergens'] ?? []),
    swaps: Map<String, String>.from(j['swaps'] ?? {}),
    timers: j['timers'] is List
        ? {
            for (final e in (j['timers'] as List).asMap().entries)
              e.key.toString(): e.value,
          }
        : Map<String, dynamic>.from(j['timers'] ?? {}),
    own: j['own'] ?? false,
    tools: j['tools'] ?? '',
    tips: j['tips'] ?? '',
  );
}

final seedRecipes = (jsonDecode(recipeCatalog) as List)
    .map((r) => Recipe.fromJson(Map<String, dynamic>.from(r)))
    .toList();

class KitchenStore extends ChangeNotifier {
  final dynamic prefs;
  final CloudAccount? cloud;
  Map<String, dynamic> wellness = {'purpose': 'Recipes'};
  List<Map<String, dynamic>> foodLog = [];
  Map<String, dynamic> targets = {};
  List<Map<String, dynamic>> deficitPlans = [];
  Map<String, dynamic> completedFoodDays = {};
  Map<String, dynamic> prices = {};
  KitchenStore(this.prefs, {this.cloud}) {
    if (cloud != null) cloud!.onReload = reload;
    _load();
  }
  String avatar = '';
  String name = 'Home cook',
      bio = 'A little curiosity. A lot of good food.',
      skill = 'Beginner';
  List<String> cuisines = [],
      allergies = [],
      pantry = ['Rice', 'Garlic', 'Olive oil', 'Eggs', 'Tomatoes'];
  List<Recipe> own = [];
  Set<String> saved = {}, liked = {}, following = {};
  List<String> activity = [];
  Map<String, List<String>> comments = {};
  int cooked = 0;
  bool onboarded = false, notifications = true;
  String? storageError;
  int? requestedTab;
  void navigate(int index) {
    requestedTab = index;
    notifyListeners();
  }

  List<Recipe> get recipes => [...own, ...seedRecipes];
  void reload() {
    _load();
    notifyListeners();
  }

  void _load() {
    final raw = prefs.getString('kitchen_v1');
    // Empty account scope must never inherit a previous user’s values.
    try {
      final j = jsonDecode(raw ?? '{}') as Map<String, dynamic>;
      wellness = Map<String, dynamic>.from(
        j['wellness'] ?? {'purpose': 'Recipes'},
      );
      foodLog = (j['foodLog'] as List? ?? [])
          .map((v) => Map<String, dynamic>.from(v))
          .toList();
      targets = Map<String, dynamic>.from(j['targets'] ?? {});
      deficitPlans = (j['deficitPlans'] as List? ?? [])
          .map((v) => Map<String, dynamic>.from(v))
          .where(validDeficitPlan)
          .toList();
      completedFoodDays = Map<String, dynamic>.from(
        j['completedFoodDays'] ?? {},
      );
      prices = Map<String, dynamic>.from(j['prices'] ?? {});
      avatar = j['avatar'] ?? '';
      name = j['name'] ?? 'Home cook';
      bio = j['bio'] ?? 'A little curiosity. A lot of good food.';
      skill = j['skill'] ?? 'Beginner';
      cuisines = List<String>.from(j['cuisines'] ?? []);
      allergies = List<String>.from(j['allergies'] ?? []);
      pantry = List<String>.from(j['pantry'] ?? []);
      own = (j['own'] as List? ?? [])
          .map((r) => Recipe.fromJson(Map<String, dynamic>.from(r)))
          .toList();
      saved = Set<String>.from(j['saved'] ?? []);
      liked = Set<String>.from(j['liked'] ?? []);
      following = Set<String>.from(j['following'] ?? []);
      activity = List<String>.from(j['activity'] ?? []);
      comments = (j['comments'] as Map? ?? {}).map(
        (k, v) => MapEntry(k.toString(), List<String>.from(v)),
      );
      cooked = j['cooked'] ?? 0;
      onboarded = j['onboarded'] ?? false;
      notifications = j['notifications'] ?? true;
    } catch (_) {
      storageError =
          'Saved data could not be read. Your original data has been kept.';
    }
  }

  Map<String, dynamic> toJson() => {
    'wellness': wellness,
    'foodLog': foodLog,
    'targets': targets,
    'deficitPlans': deficitPlans,
    'completedFoodDays': completedFoodDays,
    'prices': prices,
    'avatar': avatar,
    'name': name,
    'bio': bio,
    'skill': skill,
    'cuisines': cuisines,
    'allergies': allergies,
    'pantry': pantry,
    'own': own.map((r) => r.toJson()).toList(),
    'saved': saved.toList(),
    'liked': liked.toList(),
    'following': following.toList(),
    'activity': activity,
    'comments': comments,
    'cooked': cooked,
    'onboarded': onboarded,
    'notifications': notifications,
  };
  Future<void> save() async {
    notifyListeners();
    try {
      if (!await prefs.setString('kitchen_v1', jsonEncode(toJson()))) {
        throw Exception();
      }
      storageError = null;
    } catch (_) {
      storageError = 'Could not save changes on this device. Please try again.';
    }
    notifyListeners();
  }

  void log(String message) {
    if (notifications) {
      activity.insert(0, message);
      AndroidApi.notification(message).catchError((_) {});
    }
    if (activity.length > 100) activity.removeLast();
  }

  void bookmark(Recipe r) {
    saved.contains(r.id) ? saved.remove(r.id) : saved.add(r.id);
    save();
  }

  void like(Recipe r) {
    liked.contains(r.id) ? liked.remove(r.id) : liked.add(r.id);
    save();
  }

  void put(Recipe r) {
    own.removeWhere((x) => x.id == r.id);
    own.insert(0, r);
    log('You saved ${r.title} to your recipes.');
    save();
  }

  void remove(Recipe r) {
    own.removeWhere((x) => x.id == r.id);
    saved.remove(r.id);
    liked.remove(r.id);
    comments.remove(r.id);
    save();
  }

  List<String> warnings(Recipe r) =>
      allergyWarnings(allergies, r.allergens, r.ingredients);
  bool hasIngredient(String ingredient) =>
      ingredientMatches(ingredient, pantry);
  double match(Recipe r) =>
      r.ingredients.where(hasIngredient).length / r.ingredients.length;
  List<Recipe> search(
    String q,
    String category, {
    bool quick = false,
  }) => recipes
      .where(
        (r) =>
            (category == 'All recipes' || r.category == category) &&
            (!quick || r.minutes <= 30) &&
            '${r.title} ${r.category} ${r.ingredients.join(' ')} ${r.author}'
                .toLowerCase()
                .contains(q.toLowerCase()),
      )
      .toList();
  Future<void> reset() async {
    await prefs.remove('kitchen_v1');
    wellness = {'purpose': 'Recipes'};
    foodLog = [];
    targets = {};
    deficitPlans = [];
    completedFoodDays = {};
    prices = {};
    avatar = '';
    name = 'Home cook';
    bio = 'A little curiosity. A lot of good food.';
    skill = 'Beginner';
    cuisines = [];
    allergies = [];
    pantry = [];
    own = [];
    saved = {};
    liked = {};
    following = {};
    activity = [];
    comments = {};
    cooked = 0;
    onboarded = false;
    notifications = true;
    await save();
  }
}
