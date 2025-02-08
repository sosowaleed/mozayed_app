import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/models/cart_model.dart';
import 'package:mozayed_app/models/listing_model.dart';
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
          title: const Text("Checkout"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter Delivery address:"),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: "Delivery Address",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text("Confirm Purchase"),
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

      final orderData = {
        'userId': ref.read(userDataProvider).value!['id'],
        'orderTime': DateTime.now().toIso8601String(),
        'items':
            ref.read(cartProvider).map((cartItem) => cartItem.toMap()).toList(),
        'shippingAddress': _addressController.text,
      };
      await FirebaseFirestore.instance
          .collection("orders")
          .doc(ref.read(userDataProvider).value!['id'])
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
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        title: const Text("Your Cart"),
      ),
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
                    ? const Center(child: Text("No items added"))
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
                                Text("Quantity: ${cartItem.quantity}"),
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
                                          ScaffoldMessenger.of(context).clearSnackBars();
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
                  color: Colors.white,
                  child: ElevatedButton(
                    onPressed: () => _checkout(),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 0),
                      fixedSize: Size(
                        MediaQuery.of(context).size.width,
                        40,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      backgroundColor: Colors.purple[300],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Checkout",
                        style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
            ],
          );
        });
      }),
    );
  }
}
