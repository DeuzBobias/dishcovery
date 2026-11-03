import 'dart:convert';

import 'package:flutter/material.dart';

import 'data.dart';

const ink = Color(0xFF2D2225),
    green = Color(0xFFFF505F),
    cream = Color(0xFFFFFFFF),
    muted = Color(0xFF89838A),
    line = Color(0xFFEEEAEE),
    pale = Color(0xFFFFE9EC),
    orange = Color(0xFFC47343);
TextStyle serif(double size, {Color color = ink}) => TextStyle(
  fontFamily: 'DM Sans',
  fontWeight: FontWeight.w700,
  fontSize: size,
  color: color,
  height: 1.12,
);
Widget gap([double n = 16]) => SizedBox(height: n);
Widget label(String text) => Text(
  text,
  style: const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.8,
    color: green,
  ),
);

class FoodImage extends StatelessWidget {
  final String source;
  final double? height;
  final BoxFit fit;
  const FoodImage(
    this.source, {
    super.key,
    this.height,
    this.fit = BoxFit.cover,
  });
  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
      height: height,
      color: pale,
      child: const Center(
        child: Icon(Icons.restaurant_rounded, size: 60, color: green),
      ),
    );
    if (source.startsWith('data:')) {
      try {
        return Image.memory(
          base64Decode(source.split(',').last),
          width: double.infinity,
          height: height,
          fit: fit,
          errorBuilder: (_, e, s) => fallback(),
        );
      } catch (_) {
        return fallback();
      }
    }
    return Image.asset(
      source,
      width: double.infinity,
      height: height,
      fit: fit,
      errorBuilder: (_, e, s) => fallback(),
    );
  }
}

class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color borderColor;
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color = Colors.white,
    this.borderColor = line,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borderColor),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class TitleRow extends StatelessWidget {
  final String title, subtitle;
  final Widget? action;
  const TitleRow(this.title, this.subtitle, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 24,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: serif(34)),
            gap(8),
            Text(subtitle, style: const TextStyle(color: muted)),
          ],
        ),
        ?action,
      ],
    ),
  );
}

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final KitchenStore store;
  final VoidCallback onTap;
  const RecipeCard(this.recipe, this.store, {super.key, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final r = recipe;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(aspectRatio: 1.65, child: FoodImage(r.image)),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      r.category,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filledTonal(
                    tooltip: store.saved.contains(r.id)
                        ? 'Unsave recipe'
                        : 'Save recipe',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: ink,
                    ),
                    onPressed: () => toggleBookmark(context, store, r),
                    icon: Icon(
                      store.saved.contains(r.id)
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  gap(7),
                  Text(
                    'by ${r.author}',
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                  gap(18),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: muted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${r.minutes} min',
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                      const SizedBox(width: 16),
                      const Icon(
                        Icons.bar_chart_rounded,
                        size: 16,
                        color: muted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          r.level,
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                      ),
                      if (store.warnings(r).isNotEmpty)
                        const Tooltip(
                          message: 'Contains a selected allergen',
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: orange,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecipeGrid extends StatelessWidget {
  final List<Recipe> recipes;
  final KitchenStore store;
  final void Function(Recipe) onOpen;
  const RecipeGrid(this.recipes, this.store, this.onOpen, {super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final count = c.maxWidth > 1000
          ? 3
          : c.maxWidth > 560
          ? 2
          : 1;
      if (recipes.isEmpty) {
        return const Surface(
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                children: [
                  Icon(Icons.ramen_dining_rounded, color: green, size: 44),
                  SizedBox(height: 16),
                  Text(
                    'A fresh start',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Try another search, save a recipe, or create something of your own.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return Wrap(
        spacing: 20,
        runSpacing: 20,
        children: recipes
            .map(
              (r) => SizedBox(
                width: (c.maxWidth - 20 * (count - 1)) / count,
                child: RecipeCard(r, store, onTap: () => onOpen(r)),
              ),
            )
            .toList(),
      );
    },
  );
}

void toggleBookmark(BuildContext context, KitchenStore store, Recipe recipe) {
  store.bookmark(recipe);
  toast(
    context,
    store.saved.contains(recipe.id)
        ? 'Added to Bookmarks'
        : 'Removed from Bookmarks',
  );
}

void toast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}
