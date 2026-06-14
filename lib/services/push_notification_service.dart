import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'expiry_notification_service.dart';
import 'firestore_database.dart';

// Status for forsøg på at registrere push-notifikationer.
enum PushRegistrationStatus {
  registered,
  permissionDenied,
  tokenUnavailable,
  failed,
}

// Resultat der fortæller UI'et om push-registreringen lykkedes.
class PushRegistrationResult {
  const PushRegistrationResult({
    required this.status,
    required this.message,
    this.token,
  });

  final PushRegistrationStatus status;
  final String message;
  final String? token;

  // True når FCM-tokenen blev hentet og gemt.
  bool get isRegistered => status == PushRegistrationStatus.registered;
}

// Service der håndterer Firebase Cloud Messaging og gemmer FCM-token.
class PushNotificationService {
  PushNotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _firestore = firestore ?? FirestoreDatabase.instance;

  // Singleton bruges på tværs af appen.
  static final instance = PushNotificationService();

  // Firebase Messaging henter tokens og modtager push-beskeder.
  final FirebaseMessaging _messaging;

  // Firestore bruges til at gemme brugerens token.
  final FirebaseFirestore _firestore;

  // Subscriptions holdes her, så de ikke oprettes flere gange.
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  // Aktiv bruger bruges, når tokenen senere bliver opdateret.
  String? _activeUserId;

  // Seneste token og resultat bruges af UI'et.
  String? _lastToken;
  PushRegistrationResult? _lastResult;

  PushRegistrationResult? get lastResult => _lastResult;
  String? get lastToken => _lastToken;

  // Lytter efter push-beskeder, mens appen er åben.
  Future<void> initialize() async {
    _foregroundMessageSubscription ??= FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );
  }

  // Registrerer push for en bestemt bruger.
  Future<PushRegistrationResult> registerForUser(String userId) async {
    await initialize();

    // Tomt bruger-id kan ikke gemmes i Firestore.
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) {
      return _remember(
        const PushRegistrationResult(
          status: PushRegistrationStatus.failed,
          message: 'Mangler bruger-id til push-registrering.',
        ),
      );
    }

    // Gemmer aktiv bruger, så token refresh kan opdatere den rigtige bruger.
    _activeUserId = trimmedUserId;

    // Først skal brugeren give tilladelse.
    final permission = await _requestPermission();
    if (!permission) {
      return _remember(
        const PushRegistrationResult(
          status: PushRegistrationStatus.permissionDenied,
          message: 'Push-tilladelse blev ikke givet.',
        ),
      );
    }

    // Derefter hentes FCM-tokenen.
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

    // Token gemmes i Firestore og opdateres senere ved refresh.
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

  // Stopper listeners, hvis servicen skal ryddes op.
  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _foregroundMessageSubscription = null;
    _activeUserId = null;
  }

  // Gemmer seneste resultat og skriver det i debug-loggen.
  PushRegistrationResult _remember(PushRegistrationResult result) {
    _lastResult = result;
    _lastToken = result.token;
    debugPrint('Push registration: ${result.message}');
    return result;
  }

  // Spørger Firebase Messaging om push-tilladelse.
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

      // Authorized og provisional regnes som tilladt.
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (error) {
      debugPrint('Push permission request failed: $error');
      return false;
    }
  }

  // Henter FCM-tokenen, hvis platformen kan levere den.
  Future<String?> _readToken() async {
    try {
      return await _messaging.getToken();
    } catch (error) {
      debugPrint('Could not read FCM token: $error');
      return null;
    }
  }

  // Lytter på token-refresh, så Firestore altid har nyeste token.
  void _listenForTokenRefresh() {
    _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen((token) {
      final userId = _activeUserId;
      if (userId == null) {
        return;
      }
      // Gemmer ny token uden at blokere UI'et.
      _lastToken = token;
      unawaited(_storeToken(userId: userId, token: token));
    });
  }

  // Gemmer tokenen under users/{uid}/fcmTokens.
  Future<void> _storeToken({
    required String userId,
    required String token,
  }) async {
    // Token bruges som dokument-id i base64url-format.
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

  // Viser foreground push som en lokal notifikation.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // Bruger notification-data først og fallback til data-payload.
    final title =
        message.notification?.title ??
        message.data['title']?.toString() ??
        'Fridge Tracker';
    final body =
        message.notification?.body ??
        message.data['body']?.toString() ??
        'Du har en ny besked.';

    // Lokale notifikationer bruges, når appen allerede er åben.
    await ExpiryNotificationService.instance.showImmediate(
      title: title,
      body: body,
      payload: message.messageId,
    );
  }

  // Gemmer hvilken platform tokenen kom fra.
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
