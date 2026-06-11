import 'package:flutter/material.dart';

import '../services/shared_fridge_service.dart';

class SharedFridgeMembersScreen extends StatefulWidget {
  const SharedFridgeMembersScreen({super.key, required this.ownerUserId});

  final String ownerUserId;

  @override
  State<SharedFridgeMembersScreen> createState() =>
      _SharedFridgeMembersScreenState();
}

class _SharedFridgeMembersScreenState extends State<SharedFridgeMembersScreen> {
  final _emailController = TextEditingController();
  final _service = SharedFridgeService();

  bool _isSharing = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _shareFridge() async {
    setState(() {
      _isSharing = true;
    });

    try {
      await _service.shareWithEmail(
        ownerUserId: widget.ownerUserId,
        recipientEmail: _emailController.text,
      );
      _emailController.clear();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Køleskabet er delt')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kunne ikke dele: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delt køleskab')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.group_add_outlined, size: 56, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            'Del dit køleskab',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Skriv emailen på en bruger. Når brugeren logger ind, kan de vælge dit køleskab i oversigten.',
          ),
          const SizedBox(height: 20),
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
          FilledButton.icon(
            onPressed: _isSharing ? null : _shareFridge,
            icon: const Icon(Icons.share_outlined),
            label: Text(_isSharing ? 'Deler...' : 'Del køleskab'),
          ),
          const SizedBox(height: 24),
          Text('Medlemmer', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          StreamBuilder<List<SharedFridgeMember>>(
            stream: _service.watchMembers(widget.ownerUserId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final members = snapshot.data ?? [];
              if (members.isEmpty) {
                return const Text('Ingen medlemmer endnu.');
              }

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
