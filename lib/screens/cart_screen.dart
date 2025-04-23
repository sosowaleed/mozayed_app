import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mozayed_app/providers/cart_provider.dart';
import 'package:mozayed_app/providers/user_and_auth_provider.dart';
import 'package:mozayed_app/widgets/listing_widget.dart';
import 'package:http/http.dart' as http;
import 'dart:developer';

/// A screen that displays the user's cart and allows them to manage items
/// and proceed to checkout.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  // Controller for the delivery address input field.
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    // Initialize the address controller with the user's saved address.
    _addressController.text =
        ref.read(userDataProvider).value!['location']['address'];
    super.initState();
  }

  /// Handles the checkout process, including:
  /// - Displaying a confirmation dialog.
  /// - Showing a progress indicator.
  /// - Updating Firestore with the new listing quantities or removing listings.
  /// - Creating an order document in Firestore.
  /// - Clearing the cart.
  /// - Calling a Cloud Function to process new orders.
  Future<void> _checkout() async {
    // Show a popup form to get checkout info.
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            "Checkout",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Enter Delivery address:",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: "Delivery Address",
                  labelStyle: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(false);
              },
              child: Text(
                "Cancel",
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text("Confirm Purchase",
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      // Show a circular progress indicator for 3 seconds.
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator()),
        );
      }
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss progress indicator.
      }

      // Get current cart items from the cart provider.
      final cartItems = ref.read(cartProvider);

      // Process each cart item: update listing quantity or remove listing if quantity reaches 0.
      for (final cartItem in cartItems) {
        final listingId = cartItem.listing.id;
        final currentQty = cartItem.listing.quantity;
        final purchasedQty = cartItem.quantity;
        final newQty = currentQty - purchasedQty;

        if (newQty > 0) {
          // Update the listing document with the new quantity.
          await FirebaseFirestore.instance
              .collection("listings")
              .doc(listingId)
              .update({"quantity": newQty});
        } else {
          // Remove the listing if quantity is 0 (or less).
          await FirebaseFirestore.instance
              .collection("listings")
              .doc(listingId)
              .delete();
        }
      }

      // Create an order document in Firestore.
      final orderData = {
        'userId': ref.read(userDataProvider).value!['id'],
        'orderTime': DateTime.now().toIso8601String(),
        'items': ref
            .read(cartProvider)
            .map((cartItem) => {
                  'listingId': cartItem.listing.id,
                  'quantity': cartItem.quantity,
                  'price':
                      NumberFormat('#,##0.00').format(cartItem.listing.price),
                  'title': cartItem.listing.title,
                })
            .toList(),
        'shippingAddress': _addressController.text,
        "emailSent": false,
      };
      await FirebaseFirestore.instance
          .collection("orders")
          .doc()
          .set(orderData);

      // Clear the cart.
      ref.read(cartProvider.notifier).clearCart();

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Purchase completed successfully.")),
        );
      }

      // Call the processNewOrders Cloud Function.
      const processOrdersUrl =
          "https://processneworders-cj7ajmydla-uc.a.run.app";
      try {
        final response = await http.get(Uri.parse(processOrdersUrl));
        if (response.statusCode == 200) {
          log("processNewOrders called successfully: ${response.body}");
        } else {
          log("processNewOrders error: ${response.statusCode} ${response.body}");
        }
      } catch (error) {
        log("Error calling processNewOrders: $error");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Consumer(builder: (context, ref, child) {
        // Watch the cart provider to get the current cart items.
        final cartItems = ref.watch(cartProvider);
        return LayoutBuilder(builder: (context, constraints) {
          // Determine the number of columns in the grid based on screen size.
          int crossAxisCount = 2;
          if (constraints.maxWidth >= 1200 && constraints.maxHeight >= 500) {
            crossAxisCount = 6;
          } else if (constraints.maxWidth >= 735 &&
              constraints.maxHeight >= 400) {
            crossAxisCount = 5;
          } else if (constraints.maxWidth >= 600) {
            crossAxisCount = 3;
          }
          return Column(
            children: [
              Expanded(
                child: cartItems.isEmpty
                    ? Center(
                        child: Text(
                        "No items added",
                        style: Theme.of(context).textTheme.headlineSmall,
                      ))
                    : GridView.builder(
                        key: UniqueKey(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: cartItems.length,
                        itemBuilder: (context, index) {
                          final cartItem = cartItems[index];
                          return Card(
                            child: Column(
                              children: [
                                // Display the listing using a custom widget.
                                Expanded(
                                  child: ListingWidget(
                                    listingItem: cartItem.listing,
                                  ),
                                ),
                                Text(
                                  "Quantity: ${cartItem.quantity}",
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    // Decrease quantity button.
                                    IconButton(
                                      icon: const Icon(Icons.remove),
                                      onPressed: () {
                                        int newQty = cartItem.quantity - 1;
                                        ref
                                            .read(cartProvider.notifier)
                                            .updateQuantity(
                                                cartItem.listing.id, newQty);
                                      },
                                    ),
                                    // Increase quantity button.
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: () {
                                        int newQty = cartItem.quantity + 1;
                                        if (cartItem.listing.quantity >=
                                            newQty) {
                                          ref
                                              .read(cartProvider.notifier)
                                              .updateQuantity(
                                                  cartItem.listing.id, newQty);
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .clearSnackBars();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  "Not enough items in stock."),
                                              duration: Duration(seconds: 2),
                                              showCloseIcon: true,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    // Remove item from cart button.
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () {
                                        ref
                                            .read(cartProvider.notifier)
                                            .removeFromCart(
                                                cartItem.listing.id);
                                      },
                                    ),
                                  ],
                                )
                              ],
                            ),
                          );
                        },
                      ),
              ),
              // Checkout Button
              if (cartItems.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8.0),
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: ElevatedButton(
                    onPressed: () => _checkout(),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 0),
                      fixedSize: Size(MediaQuery.of(context).size.width, 50),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      "Checkout",
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                    ),
                  ),
                ),
            ],
          );
        });
      }),
    );
  }
}
