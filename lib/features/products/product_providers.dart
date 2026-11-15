import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/product.dart';
import '../../core/services/database_provider.dart';
import '../../core/services/daos/products_dao.dart';
import '../products/product_repository.dart';

final productsDaoProvider = Provider<ProductsDao>((ref) =>
    ProductsDao(ref.watch(databaseProvider)));

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(productsDaoProvider));
});

final productListProvider = StreamProvider<List<Product>>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  return repo.stream();
});

final productProvider = FutureProvider.family<Product?, String>((ref, id) async {
  final products = await ref.watch(productListProvider.future);
  try {
    return products.firstWhere((p) => p.id == id);
  } catch (_) {
    return null;
  }
});
