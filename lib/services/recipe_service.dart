import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

// Kort opskriftsmodel fra TheMealDBs søgeresultat.
class MealRecipe {
  const MealRecipe({required this.id, required this.name, this.thumbnailUrl});

  final String id;
  final String name;
  final String? thumbnailUrl;
}

// Detaljeret opskriftsmodel med ingredienser og instruktioner.
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

// Exception bruges når opskrifts-API'et fejler eller svarer forkert.
class RecipeLookupException implements Exception {
  const RecipeLookupException(this.message);

  final String message;

  @override
  String toString() => message;
}

// Service der henter opskrifter fra TheMealDB.
class RecipeService {
  RecipeService({http.Client? client}) : _client = client ?? http.Client();

  // API-konfiguration for TheMealDB.
  static const _host = 'www.themealdb.com';
  static const _apiBasePath = '/api/json/v1/1';
  static const _timeout = Duration(seconds: 12);

  // HTTP-client kan erstattes i tests.
  final http.Client _client;

  // Finder opskrifter ud fra én ingrediens.
  Future<List<MealRecipe>> findByIngredient(
    String ingredient, {
    int limit = 8,
  }) async {
    // TheMealDB forventer ingrediensnavne som query-tekst.
    final query = _normalizeIngredientQuery(ingredient);
    if (query.isEmpty) {
      return const [];
    }

    final uri = Uri.https(_host, '$_apiBasePath/filter.php', {'i': query});
    final response = await _client.get(uri).timeout(_timeout);

    // Ikke-200 betyder at API'et ikke svarede korrekt.
    if (response.statusCode != 200) {
      throw RecipeLookupException(
        'TheMealDB returned status ${response.statusCode}',
      );
    }

    // meals kan være null, hvis API'et ikke fandt noget.
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
      // Springer ugyldige elementer over i stedet for at crashe.
      if (meal is! Map<String, dynamic>) {
        continue;
      }

      // Opskrifter uden id eller navn kan ikke bruges i appen.
      final id = _readString(meal['idMeal']);
      final name = _readString(meal['strMeal']);
      if (id == null || name == null) {
        continue;
      }

      // Mapper API-felter til den korte opskriftsmodel.
      recipes.add(
        MealRecipe(
          id: id,
          name: name,
          thumbnailUrl: _readString(meal['strMealThumb']),
        ),
      );

      // Stopper når det ønskede antal forslag er nået.
      if (recipes.length >= limit) {
        break;
      }
    }

    return recipes;
  }

  // Henter detaljer for én opskrift.
  Future<MealRecipeDetails> findDetails(String mealId) async {
    final id = mealId.trim();
    if (id.isEmpty) {
      throw const RecipeLookupException('Missing meal id');
    }

    final uri = Uri.https(_host, '$_apiBasePath/lookup.php', {'i': id});
    final response = await _client.get(uri).timeout(_timeout);

    // Ikke-200 betyder at API'et ikke svarede korrekt.
    if (response.statusCode != 200) {
      throw RecipeLookupException(
        'TheMealDB returned status ${response.statusCode}',
      );
    }

    // Lookup skal give mindst én opskrift tilbage.
    final body = _decodeJsonObject(response.body);
    final meals = body['meals'];
    if (meals is! List || meals.isEmpty) {
      throw const RecipeLookupException('Recipe was not found');
    }

    // Første meal bruges som opskriftens detaljer.
    final meal = meals.first;
    if (meal is! Map<String, dynamic>) {
      throw const RecipeLookupException('TheMealDB returned invalid details');
    }

    // Navn er påkrævet for at vise opskriften.
    final name = _readString(meal['strMeal']);
    if (name == null) {
      throw const RecipeLookupException('Recipe was missing a name');
    }

    // Mapper API-data til appens detaljerede model.
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

  // Omsætter køleskabsnavn/kategori til en ingrediens TheMealDB forstår.
  String ingredientFromFridgeItem({
    required String name,
    required String category,
  }) {
    final normalized = _normalize('$name $category');
    // Prøver først kendte danske/engelske keywords.
    for (final keyword in _ingredientKeywords) {
      if (keyword.words.any(normalized.contains)) {
        return keyword.ingredient;
      }
    }

    // Hvis intet keyword matcher, bruges første brugbare ord fra varenavnet.
    final fallback = _fallbackIngredient(name);
    if (fallback.isNotEmpty) {
      return fallback;
    }

    // Til sidst prøves kategorien som fallback.
    return _fallbackIngredient(category);
  }

  // Parser API-svar som JSON-objekt.
  Map<String, dynamic> _decodeJsonObject(String responseBody) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw const RecipeLookupException('TheMealDB returned invalid JSON');
    }
    return decoded;
  }

  // Læser op til 20 ingrediens- og mængdefelter fra TheMealDB.
  List<String> _readIngredients(Map<String, dynamic> meal) {
    final ingredients = <String>[];
    for (var index = 1; index <= 20; index += 1) {
      final ingredient = _readString(meal['strIngredient$index']);
      if (ingredient == null) {
        continue;
      }

      // Målet tilføjes foran ingrediensen, hvis det findes.
      final measure = _readString(meal['strMeasure$index']);
      ingredients.add(measure == null ? ingredient : '$measure $ingredient');
    }

    return ingredients;
  }

  // Gør ingrediens klar til TheMealDB-query.
  String _normalizeIngredientQuery(String value) {
    return _normalize(
      value,
    ).split(RegExp(r'[^a-z0-9]+')).where((word) => word.isNotEmpty).join('_');
  }

  // Finder første brugbare ord som fallback-ingrediens.
  String _fallbackIngredient(String value) {
    final words = _normalize(value)
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.length >= 3)
        .where((word) => !_ignoredFallbackWords.contains(word))
        .toList();

    return words.isEmpty ? '' : words.first;
  }

  // Normaliserer tekst, så danske bogstaver kan matches stabilt.
  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('å', 'aa')
        .replaceAll('ä', 'ae')
        .replaceAll('æ', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ø', 'oe');
  }

  // Returnerer kun ikke-tomme strings.
  String? _readString(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }
}

// Binder mulige ord fra køleskabet sammen med en API-ingrediens.
class _IngredientKeyword {
  const _IngredientKeyword(this.words, this.ingredient);

  final List<String> words;
  final String ingredient;
}

// Keywords der hjælper appen med at oversætte danske varer til TheMealDB.
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

// Ord der ikke er gode som fallback-ingrediens.
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
