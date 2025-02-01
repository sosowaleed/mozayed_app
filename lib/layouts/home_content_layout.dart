import 'package:flutter/material.dart';
import 'package:mozayed_app/widgets/listing_widget.dart';

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = 2;
          if (constraints.maxWidth >= 1200 && constraints.maxHeight >= 500) {
            crossAxisCount = 6;
          } else if (constraints.maxWidth >= 735 && constraints.maxHeight >= 400) {
            crossAxisCount = 5;
          } else if (constraints.maxWidth >= 600) {
            crossAxisCount = 3;
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
        }
    );
  }
}