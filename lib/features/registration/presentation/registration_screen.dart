import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_palette.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/photo_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/phone.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/network_photo.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/business.dart';
import '../../../data/models/business_draft.dart';
import '../../../data/models/category.dart';
import '../../../data/reference/catalog_taxonomy.dart';
import '../../../data/repositories/location_repository.dart';
import '../../../data/repositories/providers.dart';
import '../../location/area_picker_sheet.dart';
import '../registration_rules.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({
    super.key,
    this.initialKind = CategoryKind.service,
  });

  final CategoryKind initialKind;

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  static const _stepTitles = [
    'What do you offer?',
    'Your business',
    'Where you work',
    'Contact & photos',
    'Preview & publish',
  ];

  static const _stepFields = <Set<BusinessField>>[
    {BusinessField.category},
    {BusinessField.name},
    {
      BusinessField.state,
      BusinessField.lga,
      BusinessField.baseArea,
      BusinessField.operatingModel,
      BusinessField.servedAreas,
    },
    {BusinessField.phone, BusinessField.ownerName, BusinessField.photos},
    {},
  ];

  static const _fieldLabels = {
    BusinessField.phone: 'Business phone',
    BusinessField.name: 'Business name',
    BusinessField.category: 'Category',
    BusinessField.state: 'State',
    BusinessField.lga: 'LGA',
    BusinessField.baseArea: 'Base area',
    BusinessField.operatingModel: 'Operating model',
    BusinessField.servedAreas: 'Served areas',
    BusinessField.ownerName: 'Owner name',
    BusinessField.photos: 'Portfolio photos',
  };

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _baseAreaController = TextEditingController();
  final _addressController = TextEditingController();
  final _businessPhoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerBioController = TextEditingController();
  final _listingTitleController = TextEditingController();
  final _listingPriceController = TextEditingController();

  BusinessDraft _draft = const BusinessDraft();
  final List<String> _photos = [];
  final PhotoService _photoService = PhotoService();
  Map<BusinessField, String> _errors = const {};
  int _step = 0;
  bool _publishing = false;
  String? _expandedCategoryParent;
  late CategoryKind _categoryKind;

  @override
  void initState() {
    super.initState();
    _categoryKind = widget.initialKind;
    final user = ref.read(currentUserProvider);
    if (user != null) {
      final normalizedPhone = normalizeNigerianPhone(user.phone);
      _ownerNameController.text = user.displayName;
      _businessPhoneController.text = normalizedPhone ?? user.phone;
      _draft = _draft.copyWith(
        phoneVerified: normalizedPhone != null,
        phoneNumber: normalizedPhone,
        ownerName: user.displayName,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _baseAreaController.dispose();
    _addressController.dispose();
    _whatsappController.dispose();
    _ownerNameController.dispose();
    _ownerBioController.dispose();
    _businessPhoneController.dispose();
    _listingTitleController.dispose();
    _listingPriceController.dispose();
    super.dispose();
  }

  void _updateDraft() {
    final priceText = _listingPriceController.text.replaceAll(',', '').trim();
    final contactPhone = _businessPhoneController.text.trim();
    final normalizedPhone = normalizeNigerianPhone(contactPhone);
    _draft = _draft.copyWith(
      name: _nameController.text,
      description: _descriptionController.text,
      baseArea: _baseAreaController.text,
      address: _addressController.text,
      phoneNumber: normalizedPhone ?? contactPhone,
      phoneVerified: normalizedPhone != null,
      whatsappNumber: _whatsappController.text.trim().isEmpty
          ? null
          : _whatsappController.text.trim(),
      photos: List.of(_photos),
      ownerName: _ownerNameController.text.trim(),
      ownerBio: _ownerBioController.text.trim().isEmpty
          ? null
          : _ownerBioController.text.trim(),
      listingTitle: _listingTitleController.text.trim(),
      listingPrice: priceText.isEmpty ? null : int.tryParse(priceText),
      clearListingPrice: priceText.isEmpty,
    );
  }

  void _onFieldChanged() {
    setState(() {
      _updateDraft();
      final all = validateBusinessDraft(
        _draft,
        ref.read(locationRepositoryProvider),
      );
      final remaining = <BusinessField, String>{};
      for (final field in _errors.keys) {
        if (all[field] != null) remaining[field] = all[field]!;
      }
      _errors = remaining;
    });
  }

  bool _validateStep({required bool advance}) {
    _updateDraft();
    final all = validateBusinessDraft(
      _draft,
      ref.read(locationRepositoryProvider),
    );
    final relevant = <BusinessField, String>{};
    for (final field in _stepFields[_step]) {
      if (all[field] != null) relevant[field] = all[field]!;
    }
    setState(() => _errors = {..._errors, ...all});
    if (relevant.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(relevant.values.first)));
      }
      return false;
    }
    return advance;
  }

  void _next() {
    if (!_validateStep(advance: true)) return;
    if (_step < _stepTitles.length - 1) {
      setState(() => _step++);
    }
  }

  void _back() {
    if (_step == 0) {
      context.pop();
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _pickLocation() async {
    final picked = await showAreaPicker(context);
    if (picked == null) return;
    if (picked.lgaId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose an LGA, not the whole state.')),
        );
      }
      return;
    }
    final locations = ref.read(locationRepositoryProvider);
    final baseArea =
        locations.byId(picked.neighbourhoodId)?.name ??
        locations.byId(picked.lgaId)?.name ??
        '';
    _baseAreaController.text = baseArea;

    final served = List<String>.of(_draft.serviceAreaLgaIds);
    if (_draft.operatingModel == OperatingModel.mobile &&
        !served.contains(picked.lgaId)) {
      served.add(picked.lgaId!);
    }

    setState(() {
      _draft = _draft.copyWith(
        stateId: picked.stateId,
        lgaId: picked.lgaId,
        neighbourhoodId: picked.neighbourhoodId,
        baseArea: baseArea,
        serviceAreaLgaIds: served,
      );
    });
  }

  void _toggleCategory(String id) {
    final ids = List<String>.of(_draft.categoryIds);
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      if (ids.length >= 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose up to two categories.')),
        );
        return;
      }
      ids.add(id);
    }
    setState(() => _draft = _draft.copyWith(categoryIds: ids));
  }

  void _setOperatingModel(OperatingModel model) {
    final served = List<String>.of(_draft.serviceAreaLgaIds);
    if (model == OperatingModel.mobile &&
        _draft.lgaId != null &&
        !served.contains(_draft.lgaId)) {
      served.add(_draft.lgaId!);
    }
    setState(() {
      _draft = _draft.copyWith(
        operatingModel: model,
        serviceAreaLgaIds: served,
      );
    });
  }

  void _toggleServedLga(String id) {
    final served = List<String>.of(_draft.serviceAreaLgaIds);
    if (served.contains(id)) {
      served.remove(id);
    } else {
      if (served.length >= AppConfig.maxServedLgas) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You can choose up to ${AppConfig.maxServedLgas} LGAs.',
            ),
          ),
        );
        return;
      }
      served.add(id);
    }
    setState(() => _draft = _draft.copyWith(serviceAreaLgaIds: served));
  }

  Future<void> _pickPhotos() async {
    final remaining = AppConfig.maxPortfolioPhotos - _photos.length;
    if (remaining <= 0) return;
    try {
      final picked = await _photoService.pickPortfolioPhotos(limit: remaining);
      if (!mounted || picked.isEmpty) return;
      setState(() {
        _photos.addAll(picked.take(remaining));
        _updateDraft();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add those photos: $error')),
      );
    }
  }

  Future<void> _pickOwnerPhoto() async {
    try {
      final picked = await _photoService.pickOwnerPhoto();
      if (!mounted || picked == null) return;
      setState(() => _draft = _draft.copyWith(ownerPhotoUrl: picked));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add your photo: $error')),
      );
    }
  }

  Future<void> _publish() async {
    _updateDraft();
    final all = validateBusinessDraft(
      _draft,
      ref.read(locationRepositoryProvider),
    );
    setState(() => _errors = all);
    if (all.isNotEmpty) {
      final first = all.entries.first;
      setState(() => _step = _stepForField(first.key));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(first.value)));
      return;
    }

    if (_categoryKind == CategoryKind.product &&
        _draft.listingTitle.trim().isEmpty) {
      setState(() => _step = 1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add a product name so buyers can find it in Products.',
          ),
        ),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _publishing = true);
    try {
      if (user.role != UserRole.business) {
        await ref.read(authRepositoryProvider).updateRole(UserRole.business);
      }
      final business = await ref
          .read(businessRepositoryProvider)
          .publish(_draft, ownerId: user.id);
      ref.invalidate(publishedBusinessesProvider);
      ref.invalidate(productItemsProvider);
      ref.invalidate(businessProvider(business.id));
      ref.read(analyticsProvider).track('business_published', {
        'category': _draft.categoryIds.first,
        'stateId': _draft.stateId,
        'lgaId': _draft.lgaId,
        'onboardingSource': 'self',
      });
      if (!mounted) return;
      context.go('/business/${business.id}');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('We could not publish your profile. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  int _stepForField(BusinessField field) {
    if (field == BusinessField.category) return 0;
    if (field == BusinessField.name) return 1;
    if (field == BusinessField.phone || field == BusinessField.photos) return 3;
    if (field == BusinessField.state ||
        field == BusinessField.lga ||
        field == BusinessField.baseArea ||
        field == BusinessField.operatingModel ||
        field == BusinessField.servedAreas) {
      return 2;
    }
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create your business')),
        body: EmptyState(
          icon: Icons.storefront_rounded,
          title: 'Sign in to list your business',
          message:
              'A verified phone number helps customers trust your profile. '
              'It takes under five minutes.',
          actions: [
            FilledButton(
              onPressed: () => context.go('/welcome'),
              child: const Text('Sign in with phone'),
            ),
          ],
        ),
      );
    }

    final locations = ref.watch(locationRepositoryProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final errors = validateBusinessDraft(_draft, locations);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Create your business'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Step ${_step + 1} of ${_stepTitles.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Text(
                      _stepTitles[_step],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / _stepTitles.length,
                    minHeight: 6,
                    backgroundColor: context.palette.surfaceAlt,
                    valueColor: AlwaysStoppedAnimation(context.palette.amber),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: _stepContent(categories, locations, errors),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: context.palette.surface,
              border: Border(top: BorderSide(color: context.palette.border)),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  if (_step > 0)
                    OutlinedButton(
                      onPressed: _publishing ? null : _back,
                      child: const Text('Back'),
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: _publishing
                          ? null
                          : _step == _stepTitles.length - 1
                          ? (errors.isEmpty ? _publish : null)
                          : _next,
                      child: _publishing
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: context.palette.cream,
                              ),
                            )
                          : Text(
                              _step == _stepTitles.length - 1
                                  ? 'Publish profile'
                                  : 'Continue',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _stepContent(
    List<Category> categories,
    LocationRepository locations,
    Map<BusinessField, String> errors,
  ) {
    return switch (_step) {
      0 => [
        SegmentedButton<CategoryKind>(
          segments: const [
            ButtonSegment(
              value: CategoryKind.service,
              label: Text('Services'),
              icon: Icon(Icons.handyman_outlined),
            ),
            ButtonSegment(
              value: CategoryKind.product,
              label: Text('Products'),
              icon: Icon(Icons.shopping_bag_outlined),
            ),
          ],
          selected: {_categoryKind},
          onSelectionChanged: (selection) {
            setState(() {
              _categoryKind = selection.first;
              _expandedCategoryParent = null;
              _draft = _draft.copyWith(categoryIds: const []);
              _errors = {..._errors}..remove(BusinessField.category);
            });
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          _categoryKind == CategoryKind.product
              ? 'Choose a product category, then the specific shelf customers '
                    'will find you on.'
              : 'Choose a parent category, then the specific trade customers '
                    'will find you for. You can add a second trade.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final parent
            in _categoryKind == CategoryKind.product
                ? productParents(categories)
                : serviceParents(categories)) ...[
          _SelectableRow(
            title: parent.name,
            subtitle:
                '${childrenOf(categories, parent.id).length} '
                '${_categoryKind == CategoryKind.product ? 'categories' : 'services'}',
            selected: _draft.categoryIds.any(
              (id) => categoryById(categories, id)?.parentId == parent.id,
            ),
            trailingLabel:
                _draft.categoryIds.any(
                  (id) => categoryById(categories, id)?.parentId == parent.id,
                )
                ? 'Selected'
                : null,
            onTap: () => setState(() {
              _expandedCategoryParent = _expandedCategoryParent == parent.id
                  ? null
                  : parent.id;
            }),
          ),
          if (_expandedCategoryParent == parent.id)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                bottom: AppSpacing.sm,
              ),
              child: Column(
                children: [
                  for (final child in childrenOf(categories, parent.id))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: _SelectableRow(
                        title: child.name,
                        subtitle: child.description,
                        selected: _draft.categoryIds.contains(child.id),
                        trailingLabel: _draft.categoryIds.contains(child.id)
                            ? (_draft.categoryIds.first == child.id
                                  ? 'Primary'
                                  : 'Secondary')
                            : null,
                        onTap: () => _toggleCategory(child.id),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
        _errorText(BusinessField.category, errors),
      ],
      1 => [
        Text(
          'Customers see this first. Be specific about what you make or fix.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _nameController,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _onFieldChanged(),
          decoration: const InputDecoration(
            labelText: 'Business name',
            hintText: 'e.g. Radiance Tailors',
            counterText: '',
          ),
        ),
        _errorText(BusinessField.name, errors),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          minLines: 3,
          maxLength: 300,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => _onFieldChanged(),
          decoration: const InputDecoration(
            labelText: 'Short description',
            hintText:
                'What do you do, how long have you done it, and what should '
                'a customer know?',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          _categoryKind == CategoryKind.product
              ? 'Your first product'
              : 'Your first service',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 2),
        Text(
          _categoryKind == CategoryKind.product
              ? 'This is the item customers will see in Products. You can add '
                    'more later.'
              : 'This is the service customers will see on your profile.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _listingTitleController,
          maxLength: 70,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => _onFieldChanged(),
          decoration: InputDecoration(
            labelText: _categoryKind == CategoryKind.product
                ? 'Product name'
                : 'Service name',
            hintText: _categoryKind == CategoryKind.product
                ? 'e.g. Ankara midi dress'
                : 'e.g. Bridal makeup',
            counterText: '',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _listingPriceController,
          keyboardType: TextInputType.number,
          onChanged: (_) => _onFieldChanged(),
          decoration: const InputDecoration(
            labelText: 'Price (optional)',
            prefixText: '₦ ',
            hintText: 'Leave blank for “price on request”',
          ),
        ),
      ],
      2 => [
        Text(
          'Your base must be in Nigeria. A shop or street address is optional '
          'and only shown to customers if you add it.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Base location', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        _SelectableRow(
          title: _draft.stateId == null
              ? 'Choose state and LGA'
              : '${locations.byId(_draft.lgaId)?.name ?? ''}, '
                    '${locations.byId(_draft.stateId)?.name ?? ''}',
          subtitle: _draft.neighbourhoodId == null
              ? 'Tap to choose'
              : locations.byId(_draft.neighbourhoodId)?.name ?? 'Tap to change',
          selected: _draft.lgaId != null,
          onTap: _pickLocation,
          trailingLabel: 'Change',
        ),
        _errorText(BusinessField.state, errors),
        _errorText(BusinessField.lga, errors),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _baseAreaController,
          onChanged: (_) => _onFieldChanged(),
          decoration: const InputDecoration(
            labelText: 'Neighbourhood or area',
            hintText: 'e.g. Allen Avenue, Opebi, Bodija',
          ),
        ),
        _errorText(BusinessField.baseArea, errors),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _addressController,
          maxLength: 160,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _onFieldChanged(),
          decoration: const InputDecoration(
            labelText: 'Business address (optional)',
            hintText: 'Shop number, street, landmark',
            helperText: 'Only add this if you want customers to see it.',
            counterText: '',
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'How do you work?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _ModelCard(
                title: 'Fixed location',
                subtitle: 'Customers come to your shop',
                icon: Icons.storefront_rounded,
                selected: _draft.operatingModel == OperatingModel.fixedLocation,
                onTap: () => _setOperatingModel(OperatingModel.fixedLocation),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ModelCard(
                title: 'Mobile / on-site',
                subtitle: 'You travel to customers',
                icon: Icons.directions_car_rounded,
                selected: _draft.operatingModel == OperatingModel.mobile,
                onTap: () => _setOperatingModel(OperatingModel.mobile),
              ),
            ),
          ],
        ),
        _errorText(BusinessField.operatingModel, errors),
        if (_draft.operatingModel == OperatingModel.mobile) ...[
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Where can you work?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${_draft.serviceAreaLgaIds.length}/${AppConfig.maxServedLgas}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Choose the LGAs you actually serve, including your base. '
            'Add at least one more LGA besides your base.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_draft.stateId == null)
            Text(
              'Choose your state and LGA first.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final lga in locations.lgas(_draft.stateId!))
                  _SelectableChip(
                    label: lga.name,
                    selected: _draft.serviceAreaLgaIds.contains(lga.id),
                    onTap: () => _toggleServedLga(lga.id),
                  ),
              ],
            ),
          _errorText(BusinessField.servedAreas, errors),
        ],
      ],
      3 => [
        Text(
          'Chat is always on. WhatsApp is optional but many customers prefer '
          'it.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _businessPhoneController,
          keyboardType: TextInputType.phone,
          onChanged: (_) => _onFieldChanged(),
          decoration: const InputDecoration(
            labelText: 'Business phone number',
            hintText: '0803 123 4567',
            helperText: 'Customers will see this number on your profile.',
            prefixIcon: Icon(Icons.phone_iphone_rounded, size: 20),
          ),
        ),
        _errorText(BusinessField.phone, errors),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            ClipOval(
              child: NetworkPhoto(
                url: _draft.ownerPhotoUrl,
                width: 62,
                height: 62,
                fallbackIcon: Icons.person_rounded,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your photo',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'A clear face photo helps customers trust you.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _pickOwnerPhoto,
              child: Text(_draft.ownerPhotoUrl == null ? 'Add' : 'Change'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _ownerNameController,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _onFieldChanged(),
          decoration: const InputDecoration(
            labelText: 'Your name',
            hintText: 'e.g. Chidinma Okafor',
            helperText: 'Customers see who they are dealing with.',
          ),
        ),
        _errorText(BusinessField.ownerName, errors),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _ownerBioController,
          maxLines: 3,
          maxLength: 240,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => _onFieldChanged(),
          decoration: const InputDecoration(
            labelText: 'About you (optional)',
            hintText: 'Your experience, training or what you care about.',
            counterText: '',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _whatsappController,
          keyboardType: TextInputType.phone,
          onChanged: (_) => _onFieldChanged(),
          decoration: const InputDecoration(
            labelText: 'WhatsApp number (optional)',
            hintText: '0803 123 4567',
            helperText: 'Customers can tap through to WhatsApp.',
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: Text(
                'Portfolio photos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              '${_photos.length}/${AppConfig.maxPortfolioPhotos}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'At least three photos of your work. Add more later.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        if (_photos.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _photos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) => Stack(
              fit: StackFit.expand,
              children: [
                NetworkPhoto(
                  url: _photos[index],
                  borderRadius: BorderRadius.circular(12),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _photos.removeAt(index);
                        _updateDraft();
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.palette.ink,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 13,
                        color: context.palette.cream,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: _photos.length >= AppConfig.maxPortfolioPhotos
              ? null
              : _pickPhotos,
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
          label: const Text('Add photos'),
        ),
        _errorText(BusinessField.photos, errors),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Use photos of your own work. You can add up to '
          '${AppConfig.maxPortfolioPhotos}.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
        ),
      ],
      _ => [
        Text(
          'Check everything before you publish. You can edit your profile '
          'afterwards.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.palette.border),
          ),
          child: Column(
            children: [
              _SummaryRow(
                label: 'Business',
                value: _draft.name.trim().isEmpty
                    ? 'Not set'
                    : _draft.name.trim(),
              ),
              _SummaryRow(
                label: 'Category',
                value: _draft.categoryIds
                    .map((id) => _categoryName(categories, id))
                    .join(', '),
              ),
              if (_draft.listingTitle.trim().isNotEmpty)
                _SummaryRow(
                  label: _categoryKind == CategoryKind.product
                      ? 'Product'
                      : 'Service',
                  value: _draft.listingPrice == null
                      ? _draft.listingTitle.trim()
                      : '${_draft.listingTitle.trim()} · '
                            '${formatNaira(_draft.listingPrice!)}',
                ),
              _SummaryRow(
                label: 'Base',
                value: _draft.lgaId == null
                    ? 'Not set'
                    : '${_draft.baseArea}, '
                          '${locations.byId(_draft.lgaId)?.name ?? ''}',
              ),
              if (_draft.address.trim().isNotEmpty)
                _SummaryRow(label: 'Address', value: _draft.address.trim()),
              _SummaryRow(
                label: 'Operating model',
                value: _draft.operatingModel?.label ?? 'Not set',
              ),
              _SummaryRow(
                label: 'Served LGAs',
                value: _draft.operatingModel == OperatingModel.mobile
                    ? '${_draft.serviceAreaLgaIds.length} selected'
                    : 'Not applicable',
              ),
              _SummaryRow(
                label: 'Owner',
                value: _draft.ownerName.trim().isEmpty
                    ? 'Not set'
                    : _draft.ownerName.trim(),
              ),
              _SummaryRow(label: 'Photos', value: '${_photos.length} added'),
              _SummaryRow(
                label: 'WhatsApp',
                value: _draft.whatsappNumber ?? 'Not added',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Before you publish',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.palette.border),
          ),
          child: Column(
            children: [
              for (final field in BusinessField.values)
                ListTile(
                  dense: true,
                  leading: Icon(
                    errors[field] == null
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: errors[field] == null
                        ? context.palette.green
                        : context.palette.muted,
                  ),
                  title: Text(
                    _fieldLabels[field] ?? field.name,
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: errors[field] == null
                      ? null
                      : Text(
                          errors[field]!,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.palette.red,
                          ),
                        ),
                  trailing: errors[field] == null
                      ? null
                      : const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: errors[field] == null
                      ? null
                      : () => setState(() => _step = _stepForField(field)),
                ),
            ],
          ),
        ),
        if (errors.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Fix the items above to enable publishing.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.palette.red),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Photos and descriptions must be your own work and must not '
          'misrepresent your location. Nijaora may hide profiles that break '
          'the content rules.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
        ),
      ],
    };
  }

  String _categoryName(List<Category> categories, String id) {
    for (final category in categories) {
      if (category.id == id) return category.name;
    }
    return id;
  }

  Widget _errorText(BusinessField field, Map<BusinessField, String> errors) {
    final message = errors[field];
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: Text(
        message,
        style: TextStyle(color: context.palette.red, fontSize: 12),
      ),
    );
  }
}

class _SelectableRow extends StatelessWidget {
  const _SelectableRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.trailingLabel,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.palette.amberWash : context.palette.surface,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: Border.all(
              color: selected ? context.palette.amber : context.palette.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (trailingLabel != null)
                Text(
                  trailingLabel!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.palette.amberDeep,
                  ),
                ),
              if (selected)
                Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 17,
                    color: context.palette.amberDeep,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.palette.ink : context.palette.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? context.palette.ink : context.palette.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? context.palette.cream : context.palette.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.palette.amberWash : context.palette.surface,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: Border.all(
              color: selected ? context.palette.amber : context.palette.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontSize: 10.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not set' : value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
