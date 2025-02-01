import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mozayed_app/layouts/home_content_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/providers/auth_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _menuItems = [
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
      'title': 'Profile',
      'icon': Icons.person,
      'screen': const Center(child: Text('Profile')),
    },
    {
      'title': 'Settings',
      'icon': Icons.settings,
      'screen': const Center(child: Text('Settings')),
    },
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = constraints.maxWidth < 650;

        return Scaffold(
          appBar: AppBar(
            title: Text(_menuItems[_selectedIndex]['title'] == 'Home' ? 'Mozayed' : _menuItems[_selectedIndex]['title']),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text("Sign Out"),
                onPressed: () async {
                  // Sign out from Firebase
                  await FirebaseAuth.instance.signOut();
                  // Optionally, navigate to the login screen or perform other cleanup
                },
              )
            ],
          ),
          // if its a phone, we do not need a drawer
          /*drawer: isPhone
              ? Drawer(
            child: ListView(
              children: _menuItems.map((item) {
                final index = _menuItems.indexOf(item);
                return ListTile(
                  leading: Icon(item['icon']),
                  title: Text(item['title']),
                  onTap: () {
                    _onItemTapped(index);
                    Navigator.pop(context); // Close drawer on mobile
                  },
                );
              }).toList(),
            ),
          )
              : null,*/
          body: isPhone
              ? _menuItems[_selectedIndex]['screen']
              : Row(
            children: [
              // Drawer-like widget always open
              Container(
                width: 200,
                color: Colors.grey[100],
                child: ListView(
                  children: _menuItems.map((item) {
                    final index = _menuItems.indexOf(item);
                    return ListTile(
                      leading: Icon(item['icon']),
                      title: Text(item['title']),
                      selected: index == _selectedIndex,
                      style: ListTileStyle.drawer,
                      onTap: () => _onItemTapped(index),
                    );
                  }).toList(),
                ),
              ),
              // Main content
              Expanded(
                child: _menuItems[_selectedIndex]['screen'],
              ),
            ],
          ),
          bottomNavigationBar: isPhone
              ? BottomNavigationBar(
            items: _menuItems
                .map(
                  (item) => BottomNavigationBarItem(
                    icon: Icon(item['icon']),
                    label: item['title'],
                    backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            ).toList(),
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
          )
              : null,
        );
      },
    );
  }
}

