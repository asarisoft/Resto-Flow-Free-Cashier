import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/product.dart';
import '../../models/transaction_item.dart';

class CartNotifier extends Notifier<List<TransactionItem>> {
  @override
  List<TransactionItem> build() => [];

  int get subtotal =>
      state.fold(0, (sum, i) => sum + i.subtotal);
  int get itemCount => state.fold(0, (sum, i) => sum + i.qty);

  void addItem(Product product) {
    final existing = state.indexWhere(
        (i) => i.productId == product.id && i.discount == 0 && (i.note == null || i.note!.isEmpty));
    if (existing >= 0) {
      state = [
        for (var i = 0; i < state.length; i++)
          if (i == existing) state[i].copyWith(qty: state[i].qty + 1) else state[i],
      ];
    } else {
      state = [...state, TransactionItem.fromProduct(product)];
    }
  }

  void updateQty(int index, int qty) {
    if (qty <= 0) {
      removeAt(index);
      return;
    }
    state = [
      for (var i = 0; i < state.length; i++)
        if (i == index) state[i].copyWith(qty: qty) else state[i],
    ];
  }

  /// Kurangi 1 pada baris TERAKHIR produk ini (qty 1 → baris dihapus).
  void decrementProduct(String? productId) {
    final idx = state.lastIndexWhere((i) => i.productId == productId);
    if (idx >= 0) updateQty(idx, state[idx].qty - 1);
  }

  void updateDiscount(int index, int discount) {
    state = [
      for (var i = 0; i < state.length; i++)
        if (i == index) state[i].copyWith(discount: discount.clamp(0, state[i].price)) else state[i],
    ];
  }

  void setNote(int index, String? note) {
    state = [
      for (var i = 0; i < state.length; i++)
        if (i == index) state[i].copyWith(note: note) else state[i],
    ];
  }

  void removeAt(int index) {
    state = [...state.take(index), ...state.skip(index + 1)];
    _dropResumedIfEmpty();
  }

  /// Ganti seluruh isi keranjang (dipakai saat melanjutkan pesanan terbuka).
  void setItems(List<TransactionItem> items) => state = List.of(items);

  void clear() {
    state = [];
    _dropResumedIfEmpty();
  }

  /// Keranjang jadi kosong saat melanjutkan pesanan → lepas resumed,
  /// agar isi keranjang berikutnya tidak tersimpan ke baris pesanan lama
  /// (pesanan lama tetap `open` di DB).
  void _dropResumedIfEmpty() {
    if (state.isEmpty) ref.read(resumedOrderProvider.notifier).state = null;
  }
}

/// Id + label pesanan terbuka yang sedang dilanjutkan di keranjang
/// (null = keranjang adalah pesanan baru, bukan lanjutan).
typedef OpenOrderRef = ({String id, String label});
final resumedOrderProvider = StateProvider<OpenOrderRef?>((ref) => null);

final cartProvider = NotifierProvider<CartNotifier, List<TransactionItem>>(
  CartNotifier.new,
);
