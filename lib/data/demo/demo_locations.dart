import '../models/location_node.dart';
import '../reference/nigeria_lgas.dart' as reference;

/// Demo reference dataset.
///
/// Covers all 37 states/FCT, full LGAs for Lagos, FCT and Oyo, plus curated
/// neighbourhoods and adjacency for the pilot zone. A production dataset can
/// replace this without touching the UI or matching code.
class DemoLocations {
  DemoLocations._();

  static String slugify(String value) {
    return value
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'(^-+|-+$)'), '');
  }

  static const Map<String, String> statesByCode = {
    'ab': 'Abia',
    'ad': 'Adamawa',
    'ak': 'Akwa Ibom',
    'an': 'Anambra',
    'ba': 'Bauchi',
    'by': 'Bayelsa',
    'be': 'Benue',
    'bo': 'Borno',
    'cr': 'Cross River',
    'de': 'Delta',
    'eb': 'Ebonyi',
    'ed': 'Edo',
    'ek': 'Ekiti',
    'en': 'Enugu',
    'fc': 'Federal Capital Territory',
    'go': 'Gombe',
    'im': 'Imo',
    'ji': 'Jigawa',
    'kd': 'Kaduna',
    'kn': 'Kano',
    'kt': 'Katsina',
    'ke': 'Kebbi',
    'ko': 'Kogi',
    'kw': 'Kwara',
    'la': 'Lagos',
    'na': 'Nasarawa',
    'ni': 'Niger',
    'og': 'Ogun',
    'on': 'Ondo',
    'os': 'Osun',
    'oy': 'Oyo',
    'pl': 'Plateau',
    'ri': 'Rivers',
    'so': 'Sokoto',
    'ta': 'Taraba',
    'yo': 'Yobe',
    'za': 'Zamfara',
  };

  static const Map<String, List<String>> lgasByState = reference.lgasByState;

  static const Map<String, List<String>> neighbourhoodsByLga = {
    'ng-la-ikeja': [
      'Allen Avenue',
      'Opebi',
      'Oregun',
      'Maryland',
      'Agidingbi',
      'Ogba',
    ],
    'ng-la-surulere': [
      'Ojuelegba',
      'Bode Thomas',
      'Aguda',
      'Itire',
      'Adeniran Ogunsanya',
    ],
    'ng-la-eti-osa': [
      'Lekki Phase 1',
      'Victoria Island',
      'Ikoyi',
      'Ajah',
      'Sangotedo',
      'Chevron Drive',
    ],
    'ng-oy-ibadan-north': [
      'Bodija',
      'Agbowo',
      'Mokola',
      'University of Ibadan',
    ],
    'ng-fc-abuja-municipal-amac': [
      'Wuse 2',
      'Garki',
      'Maitama',
      'Asokoro',
      'Gwarinpa',
      'Kubwa',
    ],
  };

  static const Map<String, List<String>> neighbourhoodAliases = {
    'Lekki Phase 1': ['Lekki'],
    'Victoria Island': ['VI'],
    'University of Ibadan': ['UI'],
    'Wuse 2': ['Wuse'],
  };

  static const Map<String, List<String>> _adjacent = {
    'ng-la-ikeja': [
      'ng-la-agege',
      'ng-la-ifako-ijaiye',
      'ng-la-kosofe',
      'ng-la-oshodi-isolo',
    ],
    'ng-la-surulere': [
      'ng-la-lagos-mainland',
      'ng-la-mushin',
      'ng-la-oshodi-isolo',
      'ng-la-apapa',
    ],
    'ng-la-eti-osa': [
      'ng-la-lagos-island',
      'ng-la-ibeju-lekki',
    ],
    'ng-la-lagos-mainland': [
      'ng-la-surulere',
      'ng-la-mushin',
      'ng-la-shomolu',
    ],
    'ng-oy-ibadan-north': [
      'ng-oy-ibadan-north-east',
      'ng-oy-ibadan-north-west',
      'ng-oy-ibadan-south-west',
      'ng-oy-egbeda',
      'ng-oy-lagelu',
    ],
    'ng-fc-abuja-municipal-amac': [
      'ng-fc-bwari',
      'ng-fc-gwagwalada',
      'ng-fc-kuje',
    ],
  };

  static final List<LocationNode> nodes = _build();

  static List<LocationNode> _build() {
    final result = <LocationNode>[];

    for (final entry in statesByCode.entries) {
      final stateId = 'ng-${entry.key}';
      result.add(LocationNode(
        id: stateId,
        type: LocationType.state,
        name: entry.value,
        aliases: switch (entry.key) {
          'fc' => const ['Abuja', 'FCT'],
          'la' => const ['Eko'],
          'oy' => const ['Ibadan'],
          _ => const [],
        },
      ));

      for (final lgaName in lgasByState[entry.key] ?? const <String>[]) {
        final lgaId = '$stateId-${slugify(lgaName)}';
        result.add(LocationNode(
          id: lgaId,
          type: LocationType.lga,
          parentId: stateId,
          name: lgaName,
          aliases: switch (lgaName) {
            'Abuja Municipal (AMAC)' => const ['AMAC', 'Municipal'],
            'Ibadan North' => const ['Ibadan'],
            _ => const [],
          },
          adjacentIds: _adjacentFor(lgaId),
        ));

        for (final hood in neighbourhoodsByLga[lgaId] ?? const <String>[]) {
          result.add(LocationNode(
            id: '$lgaId-${slugify(hood)}',
            type: LocationType.neighbourhood,
            parentId: lgaId,
            name: hood,
            aliases: neighbourhoodAliases[hood] ?? const [],
          ));
        }
      }
    }

    return List.unmodifiable(result);
  }

  static List<String> _adjacentFor(String lgaId) {
    final neighbours = <String>{};
    _adjacent.forEach((from, targets) {
      if (from == lgaId) neighbours.addAll(targets);
      if (targets.contains(lgaId)) neighbours.add(from);
    });
    return List.unmodifiable(neighbours);
  }
}
