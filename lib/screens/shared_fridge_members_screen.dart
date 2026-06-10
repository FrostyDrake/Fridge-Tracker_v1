import 'package:flutter/material.dart';

class SharedFridgeMockState {
  static final sharedEmail = ValueNotifier<String?>(null);
}

class SharedFridgeMembersScreen extends StatefulWidget {
  const SharedFridgeMembersScreen({super.key});

  @override
  State<SharedFridgeMembersScreen> createState() =>
      _SharedFridgeMembersScreenState();
}

class _SharedFridgeMembersScreenState extends State<SharedFridgeMembersScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _shareFridge() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Skriv en email f\u00f8rst')),
      );
      return;
    }

    SharedFridgeMockState.sharedEmail.value = email;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('K\u00f8leskabet deles med $email')));
  }

  void _stopSharing() {
    SharedFridgeMockState.sharedEmail.value = null;
    _emailController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delt k\u00f8leskab')),
      body: ValueListenableBuilder<String?>(
        valueListenable: SharedFridgeMockState.sharedEmail,
        builder: (context, sharedEmail, _) {
          final isShared = sharedEmail != null;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(
                isShared ? Icons.groups : Icons.group_add_outlined,
                size: 56,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              Text(
                isShared ? 'K\u00f8leskabet er delt' : 'Del dit k\u00f8leskab',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isShared
                    ? '$sharedEmail kan nu ses som medlem i denne mock.'
                    : 'Skriv emailen p\u00e5 en anden bruger. Personen skal ikke godkende f\u00f8rst i denne mock.',
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
                onPressed: _shareFridge,
                icon: const Icon(Icons.share_outlined),
                label: const Text('Del k\u00f8leskab'),
              ),
              if (isShared) ...[
                const SizedBox(height: 24),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: const Text('Medlem'),
                    subtitle: Text(sharedEmail),
                    trailing: const Chip(label: Text('shared')),
                  ),
                ),
                TextButton.icon(
                  onPressed: _stopSharing,
                  icon: const Icon(Icons.close),
                  label: const Text('Stop deling'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
