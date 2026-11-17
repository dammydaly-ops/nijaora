enum CategoryKind { service, product }

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.synonyms,
    required this.description,
    this.parentId,
    this.kind = CategoryKind.service,
  });

  final String id;
  final String name;
  final List<String> synonyms;
  final String description;

  /// Parent category for a specific trade/service. `null` for a parent.
  final String? parentId;

  /// Whether this belongs to the services tree or the products tree.
  final CategoryKind kind;

  bool get isParent => parentId == null;
  bool get isService => kind == CategoryKind.service;
  bool get isProduct => kind == CategoryKind.product;

  /// Everything keyword search should consider for this category.
  List<String> get searchableTerms => [name, ...synonyms];
}
