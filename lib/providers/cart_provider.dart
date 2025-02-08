import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/models/listing_model.dart';
import 'package:mozayed_app/models/cart_model.dart';

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  // Adds an item: if already present, increment quantity.
  void addToCart(ListingItem item) {
    // Check if an item with the same listing id exists.
    int index = state.indexWhere((cartItem) => cartItem.listing.id == item.id);
    if (index != -1) {
      // Increase quantity.
      CartItem existing = state[index];
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == index)
            existing.copyWith(quantity: existing.quantity + 1)
          else
            state[i]
      ];
    } else {
      // Add new CartItem with quantity 1.
      state = [...state, CartItem(listing: item, quantity: 1)];
    }
  }

  // Update quantity for a given listing.
  void updateQuantity(String listingId, int newQuantity) {
    state = state.map((cartItem) {
      if (cartItem.listing.id == listingId) {
        return cartItem.copyWith(quantity: newQuantity);
      }
      return cartItem;
    }).toList();
    // Remove the item if quantity is zero.
    state = state.where((cartItem) => cartItem.quantity > 0).toList();
  }

  // Removes an item entirely.
  void removeFromCart(String listingId) {
    state = state.where((cartItem) => cartItem.listing.id != listingId).toList();
  }

  // Clears the entire cart.
  void clearCart() {
    state = [];
  }
}
