import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_tracker/services/open_food_facts_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OpenFoodFactsService', () {
    test('fetches product data by barcode', () async {
      final service = OpenFoodFactsService(
        client: MockClient((request) async {
          expect(request.url.host, 'world.openfoodfacts.org');
          expect(request.url.path, '/api/v2/product/123456789.json');
          expect(request.url.queryParameters['fields'], contains('image_url'));
          expect(
            request.headers['User-Agent'],
            'FridgeTracker/1.0 (student project)',
          );

          return http.Response(
            jsonEncode({
              'status': 1,
              'product': {
                'product_name_da': 'Dansk yoghurt',
                'product_name': 'Yogurt',
                'categories': 'Mejeri, Yoghurt',
                'image_url': 'https://example.com/yogurt.jpg',
              },
            }),
            200,
          );
        }),
      );

      final product = await service.findByBarcode('123456789');

      expect(product.barcode, '123456789');
      expect(product.name, 'Dansk yoghurt');
      expect(product.category, 'Mejeri');
      expect(product.imageUrl, 'https://example.com/yogurt.jpg');
    });

    test('falls back to generic name and category tags', () async {
      final service = OpenFoodFactsService(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'status': 1,
              'product': {
                'generic_name': 'Canned tomatoes',
                'categories_tags': ['en:vegetables', 'en:tomatoes'],
              },
            }),
            200,
          );
        }),
      );

      final product = await service.findByBarcode('987');

      expect(product.name, 'Canned tomatoes');
      expect(product.category, 'vegetables');
      expect(product.imageUrl, isNull);
    });

    test('throws when product is not found', () async {
      final service = OpenFoodFactsService(
        client: MockClient((request) async {
          return http.Response(jsonEncode({'status': 0}), 200);
        }),
      );

      await expectLater(
        service.findByBarcode('missing'),
        throwsA(
          isA<ProductLookupException>().having(
            (error) => error.message,
            'message',
            'Produktet blev ikke fundet',
          ),
        ),
      );
    });

    test('throws when Open Food Facts returns an error status', () async {
      final service = OpenFoodFactsService(
        client: MockClient((request) async {
          return http.Response('Service unavailable', 503);
        }),
      );

      await expectLater(
        service.findByBarcode('123'),
        throwsA(
          isA<ProductLookupException>().having(
            (error) => error.message,
            'message',
            contains('status 503'),
          ),
        ),
      );
    });
  });
}
