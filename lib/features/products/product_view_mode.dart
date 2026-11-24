import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/product.dart';

const _prefsKey = 'product_view_list';

/// Tampilan produk (Produk & POS): true = list, false = grid. Disimpan di prefs.
class ProductViewMode extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  Future<void> toggle() async {
    final next = !(state.valueOrNull ?? false);
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, next);
  }
}

final productViewModeProvider =
    AsyncNotifierProvider<ProductViewMode, bool>(ProductViewMode.new);

/// Cari nama produk: contains, tanpa beda huruf besar/kecil.
List<Product> filterProductsByName(List<Product> products, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return products;
  return products.where((p) => p.name.toLowerCase().contains(q)).toList();
}
