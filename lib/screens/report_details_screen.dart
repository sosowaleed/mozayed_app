import 'dart:developer';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/models/report_model.dart';
import 'package:mozayed_app/models/user_model.dart';

enum ReportAction { warn, suspend, deactivate, remove }

class ReportDetailsScreen extends ConsumerStatefulWidget {
  final ReportModel report;
  final UserModel currentAdmin; // The admin using the screen.
  const ReportDetailsScreen({super.key, required this.report, required this.currentAdmin});

  @override
  ConsumerState<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends ConsumerState<ReportDetailsScreen> {
  bool _processing = false;
  int _currentImageIndex = 0;
  final TextEditingController _actionMessageController = TextEditingController();

  // Shows an overlay dialog to collect admin message; returns the entered message.
  Future<String?> _showActionOverlay() async {
    _actionMessageController.clear();
    return await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Enter Email Message"),
          content: TextField(
            controller: _actionMessageController,
            decoration: const InputDecoration(labelText: "Message Will be sent to the Seller"),
            maxLines: 4,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, _actionMessageController.text.trim());
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }
  void _previousImage() {
    setState(() {
      if (_currentImageIndex > 0) {
        _currentImageIndex--;
      } else {
        _currentImageIndex = widget.report.image.length - 1;
      }
    });
  }

  void _nextImage() {
    setState(() {
      if (_currentImageIndex < widget.report.image.length - 1) {
        _currentImageIndex++;
      } else {
        _currentImageIndex = 0;
      }
    });
  }
  // Calls the HTTPS function to send an email.
  Future<void> sendReportEmail({
    required String functionUrl, // URL of the deployed HTTP function.
    required String recipient,
    required String category,
    required String flag,
    required String bodyText,
  }) async {
    final url = Uri.parse(functionUrl);
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'recipient': recipient,
        'category': category,
        'flag': flag,
        'bodyText': bodyText,
      }),
    );

    if (response.statusCode == 200) {
      log("Email sent successfully: ${response.body}");
    } else {
      log("Error sending email: ${response.body}");
      throw Exception("Failed to send email");
    }
  }

  // Process the report action.
  Future<void> _processReportAction(ReportAction action) async {
    final report = widget.report;
    setState(() {
      _processing = true;
    });

    // Show overlay to get admin's message.
    final adminMessage = await _showActionOverlay();
    if (adminMessage == null || adminMessage.isEmpty) {
      setState(() {
        _processing = false;
      });
      return;
    }

    // Determine recipient email:
    // For a "User" report, the reported user is the one in report.listingOwnerId.
    // For an "Item" or "Bid" report, use the listing owner's email.
    String recipientEmail = "";
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(report.listingOwnerId)
          .get();
      final userData = userDoc.data();
      recipientEmail = userData?["email"] ?? "";
    } catch (e) {
      log("Error fetching reported user email: $e");
    }

    String actionPrefix = "";
    switch (action) {
      case ReportAction.deactivate:
        actionPrefix = "Account Deactivation. Report Details";
        break;
      case ReportAction.suspend:
        actionPrefix = "Account Suspension. Report Details";
        break;
      case ReportAction.warn:
        actionPrefix = "Account Warning. Report Details";
        break;
      case ReportAction.remove:
        actionPrefix = "Removed Item/Bid. Report Details";
        break;
    }

    final String prefixedCategory = "$actionPrefix: ${report.category}";
    // Send email using the callable function.
    await sendReportEmail(
      functionUrl: "https://sendreportemailhttp-cj7ajmydla-uc.a.run.app",
      recipient: recipientEmail,
      category: prefixedCategory,
      flag: report.flag,
      bodyText: adminMessage,
    );

    // Process backend updates.
    if (report.category.toLowerCase() == "user") {
      // For a user report, update the reported user's document.
      if (action == ReportAction.deactivate) {
        await FirebaseFirestore.instance
            .collection("users")
            .doc(report.listingOwnerId)
            .update({"activated": false});
      } else if (action == ReportAction.suspend) {
        await FirebaseFirestore.instance
            .collection("users")
            .doc(report.listingOwnerId)
            .update({"suspended": true});
      }
      // Warn action does not update user status.
    } else {
      // For an item or bid report, if action is remove, delete the listing.
      if (action == ReportAction.remove) {
        await FirebaseFirestore.instance
            .collection("listings")
            .doc(report.listingId)
            .delete();
      }
    }

    // Mark the report as handled.
    await FirebaseFirestore.instance
        .collection("reports")
        .doc(report.id)
        .update({"handled": true});

    setState(() {
      _processing = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Report processed.")));
    }
  }

  @override
  void dispose() {
    _actionMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Report Details"),
      ),
      body: _processing
          ? const Center(child: CircularProgressIndicator())
          : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (report.image.isNotEmpty)
                Expanded(
                  flex: 3,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          report.image[_currentImageIndex],
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                      // Left Arrow.
                      Positioned(
                        left: 10,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios, size: 30),
                          onPressed: _previousImage,
                          color: theme.colorScheme.onPrimary,
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(theme.colorScheme.secondary.withOpacity(0.5)),
                          ),
                        ),
                      ),
                      // Right Arrow.
                      Positioned(
                        right: 10,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_forward_ios, size: 30),
                          onPressed: _nextImage,
                          color: theme.colorScheme.onPrimary,
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(theme.colorScheme.secondary.withOpacity(0.5)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                flex: 7,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Listed by: ${report.listingOwnerName}",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("Category: ${report.category}",
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text("Flag: ${report.flag}",
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text("Description: ${report.description}",
                          style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Text("Listing Title: ${report.listingTitle}",
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text("Listing Condition: ${report.listingCondition}",
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text("Reported At: ${report.timestamp}",
                          style: theme.textTheme.bodySmall),
                      const SizedBox(height: 16),
                      // Action buttons.
                      if (report.category.toLowerCase() == "user") ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () => _processReportAction(ReportAction.deactivate),
                              child: const Text("Deactivate"),
                            ),
                            ElevatedButton(
                              onPressed: () => _processReportAction(ReportAction.suspend),
                              child: const Text("Suspend"),
                            ),
                            ElevatedButton(
                              onPressed: () => _processReportAction(ReportAction.warn),
                              child: const Text("Send Warning"),
                            ),
                          ],
                        ),
                      ] else if (report.category.toLowerCase() == "item" ||
                          report.category.toLowerCase() == "bid") ...[
                        Center(
                          child: ElevatedButton(
                            onPressed: () => _processReportAction(ReportAction.remove),
                            child: const Text("Remove Listing / Bid"),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }
}
