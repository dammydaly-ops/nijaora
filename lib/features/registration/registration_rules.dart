import '../../core/config/app_config.dart';
import '../../core/utils/phone.dart';
import '../../data/models/business.dart';
import '../../data/models/business_draft.dart';
import '../../data/repositories/location_repository.dart';

enum BusinessField {
  phone,
  name,
  category,
  state,
  lga,
  baseArea,
  operatingModel,
  servedAreas,
  ownerName,
  photos,
}

/// Plain-language messages from PRD 5.8.
const businessFieldMessages = {
  BusinessField.phone: 'Please confirm your phone number.',
  BusinessField.name: 'Enter your business name.',
  BusinessField.category: 'Choose what you do.',
  BusinessField.state: 'Choose your state.',
  BusinessField.lga: 'Choose an LGA in this state.',
  BusinessField.baseArea: 'Tell customers where you are based.',
  BusinessField.operatingModel: 'Choose how you work.',
  BusinessField.servedAreas: 'Choose where you can work.',
  BusinessField.ownerName: 'Add the name customers should see.',
  BusinessField.photos: 'Add at least three photos of your work.',
};

/// Returns one message per failing field. An empty map means the draft can be
/// published. Mirrors the server-side check that will run in a callable.
Map<BusinessField, String> validateBusinessDraft(
  BusinessDraft draft,
  LocationRepository locations,
) {
  final errors = <BusinessField, String>{};

  if (!draft.phoneVerified) {
    errors[BusinessField.phone] = businessFieldMessages[BusinessField.phone]!;
  }
  if (!isValidBusinessName(draft.name)) {
    errors[BusinessField.name] = businessFieldMessages[BusinessField.name]!;
  }
  if (draft.categoryIds.isEmpty) {
    errors[BusinessField.category] =
        businessFieldMessages[BusinessField.category]!;
  }
  if (draft.stateId == null) {
    errors[BusinessField.state] = businessFieldMessages[BusinessField.state]!;
  }
  if (!locations.isValidPair(draft.stateId, draft.lgaId)) {
    errors[BusinessField.lga] = businessFieldMessages[BusinessField.lga]!;
  }
  if (draft.baseArea.trim().isEmpty && draft.neighbourhoodId == null) {
    errors[BusinessField.baseArea] =
        businessFieldMessages[BusinessField.baseArea]!;
  }
  if (draft.operatingModel == null) {
    errors[BusinessField.operatingModel] =
        businessFieldMessages[BusinessField.operatingModel]!;
  }
  if (draft.operatingModel == OperatingModel.mobile) {
    final servedBesidesBase = draft.serviceAreaLgaIds
        .where((id) => id != draft.lgaId)
        .toList();
    if (servedBesidesBase.isEmpty) {
      errors[BusinessField.servedAreas] =
          businessFieldMessages[BusinessField.servedAreas]!;
    }
  }
  if (draft.ownerName.trim().isEmpty) {
    errors[BusinessField.ownerName] =
        businessFieldMessages[BusinessField.ownerName]!;
  }
  if (draft.photos.length < AppConfig.minPortfolioPhotos) {
    errors[BusinessField.photos] = businessFieldMessages[BusinessField.photos]!;
  }

  return errors;
}
