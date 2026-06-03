import 'dart:convert';

import 'package:http/http.dart' as http;

class OpenFoodFactsProduct {
  const OpenFoodFactsProduct({
    required this.barcode,
    required this.name,
    required this.category,
    this.imageUrl,
  });

  final String barcode;
  final String name;
  final String category;
  final String? imageUrl;
}

class ProductLookupException implements Exception {
  const ProductLookupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OpenFoodFactsService {
  OpenFoodFactsService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<OpenFoodFactsProduct> findByBarcode(String barcode) async {
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

    final response = await _client.get(
      uri,
      headers: {'User-Agent': 'FridgeTracker/1.0 (student project)'},
    );

    if (response.statusCode != 200) {
      throw ProductLookupException(
        'Open Food Facts svarede med status ${response.statusCode}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['status'] == 0 || body['product'] is! Map<String, dynamic>) {
      throw const ProductLookupException('Produktet blev ikke fundet');
    }

    final product = body['product'] as Map<String, dynamic>;
    return OpenFoodFactsProduct(
      barcode: barcode,
      name: _readName(product, barcode),
      category: _readCategory(product),
      imageUrl: _readString(product['image_url']),
    );
  }

  String _readName(Map<String, dynamic> product, String barcode) {
    return _readString(product['product_name_da']) ??
        _readString(product['product_name']) ??
        _readString(product['generic_name']) ??
        'Stregkode $barcode';
  }

  String _readCategory(Map<String, dynamic> product) {
    final categories = _readString(product['categories']);
    if (categories != null) {
      return categories.split(',').first.trim();
    }

    final tags = product['categories_tags'];
    if (tags is List && tags.isNotEmpty) {
      final tag = tags.first.toString();
      return tag.contains(':') ? tag.split(':').last : tag;
    }

    return 'Ukendt';
  }

  String? _readString(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }
}
