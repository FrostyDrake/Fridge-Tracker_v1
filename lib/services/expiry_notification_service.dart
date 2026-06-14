import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// Lille model for en vare, som kan få en udløbsnotifikation.
class ExpiryNotificationItem {
  const ExpiryNotificationItem({
    required this.id,
    required this.name,
    required this.expiryDate,
  });

  final String id;
  final String name;
  final DateTime expiryDate;
}

// Plan for én konkret notifikation.
class ExpiryNotificationPlan {
  const ExpiryNotificationPlan({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.payload,
    required this.scheduledAt,
  });

  final int notificationId;
  final String title;
  final String body;
  final String payload;
  final DateTime scheduledAt;
}

// Service der opretter lokale notifikationer om varer, der snart udløber.
class ExpiryNotificationService {
  ExpiryNotificationService._();

  // Singleton bruges, så hele appen deler samme notifikationsservice.
  static final instance = ExpiryNotificationService._();

  // Konstanter til notifikationskanal og planlægning.
  static const _channelId = 'expiry_reminders';
  static const _channelName = 'Udløbsnotifikationer';
  static const _channelDescription =
      'Påmindelser om madvarer der snart udløber.';
  static const _notificationIdBase = 400000;
  static const _notificationIdRange = 1000000000;
  static const _reminderDaysBeforeExpiry = 2;
  static const _fallbackDelay = Duration(minutes: 1);

  // Pluginet sender og planlægger lokale notifikationer.
  final _plugin = FlutterLocalNotificationsPlugin();

  // State der forhindrer dobbelt-initialisering og gentagne synkroniseringer.
  bool _initialized = false;
  bool _initializationFailed = false;
  bool? _permissionsGranted;
  String? _lastSyncKey;

  // Starter notifikationspluginet, hvis platformen understøtter det.
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    if (!_supportsPluginInitialization) {
      // Ikke alle platforme understøtter dette plugin.
      debugPrint('Expiry notifications are not initialized on this platform.');
      return;
    }

    try {
      // Tidszone skal sættes før planlagte notifikationer kan bruges.
      await _configureTimeZone();

      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        web: WebInitializationSettings(),
      );

      await _plugin.initialize(settings: initializationSettings);
    } catch (error, stackTrace) {
      // Fejl gemmes, så appen kan fortsætte uden notifikationer.
      _initializationFailed = true;
      debugPrint('Expiry notification initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // Synkroniserer planlagte udløbsnotifikationer med den aktuelle vareliste.
  Future<void> syncExpiryReminders(List<ExpiryNotificationItem> items) async {
    // Hvis vareliste og datoer er uændrede, springes arbejdet over.
    final syncKey = _syncKey(items);
    if (syncKey == _lastSyncKey) {
      return;
    }
    _lastSyncKey = syncKey;

    await initialize();
    if (_initializationFailed || !_supportsScheduledReminders) {
      // Web understøtter ikke planlagte lokale reminders her.
      return;
    }

    // Notifikationer kræver brugerens tilladelse.
    final permissionsGranted = await requestPermissions();
    if (!permissionsGranted) {
      debugPrint('Expiry notifications skipped: permission was not granted.');
      return;
    }

    // Bygger nye planer og erstatter gamle udløbsreminders.
    final plans = buildReminderPlans(items: items, now: DateTime.now());

    await _cancelExpiryReminders();
    for (final plan in plans) {
      await _schedule(plan);
    }

    debugPrint('Expiry notifications synced: ${plans.length} reminders.');
  }

  // Viser en notifikation med det samme, fx ved foreground push.
  Future<void> showImmediate({
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();
    if (_initializationFailed || !_supportsPluginInitialization) {
      return;
    }

    // Id'et gøres stabilt nok til at undgå simple kollisioner.
    await _plugin.show(
      id: _stableHash('$title:$body:${DateTime.now().millisecondsSinceEpoch}'),
      title: title,
      body: body,
      payload: payload,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        web: WebNotificationDetails(),
      ),
    );
  }

  // Spørger brugeren om notifikationstilladelse.
  Future<bool> requestPermissions() async {
    await initialize();
    if (_initializationFailed) {
      return false;
    }
    if (_permissionsGranted != null) {
      // Tilladelsen caches, så appen ikke spørger igen og igen.
      return _permissionsGranted!;
    }

    if (kIsWeb) {
      // Web har sin egen plugin-implementation.
      final webPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            WebFlutterLocalNotificationsPlugin
          >();
      _permissionsGranted =
          await webPlugin?.requestNotificationsPermission() ?? false;
      return _permissionsGranted!;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android kan kræve runtime-permission til notifikationer.
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        _permissionsGranted =
            await androidPlugin?.requestNotificationsPermission() ?? true;
        return _permissionsGranted!;
      case TargetPlatform.iOS:
        // iOS spørger efter alert, badge og lyd.
        final iosPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        _permissionsGranted =
            await iosPlugin?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
        return _permissionsGranted!;
      case TargetPlatform.macOS:
        // macOS bruger samme type tilladelser som iOS.
        final macPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >();
        _permissionsGranted =
            await macPlugin?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
        return _permissionsGranted!;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        // Disse platforme bruges ikke til reminders i projektet.
        _permissionsGranted = false;
        return false;
    }
  }

  // Bygger reminder-planer for varer, der ikke allerede er udløbet.
  static List<ExpiryNotificationPlan> buildReminderPlans({
    required List<ExpiryNotificationItem> items,
    required DateTime now,
  }) {
    final plans = <ExpiryNotificationPlan>[];
    final today = _dateOnly(now);

    for (final item in items) {
      // Sammenligner kun datoer, ikke klokkeslæt.
      final expiryDate = _dateOnly(item.expiryDate);
      final daysLeft = expiryDate.difference(today).inDays;
      if (daysLeft < 0) {
        continue;
      }

      // Reminder planlægges to dage før udløb kl. 09.
      final reminderDate = expiryDate.subtract(
        const Duration(days: _reminderDaysBeforeExpiry),
      );
      var scheduledAt = DateTime(
        reminderDate.year,
        reminderDate.month,
        reminderDate.day,
        9,
      );

      if (!scheduledAt.isAfter(now)) {
        // Hvis reminder-tidspunktet allerede er passeret, bruges fallback.
        if (daysLeft > _reminderDaysBeforeExpiry) {
          continue;
        }
        scheduledAt = now.add(_fallbackDelay);
      }

      // Teksten beregnes ud fra hvor mange dage der er tilbage ved notifikationen.
      final daysAtNotification = expiryDate
          .difference(_dateOnly(scheduledAt))
          .inDays;

      plans.add(
        ExpiryNotificationPlan(
          notificationId: notificationIdForItem(item.id),
          title: 'Madvarer udløber snart',
          body: _notificationBody(item.name, daysAtNotification),
          payload: 'fridge_item:${item.id}',
          scheduledAt: scheduledAt,
        ),
      );
    }

    // Tidligste notifikation kommer først.
    plans.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return plans;
  }

  // Laver et stabilt notifikations-id ud fra vare-id.
  static int notificationIdForItem(String itemId) {
    return _notificationIdBase + (_stableHash(itemId) % _notificationIdRange);
  }

  // Sætter lokal tidszone for planlagte notifikationer.
  Future<void> _configureTimeZone() async {
    tz_data.initializeTimeZones();

    try {
      // Bruger enhedens lokale tidszone, hvis den kan læses.
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (error) {
      debugPrint('Could not read local timezone for notifications: $error');
    }
  }

  // Fjerner gamle udløbsnotifikationer, før nye planlægges.
  Future<void> _cancelExpiryReminders() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (_isExpiryNotificationId(request.id)) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  // Planlægger én notifikation på et bestemt tidspunkt.
  Future<void> _schedule(ExpiryNotificationPlan plan) {
    return _plugin.zonedSchedule(
      id: plan.notificationId,
      title: plan.title,
      body: plan.body,
      scheduledDate: tz.TZDateTime.from(plan.scheduledAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: plan.payload,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  // Laver en nøgle der beskriver den aktuelle reminder-liste.
  String _syncKey(List<ExpiryNotificationItem> items) {
    final sorted = [...items]
      ..sort((a, b) {
        final idOrder = a.id.compareTo(b.id);
        if (idOrder != 0) {
          return idOrder;
        }
        return a.expiryDate.compareTo(b.expiryDate);
      });

    // Sortering gør nøglen stabil uanset rækkefølgen på items.
    return sorted
        .map(
          (item) =>
              '${item.id}:${item.name}:${_dateOnly(item.expiryDate).toIso8601String()}',
        )
        .join('|');
  }

  // Tjekker om et notifikations-id hører til udløbsreminders.
  static bool _isExpiryNotificationId(int id) {
    return id >= _notificationIdBase &&
        id < _notificationIdBase + _notificationIdRange;
  }

  // Platforme hvor pluginet kan initialiseres.
  bool get _supportsPluginInitialization {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  // Platforme hvor planlagte reminders understøttes i appen.
  bool get _supportsScheduledReminders {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
  }

  // Fjerner klokkeslæt fra en dato.
  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  // Laver brødteksten til reminder-notifikationen.
  static String _notificationBody(String itemName, int daysLeft) {
    if (daysLeft <= 0) {
      return '$itemName udløber i dag.';
    }
    if (daysLeft == 1) {
      return '$itemName udløber i morgen.';
    }
    return '$itemName udløber om $daysLeft dage.';
  }

  // Stabil hash bruges til notifikations-id'er.
  static int _stableHash(String value) {
    const fnvPrime = 16777619;
    const fnvOffset = 2166136261;
    var hash = fnvOffset;

    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0x7fffffff;
    }

    return hash;
  }
}
