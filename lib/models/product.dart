class Store {
  final String id;
  final String name;
  final String logo;
  final String color;

  Store({
    required this.id,
    required this.name,
    required this.logo,
    required this.color,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      logo: json['logo'] ?? '',
      color: json['color'] ?? '#D4AF37',
    );
  }
}

class Product {
  final String name;
  final String price;
  final double rawPrice;
  final String? listPrice;
  final int discount;
  final String? unitPrice;
  final double rawUnitPrice;
  final String img;
  final String link;
  final Store store;
  final List<String> promos;
  final double relevance;

  Product({
    required this.name,
    required this.price,
    required this.rawPrice,
    this.listPrice,
    required this.discount,
    this.unitPrice,
    required this.rawUnitPrice,
    required this.img,
    required this.link,
    required this.store,
    required this.promos,
    required this.relevance,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      name: json['name'] ?? '',
      price: json['price'] ?? '0,00',
      rawPrice: (json['raw_price'] ?? 0).toDouble(),
      listPrice: json['list_price'],
      discount: json['discount'] ?? 0,
      unitPrice: json['unit_price'],
      rawUnitPrice: (json['raw_unit_price'] ?? 999999).toDouble(),
      img: json['img'] ?? '',
      link: json['link'] ?? '',
      store: Store.fromJson(json['store'] ?? {}),
      promos: List<String>.from(json['promos'] ?? []),
      relevance: (json['relevance'] ?? 0).toDouble(),
    );
  }
}
