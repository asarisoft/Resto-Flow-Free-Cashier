class Product {
  final String? id;
  final String name;
  final String? category;
  final int price;
  final int hpp;
  final bool ready;
  final bool archived;
  final String? imagePath;

  /// Sisa porsi/stok. null = tidak dilacak.
  final int? stock;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    this.id,
    required this.name,
    this.category,
    required this.price,
    this.hpp = 0,
    this.ready = true,
    this.archived = false,
    this.imagePath,
    this.stock,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Stok dilacak dan sudah habis (≤ 0).
  bool get outOfStock => stock != null && stock! <= 0;

  static const _unset = Object();

  Product copyWith({
    String? id,
    String? name,
    String? category,
    int? price,
    int? hpp,
    bool? ready,
    bool? archived,
    String? imagePath,
    Object? stock = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        price: price ?? this.price,
        hpp: hpp ?? this.hpp,
        ready: ready ?? this.ready,
        archived: archived ?? this.archived,
        imagePath: imagePath ?? this.imagePath,
        stock: identical(stock, _unset) ? this.stock : stock as int?,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Product toggleReady() => copyWith(ready: !ready);

  int get margin => price - hpp;
}
