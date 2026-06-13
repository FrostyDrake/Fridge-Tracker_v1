import 'package:flutter/material.dart';

import '../services/shared_fridge_service.dart';

// Skærmen bruges til at dele brugerens køleskab med andre via email.
class SharedFridgeMembersScreen extends StatefulWidget {
  const SharedFridgeMembersScreen({super.key, required this.ownerUserId});

  // Id på brugeren der ejer køleskabet, som skal deles.
  final String ownerUserId;

  @override
  State<SharedFridgeMembersScreen> createState() =>
      _SharedFridgeMembersScreenState();
}

class _SharedFridgeMembersScreenState extends State<SharedFridgeMembersScreen> {
  // Controlleren læser emailen fra inputfeltet.
  final _emailController = TextEditingController();

  // Servicen håndterer deling og henter medlemmer fra Firestore.
  final _service = SharedFridgeService();

  // Bruges til at deaktivere knappen, mens deling er i gang.
  bool _isSharing = false;

  @override
  void dispose() {
    // Controlleren ryddes op, når skærmen lukkes.
    _emailController.dispose();
    super.dispose();
  }

  // Deler køleskabet med den email, brugeren har skrevet.
  Future<void> _shareFridge() async {
    setState(() {
      _isSharing = true;
    });

    try {
      // Servicen finder brugeren via email og opretter shared fridge-data.
      await _service.shareWithEmail(
        ownerUserId: widget.ownerUserId,
        recipientEmail: _emailController.text,
      );
      _emailController.clear();
      if (!mounted) {
        return;
      }
      // Viser en kort besked når delingen lykkes.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Køleskabet er delt')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      // Viser fejl, hvis emailen ikke findes eller Firestore fejler.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kunne ikke dele: $error')));
    } finally {
      // Slukker loading-state igen, hvis skærmen stadig er åben.
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold viser formularen og medlemslisten.
    return Scaffold(
      appBar: AppBar(title: const Text('Delt køleskab')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Ikon der viser at siden handler om deling.
          Icon(Icons.group_add_outlined, size: 56, color: Colors.green),
          const SizedBox(height: 16),
          // Overskrift for delingsfunktionen.
          Text(
            'Del dit køleskab',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          // Kort forklaring af hvordan delingen virker.
          const Text(
            'Skriv emailen på en bruger. Når brugeren logger ind, kan de vælge dit køleskab i oversigten.',
          ),
          const SizedBox(height: 20),
          // Her skriver brugeren emailen på personen, der skal have adgang.
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'fx example@example.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          // Starter delingen og deaktiveres mens appen arbejder.
          FilledButton.icon(
            onPressed: _isSharing ? null : _shareFridge,
            icon: const Icon(Icons.share_outlined),
            label: Text(_isSharing ? 'Deler...' : 'Del køleskab'),
          ),
          const SizedBox(height: 24),
          // Overskrift til listen over personer, der har adgang.
          Text('Medlemmer', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          // Lytter live på medlemmerne i Firestore.
          StreamBuilder<List<SharedFridgeMember>>(
            stream: _service.watchMembers(widget.ownerUserId),
            builder: (context, snapshot) {
              // Loading vises mens medlemslisten hentes.
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final members = snapshot.data ?? [];
              if (members.isEmpty) {
                // Tom besked hvis køleskabet ikke er delt endnu.
                return const Text('Ingen medlemmer endnu.');
              }

              // Viser hvert medlem som et kort i listen.
              return Column(
                children: [
                  for (final member in members)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(member.email),
                        subtitle: const Text('Kan se køleskabet'),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
