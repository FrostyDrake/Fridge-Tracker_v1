import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_tracker/services/default_expiry_service.dart';

void main() {
  group('DefaultExpiryService', () {
    const daysByCategory = {
      'kød': 4,
      'fjerkræ': 3,
      'fisk og skaldyr': 2,
      'mejeri': 14,
      'grøntsager': 14,
    };

    test('uses direct category match', () {
      final days = DefaultExpiryService.daysForSync(
        name: 'Arla mælk',
        category: 'mejeri',
        daysByCategory: daysByCategory,
      );

      expect(days, 14);
    });

    test('maps common product keywords to local categories', () {
      final chickenDays = DefaultExpiryService.daysForSync(
        name: 'Chicken breast',
        category: 'Ukendt',
        daysByCategory: daysByCategory,
      );
      final fishDays = DefaultExpiryService.daysForSync(
        name: 'Laks',
        category: 'Ukendt',
        daysByCategory: daysByCategory,
      );

      expect(chickenDays, 3);
      expect(fishDays, 2);
    });

    test('falls back when no category or keyword matches', () {
      final days = DefaultExpiryService.daysForSync(
        name: 'Mystery item',
        category: 'Ukendt',
        daysByCategory: daysByCategory,
      );

      expect(days, DefaultExpiryService.fallbackDays);
    });
  });
}
