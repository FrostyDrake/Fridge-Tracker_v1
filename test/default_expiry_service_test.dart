import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_tracker/services/default_expiry_service.dart';

void main() {
  group('DefaultExpiryService', () {
    const daysByCategory = {
      'k\u00f8d': 4,
      'fjerkr\u00e6': 3,
      'fisk og skaldyr': 2,
      'mejeri': 14,
      'gr\u00f8ntsager': 14,
    };

    test('uses direct category match', () {
      final days = DefaultExpiryService.daysForSync(
        name: 'Arla m\u00e6lk',
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

    test('uses category substring matches from normalized category text', () {
      final days = DefaultExpiryService.daysForSync(
        name: 'Spidsk\u00e5l',
        category: 'Friske gr\u00f8ntsager',
        daysByCategory: daysByCategory,
      );

      expect(days, 14);
    });

    test('falls back when no category or keyword matches', () {
      final days = DefaultExpiryService.daysForSync(
        name: 'Mystery item',
        category: 'Ukendt',
        daysByCategory: daysByCategory,
      );

      expect(days, DefaultExpiryService.fallbackDays);
    });

    testWidgets('loads local JSON asset and returns a date from midnight', (
      tester,
    ) async {
      final service = DefaultExpiryService();

      final expiryDate = await service.expiryDateFor(
        name: 'Arla minim\u00e6lk',
        category: 'mejeri',
        now: DateTime(2026, 6, 14, 21, 45),
      );

      expect(expiryDate, DateTime(2026, 6, 28));
    });
  });
}
