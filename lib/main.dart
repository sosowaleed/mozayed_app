import 'package:flutter/material.dart';
import 'package:mozayed_app/screens/auth_screen.dart';
import 'package:mozayed_app/screens/home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/user_and_auth_provider.dart';
import 'firebase_options.dart';

final theme = ThemeData().copyWith(
  scaffoldBackgroundColor: Colors.white70,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.lightGreenAccent,
  ),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Mozayed App',
      theme: theme,
      home: authState.when(
        data: (user) => user != null ? const HomeScreen() : const AuthScreen(),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => const AuthScreen(),
      ),
    );
  }
}
