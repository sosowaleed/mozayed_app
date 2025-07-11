/// This file defines the `HomeScreen` widget, which serves as the main screen
/// of the application. It includes navigation between different sections of the app,
/// such as Home, Cart, and Sell, and provides a profile menu for user-related actions.

import 'dart:developer';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/layouts/home_content_layout.dart';
import 'package:mozayed_app/models/user_model.dart';
import 'package:mozayed_app/providers/user_and_auth_provider.dart';
import 'package:mozayed_app/screens/cart_screen.dart';
import 'package:mozayed_app/screens/profile_screen.dart';
import 'package:mozayed_app/screens/sell_screen.dart';
import 'package:mozayed_app/screens/settings_screen.dart';
import 'package:mozayed_app/screens/user_history_screen.dart';
import 'package:mozayed_app/screens/user_listing_screen.dart';
import 'package:mozayed_app/providers/cart_provider.dart';
import 'package:mozayed_app/screens/adminScreen.dart';
import 'package:mozayed_app/widgets/activation_checker.dart';

/// A stateful widget that represents the main home screen of the app.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// The state class for `HomeScreen`, managing navigation and user interactions.
class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// The currently selected index for the main navigation menu.
  int _selectedIndex = 0;

  /// The main navigation items, each containing a title, icon, and associated screen.
  final List<Map<String, dynamic>> _mainMenuItems = [
    {
      'title': 'Home',
      'icon': Icons.home,
      'screen': const HomeContent(),
    },
    {
      'title': 'Cart',
      'icon': Icons.shopping_cart,
      'screen': const CartScreen(),
    },
    {
      'title': 'Sell',
      'icon': Icons.add_box,
      'screen': const SellScreen(showBackButton: false),
    },
  ];

  /// Updates the selected index when a navigation item is tapped.
  void _onMainItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Builds the profile popup menu button for the AppBar.
  ///
  /// [ctx] is the BuildContext, and [profileMenuItems] is the list of menu items.
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

  /// Fetches the activation status of the user.
  Future<bool?> _isActivated() async {
    return await ref.read(userDataProvider.notifier).fetchActivated();
  }

  @override
  Widget build(BuildContext context) {
    /// Profile menu items shown in the AppBar popup menu.
    final List<Map<String, dynamic>> profileMenuItems = [
      {
        'title': const Text('Profile'),
        'icon': Icons.person,
        'onTap': (context) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProfileScreen(),
            ),
          );
        },
      },
      {
        'title': const Text('My items'),
        'icon': Icons.list_alt,
        'onTap': (context) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MyListingsScreen(),
            ),
          );
        },
      },
      {
        'title': const Text('History'),
        'icon': Icons.history,
        'onTap': (context) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const UserHistoryScreen()));
        },
      },
      {
        'title': const Text('Settings'),
        'icon': Icons.settings,
        'onTap': (context) {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()));
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

    /// Watches the cart and user data providers.
    final carData = ref.watch(cartProvider);
    final userAsyncValue = ref.watch(userDataProvider);

    return userAsyncValue.when(
      loading: () {
        // Show a loading indicator while user data is being fetched.
        return const Center(child: CircularProgressIndicator());
      },
      error: (error, stackTrace) {
        // Handle errors during user data fetching.
        log('Error fetching user data: $error');
        return Center(child: Text('Error: $error'));
      },
      data: (userMap) {
        if (userMap == null) {
          return const Center(
              child:
                  Text('Failed to fetch user data, please try again later.'));
        }

        /// Parse the user data and check if the user is an admin.
        final UserModel userData = UserModel.fromMap(userMap);
        if (userData.admin) {
          profileMenuItems.add({
            'title': const Text('Admin Panel'),
            'icon': Icons.admin_panel_settings,
            'onTap': (context) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AdminScreen()),
              );
            },
          });
        }

        return FutureBuilder<bool?>(
          future: _isActivated(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            }

            /// Check if the account is activated.
            final isActivated = snapshot.data;
            if (isActivated != null) {
              if (!isActivated) {
                return const AccountNotActivatedScreen();
              }
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                /// Determine if the device is a phone or a larger screen.
                final isPhone = constraints.maxWidth < 650;

                return Scaffold(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  appBar: AppBar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    title: AutoSizeText(
                      _mainMenuItems[_selectedIndex]['title'] == 'Home'
                          ? 'Mozayed'
                          : _mainMenuItems[_selectedIndex]['title'],
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary),
                    ),
                    actions: [
                      // Display the profile icon as a popup menu button.
                      _buildProfileMenuButton(context, profileMenuItems),
                      const SizedBox(width: 10),
                    ],
                  ),
                  // For larger screens, use a persistent drawer; for phones, use a bottom nav.
                  body: isPhone
                      ? snapshot.connectionState == ConnectionState.waiting
                          ? const Center(child: CircularProgressIndicator())
                          : _mainMenuItems[_selectedIndex]['screen']
                      : Row(
                          children: [
                            // Always-open drawer-like widget for larger screens.
                            Container(
                              width: 200,
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              child: ListView(
                                children: _mainMenuItems.map((item) {
                                  final index = _mainMenuItems.indexOf(item);

                                  return ListTile(
                                    leading: Icon(item['icon']),
                                    title: Text(item['title']),
                                    trailing: item['title'] == 'Cart'
                                        ? carData.isNotEmpty
                                            ? Container(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: const Color.fromARGB(
                                                      255, 237, 72, 72),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '${carData.length}',
                                                  style: const TextStyle(
                                                      color: Color.fromARGB(
                                                          255, 231, 231, 231),
                                                      fontSize: 12),
                                                ),
                                              )
                                            : null
                                        : null,
                                    selected: index == _selectedIndex,
                                    style: ListTileStyle.drawer,
                                    onTap: () => _onMainItemTapped(index),
                                  );
                                }).toList(),
                              ),
                            ),
                            // Main content area for larger screens.
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
                                      if (item['title'] == 'Cart' &&
                                          carData.isNotEmpty)
                                        Positioned(
                                          right: 0,
                                          child: CircleAvatar(
                                            backgroundColor:
                                                const Color.fromARGB(
                                                    255, 237, 72, 72),
                                            radius: 8,
                                            child: Text(
                                              '${carData.length}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Color.fromARGB(
                                                    255, 231, 231, 231),
                                              ),
                                            ),
                                          ),
                                        ),
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
          },
        );
      },
    );
  }
}
