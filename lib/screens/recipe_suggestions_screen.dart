import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/fridge_item_service.dart';
import '../services/recipe_service.dart';

class RecipeSuggestionsScreen extends StatefulWidget {
  const RecipeSuggestionsScreen({super.key, required this.userId});

  final String userId;

  @override
  State<RecipeSuggestionsScreen> createState() =>
      _RecipeSuggestionsScreenState();
}

class _RecipeSuggestionsScreenState extends State<RecipeSuggestionsScreen> {
  static const _soonDays = 3;
  static const _maxSuggestions = 12;

  final _itemService = FridgeItemService();
  final _recipeService = RecipeService();
  final _detailsCache = <String, Future<MealRecipeDetails>>{};

  String? _suggestionsKey;
  Future<List<_RecipeSuggestion>>? _suggestionsFuture;

  Future<List<_RecipeSuggestion>> _suggestionsFor(
    List<_ExpiringFridgeItem> items,
  ) {
    final key = items
        .map(
          (item) =>
              '${item.id}:${item.name}:${item.category}:'
              '${item.expiryDate.millisecondsSinceEpoch}',
        )
        .join('|');

    if (_suggestionsKey != key || _suggestionsFuture == null) {
      _suggestionsKey = key;
      _suggestionsFuture = _loadSuggestions(items);
    }

    return _suggestionsFuture!;
  }

  Future<List<_RecipeSuggestion>> _loadSuggestions(
    List<_ExpiringFridgeItem> items,
  ) async {
    final suggestions = <_RecipeSuggestion>[];
    final seenIngredients = <String>{};
    final seenRecipes = <String>{};
    final failures = <Object>[];

    for (final item in items) {
      if (suggestions.length >= _maxSuggestions) {
        break;
      }

      final ingredient = _recipeService.ingredientFromFridgeItem(
        name: item.name,
        category: item.category,
      );

      if (ingredient.isEmpty || !seenIngredients.add(ingredient)) {
        continue;
      }

      try {
        debugPrint('Recipe lookup: ${item.name} -> $ingredient');
        final recipes = await _recipeService.findByIngredient(
          ingredient,
          limit: 5,
        );
        debugPrint(
          'Recipe lookup: $ingredient returned ${recipes.length} meals',
        );

        for (final recipe in recipes) {
          if (!seenRecipes.add(recipe.id)) {
            continue;
          }

          suggestions.add(
            _RecipeSuggestion(
              recipe: recipe,
              sourceItem: item,
              ingredient: ingredient,
            ),
          );

          if (suggestions.length >= _maxSuggestions) {
            break;
          }
        }
      } catch (error, stackTrace) {
        failures.add(error);
        debugPrint('Recipe lookup failed for $ingredient: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    if (suggestions.isEmpty && failures.isNotEmpty) {
      throw const _RecipeSuggestionException(
        'Opskrifter kunne ikke hentes fra TheMealDB.',
      );
    }

    return suggestions;
  }

  Future<MealRecipeDetails> _detailsFor(String mealId) {
    return _detailsCache.putIfAbsent(
      mealId,
      () => _recipeService.findDetails(mealId),
    );
  }

  void _refreshSuggestions() {
    setState(() {
      _suggestionsKey = null;
      _suggestionsFuture = null;
    });
  }

  List<_ExpiringFridgeItem> _expiringSoonItems(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final items = snapshot.docs.map(_ExpiringFridgeItem.fromDoc).where((item) {
      final daysLeft = _daysLeft(item.expiryDate);
      return daysLeft >= 0 && daysLeft <= _soonDays;
    }).toList();

    items.sort((a, b) {
      final dateOrder = a.expiryDate.compareTo(b.expiryDate);
      if (dateOrder != 0) {
        return dateOrder;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return items;
  }

  int _daysLeft(DateTime date) {
    final today = DateTime.now();
    final currentDate = DateTime(today.year, today.month, today.day);
    final itemDate = DateTime(date.year, date.month, date.day);
    return itemDate.difference(currentDate).inDays;
  }

  String _expiryText(DateTime date) {
    final daysLeft = _daysLeft(date);
    if (daysLeft == 0) {
      return 'Udl\u00f8ber i dag';
    }
    if (daysLeft == 1) {
      return 'Udl\u00f8ber i morgen';
    }
    return '$daysLeft dage tilbage';
  }

  void _showRecipeDetails(BuildContext context, _RecipeSuggestion suggestion) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height * 0.86;

        return SafeArea(
          child: SizedBox(
            height: height,
            child: FutureBuilder<MealRecipeDetails>(
              future: _detailsFor(suggestion.recipe.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _messageState(
                    icon: Icons.error_outline,
                    title: 'Opskriften kunne ikke hentes',
                    message: '${snapshot.error}',
                    action: OutlinedButton.icon(
                      onPressed: () {
                        _detailsCache.remove(suggestion.recipe.id);
                        Navigator.pop(sheetContext);
                        if (mounted) {
                          _showRecipeDetails(this.context, suggestion);
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Pr\u00f8v igen'),
                    ),
                  );
                }

                return _detailsView(snapshot.data!, suggestion);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _detailsView(MealRecipeDetails details, _RecipeSuggestion suggestion) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroImage(details.thumbnailUrl, height: 180),
          const SizedBox(height: 16),
          Text(
            details.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _detailChip(
                Icons.inventory_2_outlined,
                suggestion.sourceItem.name,
              ),
              _detailChip(Icons.restaurant_outlined, suggestion.ingredient),
              if (details.category != null)
                _detailChip(Icons.category_outlined, details.category!),
              if (details.area != null)
                _detailChip(Icons.public, details.area!),
            ],
          ),
          const SizedBox(height: 20),
          _sectionTitle('Ingredienser'),
          const SizedBox(height: 8),
          if (details.ingredients.isEmpty)
            const Text('Ingen ingredienser fundet.')
          else
            ...details.ingredients.map(
              (ingredient) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Icon(Icons.circle, size: 6),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(ingredient)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
          _sectionTitle('Fremgangsmade'),
          const SizedBox(height: 8),
          Text(
            details.instructions.trim().isEmpty
                ? 'Ingen fremgangsmade fundet.'
                : details.instructions.trim(),
          ),
          if (details.sourceUrl != null || details.youtubeUrl != null) ...[
            const SizedBox(height: 18),
            _sectionTitle('Links'),
            if (details.sourceUrl != null) SelectableText(details.sourceUrl!),
            if (details.youtubeUrl != null) SelectableText(details.youtubeUrl!),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }

  Widget _detailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recipesView(List<_ExpiringFridgeItem> expiringItems) {
    return FutureBuilder<List<_RecipeSuggestion>>(
      future: _suggestionsFor(expiringItems),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _messageState(
            icon: Icons.cloud_off_outlined,
            title: 'Ingen forbindelse til opskrifter',
            message: '${snapshot.error}',
            action: OutlinedButton.icon(
              onPressed: _refreshSuggestions,
              icon: const Icon(Icons.refresh),
              label: const Text('Pr\u00f8v igen'),
            ),
          );
        }

        final suggestions = snapshot.data ?? const [];
        if (suggestions.isEmpty) {
          return _messageState(
            icon: Icons.no_food_outlined,
            title: 'Ingen opskrifter fundet',
            message:
                'TheMealDB fandt ingen forslag til de varer, der '
                'udl\u00f8ber snart.',
            action: OutlinedButton.icon(
              onPressed: _refreshSuggestions,
              icon: const Icon(Icons.refresh),
              label: const Text('S\u00f8g igen'),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: suggestions.length + 1,
          separatorBuilder: (_, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _summaryHeader(expiringItems, suggestions.length);
            }
            return _recipeCard(suggestions[index - 1]);
          },
        );
      },
    );
  }

  Widget _summaryHeader(List<_ExpiringFridgeItem> items, int suggestionCount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$suggestionCount opskrifter baseret p\u00e5 '
            '${items.length} varer',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .take(6)
                .map(
                  (item) => _detailChip(
                    Icons.event_outlined,
                    '${item.name} · ${_expiryText(item.expiryDate)}',
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _recipeCard(_RecipeSuggestion suggestion) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        onTap: () => _showRecipeDetails(context, suggestion),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumbnail(suggestion.recipe.thumbnailUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.recipe.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      suggestion.sourceItem.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _miniChip(
                          Icons.restaurant_outlined,
                          suggestion.ingredient,
                        ),
                        _miniChip(
                          Icons.event_outlined,
                          _expiryText(suggestion.sourceItem.expiryDate),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbnail(String? imageUrl) {
    return _networkImage(imageUrl, width: 88, height: 88);
  }

  Widget _heroImage(String? imageUrl, {required double height}) {
    return _networkImage(imageUrl, width: double.infinity, height: height);
  }

  Widget _networkImage(
    String? imageUrl, {
    required double width,
    required double height,
  }) {
    final placeholder = Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.restaurant_menu)),
    );

    if (imageUrl == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: placeholder,
      );
    }

    final imageWidth = width.isInfinite ? null : width;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        width: imageWidth,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }

  Widget _messageState({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }

  String _firestoreError(Object error) {
    if (error is FirebaseException) {
      return 'Firebase fejl (${error.code}): ${error.message ?? error}';
    }
    return 'Varerne kunne ikke hentes: $error';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Opskrifter'),
        actions: [
          IconButton(
            onPressed: _refreshSuggestions,
            tooltip: 'Opdater',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _itemService.watchItems(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _messageState(
              icon: Icons.error_outline,
              title: 'Varerne kunne ikke hentes',
              message: _firestoreError(snapshot.error!),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data;
          if (data == null) {
            return _messageState(
              icon: Icons.inventory_2_outlined,
              title: 'Ingen varer fundet',
              message: 'Tilf\u00f8j varer, f\u00f8r du henter opskrifter.',
            );
          }

          final expiringItems = _expiringSoonItems(data);
          if (expiringItems.isEmpty) {
            return _messageState(
              icon: Icons.restaurant_menu,
              title: 'Ingen varer udl\u00f8ber snart',
              message:
                  'Opskrifter vises for varer med udl\u00f8bsdato inden for '
                  '$_soonDays dage.',
            );
          }

          return _recipesView(expiringItems);
        },
      ),
    );
  }
}

class _RecipeSuggestionException implements Exception {
  const _RecipeSuggestionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _RecipeSuggestion {
  const _RecipeSuggestion({
    required this.recipe,
    required this.sourceItem,
    required this.ingredient,
  });

  final MealRecipe recipe;
  final _ExpiringFridgeItem sourceItem;
  final String ingredient;
}

class _ExpiringFridgeItem {
  const _ExpiringFridgeItem({
    required this.id,
    required this.name,
    required this.category,
    required this.expiryDate,
  });

  final String id;
  final String name;
  final String category;
  final DateTime expiryDate;

  factory _ExpiringFridgeItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _ExpiringFridgeItem(
      id: doc.id,
      name: data['name'] as String? ?? 'Ukendt vare',
      category: data['category'] as String? ?? 'Ingen kategori',
      expiryDate:
          _readDate(data['expiryDate']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}
