import 'dart:convert';

import 'package:flutter/services.dart';

// Service der finder en standard udløbsdato ud fra varenavn og kategori.
class DefaultExpiryService {
  DefaultExpiryService({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  // Singleton bruges, så samme service kan deles på tværs af appen.
  static final instance = DefaultExpiryService();

  // Fallback bruges, hvis appen ikke kan finde en bedre kategori.
  static const fallbackDays = 7;

  // AssetBundle bruges til at læse JSON-filen med standarddage.
  final AssetBundle _bundle;

  // Cache så JSON-filen kun læses én gang.
  Future<Map<String, int>>? _daysByCategoryFuture;

  // Finder antal dage ud fra navn og kategori.
  Future<int> daysFor({required String name, required String category}) async {
    final daysByCategory = await _loadDaysByCategory();
    return daysForSync(
      name: name,
      category: category,
      daysByCategory: daysByCategory,
    );
  }

  // Laver en konkret udløbsdato baseret på antal standarddage.
  Future<DateTime> expiryDateFor({
    required String name,
    required String category,
    DateTime? now,
  }) async {
    final days = await daysFor(name: name, category: category);
    final base = now ?? DateTime.now();
    return DateTime(base.year, base.month, base.day).add(Duration(days: days));
  }

  // Synkron version som kan testes uden async asset-læsning.
  static int daysForSync({
    required String name,
    required String category,
    required Map<String, int> daysByCategory,
  }) {
    // Normaliserer kategorier, så æ/ø/å og store bogstaver ikke driller.
    final normalizedDays = {
      for (final entry in daysByCategory.entries)
        _normalize(entry.key): entry.value,
    };

    // Prøver først et direkte kategori-match.
    final normalizedCategory = _normalize(category);
    final directCategoryDays = normalizedDays[normalizedCategory];
    if (directCategoryDays != null) {
      return directCategoryDays;
    }

    // Prøver derefter om brugerens kategori indeholder en kendt kategori.
    for (final entry in normalizedDays.entries) {
      if (normalizedCategory.contains(entry.key)) {
        return entry.value;
      }
    }

    // Til sidst søges der efter nøgleord i både navn og kategori.
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

  // Returnerer cached kategori-data eller læser den første gang.
  Future<Map<String, int>> _loadDaysByCategory() {
    return _daysByCategoryFuture ??= _readDaysByCategory();
  }

  // Læser standarddage fra data/default_expiry_days.json.
  Future<Map<String, int>> _readDaysByCategory() async {
    final rawJson = await _bundle.loadString('data/default_expiry_days.json');
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      return const {};
    }

    return decoded.map((key, value) {
      // Hvis en værdi ikke er et tal, bruges fallback.
      final days = value is num ? value.toInt() : fallbackDays;
      return MapEntry(key, days);
    });
  }

  // Gør tekst lettere at sammenligne på tværs af dansk/engelsk stavning.
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

// Lille model der binder nøgleord sammen med en standardkategori.
class _CategoryKeyword {
  const _CategoryKeyword(this.words, this.category);

  final List<String> words;
  final String category;
}

// Nøgleord der hjælper appen med at gætte kategori ud fra varenavn.
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
