import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:mozayed_app/models/report_model.dart';
import 'package:mozayed_app/models/user_model.dart';
import 'package:mozayed_app/screens/report_details_screen.dart';
import 'dart:typed_data';

class ReportWidget extends StatelessWidget {
  final ReportModel report;
  final UserModel currentAdmin; // The admin who is using the screen.
  const ReportWidget({super.key, required this.report, required this.currentAdmin});

  // Choose an icon based on the report category.
  IconData _iconForCategory(String category) {
    switch (category.toLowerCase()) {
      case "user":
        return Icons.person;
      default:
        return Icons.report;
    }
  }

  // Helper function to get image bytes from Firebase Storage
  Future<Uint8List?> _getImageBytes(String imageUrl) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      return await ref.getData();
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Navigate to the Listing Details Screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                ReportDetailsScreen(report: report, currentAdmin: currentAdmin),
          ),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
        margin: const EdgeInsets.all(8.0),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            // Icon/Image Section.
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Center(
                child: (report.category.toLowerCase() == 'item' ||
                    report.category.toLowerCase() == 'bid') &&
                    report.image.isNotEmpty
                    ? Hero(
                        tag: report.id,
                        child: FutureBuilder<Uint8List?>(
                          future: _getImageBytes(report.image[0]),
                          builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            } else if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                              return const Center(child: Icon(Icons.error));
                            } else {
                              return Image.memory(
                                snapshot.data!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              );
                            }
                          },
                        ),
                    )
                    : Icon(
                  _iconForCategory(report.category),
                  size: 50,
                  color: Colors.grey[700],
                ),
              ),
            ),
            // Metadata Section.
            Container(
              width: double.infinity,
              color: Colors.black54,
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AutoSizeText(
                    report.listingTitle,
                    softWrap: true,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  AutoSizeText(
                    "Flag: ${report.flag}",
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
