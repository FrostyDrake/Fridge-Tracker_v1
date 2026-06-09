import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class MealRecipe {
  const MealRecipe({required this.id, required this.name, this.thumbnailUrl});

  final String id;
  final String name;
  final String? thumbnailUrl;
}

class MealRecipeDetails {
  const MealRecipeDetails({
    required this.id,
    required this.name,
    required this.ingredients,
    required this.instructions,
    this.thumbnailUrl,
    this.category,
    this.area,
    this.sourceUrl,
    this.youtubeUrl,
  });

  final String id;
  final String name;
  final List<String> ingredients;
  final String instructions;
  final String? thumbnailUrl;
  final String? category;
  final String? area;
  final String? sourceUrl;
  final String? youtubeUrl;
}

class RecipeLookupException implements Exception {
  const RecipeLookupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RecipeService {
  RecipeService({http.Client? client}) : _client = client ?? http.Client();

  static const _host = 'www.themealdb.com';
  static const _apiBasePath = '/api/json/v1/1';
  static const _timeout = Duration(seconds: 12);

  final http.Client _client;

  Future<List<MealRecipe>> findByIngredient(
    String ingredient, {
    int limit = 8,
  }) async {
    final query = _normalizeIngredientQuery(ingredient);
    if (query.isEmpty) {
      return const [];
    }

    final uri = Uri.https(_host, '$_apiBasePath/filter.php', {'i': query});
    final response = await _client.get(uri).timeout(_timeout);

    if (response.statusCode != 200) {
      throw RecipeLookupException(
        'TheMealDB returned status ${response.statusCode}',
      );
    }

    final body = _decodeJsonObject(response.body);
    final meals = body['meals'];
    if (meals == null) {
      return const [];
    }
    if (meals is! List) {
      throw const RecipeLookupException('TheMealDB returned invalid meals');
    }

    final recipes = <MealRecipe>[];
    for (final meal in meals) {
      if (meal is! Map<String, dynamic>) {
        continue;
      }

      final id = _readString(meal['idMeal']);
      final name = _readString(meal['strMeal']);
      if (id == null || name == null) {
        continue;
      }

      recipes.add(
        MealRecipe(
          id: id,
          name: name,
          thumbnailUrl: _readString(meal['strMealThumb']),
        ),
      );

      if (recipes.length >= limit) {
        break;
      }
    }

    return recipes;
  }

  Future<MealRecipeDetails> findDetails(String mealId) async {
    final id = mealId.trim();
    if (id.isEmpty) {
      throw const RecipeLookupException('Missing meal id');
    }

    final uri = Uri.https(_host, '$_apiBasePath/lookup.php', {'i': id});
    final response = await _client.get(uri).timeout(_timeout);

    if (response.statusCode != 200) {
      throw RecipeLookupException(
        'TheMealDB returned status ${response.statusCode}',
      );
    }

    final body = _decodeJsonObject(response.body);
    final meals = body['meals'];
    if (meals is! List || meals.isEmpty) {
      throw const RecipeLookupException('Recipe was not found');
    }

    final meal = meals.first;
    if (meal is! Map<String, dynamic>) {
      throw const RecipeLookupException('TheMealDB returned invalid details');
    }

    final name = _readString(meal['strMeal']);
    if (name == null) {
      throw const RecipeLookupException('Recipe was missing a name');
    }

    return MealRecipeDetails(
      id: _readString(meal['idMeal']) ?? id,
      name: name,
      ingredients: _readIngredients(meal),
      instructions: _readString(meal['strInstructions']) ?? '',
      thumbnailUrl: _readString(meal['strMealThumb']),
      category: _readString(meal['strCategory']),
      area: _readString(meal['strArea']),
      sourceUrl: _readString(meal['strSource']),
      youtubeUrl: _readString(meal['strYoutube']),
    );
  }

  String ingredientFromFridgeItem({
    required String name,
    required String category,
  }) {
    final normalized = _normalize('$name $category');
    for (final keyword in _ingredientKeywords) {
      if (keyword.words.any(normalized.contains)) {
        return keyword.ingredient;
      }
    }

    final fallback = _fallbackIngredient(name);
    if (fallback.isNotEmpty) {
      return fallback;
    }

    return _fallbackIngredient(category);
  }

  Map<String, dynamic> _decodeJsonObject(String responseBody) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw const RecipeLookupException('TheMealDB returned invalid JSON');
    }
    return decoded;
  }

  List<String> _readIngredients(Map<String, dynamic> meal) {
    final ingredients = <String>[];
    for (var index = 1; index <= 20; index += 1) {
      final ingredient = _readString(meal['strIngredient$index']);
      if (ingredient == null) {
        continue;
      }

      final measure = _readString(meal['strMeasure$index']);
      ingredients.add(measure == null ? ingredient : '$measure $ingredient');
    }

    return ingredients;
  }

  String _normalizeIngredientQuery(String value) {
    return _normalize(
      value,
    ).split(RegExp(r'[^a-z0-9]+')).where((word) => word.isNotEmpty).join('_');
  }

  String _fallbackIngredient(String value) {
    final words = _normalize(value)
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.length >= 3)
        .where((word) => !_ignoredFallbackWords.contains(word))
        .toList();

    return words.isEmpty ? '' : words.first;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('å', 'aa')
        .replaceAll('ä', 'ae')
        .replaceAll('æ', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ø', 'oe');
  }

  String? _readString(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }
}

class _IngredientKeyword {
  const _IngredientKeyword(this.words, this.ingredient);

  final List<String> words;
  final String ingredient;
}

const _ingredientKeywords = [
  _IngredientKeyword(['kylling', 'chicken'], 'chicken'),
  _IngredientKeyword(['okse', 'beef'], 'beef'),
  _IngredientKeyword(['svin', 'pork'], 'pork'),
  _IngredientKeyword(['bacon'], 'bacon'),
  _IngredientKeyword(['laks', 'salmon'], 'salmon'),
  _IngredientKeyword(['tun', 'tuna'], 'tuna'),
  _IngredientKeyword(['reje', 'shrimp'], 'shrimp'),
  _IngredientKeyword(['fisk', 'fish'], 'fish'),
  _IngredientKeyword(['maelk', 'milk'], 'milk'),
  _IngredientKeyword(['yoghurt', 'yogurt'], 'yogurt'),
  _IngredientKeyword(['ost', 'cheese'], 'cheese'),
  _IngredientKeyword(['smoer', 'butter'], 'butter'),
  _IngredientKeyword(['aeg', 'egg'], 'eggs'),
  _IngredientKeyword(['tomat', 'tomato'], 'tomato'),
  _IngredientKeyword(['agurk', 'cucumber'], 'cucumber'),
  _IngredientKeyword(['salat', 'lettuce'], 'lettuce'),
  _IngredientKeyword(['kartoffel', 'potato'], 'potato'),
  _IngredientKeyword(['pasta'], 'pasta'),
  _IngredientKeyword(['ris', 'rice'], 'rice'),
  _IngredientKeyword(['broed', 'bread'], 'bread'),
  _IngredientKeyword(['hvidloeg', 'garlic'], 'garlic'),
  _IngredientKeyword(['loeg', 'onion'], 'onion'),
  _IngredientKeyword(['gulerod', 'carrot'], 'carrot'),
  _IngredientKeyword(['champignon', 'mushroom'], 'mushroom'),
  _IngredientKeyword(['majs', 'corn'], 'corn'),
  _IngredientKeyword(['aeble', 'apple'], 'apple'),
  _IngredientKeyword(['banan', 'banana'], 'banana'),
];

const _ignoredFallbackWords = {
  'arla',
  'coop',
  'irma',
  'netto',
  'rema',
  'super',
  'mini',
  'let',
  'light',
  'oko',
  'oekologisk',
  'organic',
  'ukendt',
  'ingen',
  'kategori',
  'vare',
  'frisk',
  'fersk',
};
