import 'android_api.dart';
import 'dart:convert';
import 'catalog.dart';
import 'nutrition.dart';
import 'deficit.dart';

import 'package:flutter/foundation.dart';
import 'cloud_account.dart';
import 'allergies.dart';
import 'media_store.dart';

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
  final String authorAvatar;
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
    this.authorAvatar = '',
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
    authorAvatar: j['authorAvatar'] is String ? j['authorAvatar'] : '',
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

  String? _feedViewer;
  List<Recipe> _posts = [];
  int _feedRequest = 0;
  String? feedError;
  String? get viewer => cloud?.signedIn == true ? cloud!.local.scope : null;
  List<Recipe> get posts =>
      viewer != null && viewer == _feedViewer ? _posts : const [];
  List<Recipe> get recipes => [
    ...own,
    ...posts.where((post) => !own.any((r) => r.id == post.id)),
    ...seedRecipes,
  ];

  Future<void> refreshCommunity() async {
    final user = viewer;
    if (user == null) return;
    final request = ++_feedRequest;
    try {
      final rows = await cloud!.client!
          .from('community_recipes')
          .select('owner_id,recipe_id,recipe')
          .order('posted_at', ascending: false)
          .limit(50)
          .timeout(const Duration(seconds: 12));
      if (viewer != user || request != _feedRequest) return;
      final loaded = <Recipe>[];
      for (final row in rows) {
        try {
          final isMine = row['owner_id'] == user;
          final post = Recipe.fromJson({
            ...Map<String, dynamic>.from(row['recipe']),
            'id': isMine
                ? row['recipe_id']
                : 'community/${row['owner_id']}/${row['recipe_id']}',
            'own': isMine && own.any((r) => r.id == row['recipe_id']),
          });
          if (post.author.trim().isNotEmpty && post.title.trim().isNotEmpty) {
            loaded.add(post);
          }
        } on TypeError {
          continue;
        }
      }
      _posts = loaded;
      _feedViewer = user;
      feedError = null;
    } catch (_) {
      if (viewer != user || request != _feedRequest) return;
      feedError = 'Could not refresh community posts. Tap refresh to retry.';
    }
    notifyListeners();
  }

  Future<void> publishRecipe(Recipe recipe) async {
    if (viewer == null || !own.any((item) => item.id == recipe.id)) {
      throw StateError('A signed-in recipe owner is required.');
    }
    final data = recipe.toJson();
    final owner = viewer;
    final client = cloud!.client!;
    if (recipe.image.startsWith('data:') &&
        await MediaStore.origin(client) != null) {
      data['image'] = await MediaStore.upload(
        client,
        base64Decode(recipe.image.split(',').last),
        'recipe',
      );
    }
    if (viewer != owner) throw StateError('Account changed');
    await client
        .rpc(
          'publish_recipe',
          params: {
            'recipe_id_arg': recipe.id,
            'recipe_arg': {
              ...data,
              'own': false,
              'author': name,
              if (avatar.startsWith('r2:')) 'authorAvatar': avatar,
            },
          },
        )
        .timeout(const Duration(seconds: 15));
    await refreshCommunity();
  }

  Future<void> withdrawRecipe(Recipe recipe) async {
    final user = viewer;
    if (user == null) return;
    await cloud!.client!
        .from('community_recipes')
        .delete()
        .eq('owner_id', user)
        .eq('recipe_id', recipe.id)
        .timeout(const Duration(seconds: 12));
    await refreshCommunity();
  }

  Future<String> storePhoto(
    Uint8List bytes,
    String kind,
    String? extension,
  ) async {
    final user = viewer;
    if (user == null || await MediaStore.origin(cloud!.client!) == null) {
      return 'data:image/$extension;base64,${base64Encode(bytes)}';
    }
    final ref = await MediaStore.upload(cloud!.client!, bytes, kind);
    if (viewer != user) throw StateError('Account changed');
    return ref;
  }

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
