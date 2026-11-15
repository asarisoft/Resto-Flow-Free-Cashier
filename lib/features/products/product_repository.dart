import '../../core/services/daos/products_dao.dart';
import '../../models/product.dart';

class ProductRepository {
  final ProductsDao _dao;
  ProductRepository(this._dao);

  Future<List<Product>> getAll() => _dao.getAll();
  Stream<List<Product>> stream() => _dao.watchAll();
  Future<String> add(Product product) => _dao.add(product);
  Future<void> save(Product product) => _dao.save(product);
  Future<void> delete(String id) => _dao.archive(id);
  Future<void> toggleReady(String id, bool ready) => _dao.toggleReady(id, ready);
}
