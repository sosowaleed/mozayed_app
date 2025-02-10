import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/providers/cart_provider.dart';
import 'package:mozayed_app/providers/user_and_auth_provider.dart';
import 'package:mozayed_app/widgets/listing_widget.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    _addressController.text =
        ref.read(userDataProvider).value!['location']['address'];
    super.initState();
  }

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
                  style: TextStyle(color: Theme.of(context).colorScheme.primary)),
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
      //TODO: Remove comments in final project; removes items if they reach 0 from backend and frontend.
      /*// Get current cart items from the cart provider.
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
      }*/

      final orderData = {
        'userId': ref.read(userDataProvider).value!['id'],
        'orderTime': DateTime.now().toIso8601String(),
        'items': ref
            .read(cartProvider)
            .map((cartItem) => {
                  'listingId': cartItem.listing.id,
                  'quantity': cartItem.quantity,
                  'price': cartItem.listing.price,
                  'title': cartItem.listing.title,
                })
            .toList(),
        'shippingAddress': _addressController.text,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Consumer(builder: (context, ref, child) {
        final cartItems = ref.watch(cartProvider);
        return LayoutBuilder(builder: (context, constraints) {
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
                                // You may use your ListingWidget here.
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
