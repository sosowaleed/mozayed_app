import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/providers/user_and_auth_provider.dart';

class ActivationChecker extends ConsumerWidget {
  final Widget child;
  const ActivationChecker({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDataAsync = ref.watch(userStreamProvider);
    return userDataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text("Error: $error")),
      data: (userData) {
        // If no data or account is not activated, show an account disabled screen.
        if (userData == null || !userData['activated']) {
          return const AccountNotActivatedScreen();
        }
        // Otherwise, display the main content.
        return child;
      },
    );
  }
}

class AccountNotActivatedScreen extends StatelessWidget {
  const AccountNotActivatedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton.icon(
            onPressed: () => FirebaseAuth.instance.signOut(),
            label: const Text('Sign Out'),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.red),
              SizedBox(height: 20),
              Text(
                "Your account is not activated.",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                "Please contact support or check your email for an activation link.",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
