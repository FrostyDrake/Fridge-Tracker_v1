import 'dart:convert';

import 'package:flutter/services.dart';

class DefaultExpiryService {
  DefaultExpiryService({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static final instance = DefaultExpiryService();
  static const fallbackDays = 7;

  final AssetBundle _bundle;
  Future<Map<String, int>>? _daysByCategoryFuture;

  Future<int> daysFor({required String name, required String category}) async {
    final daysByCategory = await _loadDaysByCategory();
    return daysForSync(
      name: name,
      category: category,
      daysByCategory: daysByCategory,
    );
  }

  Future<DateTime> expiryDateFor({
    required String name,
    required String category,
    DateTime? now,
  }) async {
    final days = await daysFor(name: name, category: category);
    final base = now ?? DateTime.now();
    return DateTime(base.year, base.month, base.day).add(Duration(days: days));
  }

  static int daysForSync({
    required String name,
    required String category,
    required Map<String, int> daysByCategory,
  }) {
    final normalizedDays = {
      for (final entry in daysByCategory.entries)
        _normalize(entry.key): entry.value,
    };

    final normalizedCategory = _normalize(category);
    final directCategoryDays = normalizedDays[normalizedCategory];
    if (directCategoryDays != null) {
      return directCategoryDays;
    }

    for (final entry in normalizedDays.entries) {
      if (normalizedCategory.contains(entry.key)) {
        return entry.value;
      }
    }

    final normalizedText = _normalize('$name $category');
    for (final keyword in _categoryKeywords) {
      if (keyword.words.any(normalizedText.contains)) {
        final days = normalizedDays[keyword.category];
        if (days != null) {
          return days;
        }
      }
    }

    return fallbackDays;
  }

  Future<Map<String, int>> _loadDaysByCategory() {
    return _daysByCategoryFuture ??= _readDaysByCategory();
  }

  Future<Map<String, int>> _readDaysByCategory() async {
    final rawJson = await _bundle.loadString('data/default_expiry_days.json');
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      return const {};
    }

    return decoded.map((key, value) {
      final days = value is num ? value.toInt() : fallbackDays;
      return MapEntry(key, days);
    });
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('å', 'aa')
        .replaceAll('ä', 'ae')
        .replaceAll('æ', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ø', 'oe');
  }
}

class _CategoryKeyword {
  const _CategoryKeyword(this.words, this.category);

  final List<String> words;
  final String category;
}

const _categoryKeywords = [
  _CategoryKeyword(['kylling', 'chicken', 'fjerkrae', 'poultry'], 'fjerkrae'),
  _CategoryKeyword(['okse', 'beef', 'svin', 'pork', 'koed', 'meat'], 'koed'),
  _CategoryKeyword([
    'fisk',
    'laks',
    'salmon',
    'tuna',
    'seafood',
  ], 'fisk og skaldyr'),
  _CategoryKeyword([
    'maelk',
    'milk',
    'yoghurt',
    'yogurt',
    'ost',
    'cheese',
  ], 'mejeri'),
  _CategoryKeyword([
    'tomat',
    'agurk',
    'salat',
    'groent',
    'vegetable',
  ], 'groentsager'),
  _CategoryKeyword([
    'aeble',
    'apple',
    'banan',
    'banana',
    'frugt',
    'fruit',
  ], 'frugt'),
  _CategoryKeyword(['juice', 'soda', 'vand', 'water', 'drik'], 'drikkevare'),
  _CategoryKeyword(['ris', 'rice', 'pasta', 'broed', 'bread', 'korn'], 'korn'),
  _CategoryKeyword(['boenne', 'beans', 'linse', 'lentil'], 'baelgfrugter'),
  _CategoryKeyword(['noed', 'nut', 'froe', 'seed'], 'noedder og froe'),
  _CategoryKeyword(['olie', 'oil', 'smoer', 'butter'], 'fedtstoffer og olier'),
  _CategoryKeyword(['slik', 'sugar', 'sukker', 'candy'], 'slik og sukker'),
  _CategoryKeyword(['krydderi', 'urter', 'spice', 'herb'], 'krydderi og urter'),
];
