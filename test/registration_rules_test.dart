import 'package:flutter_test/flutter_test.dart';
import 'package:nijagig/data/demo/demo_catalog.dart';
import 'package:nijagig/data/models/business.dart';
import 'package:nijagig/data/models/business_draft.dart';
import 'package:nijagig/data/repositories/demo/demo_location_repository.dart';
import 'package:nijagig/features/registration/registration_rules.dart';

void main() {
  final locations = DemoLocationRepository(DemoCatalog.instance);

  BusinessDraft completeDraft({
    OperatingModel model = OperatingModel.fixedLocation,
  }) {
    return BusinessDraft(
      name: 'Ada Stitches',
      description: 'Bespoke tailoring in Ikeja.',
      categoryIds: const ['tailoring'],
      stateId: 'ng-la',
      lgaId: 'ng-la-ikeja',
      neighbourhoodId: 'ng-la-ikeja-allen-avenue',
      baseArea: 'Allen Avenue',
      operatingModel: model,
      serviceAreaLgaIds: const ['ng-la-ikeja', 'ng-la-surulere'],
      phoneNumber: '+2348031234567',
      whatsappNumber: '+2348031234567',
      photos: const ['one.jpg', 'two.jpg', 'three.jpg'],
      phoneVerified: true,
      ownerName: 'Ada Okafor',
    );
  }

  test('an empty draft returns every required PRD 5.8 message', () {
    final errors = validateBusinessDraft(const BusinessDraft(), locations);

    expect(
      errors.keys,
      containsAll([
        BusinessField.phone,
        BusinessField.name,
        BusinessField.category,
        BusinessField.state,
        BusinessField.lga,
        BusinessField.baseArea,
        BusinessField.operatingModel,
        BusinessField.ownerName,
        BusinessField.photos,
      ]),
    );
    expect(
      errors.containsKey(BusinessField.servedAreas),
      isFalse,
      reason: 'service areas are only required once mobile is chosen',
    );
    expect(errors[BusinessField.phone], 'Please confirm your phone number.');
    expect(errors[BusinessField.name], 'Enter your business name.');
    expect(errors[BusinessField.category], 'Choose what you do.');
    expect(errors[BusinessField.state], 'Choose your state.');
    expect(errors[BusinessField.lga], 'Choose an LGA in this state.');
    expect(
      errors[BusinessField.baseArea],
      'Tell customers where you are based.',
    );
    expect(errors[BusinessField.operatingModel], 'Choose how you work.');
    expect(
      errors[BusinessField.ownerName],
      'Add the name customers should see.',
    );
    expect(
      errors[BusinessField.photos],
      'Add at least three photos of your work.',
    );
  });

  test('a complete fixed-location draft publishes cleanly', () {
    expect(validateBusinessDraft(completeDraft(), locations), isEmpty);
  });

  test('an LGA outside the chosen state is rejected', () {
    final draft = completeDraft().copyWith(stateId: 'ng-oy');

    final errors = validateBusinessDraft(draft, locations);

    expect(errors[BusinessField.lga], 'Choose an LGA in this state.');
  });

  test('mobile businesses must serve at least one LGA beyond their base', () {
    final onlyBase = completeDraft(model: OperatingModel.mobile)
        .copyWith(serviceAreaLgaIds: const ['ng-la-ikeja']);

    expect(
      validateBusinessDraft(onlyBase, locations)[BusinessField.servedAreas],
      'Choose where you can work.',
    );

    final withAnother =
        onlyBase.copyWith(serviceAreaLgaIds: const ['ng-la-ikeja', 'ng-la-agege']);
    expect(validateBusinessDraft(withAnother, locations), isEmpty);
  });

  test('fewer than three photos blocks publishing', () {
    final draft = completeDraft().copyWith(photos: const ['one.jpg']);

    expect(
      validateBusinessDraft(draft, locations)[BusinessField.photos],
      'Add at least three photos of your work.',
    );
  });

  test('business names need a letter and at least two characters', () {
    expect(
      validateBusinessDraft(completeDraft().copyWith(name: '7'), locations)[
        BusinessField.name
      ],
      'Enter your business name.',
    );
  });
}
