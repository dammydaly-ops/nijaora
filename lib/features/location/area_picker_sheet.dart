import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_palette.dart';
import '../../app/theme/app_spacing.dart';
import '../../data/models/location_node.dart';
import '../../data/repositories/location_repository.dart';
import '../../data/repositories/providers.dart';
import 'area_selection.dart';

Future<AreaScope?> showAreaPicker(BuildContext context) {
  return showModalBottomSheet<AreaScope>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const AreaPickerSheet(),
  );
}

enum _Step { state, lga, neighbourhood }

class AreaPickerSheet extends ConsumerStatefulWidget {
  const AreaPickerSheet({super.key});

  @override
  ConsumerState<AreaPickerSheet> createState() => _AreaPickerSheetState();
}

class _AreaPickerSheetState extends ConsumerState<AreaPickerSheet> {
  final _searchController = TextEditingController();
  late _Step _step;
  String? _stateId;
  String? _lgaId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final area = ref.read(selectedAreaProvider);
    _stateId = area?.stateId;
    _lgaId = area?.lgaId;
    _step = _stateId == null ? _Step.state : _Step.lga;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  LocationRepository get _locations => ref.read(locationRepositoryProvider);

  LocationNode? get _state => _locations.byId(_stateId);
  LocationNode? get _lga => _locations.byId(_lgaId);

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.92;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: context.palette.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.palette.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Row(
                children: [
                  if (_step == _Step.state)
                    const SizedBox(width: 8)
                  else
                    IconButton(
                      tooltip: 'Back',
                      onPressed: _goBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          _subtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                controller: _searchController,
                autofocus: false,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: _searchHint,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            Expanded(child: _content()),
          ],
        ),
      ),
    );
  }

  String get _title => switch (_step) {
        _Step.state => 'Choose your state',
        _Step.lga => 'Choose your LGA',
        _Step.neighbourhood => 'Refine by area',
      };

  String get _subtitle => switch (_step) {
        _Step.state => 'All 36 states and the FCT',
        _Step.lga => _lga == null
            ? 'Pick an LGA, or search the whole state'
            : 'Selected: ${_lga!.name}',
        _Step.neighbourhood => 'Optional. Helps customers find you faster.',
      };

  String get _searchHint => switch (_step) {
        _Step.state => 'Search states',
        _Step.lga => 'Search LGAs',
        _Step.neighbourhood => 'Search neighbourhoods',
      };

  void _goBack() {
    setState(() {
      _query = '';
      _searchController.clear();
      if (_step == _Step.neighbourhood) {
        _step = _Step.lga;
        _lgaId = null;
      } else {
        _step = _Step.state;
        _stateId = null;
        _lgaId = null;
      }
    });
  }

  Widget _content() {
    switch (_step) {
      case _Step.state:
        return _stateList();
      case _Step.lga:
        return _lgaList();
      case _Step.neighbourhood:
        return _neighbourhoodList();
    }
  }

  Widget _stateList() {
    final states =
        _locations.states().where((node) => node.matches(_query)).toList();
    if (states.isEmpty) {
      return const _PickerEmpty(message: 'No state matches that search.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      itemCount: states.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final state = states[index];
        return _LocationTile(
          title: state.name,
          subtitle: state.id == 'ng-fc' ? 'Federal Capital Territory' : 'State',
          selected: state.id == _stateId,
          onTap: () {
            setState(() {
              _stateId = state.id;
              _lgaId = null;
              _step = _Step.lga;
              _query = '';
              _searchController.clear();
            });
          },
        );
      },
    );
  }

  Widget _lgaList() {
    final state = _state;
    if (state == null) return const SizedBox.shrink();
    final lgas =
        _locations.lgas(state.id).where((node) => node.matches(_query)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        _LocationTile(
          title: 'All of ${state.name}',
          subtitle: 'Whole state Ã‚Â· every LGA',
          icon: Icons.public_rounded,
          onTap: () => _apply(AreaScope(stateId: state.id)),
        ),
        const SizedBox(height: 6),
        if (lgas.isEmpty)
          const _PickerEmpty(
            message:
                'No LGA in this state matches your search. You can still '
                'search the whole state.',
          )
        else
          for (final lga in lgas) ...[
            _LocationTile(
              title: lga.name,
              subtitle: 'LGA in ${state.name}',
              selected: lga.id == _lgaId,
              onTap: () => _chooseLga(lga),
            ),
            const SizedBox(height: 6),
          ],
      ],
    );
  }

  Widget _neighbourhoodList() {
    final lga = _lga;
    if (lga == null) return const SizedBox.shrink();
    final hoods = _locations
        .neighbourhoods(lga.id)
        .where((node) => node.matches(_query))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        _LocationTile(
          title: 'Use ${lga.name} only',
          subtitle: 'Skip the neighbourhood',
          icon: Icons.location_city_rounded,
          onTap: () => _apply(AreaScope(
            stateId: lga.parentId!,
            lgaId: lga.id,
          )),
        ),
        const SizedBox(height: 6),
        if (hoods.isEmpty)
          const _PickerEmpty(
            message: 'No neighbourhood matches that search.',
          )
        else
          for (final hood in hoods) ...[
            _LocationTile(
              title: hood.name,
              subtitle: 'Area in ${lga.name}',
              onTap: () => _apply(AreaScope(
                stateId: lga.parentId!,
                lgaId: lga.id,
                neighbourhoodId: hood.id,
              )),
            ),
            const SizedBox(height: 6),
          ],
      ],
    );
  }

  void _chooseLga(LocationNode lga) {
    final hoods = _locations.neighbourhoods(lga.id);
    if (hoods.isEmpty) {
      _apply(AreaScope(stateId: lga.parentId!, lgaId: lga.id));
      return;
    }
    setState(() {
      _lgaId = lga.id;
      _step = _Step.neighbourhood;
      _query = '';
      _searchController.clear();
    });
  }

  void _apply(AreaScope area) {
    ref.read(selectedAreaProvider.notifier).select(area);
    Navigator.of(context).pop(area);
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.selected = false,
    this.icon = Icons.place_outlined,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool selected;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.palette.amberWash : context.palette.surface,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.button),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: Border.all(
              color: selected ? context.palette.amber : context.palette.border,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: context.palette.muted),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 1),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                size: 20,
                color: selected ? context.palette.amberDeep : context.palette.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerEmpty extends StatelessWidget {
  const _PickerEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: context.palette.muted),
      ),
    );
  }
}
