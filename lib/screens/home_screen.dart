import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/layouts/home_content_layout.dart';
import 'package:mozayed_app/providers/user_and_auth_provider.dart';
import 'package:mozayed_app/screens/profile_screen.dart';
import 'package:mozayed_app/screens/sell_screen.dart';
import 'package:mozayed_app/screens/user_listing_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  // Main navigation items: Home, Cart, Sell.
  final List<Map<String, dynamic>> _mainMenuItems = [
    {
      'title': 'Home',
      'icon': Icons.home,
      'screen': const HomeContent(),
    },
    {
      'title': 'Cart',
      'icon': Icons.shopping_cart,
      'screen': const Center(child: Text('Shopping Cart')),
    },
    {
      'title': 'Sell',
      'icon': Icons.add_box,
      'screen': const SellScreen(),
    },
  ];

  // Profile menu items shown in the AppBar popup menu.
  final List<Map<String, dynamic>> _profileMenuItems = [
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
    },{
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
      'onTap': () {
        // Navigate to History Screen
        debugPrint('History tapped');
      },
    },
    {
      'title': const Text('Settings'),
      'icon': Icons.settings,
      'onTap': () {
        // Navigate to Settings Screen
        debugPrint('Settings tapped');
      },
    },
    {
      'title': const Text(
          'Sign Out',
        style: TextStyle(color: Colors.red),
      ),
      'icon': Icons.logout,
      'onTap': () async {
        await FirebaseAuth.instance.signOut();
      },
    },
  ];

  void _onMainItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Build the profile popup menu button for the AppBar.
  Widget _buildProfileMenuButton(BuildContext ctx) {
    return PopupMenuButton<Map<String, dynamic>>(
      icon: const CircleAvatar(
        child: Icon(Icons.person),
      ),
      onSelected: (item) => item['onTap'](ctx),
      itemBuilder: (context) {
        return _profileMenuItems.map((item) {
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
    final userData = ref.watch(userDataProvider); // if needed for display

    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = constraints.maxWidth < 650;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              _mainMenuItems[_selectedIndex]['title'] == 'Home'
                  ? 'Mozayed'
                  : _mainMenuItems[_selectedIndex]['title'],
            ),
            actions: [
              // Display the profile icon as a popup menu button
              // Passing the context
              _buildProfileMenuButton(context),
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
                color: Colors.grey[100],
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
                icon: Icon(item['icon']),
                label: item['title'],
                backgroundColor: Theme.of(context).colorScheme.primary,
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
