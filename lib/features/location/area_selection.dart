import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/prefs_keys.dart';
import '../../data/models/location_node.dart';
import '../../data/repositories/providers.dart';

/// Customer's persisted search area. Choosing a new state clears an
/// incompatible LGA (PRD 5.2).
class SelectedAreaController extends Notifier<AreaScope?> {
  @override
  AreaScope? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final locations = ref.watch(locationRepositoryProvider);
    final stateId = prefs.getString(PrefsKeys.selectedStateId);
    if (stateId == null || locations.byId(stateId) == null) return null;

    final lgaId = prefs.getString(PrefsKeys.selectedLgaId);
    final neighbourhoodId = prefs.getString(PrefsKeys.selectedNeighbourhoodId);
    if (!locations.isValidPair(stateId, lgaId)) {
      return AreaScope(stateId: stateId);
    }
    final validHood = locations.byId(neighbourhoodId)?.parentId == lgaId;
    return AreaScope(
      stateId: stateId,
      lgaId: lgaId,
      neighbourhoodId: validHood ? neighbourhoodId : null,
    );
  }

  void select(AreaScope area) {
    state = area;
    _persist(area);
  }

  void chooseState(String stateId) {
    final area = AreaScope(stateId: stateId);
    state = area;
    _persist(area);
  }

  void chooseLga(String stateId, String? lgaId, {String? neighbourhoodId}) {
    final area = AreaScope(
      stateId: stateId,
      lgaId: lgaId,
      neighbourhoodId: lgaId == null ? null : neighbourhoodId,
    );
    state = area;
    _persist(area);
  }

  void clear() {
    state = null;
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.remove(PrefsKeys.selectedStateId);
    prefs.remove(PrefsKeys.selectedLgaId);
    prefs.remove(PrefsKeys.selectedNeighbourhoodId);
  }

  void _persist(AreaScope area) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(PrefsKeys.selectedStateId, area.stateId);
    if (area.lgaId == null) {
      prefs.remove(PrefsKeys.selectedLgaId);
      prefs.remove(PrefsKeys.selectedNeighbourhoodId);
    } else {
      prefs.setString(PrefsKeys.selectedLgaId, area.lgaId!);
      if (area.neighbourhoodId == null) {
        prefs.remove(PrefsKeys.selectedNeighbourhoodId);
      } else {
        prefs.setString(
          PrefsKeys.selectedNeighbourhoodId,
          area.neighbourhoodId!,
        );
      }
    }
  }
}

final selectedAreaProvider =
    NotifierProvider<SelectedAreaController, AreaScope?>(
  SelectedAreaController.new,
);
