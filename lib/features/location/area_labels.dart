import '../../data/models/business.dart';
import '../../data/models/location_node.dart';
import '../../data/repositories/location_repository.dart';

String areaChipLabel(AreaScope? area, LocationRepository locations) {
  if (area == null) return 'Choose area';
  final state = locations.byId(area.stateId)?.name ?? 'Nigeria';
  if (area.lgaId == null) return '$state · whole state';
  final lga = locations.byId(area.lgaId)?.name ?? 'LGA';
  final hood = locations.byId(area.neighbourhoodId);
  if (hood != null) return '${hood.name}, $lga';
  return '$lga, $state';
}

String areaInlineLabel(AreaScope area, LocationRepository locations) {
  final state = locations.byId(area.stateId)?.name ?? 'Nigeria';
  if (area.lgaId == null) return state;
  final lga = locations.byId(area.lgaId)?.name ?? '';
  final hood = locations.byId(area.neighbourhoodId);
  return hood == null ? '$lga, $state' : '${hood.name}, $lga';
}

String businessAreaLabel(Business business, LocationRepository locations) {
  if (business.operatingModel == OperatingModel.fixedLocation) {
    final lga = locations.byId(business.lgaId)?.name;
    return lga == null
        ? 'Based in ${business.baseArea}'
        : 'Based in ${business.baseArea}, $lga';
  }

  final names = business.serviceAreaLgaIds
      .map((id) => locations.byId(id)?.name)
      .whereType<String>()
      .toList();
  if (names.isEmpty) return 'Serves ${business.baseArea}';
  if (names.length == 1) return 'Serves ${names.first}';
  if (names.length == 2) return 'Serves ${names.first} and ${names[1]}';
  return 'Serves ${names.take(2).join(', ')} +${names.length - 2}';
}
