import 'package:flutter/material.dart';

import '../services/push_notification_service.dart';

// Skærmen viser og aktiverer push-notifikationer for brugeren.
class PushNotificationsScreen extends StatefulWidget {
  const PushNotificationsScreen({super.key, required this.userId});

  // Brugerens id bruges, når FCM-tokenen gemmes på brugeren.
  final String userId;

  @override
  State<PushNotificationsScreen> createState() =>
      _PushNotificationsScreenState();
}

class _PushNotificationsScreenState extends State<PushNotificationsScreen> {
  // PushNotificationService håndterer registrering og seneste resultat.
  final _service = PushNotificationService.instance;

  // Indeholder resultatet fra den seneste push-registrering.
  PushRegistrationResult? _result;

  // Bruges til at vise loading og deaktivere knappen under registrering.
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();

    // Viser sidste kendte resultat, hvis brugeren allerede har prøvet før.
    _result = _service.lastResult;
  }

  // Registrerer brugeren til push og gemmer resultatet i state.
  Future<void> _register() async {
    setState(() {
      _isRegistering = true;
    });

    // Kalder servicen, som henter og gemmer FCM-tokenen.
    final result = await _service.registerForUser(widget.userId);

    if (!mounted) {
      return;
    }

    // Opdaterer UI med registreringsresultatet.
    setState(() {
      _result = result;
      _isRegistering = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final colorScheme = Theme.of(context).colorScheme;

    // Scaffold viser forklaring, aktiveringsknap og status.
    return Scaffold(
      appBar: AppBar(title: const Text('Push-notifikationer')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Ikonet skifter alt efter om push er registreret.
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
          // Titel for push-opsætningen.
          Text(
            'Push setup',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          // Forklarer hvad push-tokenen bruges til.
          const Text(
            'Aktiver push for at gemme en FCM-token på din bruger. Tokenen kan bruges af Firebase Functions eller en backend til at sende rigtige push-beskeder.',
          ),
          const SizedBox(height: 20),
          // Knappen starter registrering til push.
          FilledButton.icon(
            onPressed: _isRegistering ? null : _register,
            icon: const Icon(Icons.notification_add_outlined),
            label: Text(_isRegistering ? 'Registrerer...' : 'Aktiver push'),
          ),
          // Statuspanelet vises kun, når der findes et resultat.
          if (result != null) ...[
            const SizedBox(height: 20),
            _StatusPanel(result: result),
          ],
          const SizedBox(height: 20),
          // Note om at server-push kræver backend eller Cloud Function.
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

// Viser resultatet af push-registreringen.
class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.result});

  final PushRegistrationResult result;

  @override
  Widget build(BuildContext context) {
    // Tokenen kan være null, hvis registreringen ikke lykkedes.
    final token = result.token;

    // Kort med status, besked og eventuel token.
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
            // Viser om registreringen lykkedes.
            Text(
              result.isRegistered ? 'Registreret' : 'Ikke registreret',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            // Forklarende besked fra servicen.
            Text(result.message),
            if (token != null) ...[
              const SizedBox(height: 12),
              // Viser tokenen kortet ned, så UI ikke bliver for bredt.
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
