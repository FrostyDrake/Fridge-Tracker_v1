import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_tracker/services/ocr_product_service.dart';

void main() {
  group('OcrProductService', () {
    final service = OcrProductService();

    test('recognizes known product keywords and expiry date', () {
      final suggestion = service.analyzeText(
        'Arla\nMinimælk\nBedst før 12/06/2026',
      );

      expect(suggestion.name, 'Arla mælk');
      expect(suggestion.category, 'mejeri');
      expect(suggestion.expiryDate, DateTime(2026, 6, 12));
      expect(suggestion.confidence, greaterThanOrEqualTo(0.9));
    });

    test('uses likely product line when no keyword matches', () {
      final suggestion = service.analyzeText(
        'Super Crunch Granola\n500 g\nEnergi 1800 kJ\nBedst før 20-07-2026',
      );

      expect(suggestion.name, 'Super Crunch Granola');
      expect(suggestion.category, 'Ukendt');
      expect(suggestion.alternativeNames, contains('Super Crunch Granola'));
      expect(suggestion.expiryDate, DateTime(2026, 7, 20));
    });
  });
}
