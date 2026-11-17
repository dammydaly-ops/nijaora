import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_palette.dart';
import '../../app/theme/app_spacing.dart';
import '../../data/models/location_node.dart';
import '../../data/repositories/providers.dart';
import '../auth/guest_mode.dart';
import '../location/area_picker_sheet.dart';
import '../location/area_selection.dart';
import 'search_providers.dart';
import 'widgets/hero_collage.dart';

/// The first screen customers see: a calm, editorial introduction with a
/// working area-based search, rotating headlines and a living collage.
class HomeHero extends ConsumerStatefulWidget {
  const HomeHero({super.key});

  @override
  ConsumerState<HomeHero> createState() => _HomeHeroState();
}

class _HomeHeroState extends ConsumerState<HomeHero>
    with SingleTickerProviderStateMixin {
  static const _allLgas = '__all__';

  late final AnimationController _entrance;
  late final TextEditingController _keywordController;
  Timer? _headlineTimer;
  int _headlineIndex = 0;
  double? _topCopyHeight;
  bool _reduceMotion = false;
  bool _didStart = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _keywordController = TextEditingController(
      text: ref.read(searchQueryProvider).keyword,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.of(context).disableAnimations;

    if (!_didStart) {
      _didStart = true;
      _reduceMotion = reduce;
      if (reduce) {
        _entrance.value = 1;
      } else {
        _startHeadlineRotation();
      }
      return;
    }

    if (reduce == _reduceMotion) return;
    _reduceMotion = reduce;
    if (reduce) {
      _headlineTimer?.cancel();
      _headlineTimer = null;
      _entrance.value = 1;
    } else {
      _startHeadlineRotation();
    }
  }

  @override
  void dispose() {
    _headlineTimer?.cancel();
    _entrance.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  void _startHeadlineRotation() {
    _headlineTimer?.cancel();
    _headlineTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      setState(() {
        _headlineIndex = (_headlineIndex + 1) % _headlines.length;
      });
    });
  }

  Future<bool> _ensureArea() async {
    if (ref.read(selectedAreaProvider) != null) return true;
    final picked = await showAreaPicker(context);
    if (!mounted) return false;
    return picked != null;
  }

  Future<void> _search({String? keyword}) async {
    if (!await _ensureArea()) return;
    if (!mounted) return;

    final text = (keyword ?? _keywordController.text).trim();
    if (keyword != null) {
      _keywordController.value = TextEditingValue(
        text: keyword,
        selection: TextSelection.collapsed(offset: keyword.length),
      );
    }

    ref.read(searchQueryProvider.notifier)
      ..setCategory(null)
      ..setKeyword(text);
    FocusScope.of(context).unfocus();
    context.push('/search');
  }

  void _openBusiness() {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ref.read(guestModeProvider.notifier).disable();
      context.go('/welcome');
    } else {
      context.push('/registration');
    }
  }

  void _chooseState(String? stateId) {
    if (stateId == null) return;
    ref.read(selectedAreaProvider.notifier).chooseState(stateId);
  }

  void _chooseLga(String? value) {
    final stateId = ref.read(selectedAreaProvider)?.stateId;
    if (stateId == null || value == null) return;
    ref
        .read(selectedAreaProvider.notifier)
        .chooseLga(stateId, value == _allLgas ? null : value);
  }

  void _onTopCopyMeasured(Size size) {
    if (!mounted) return;
    final height = size.height;
    if (_topCopyHeight != null && (_topCopyHeight! - height).abs() < 0.5) {
      return;
    }
    setState(() => _topCopyHeight = height);
  }

  Widget _reveal(double start, Widget child) {
    final animation = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final area = ref.watch(selectedAreaProvider);
    final locations = ref.watch(locationRepositoryProvider);
    final states = locations.states();
    final stateId = area?.stateId;
    final lgas = stateId == null ? <LocationNode>[] : locations.lgas(stateId);

    final accent = isDark ? palette.amber : palette.amberDeep;
    final background = isDark
        ? <Color>[palette.surface, palette.surfaceAlt, palette.surface]
        : const <Color>[
            Color(0xFFFDFBF6),
            Color(0xFFF2F8F2),
            Color(0xFFFAF5EA),
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1040;
        final compact = constraints.maxWidth < 620;
        final padding = wide ? 48.0 : (compact ? 22.0 : 34.0);
        final contentWidth = constraints.maxWidth - padding * 2;

        final topCopy = _MeasureSize(
          onChange: _onTopCopyMeasured,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
            _reveal(0, _Eyebrow(accent: accent, isDark: isDark)),
            const SizedBox(height: AppSpacing.lg),
            _reveal(
              0.06,
              _RotatingHeadline(
                index: _headlineIndex,
                accent: accent,
                ink: palette.ink,
                wide: wide,
                maxWidth: contentWidth,
              ),
            ),
            SizedBox(height: wide ? 18 : 14),
            _reveal(
              0.12,
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 520 : 620),
                child: Text(
                  'Nijaora connects you with trusted artisans, local businesses '
                  'and one-of-a-kind products around you. Discover good work, '
                  'start a real conversation and support the people building '
                  'Nigeria.',
                  style: TextStyle(
                    color: palette.inkSoft.withValues(alpha: 0.86),
                    fontSize: wide ? 15.5 : 14.5,
                    height: 1.62,
                  ),
                ),
              ),
            ),
            SizedBox(height: wide ? 26 : 22),
            _reveal(
              0.18,
              _HeroSearchPanel(
                keywordController: _keywordController,
                states: states,
                lgas: lgas,
                stateId: stateId,
                lgaId: area?.lgaId,
                allLgasValue: _allLgas,
                onStateChanged: _chooseState,
                onLgaChanged: _chooseLga,
                onSearch: _search,
              ),
            ),
            const SizedBox(height: 10),
            _reveal(
              0.24,
              Row(
                children: [
                  Icon(
                    Icons.location_off_rounded,
                    size: 12,
                    color: palette.muted,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'No GPS. Your area is enough.',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: palette.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ],
          ),
        );

        final tail = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: wide ? 22 : 18),
            _reveal(0.30, _PopularSearches(onSearch: _search)),
            SizedBox(height: wide ? 22 : 18),
            _reveal(0.36, _BusinessLink(accent: accent, onTap: _openBusiness)),
            const SizedBox(height: 12),
            _reveal(0.42, _TrustLine()),
          ],
        );

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(wide ? 36 : 28),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
                blurRadius: wide ? 54 : 34,
                offset: Offset(0, wide ? 26 : 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(wide ? 36 : 28),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: background,
                ),
                border: Border.all(
                  color: isDark ? palette.border : const Color(0xFFE8E1D3),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -constraints.maxWidth * 0.18,
                    right: -constraints.maxWidth * 0.12,
                    child: IgnorePointer(
                      child: Container(
                        width: constraints.maxWidth * 0.44,
                        height: constraints.maxWidth * 0.44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              accent.withValues(alpha: isDark ? 0.13 : 0.08),
                              accent.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -constraints.maxWidth * 0.24,
                    left: -constraints.maxWidth * 0.20,
                    child: IgnorePointer(
                      child: Container(
                        width: constraints.maxWidth * 0.50,
                        height: constraints.maxWidth * 0.50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              palette.amber.withValues(alpha: 0.08),
                              palette.amber.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(padding),
                    child: wide
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 6, child: topCopy),
                                  const SizedBox(width: 36),
                                  Expanded(
                                    flex: 5,
                                    child: RepaintBoundary(
                                      child: SizedBox(
                                        height:
                                            (_topCopyHeight ?? 500) * 1.04,
                                        child: const HeroCollage(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              tail,
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              topCopy,
                              SizedBox(height: compact ? 26 : 32),
                              RepaintBoundary(
                                child: SizedBox(
                                  height: compact ? 380 : 440,
                                  child: const HeroCollage(),
                                ),
                              ),
                              tail,
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.accent, required this.isDark});

  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            'DISCOVER. CONNECT. GROW.',
            style: TextStyle(
              color: accent,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _RotatingHeadline extends StatelessWidget {
  const _RotatingHeadline({
    required this.index,
    required this.accent,
    required this.ink,
    required this.wide,
    required this.maxWidth,
  });

  final int index;
  final Color accent;
  final Color ink;
  final bool wide;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: ink,
      fontSize: wide ? 50 : 35,
      fontWeight: FontWeight.w800,
      height: 1.04,
      letterSpacing: wide ? -1.9 : -1.1,
    );

    return SizedBox(
      height: wide ? 132 : 150,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 700),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.topLeft,
          children: [...previousChildren, ?currentChild],
        ),
        transitionBuilder: (child, animation) {
          final slide =
              Tween<Offset>(
                begin: const Offset(0, 0.07),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: SizedBox(
          key: ValueKey(index),
          height: wide ? 132 : 150,
          width: maxWidth,
          child: Align(
            alignment: Alignment.topLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 560 : maxWidth),
                child: Text.rich(
                  TextSpan(
                    children: [
                      for (final part in _headlines[index].parts)
                        TextSpan(
                          text: part.text,
                          style: part.highlight
                              ? TextStyle(color: accent)
                              : null,
                        ),
                    ],
                  ),
                  style: style,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroSearchPanel extends StatelessWidget {
  const _HeroSearchPanel({
    required this.keywordController,
    required this.states,
    required this.lgas,
    required this.stateId,
    required this.lgaId,
    required this.allLgasValue,
    required this.onStateChanged,
    required this.onLgaChanged,
    required this.onSearch,
  });

  final TextEditingController keywordController;
  final List<LocationNode> states;
  final List<LocationNode> lgas;
  final String? stateId;
  final String? lgaId;
  final String allLgasValue;
  final ValueChanged<String?> onStateChanged;
  final ValueChanged<String?> onLgaChanged;
  final Future<void> Function({String? keyword}) onSearch;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? palette.amber : palette.amberDeep;
    final validState = states.any((state) => state.id == stateId)
        ? stateId
        : null;
    final lgaValue = validState == null
        ? null
        : (lgas.any((lga) => lga.id == lgaId) ? lgaId : allLgasValue);

    final stateItems = [
      for (final state in states)
        DropdownMenuItem<String>(
          value: state.id,
          child: Text(state.name, overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
    ];
    final lgaItems = [
      DropdownMenuItem<String>(
        value: allLgasValue,
        child: Text(
          validState == null ? 'Select state first' : 'All LGAs',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
      for (final lga in lgas)
        DropdownMenuItem<String>(
          value: lga.id,
          child: Text(lga.name, overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
    ];

    final keywordField = _KeywordField(
      controller: keywordController,
      onSubmit: onSearch,
    );
    final stateField = _DropdownField(
      icon: Icons.map_outlined,
      hint: 'Select state',
      value: validState,
      items: stateItems,
      onChanged: onStateChanged,
    );
    final lgaField = _DropdownField(
      icon: Icons.location_on_outlined,
      hint: validState == null ? 'Pick state first' : 'Select LGA',
      value: lgaValue,
      items: lgaItems,
      onChanged: validState == null ? null : onLgaChanged,
    );
    final searchButton = _SearchButton(
      accent: accent,
      foreground: isDark ? palette.cream : Colors.white,
      onPressed: () => onSearch(),
    );

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 500;
          if (compact) {
            return Column(
              children: [
                keywordField,
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: stateField),
                    const SizedBox(width: 8),
                    Expanded(child: lgaField),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: searchButton),
              ],
            );
          }

          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: keywordField),
                  const SizedBox(width: 8),
                  searchButton,
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: stateField),
                  const SizedBox(width: 8),
                  Expanded(child: lgaField),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KeywordField extends StatelessWidget {
  const _KeywordField({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final Future<void> Function({String? keyword}) onSubmit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _FieldShell(
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 17, color: palette.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSubmit(),
              style: TextStyle(
                color: palette.ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              cursorColor: isDark ? palette.amber : palette.amberDeep,
              decoration: InputDecoration(
                hintText: 'What are you looking for?',
                hintStyle: TextStyle(
                  color: palette.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.icon,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final IconData icon;
  final String hint;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return _FieldShell(
      enabled: onChanged != null,
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: onChanged == null
                ? palette.muted.withValues(alpha: 0.55)
                : palette.muted,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                hint: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                items: items,
                onChanged: onChanged,
                isExpanded: true,
                isDense: true,
                menuMaxHeight: 360,
                borderRadius: BorderRadius.circular(16),
                dropdownColor: palette.surface,
                icon: Icon(
                  Icons.expand_more_rounded,
                  size: 19,
                  color: palette.muted,
                ),
                style: TextStyle(
                  color: palette.ink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldShell extends StatelessWidget {
  const _FieldShell({required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark
            ? palette.surfaceAlt.withValues(alpha: 0.55)
            : palette.cream.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled
              ? palette.border
              : palette.border.withValues(alpha: 0.55),
        ),
      ),
      child: child,
    );
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton({
    required this.accent,
    required this.foreground,
    required this.onPressed,
  });

  final Color accent;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.search_rounded, size: 18),
        label: const Text('Search'),
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: foreground,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PopularSearches extends StatelessWidget {
  const _PopularSearches({required this.onSearch});

  final Future<void> Function({String? keyword}) onSearch;

  static const _terms = [
    'Plumbers',
    'Tailors',
    'Furniture',
    'Beauty Services',
    'Handmade Products',
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'POPULAR NOW',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: palette.muted,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final term in _terms)
              _SuggestionChip(
                label: term,
                onTap: () => onSearch(keyword: term),
              ),
          ],
        ),
      ],
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: palette.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: palette.border.withValues(alpha: 0.9)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: palette.inkSoft,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _BusinessLink extends StatelessWidget {
  const _BusinessLink({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: accent,
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: Alignment.centerLeft,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storefront_outlined, size: 17),
          SizedBox(width: 7),
          Flexible(
            child: Text(
              'Grow your business with Nijaora.',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 5),
          Icon(Icons.arrow_forward_rounded, size: 15),
        ],
      ),
    );
  }
}

class _TrustLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final items = [
      (Icons.location_off_rounded, 'No GPS'),
      (Icons.forum_outlined, 'Real conversations'),
      (Icons.verified_outlined, 'Verified reviews'),
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 7,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.$1, size: 12, color: palette.muted),
              const SizedBox(width: 4),
              Text(
                item.$2,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: palette.muted,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, required super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _MeasureSizeBox(onChange);

  @override
  void updateRenderObject(BuildContext context, _MeasureSizeBox renderObject) {
    renderObject.onChange = onChange;
  }
}

class _MeasureSizeBox extends RenderProxyBox {
  _MeasureSizeBox(this.onChange);

  ValueChanged<Size> onChange;
  Size? _lastSize;

  @override
  void performLayout() {
    super.performLayout();
    final measured = child?.size;
    if (measured == null || measured == _lastSize) return;
    _lastSize = measured;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(measured));
  }
}

class _Phrase {
  const _Phrase(this.parts);

  final List<_PhrasePart> parts;
}

class _PhrasePart {
  const _PhrasePart(this.text, {this.highlight = false});

  final String text;
  final bool highlight;
}

const _headlines = <_Phrase>[
  _Phrase([
    _PhrasePart('Discover '),
    _PhrasePart('talent.', highlight: true),
    _PhrasePart('\nFind what '),
    _PhrasePart('you need.', highlight: true),
  ]),
  _Phrase([
    _PhrasePart('Your next '),
    _PhrasePart('favourite product', highlight: true),
    _PhrasePart('\nis closer than you think.'),
  ]),
  _Phrase([
    _PhrasePart('From '),
    _PhrasePart('skilled hands', highlight: true),
    _PhrasePart('\nto your doorstep.'),
  ]),
  _Phrase([
    _PhrasePart('Turn your skills into\n'),
    _PhrasePart('new opportunities.', highlight: true),
  ]),
  _Phrase([
    _PhrasePart('Find '),
    _PhrasePart('local businesses', highlight: true),
    _PhrasePart('\nworth discovering.'),
  ]),
  _Phrase([
    _PhrasePart('Good work deserves\nto be '),
    _PhrasePart('discovered.', highlight: true),
  ]),
];
