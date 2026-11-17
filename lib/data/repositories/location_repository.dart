import '../models/location_node.dart';

abstract class LocationRepository {
  String get datasetVersion;

  List<LocationNode> states();

  List<LocationNode> lgas(String stateId);

  List<LocationNode> neighbourhoods(String lgaId);

  LocationNode? byId(String? id);

  bool isValidPair(String? stateId, String? lgaId);

  List<LocationNode> adjacentLgas(String lgaId);
}
