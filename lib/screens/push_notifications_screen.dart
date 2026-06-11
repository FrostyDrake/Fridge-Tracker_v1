import 'package:flutter/material.dart';

import '../services/push_notification_service.dart';

class PushNotificationsScreen extends StatefulWidget {
  const PushNotificationsScreen({super.key, required this.userId});

  final String userId;

  @override
  State<PushNotificationsScreen> createState() =>
      _PushNotificationsScreenState();
}

class _PushNotificationsScreenState extends State<PushNotificationsScreen> {
  final _service = PushNotificationService.instance;

  PushRegistrationResult? _result;
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    _result = _service.lastResult;
  }

  Future<void> _register() async {
    setState(() {
      _isRegistering = true;
    });

    final result = await _service.registerForUser(widget.userId);

    if (!mounted) {
      return;
    }

    setState(() {
      _result = result;
      _isRegistering = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Push-notifikationer')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            result?.isRegistered == true
                ? Icons.notifications_active_outlined
                : Icons.notifications_outlined,
            size: 56,
            color: result?.isRegistered == true
                ? Colors.green
                : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Push setup',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aktiver push for at gemme en FCM-token på din bruger. Tokenen kan bruges af Firebase Functions eller en backend til at sende rigtige push-beskeder.',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isRegistering ? null : _register,
            icon: const Icon(Icons.notification_add_outlined),
            label: Text(_isRegistering ? 'Registrerer...' : 'Aktiver push'),
          ),
          if (result != null) ...[
            const SizedBox(height: 20),
            _StatusPanel(result: result),
          ],
          const SizedBox(height: 20),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Bemærk: Appen kan nu modtage FCM og gemme tokens. Selve afsendelsen af server-push kræver stadig en Cloud Function eller en anden sikker backend.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.result});

  final PushRegistrationResult result;

  @override
  Widget build(BuildContext context) {
    final token = result.token;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.isRegistered ? 'Registreret' : 'Ikke registreret',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(result.message),
            if (token != null) ...[
              const SizedBox(height: 12),
              Text('Token', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              SelectableText(
                token.length <= 48 ? token : '${token.substring(0, 48)}...',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
