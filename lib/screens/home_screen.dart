import 'package:flutter/material.dart';
import 'package:mozayed_app/widgets/listing_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = 2;
          if (constraints.maxWidth >= 1200) {
            crossAxisCount = 6;
          } else if (constraints.maxWidth >= 735) {
            crossAxisCount = 5;
          }
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: 50,
              itemBuilder: (context, index) => const ListingWidget(),
            ),
          );
        },
      ),
    );
  }
}