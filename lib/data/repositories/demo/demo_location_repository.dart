import '../../demo/demo_catalog.dart';
import '../../models/location_node.dart';
import '../location_repository.dart';

class DemoLocationRepository implements LocationRepository {
  DemoLocationRepository(this._catalog)
      : _byId = {
          for (final node in _catalog.locations) node.id: node,
        };

  final DemoCatalog _catalog;
  final Map<String, LocationNode> _byId;

  @override
  String get datasetVersion => _catalog.locations.first.datasetVersion;

  @override
  List<LocationNode> states() =>
      _catalog.locations.where((node) => node.type == LocationType.state).toList();

  @override
  List<LocationNode> lgas(String stateId) => _catalog.locations
      .where((node) => node.type == LocationType.lga && node.parentId == stateId)
      .toList();

  @override
  List<LocationNode> neighbourhoods(String lgaId) => _catalog.locations
      .where((node) =>
          node.type == LocationType.neighbourhood && node.parentId == lgaId)
      .toList();

  @override
  LocationNode? byId(String? id) => id == null ? null : _byId[id];

  @override
  bool isValidPair(String? stateId, String? lgaId) {
    if (stateId == null || lgaId == null) return false;
    final lga = _byId[lgaId];
    return lga != null &&
        lga.type == LocationType.lga &&
        lga.parentId == stateId;
  }

  @override
  List<LocationNode> adjacentLgas(String lgaId) {
    final lga = _byId[lgaId];
    if (lga == null) return const [];
    return [
      for (final id in lga.adjacentIds)
        if (_byId[id] != null) _byId[id]!,
    ];
  }
}
