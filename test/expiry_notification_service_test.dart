import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_tracker/services/expiry_notification_service.dart';

void main() {
  group('ExpiryNotificationService', () {
    test('schedules future reminder two days before expiry at 09:00', () {
      final plans = ExpiryNotificationService.buildReminderPlans(
        now: DateTime(2026, 6, 9, 10),
        items: [
          ExpiryNotificationItem(
            id: 'milk-1',
            name: 'M\u00e6lk',
            expiryDate: DateTime(2026, 6, 14),
          ),
        ],
      );

      expect(plans, hasLength(1));
      expect(plans.single.scheduledAt, DateTime(2026, 6, 12, 9));
      expect(plans.single.body, 'M\u00e6lk udl\u00f8ber om 2 dage.');
      expect(plans.single.payload, 'fridge_item:milk-1');
    });

    test('schedules soon when item is already inside reminder window', () {
      final plans = ExpiryNotificationService.buildReminderPlans(
        now: DateTime(2026, 6, 9, 10),
        items: [
          ExpiryNotificationItem(
            id: 'chicken-1',
            name: 'Kylling',
            expiryDate: DateTime(2026, 6, 10),
          ),
        ],
      );

      expect(plans, hasLength(1));
      expect(plans.single.scheduledAt, DateTime(2026, 6, 9, 10, 1));
      expect(plans.single.body, 'Kylling udl\u00f8ber i morgen.');
    });

    test('skips expired items', () {
      final plans = ExpiryNotificationService.buildReminderPlans(
        now: DateTime(2026, 6, 9, 10),
        items: [
          ExpiryNotificationItem(
            id: 'old-1',
            name: 'Gammel ost',
            expiryDate: DateTime(2026, 6, 8),
          ),
        ],
      );

      expect(plans, isEmpty);
    });

    test('uses stable notification ids for same item id', () {
      final first = ExpiryNotificationService.notificationIdForItem('abc');
      final second = ExpiryNotificationService.notificationIdForItem('abc');
      final other = ExpiryNotificationService.notificationIdForItem('xyz');

      expect(first, second);
      expect(first, isNot(other));
    });
  });
}
