import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/location_node.dart';
import '../../repositories/location_repository.dart';

/// Loads the public location reference data from Supabase once at startup.
///
/// The app keeps the bundled dataset as a fallback, but this repository proves
/// the remote tables are the source of truth when they are available.
class SupabaseLocationRepository implements LocationRepository {
  SupabaseLocationRepository(this._nodes)
      : _byId = {for (final node in _nodes) node.id: node};

  final List<LocationNode> _nodes;
  final Map<String, LocationNode> _byId;

  static Future<SupabaseLocationRepository> load(SupabaseClient client) async {
    final results = await Future.wait([
      client
          .from('states')
          .select('id, name, dataset_version')
          .eq('active', true)
          .order('name', ascending: true),
      client
          .from('lgas')
          .select('id, state_id, name, adjacent_ids')
          .eq('active', true)
          .order('name', ascending: true),
      client
          .from('neighbourhoods')
          .select('id, lga_id, name, aliases')
          .eq('active', true)
          .order('name', ascending: true),
    ]);

    final states = results[0];
    final lgas = results[1];
    final neighbourhoods = results[2];
    final nodes = <LocationNode>[];

    for (final row in states) {
      nodes.add(
        LocationNode(
          id: row['id'] as String,
          type: LocationType.state,
          name: row['name'] as String,
          datasetVersion: row['dataset_version'] as String? ?? '2026.10.1',
        ),
      );
    }
    for (final row in lgas) {
      nodes.add(
        LocationNode(
          id: row['id'] as String,
          type: LocationType.lga,
          name: row['name'] as String,
          parentId: row['state_id'] as String,
          adjacentIds: List<String>.from(
            row['adjacent_ids'] as List? ?? const [],
          ),
        ),
      );
    }
    for (final row in neighbourhoods) {
      nodes.add(
        LocationNode(
          id: row['id'] as String,
          type: LocationType.neighbourhood,
          name: row['name'] as String,
          parentId: row['lga_id'] as String,
          aliases: List<String>.from(row['aliases'] as List? ?? const []),
        ),
      );
    }

    if (nodes.where((node) => node.type == LocationType.state).isEmpty) {
      throw StateError('Supabase location reference data is empty.');
    }
    return SupabaseLocationRepository(nodes);
  }

  @override
  String get datasetVersion {
    for (final node in _nodes) {
      if (node.type == LocationType.state) return node.datasetVersion;
    }
    return '2026.10.1';
  }

  @override
  List<LocationNode> states() => _nodes
      .where((node) => node.type == LocationType.state)
      .toList(growable: false);

  @override
  List<LocationNode> lgas(String stateId) => _nodes
      .where((node) =>
          node.type == LocationType.lga && node.parentId == stateId)
      .toList(growable: false);

  @override
  List<LocationNode> neighbourhoods(String lgaId) => _nodes
      .where((node) =>
          node.type == LocationType.neighbourhood && node.parentId == lgaId)
      .toList(growable: false);

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
