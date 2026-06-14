import 'dart:convert';

import 'package:http/http.dart' as http;

// Model for et produkt hentet fra Open Food Facts.
class OpenFoodFactsProduct {
  const OpenFoodFactsProduct({
    required this.barcode,
    required this.name,
    required this.category,
    this.imageUrl,
  });

  // Stregkoden der blev slået op.
  final String barcode;

  // Produktnavn, kategori og eventuelt billede.
  final String name;
  final String category;
  final String? imageUrl;
}

// Exception bruges når produktopslag fejler.
class ProductLookupException implements Exception {
  const ProductLookupException(this.message);

  final String message;

  @override
  String toString() => message;
}

// Service der slår stregkoder op i Open Food Facts API'et.
class OpenFoodFactsService {
  OpenFoodFactsService({http.Client? client})
    : _client = client ?? http.Client();

  // HTTP-client kan erstattes i tests.
  final http.Client _client;

  // Finder et produkt ud fra en stregkode.
  Future<OpenFoodFactsProduct> findByBarcode(String barcode) async {
    // API'et får kun de felter, som appen faktisk bruger.
    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v2/product/$barcode.json',
      {
        'fields': [
          'product_name_da',
          'product_name',
          'generic_name',
          'categories',
          'categories_tags',
          'image_url',
        ].join(','),
      },
    );

    // User-Agent fortæller API'et hvem der kalder.
    final response = await _client.get(
      uri,
      headers: {'User-Agent': 'FridgeTracker/1.0 (student project)'},
    );

    // Ikke-200 betyder at API'et ikke svarede korrekt.
    if (response.statusCode != 200) {
      throw ProductLookupException(
        'Open Food Facts svarede med status ${response.statusCode}',
      );
    }

    // Body parses som JSON og skal indeholde et product-objekt.
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['status'] == 0 || body['product'] is! Map<String, dynamic>) {
      throw const ProductLookupException('Produktet blev ikke fundet');
    }

    // Mapper API-data til appens egen produktmodel.
    final product = body['product'] as Map<String, dynamic>;
    return OpenFoodFactsProduct(
      barcode: barcode,
      name: _readName(product, barcode),
      category: _readCategory(product),
      imageUrl: _readString(product['image_url']),
    );
  }

  // Vælger det bedste tilgængelige navn fra API'et.
  String _readName(Map<String, dynamic> product, String barcode) {
    return _readString(product['product_name_da']) ??
        _readString(product['product_name']) ??
        _readString(product['generic_name']) ??
        'Stregkode $barcode';
  }

  // Læser kategori fra enten categories eller categories_tags.
  String _readCategory(Map<String, dynamic> product) {
    final categories = _readString(product['categories']);
    if (categories != null) {
      return categories.split(',').first.trim();
    }

    // Tags kan være skrevet som fx en:beverages.
    final tags = product['categories_tags'];
    if (tags is List && tags.isNotEmpty) {
      final tag = tags.first.toString();
      return tag.contains(':') ? tag.split(':').last : tag;
    }

    return 'Ukendt';
  }

  // Returnerer kun ikke-tomme strings.
  String? _readString(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }
}
