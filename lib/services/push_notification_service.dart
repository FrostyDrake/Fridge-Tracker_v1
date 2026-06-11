import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'expiry_notification_service.dart';
import 'firestore_database.dart';

enum PushRegistrationStatus {
  registered,
  permissionDenied,
  tokenUnavailable,
  failed,
}

class PushRegistrationResult {
  const PushRegistrationResult({
    required this.status,
    required this.message,
    this.token,
  });

  final PushRegistrationStatus status;
  final String message;
  final String? token;

  bool get isRegistered => status == PushRegistrationStatus.registered;
}

class PushNotificationService {
  PushNotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _firestore = firestore ?? FirestoreDatabase.instance;

  static final instance = PushNotificationService();

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  String? _activeUserId;
  String? _lastToken;
  PushRegistrationResult? _lastResult;

  PushRegistrationResult? get lastResult => _lastResult;
  String? get lastToken => _lastToken;

  Future<void> initialize() async {
    _foregroundMessageSubscription ??= FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );
  }

  Future<PushRegistrationResult> registerForUser(String userId) async {
    await initialize();

    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) {
      return _remember(
        const PushRegistrationResult(
          status: PushRegistrationStatus.failed,
          message: 'Mangler bruger-id til push-registrering.',
        ),
      );
    }

    _activeUserId = trimmedUserId;

    final permission = await _requestPermission();
    if (!permission) {
      return _remember(
        const PushRegistrationResult(
          status: PushRegistrationStatus.permissionDenied,
          message: 'Push-tilladelse blev ikke givet.',
        ),
      );
    }

    final token = await _readToken();
    if (token == null || token.isEmpty) {
      return _remember(
        const PushRegistrationResult(
          status: PushRegistrationStatus.tokenUnavailable,
          message:
              'FCM-token kunne ikke hentes. På web kræver det normalt VAPID/service worker opsætning.',
        ),
      );
    }

    await _storeToken(userId: trimmedUserId, token: token);
    _listenForTokenRefresh();

    return _remember(
      PushRegistrationResult(
        status: PushRegistrationStatus.registered,
        message: 'Push er registreret for denne bruger.',
        token: token,
      ),
    );
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _foregroundMessageSubscription = null;
    _activeUserId = null;
  }

  PushRegistrationResult _remember(PushRegistrationResult result) {
    _lastResult = result;
    _lastToken = result.token;
    debugPrint('Push registration: ${result.message}');
    return result;
  }

  Future<bool> _requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (error) {
      debugPrint('Push permission request failed: $error');
      return false;
    }
  }

  Future<String?> _readToken() async {
    try {
      return await _messaging.getToken();
    } catch (error) {
      debugPrint('Could not read FCM token: $error');
      return null;
    }
  }

  void _listenForTokenRefresh() {
    _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen((token) {
      final userId = _activeUserId;
      if (userId == null) {
        return;
      }
      _lastToken = token;
      unawaited(_storeToken(userId: userId, token: token));
    });
  }

  Future<void> _storeToken({
    required String userId,
    required String token,
  }) async {
    final tokenId = base64Url.encode(utf8.encode(token)).replaceAll('=', '');
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('fcmTokens')
        .doc(tokenId)
        .set({
          'token': token,
          'platform': _platformName,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final title =
        message.notification?.title ??
        message.data['title']?.toString() ??
        'Fridge Tracker';
    final body =
        message.notification?.body ??
        message.data['body']?.toString() ??
        'Du har en ny besked.';

    await ExpiryNotificationService.instance.showImmediate(
      title: title,
      body: body,
      payload: message.messageId,
    );
  }

  String get _platformName {
    if (kIsWeb) {
      return 'web';
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }
}
