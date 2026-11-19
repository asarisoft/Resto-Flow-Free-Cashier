import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/daos/categories_dao.dart';
import '../../core/services/database_provider.dart';

final categoriesDaoProvider =
    Provider<CategoriesDao>((ref) => CategoriesDao(ref.watch(databaseProvider)));

/// Daftar kategori (dengan jumlah pemakaian) per tipe: 'product' | 'expense'.
final categoryListProvider = StreamProvider.family<List<CategoryEntry>, String>(
    (ref, type) => ref.watch(categoriesDaoProvider).watch(type));
