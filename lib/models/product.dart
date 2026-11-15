class Product {
  final String? id;
  final String name;
  final String? category;
  final int price;
  final int hpp;
  final bool ready;
  final bool archived;
  final String? imagePath;
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
    required this.createdAt,
    required this.updatedAt,
  });

  Product copyWith({
    String? name,
    String? category,
    int? price,
    int? hpp,
    bool? ready,
    bool? archived,
    String? imagePath,
  }) =>
      Product(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        price: price ?? this.price,
        hpp: hpp ?? this.hpp,
        ready: ready ?? this.ready,
        archived: archived ?? this.archived,
        imagePath: imagePath ?? this.imagePath,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  Product toggleReady() => copyWith(ready: !ready);

  int get margin => price - hpp;
}
