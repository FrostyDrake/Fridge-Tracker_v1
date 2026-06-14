import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_tracker/services/ocr_product_service.dart';

void main() {
  group('OcrProductService', () {
    final service = OcrProductService();

    test('recognizes known product keywords and expiry date', () {
      final suggestion = service.analyzeText(
        'Arla\nMinim\u00e6lk\nBedst f\u00f8r 12/06/2026',
      );

      expect(suggestion.name, 'Arla m\u00e6lk');
      expect(suggestion.category, 'mejeri');
      expect(suggestion.expiryDate, DateTime(2026, 6, 12));
      expect(suggestion.confidence, greaterThanOrEqualTo(0.9));
    });

    test('uses likely product line when no keyword matches', () {
      final suggestion = service.analyzeText(
        'Super Crunch Granola\n500 g\nEnergi 1800 kJ\n'
        'Bedst f\u00f8r 20-07-2026',
      );

      expect(suggestion.name, 'Super Crunch Granola');
      expect(suggestion.category, 'Ukendt');
      expect(suggestion.alternativeNames, contains('Super Crunch Granola'));
      expect(suggestion.expiryDate, DateTime(2026, 7, 20));
    });

    test('filters nutrition and package noise from fallback names', () {
      final suggestion = service.analyzeText(
        '500 g\nEnergi 900 kJ\nClassic Hummus\nBatch 42\n'
        'Bedst f\u00f8r 31/12/2026',
      );

      expect(suggestion.name, 'Classic Hummus');
      expect(suggestion.alternativeNames, contains('Classic Hummus'));
      expect(suggestion.alternativeNames, isNot(contains('500 g')));
      expect(suggestion.alternativeNames, isNot(contains('Energi 900 kJ')));
      expect(suggestion.expiryDate, DateTime(2026, 12, 31));
    });

    test('parses year-first dates and ignores implausible dates', () {
      final suggestion = service.analyzeText(
        'Laks\nProduceret 2099-01-01\nSidste anvendelse 2026-08-03',
      );

      expect(suggestion.name, 'Laks');
      expect(suggestion.category, 'fisk');
      expect(suggestion.expiryDate, DateTime(2026, 8, 3));
    });
  });
}
