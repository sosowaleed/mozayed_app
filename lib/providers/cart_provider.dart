import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozayed_app/models/listing_model.dart';

final cartProvider = StateNotifierProvider<CartNotifier, List<ListingItem>>((ref) {
  return CartNotifier();
});

class CartNotifier extends StateNotifier<List<ListingItem>> {
  CartNotifier() : super([]);

  void addToCart(ListingItem item) {
    state = [...state, item];
  }

  void removeFromCart(String listingId) {
    state = state.where((item) => item.id != listingId).toList();
  }
}
