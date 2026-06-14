import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_tracker/services/recipe_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('RecipeService', () {
    test('maps common Danish fridge items to recipe ingredients', () {
      final service = RecipeService();

      expect(
        service.ingredientFromFridgeItem(
          name: 'Arla minim\u00e6lk',
          category: 'mejeri',
        ),
        'milk',
      );
      expect(
        service.ingredientFromFridgeItem(
          name: 'Kyllingebryst',
          category: 'k\u00f8d',
        ),
        'chicken',
      );
      expect(
        service.ingredientFromFridgeItem(
          name: 'Friske \u00e6g',
          category: '\u00e6g',
        ),
        'eggs',
      );
      expect(
        service.ingredientFromFridgeItem(
          name: 'Hvidl\u00f8g',
          category: 'gr\u00f8nt',
        ),
        'garlic',
      );
    });

    test('falls back to the first useful product word', () {
      final service = RecipeService();

      expect(
        service.ingredientFromFridgeItem(
          name: 'Rema mini organic squash',
          category: 'Ukendt',
        ),
        'squash',
      );
    });

    test('fetches recipes by ingredient', () async {
      final service = RecipeService(
        client: MockClient((request) async {
          expect(request.url.host, 'www.themealdb.com');
          expect(request.url.path, '/api/json/v1/1/filter.php');
          expect(request.url.queryParameters['i'], 'chicken_breast');

          return http.Response(
            jsonEncode({
              'meals': [
                {
                  'idMeal': '52772',
                  'strMeal': 'Teriyaki Chicken Casserole',
                  'strMealThumb': 'https://example.com/meal.jpg',
                },
              ],
            }),
            200,
          );
        }),
      );

      final recipes = await service.findByIngredient('chicken breast');

      expect(recipes, hasLength(1));
      expect(recipes.single.id, '52772');
      expect(recipes.single.name, 'Teriyaki Chicken Casserole');
      expect(recipes.single.thumbnailUrl, 'https://example.com/meal.jpg');
    });

    test('filters incomplete recipe rows and respects the limit', () async {
      final service = RecipeService(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'meals': [
                {'idMeal': '1', 'strMeal': 'Tomato Pasta'},
                {'idMeal': '2'},
                {'strMeal': 'No id'},
                {'idMeal': '3', 'strMeal': 'Tomato Soup'},
                {'idMeal': '4', 'strMeal': 'Tomato Salad'},
              ],
            }),
            200,
          );
        }),
      );

      final recipes = await service.findByIngredient('tomato', limit: 2);

      expect(recipes.map((recipe) => recipe.id), ['1', '3']);
    });

    test('returns empty list when ingredient has no meals', () async {
      final service = RecipeService(
        client: MockClient((request) async {
          return http.Response(jsonEncode({'meals': null}), 200);
        }),
      );

      final recipes = await service.findByIngredient('granola');

      expect(recipes, isEmpty);
    });

    test('throws a readable exception when recipe search fails', () async {
      final service = RecipeService(
        client: MockClient((request) async {
          return http.Response('Server error', 500);
        }),
      );

      await expectLater(
        service.findByIngredient('milk'),
        throwsA(
          isA<RecipeLookupException>().having(
            (error) => error.message,
            'message',
            contains('status 500'),
          ),
        ),
      );
    });

    test('fetches recipe details', () async {
      final service = RecipeService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/json/v1/1/lookup.php');
          expect(request.url.queryParameters['i'], '52772');

          return http.Response(
            jsonEncode({
              'meals': [
                {
                  'idMeal': '52772',
                  'strMeal': 'Teriyaki Chicken Casserole',
                  'strCategory': 'Chicken',
                  'strArea': 'Japanese',
                  'strInstructions': 'Cook everything together.',
                  'strMealThumb': 'https://example.com/meal.jpg',
                  'strSource': 'https://example.com/source',
                  'strYoutube': 'https://example.com/video',
                  'strIngredient1': 'Chicken',
                  'strMeasure1': '2 pieces',
                  'strIngredient2': 'Rice',
                  'strMeasure2': '1 cup',
                  'strIngredient3': '',
                  'strMeasure3': '',
                },
              ],
            }),
            200,
          );
        }),
      );

      final details = await service.findDetails('52772');

      expect(details.id, '52772');
      expect(details.name, 'Teriyaki Chicken Casserole');
      expect(details.category, 'Chicken');
      expect(details.area, 'Japanese');
      expect(details.ingredients, ['2 pieces Chicken', '1 cup Rice']);
      expect(details.instructions, 'Cook everything together.');
      expect(details.sourceUrl, 'https://example.com/source');
      expect(details.youtubeUrl, 'https://example.com/video');
    });

    test('throws when recipe details are missing', () async {
      final service = RecipeService(
        client: MockClient((request) async {
          return http.Response(jsonEncode({'meals': null}), 200);
        }),
      );

      await expectLater(
        service.findDetails('missing'),
        throwsA(
          isA<RecipeLookupException>().having(
            (error) => error.message,
            'message',
            'Recipe was not found',
          ),
        ),
      );
    });
  });
}
