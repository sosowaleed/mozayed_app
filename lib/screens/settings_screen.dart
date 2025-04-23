import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A provider for managing the app's theme mode state.
/// The default theme mode is set to `ThemeMode.light`.
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.light; // Default theme mode
});

/// A settings screen widget that allows the user to configure app settings,
/// such as changing the theme mode.
///
/// This widget uses the `ConsumerWidget` from Riverpod to listen to and update
/// the state of the `themeModeProvider`.
class SettingsScreen extends ConsumerWidget {
  /// Constructor for the `SettingsScreen` widget.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the current value of the theme mode from the provider.
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: ListView(
        children: [
          // A list tile for changing the app's theme mode.
          ListTile(
            title: const Text('Theme'),
            subtitle: const Text('Change the app theme'),
            trailing: DropdownButton<ThemeMode>(
              value: themeMode, // The currently selected theme mode.
              items: const [
                // Dropdown menu item for the light theme.
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text('Light'),
                ),
                // Dropdown menu item for the dark theme.
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text('Dark'),
                ),
                // Dropdown menu item for the system theme.
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('System'),
                ),
              ],
              // Callback when the user selects a new theme mode.
              onChanged: (value) async {
                if (value != null) {
                  // Update the theme mode in the provider.
                  ref.read(themeModeProvider.notifier).state = value;

                  // Save the selected theme mode to shared preferences.
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('themeMode', value.name);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
