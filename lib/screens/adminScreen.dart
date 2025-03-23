import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/layouts/home_content_layout.dart';
import 'package:mozayed_app/layouts/report_content_layout.dart';
import 'package:mozayed_app/screens/home_screen.dart';
import 'package:mozayed_app/providers/reports_provider.dart';
import 'package:mozayed_app/screens/user_management_screen.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final List<Map<String, dynamic>> _mainMenuItems = [
    {
      'title': 'Reports',
      'icon': Icons.report,
      'screen': const ReportContent(),
    },
    {
      'title': 'Monitor Screen',
      'icon': Icons.monitor_heart,
      'screen': const HomeContent(adminInfo: true,),
    },
    {
      'title': 'Users',
      'icon': Icons.person,
      'screen': const UserManagementScreen(),
    },
  ];

  int _selectedIndex = 0;

  void _onMainItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Build the profile popup menu button for the AppBar.
  Widget _buildProfileMenuButton(
      BuildContext ctx, List<Map<String, dynamic>> profileMenuItems) {
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
    final reports = ref.watch(reportsProvider);

    reports.when(
      data: (reportMap) {
        if (reportMap.isEmpty) {
          return const Center(child: Text("No reports found."));
        }
      },
      loading: () {
        // Show a loading indicator
        return const Center(child: CircularProgressIndicator());
      },
      error: (error, stackTrace) {
        // Handle the error
        log('Error fetching report data: $error');
        return Center(child: Text('Error: $error'));
      },
    );

    final List<Map<String, dynamic>> profileMenuItems = [
      {
        'title': const Text("Home Screen"),
        'icon': Icons.home,
        'onTap': (context) {
          Navigator.pushReplacement(context,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = constraints.maxWidth < 650;

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            title: Text(
              "Admin Screen",
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
            actions: [
              // Display the profile icon as a popup menu button
              // Passing the context and the profile menu items.
              _buildProfileMenuButton(context, profileMenuItems),
              const SizedBox(width: 10),
            ],
          ),
          // For larger screens, use a persistent drawer; for phones, use a bottom nav.
          body: isPhone
              ? _mainMenuItems[_selectedIndex]['screen']
              : Row(
                  children: [
                    // Always-open drawer-like widget
                    Container(
                      width: 200,
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: ListView(
                        children: _mainMenuItems.map((item) {
                          final index = _mainMenuItems.indexOf(item);

                          return ListTile(
                            leading: Icon(item['icon']),
                            title: Text(item['title']),
                            selected: index == _selectedIndex,
                            style: ListTileStyle.drawer,
                            onTap: () => _onMainItemTapped(index),
                          );
                        }).toList(),
                      ),
                    ),
                    // Main content area
                    Expanded(
                      child: _mainMenuItems[_selectedIndex]['screen'],
                    ),
                  ],
                ),
          bottomNavigationBar: isPhone
              ? BottomNavigationBar(
                  items: _mainMenuItems
                      .map(
                        (item) => BottomNavigationBarItem(
                          icon: Stack(
                            children: [
                              Icon(item['icon']),
                            ],
                          ),
                          label: item['title'],
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                      )
                      .toList(),
                  currentIndex: _selectedIndex,
                  onTap: _onMainItemTapped,
                )
              : null,
        );
      },
    );
  }
}
