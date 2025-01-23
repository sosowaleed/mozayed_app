import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 3; // Default to 3 rows

    if (screenWidth >= 1200) {
      crossAxisCount = 6; // Render 6 rows for very large screens
    } else if (screenWidth >= 735) {
      crossAxisCount = 5; // Render 5 rows for large screens
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: 50,
        itemBuilder: (context, index) {
          return Card(child: Center(child: Text('Card ${index + 1}')));
        },
      ),
    );
  }
}