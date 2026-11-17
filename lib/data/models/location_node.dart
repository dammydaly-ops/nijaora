enum LocationType { state, lga, neighbourhood }

/// One node in the location reference dataset.
///
/// IDs are stable and never reused, including when a name changes or a node is
/// deprecated. Neighbourhoods are curated by Nijaora and belong to one LGA.
class LocationNode {
  const LocationNode({
    required this.id,
    required this.type,
    required this.name,
    this.parentId,
    this.aliases = const [],
    this.adjacentIds = const [],
    this.active = true,
    this.datasetVersion = '2026.10.1',
  });

  final String id;
  final LocationType type;
  final String name;
  final String? parentId;
  final List<String> aliases;

  /// Curated neighbouring LGAs, used for the "Nearby" empty-state flow.
  final List<String> adjacentIds;
  final bool active;
  final String datasetVersion;

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    if (name.toLowerCase().contains(needle)) return true;
    return aliases.any((alias) => alias.toLowerCase().contains(needle));
  }

  factory LocationNode.fromJson(Map<String, dynamic> json, String id) {
    return LocationNode(
      id: id,
      type: LocationType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => LocationType.lga,
      ),
      name: (json['name'] as String?) ?? '',
      parentId: json['parentId'] as String?,
      aliases: List<String>.from(json['aliases'] as List? ?? const []),
      adjacentIds: List<String>.from(json['adjacentIds'] as List? ?? const []),
      active: (json['active'] as bool?) ?? true,
      datasetVersion: (json['datasetVersion'] as String?) ?? '2026.10.1',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'name': name,
        'parentId': parentId,
        'aliases': aliases,
        'adjacentIds': adjacentIds,
        'active': active,
        'datasetVersion': datasetVersion,
      };
}

/// A customer's search scope. [lgaId] null means "whole state".
class AreaScope {
  const AreaScope({
    required this.stateId,
    this.lgaId,
    this.neighbourhoodId,
  });

  final String stateId;
  final String? lgaId;
  final String? neighbourhoodId;

  bool get isWholeState => lgaId == null;

  AreaScope copyWith({
    String? stateId,
    String? lgaId,
    String? neighbourhoodId,
    bool clearLga = false,
  }) {
    return AreaScope(
      stateId: stateId ?? this.stateId,
      lgaId: clearLga ? null : (lgaId ?? this.lgaId),
      neighbourhoodId:
          clearLga ? null : (neighbourhoodId ?? this.neighbourhoodId),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AreaScope &&
      other.stateId == stateId &&
      other.lgaId == lgaId &&
      other.neighbourhoodId == neighbourhoodId;

  @override
  int get hashCode => Object.hash(stateId, lgaId, neighbourhoodId);
}
