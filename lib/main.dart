import 'package:flutter/material.dart';
import 'package:mozayed_app/screens/auth_screen.dart';
import 'package:mozayed_app/screens/home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/user_and_auth_provider.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mozayed_app/screens/settings_screen.dart';

// Define the base light theme with lightGreenAccent
final lightTheme = ThemeData(
  scaffoldBackgroundColor: Colors.white70,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.lightGreenAccent,
    brightness: Brightness.light, // Ensure light brightness
  ),
  useMaterial3: true,
);

// Define a dark theme that complements lightGreenAccent
final darkTheme = ThemeData(
  scaffoldBackgroundColor: Colors.grey[850], // Darker background
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.lightGreenAccent,
    brightness: Brightness.dark, // Ensure dark brightness
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Colors.white), // Adjust text color for readability
  ),
  useMaterial3: true,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Load the saved theme mode from shared preferences
  final prefs = await SharedPreferences.getInstance();
  final themeModeString = prefs.getString('themeMode');
  ThemeMode initialThemeMode = ThemeMode.light; // Default
  if (themeModeString != null) {
    initialThemeMode = ThemeMode.values.firstWhere(
          (element) => element.name == themeModeString,
      orElse: () => ThemeMode.light,
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        // Override the default theme mode with the saved one using an initializer.
        themeModeProvider.overrideWith((ref) => initialThemeMode),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Mozayed App',
      theme: lightTheme, // Set the light theme as the default
      darkTheme: darkTheme, // Define the dark theme
      themeMode: themeMode, // Use the themeMode to switch
      home: authState.when(
        data: (user) => user != null ? const HomeScreen() : const AuthScreen(),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => const AuthScreen(),
      ),
    );
  }
}