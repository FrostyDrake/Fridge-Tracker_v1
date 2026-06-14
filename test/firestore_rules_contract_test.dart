import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firestore rules contract', () {
    late final String rules;

    setUpAll(() {
      rules = File('firestore.rules').readAsStringSync();
    });

    test('keeps personal fridge access scoped to owner or shared members', () {
      expect(rules, contains('request.auth.uid == userId'));
      expect(rules, contains('hasSharedFridgeAccess(ownerUserId)'));
      expect(rules, contains('canUseFridge(userId)'));
      expect(rules, contains('match /items/{itemId}'));
      expect(
        rules,
        contains('allow create, update: if canUseFridge(userId)'),
      );
    });

    test('validates fridge items and known item sources', () {
      expect(rules, contains('validFridgeItem()'));
      expect(rules, contains("'name'"));
      expect(rules, contains("'category'"));
      expect(rules, contains("'expiryDate'"));
      expect(rules, contains("['manual', 'scan', 'barcode']"));
    });

    test('allows storing FCM tokens only under the signed-in user', () {
      expect(rules, contains('match /fcmTokens/{tokenId}'));
      expect(rules, contains('validFcmTokenDocument()'));
      expect(
        rules,
        contains('allow create, update: if ownsUserDocument(userId)'),
      );
    });
  });
}
