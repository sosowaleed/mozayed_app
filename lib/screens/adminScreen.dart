import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/screens/home_screen.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {

  // Build the profile popup menu button for the AppBar.
  Widget _buildProfileMenuButton(BuildContext ctx, List<Map<String, dynamic>> profileMenuItems) {

    return PopupMenuButton<Map<String, dynamic>>(
      icon: const CircleAvatar(
        child: Icon(Icons.person),
      ),
      onSelected: (item) => item['onTap'](ctx),
      itemBuilder: (context) {
        return profileMenuItems.map((item) {
          return PopupMenuItem<Map<String, dynamic>>(
            value: item,
            child: Row(
              children: [
                Icon(item['icon'], size: 20),
                const SizedBox(width: 8),
                item['title'],
              ],
            ),
          );
        }).toList();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> profileMenuItems = [
      {
        'title': const Text("Home Screen"),
        'icon': Icons.home,
        'onTap': (context) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()));
        },
      },
      {
        'title': const Text(
          'Sign Out',
          style: TextStyle(
            color: Color.fromARGB(255, 237, 72, 72),
            fontWeight: FontWeight.bold,
          ),
        ),
        'icon': Icons.logout,
        'onTap': (context) async {
          await FirebaseAuth.instance.signOut();
        },
      },
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text("Admin Screen", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
        actions: [
          // Display the profile icon as a popup menu button
          // Passing the context and the profile menu items.
          _buildProfileMenuButton(context, profileMenuItems),
          const SizedBox(width: 10),
        ],
      ),

    );
  }
}