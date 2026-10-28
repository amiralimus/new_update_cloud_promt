import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../colors.dart';
import '../data/coach_tools_api.dart';
import '../models/athlete_model.dart';

class ExpiredAthletesCarousel extends StatefulWidget {
  const ExpiredAthletesCarousel({super.key, required this.onCreateProgram});

  final ValueChanged<CoachAthlete> onCreateProgram;

  @override
  State<ExpiredAthletesCarousel> createState() =>
      _ExpiredAthletesCarouselState();
}

class _ExpiredAthletesCarouselState extends State<ExpiredAthletesCarousel> {
  static const _dismissedProgramsKey = 'dismissed_expired_programs_v1';
  static const _autoScrollThreshold = 3;

  final CoachToolsApi _api = CoachToolsApi();
  final PageController _pageController = PageController(viewportFraction: 1);
  Timer? _autoScrollTimer;

  List<_ExpiredAthlete> _athletes = const [];
  Set<String> _dismissedPrograms = <String>{};
  bool _loading = true;
  bool _isPointerOverCard = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final dismissed = preferences.getStringList(_dismissedProgramsKey) ?? [];
      final athletes = await _api.fetchAthletesWithPrograms();
      final expired = _findExpiredAthletes(athletes, dismissed.toSet());
      if (!mounted) return;
      setState(() {
        _dismissedPrograms = dismissed.toSet();
        _athletes = expired;
        _loading = false;
      });
      _syncAutoScroll();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<_ExpiredAthlete> _findExpiredAthletes(
    List<AthleteWithPrograms> athletes,
    Set<String> dismissedPrograms,
  ) {
    final now = DateTime.now();
    final result = <_ExpiredAthlete>[];

    for (final item in athletes) {
      AthleteProgramSummary? latestProgram;
      for (final program in item.programs) {
        final createdAt = program.createdAt;
        if (createdAt == null ||
            (latestProgram?.createdAt != null &&
                !createdAt.isAfter(latestProgram!.createdAt!))) {
          continue;
        }
        latestProgram = program;
      }

      final expiresAt = latestProgram?.expiresAt;
      if (latestProgram == null ||
          expiresAt == null ||
          !expiresAt.isBefore(now) ||
          dismissedPrograms.contains(
            _dismissedKey(item.athlete.id, latestProgram.id),
          )) {
        continue;
      }
      result.add(
        _ExpiredAthlete(
          athlete: item.athlete,
          program: latestProgram,
          expiresAt: expiresAt,
        ),
      );
    }

    result.sort((first, second) => first.expiresAt.compareTo(second.expiresAt));
    return result;
  }

  String _dismissedKey(int athleteId, int programId) => '$athleteId:$programId';

  void _syncAutoScroll() {
    _autoScrollTimer?.cancel();
    if (_isPointerOverCard || _athletes.length <= _autoScrollThreshold) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _isPointerOverCard || !_pageController.hasClients) return;
      final nextPage = (_currentPage + 1) % _athletes.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _setPointerOverCard(bool value) {
    if (_isPointerOverCard == value) return;
    setState(() => _isPointerOverCard = value);
    _syncAutoScroll();
  }

  Future<void> _dismiss(_ExpiredAthlete item) async {
    final key = _dismissedKey(item.athlete.id, item.program.id);
    final updated = {..._dismissedPrograms, key};
    setState(() {
      _dismissedPrograms = updated;
      _athletes = _athletes
          .where((entry) => entry.program.id != item.program.id)
          .toList();
      if (_currentPage >= _athletes.length) {
        _currentPage = _athletes.isEmpty ? 0 : _athletes.length - 1;
      }
    });
    _syncAutoScroll();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _athletes.isNotEmpty && _pageController.hasClients) {
        _pageController.jumpToPage(_currentPage);
      }
    });

    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_dismissedProgramsKey, updated.toList());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _athletes.isEmpty) {
      return const _ExpiredProgramsEmptyState();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(color: shadowColor, blurRadius: 20, offset: Offset(0, 7)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: warnBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event_busy_outlined,
                  color: warnFgColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'برنامه‌های تمام‌شده',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'برای ادامه مسیر این ورزشکارها برنامه تازه بسازید.',
                      style: TextStyle(color: textMutedColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (_athletes.length > 1)
                Text(
                  '${_currentPage + 1} / ${_athletes.length}',
                  style: const TextStyle(
                    color: textFaintColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 154,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _athletes.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: _ExpiredAthleteCard(
                  item: _athletes[index],
                  onHoverChanged: _setPointerOverCard,
                  onDismiss: () => _dismiss(_athletes[index]),
                  onCreateProgram: () =>
                      widget.onCreateProgram(_athletes[index].athlete),
                ),
              ),
            ),
          ),
          if (_athletes.length > 1) ...[
            const SizedBox(height: 10),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  _athletes.length > 6 ? 6 : _athletes.length,
                  (index) {
                    final isActive = index == _currentPage % 6;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: isActive ? 16 : 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isActive ? primeColor : borderStrongColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpiredProgramsEmptyState extends StatelessWidget {
  const _ExpiredProgramsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(color: shadowColor, blurRadius: 20, offset: Offset(0, 7)),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.event_available_outlined, color: okFgColor, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'برنامه‌ای منقضی نشده',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpiredAthlete {
  const _ExpiredAthlete({
    required this.athlete,
    required this.program,
    required this.expiresAt,
  });

  final CoachAthlete athlete;
  final AthleteProgramSummary program;
  final DateTime expiresAt;
}

class _ExpiredAthleteCard extends StatefulWidget {
  const _ExpiredAthleteCard({
    required this.item,
    required this.onHoverChanged,
    required this.onDismiss,
    required this.onCreateProgram,
  });

  final _ExpiredAthlete item;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onDismiss;
  final VoidCallback onCreateProgram;

  @override
  State<_ExpiredAthleteCard> createState() => _ExpiredAthleteCardState();
}

class _ExpiredAthleteCardState extends State<_ExpiredAthleteCard> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
    widget.onHoverChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.item.athlete.displayName.trim().characters.first;
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _setHovered(!_hovered),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hovered ? surfaceAltColor : surfaceMutedColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered
                  ? primeColor.withValues(alpha: 0.38)
                  : borderColor,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: primeColor.withValues(alpha: 0.12),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: primeColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.athlete.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'پایان برنامه: ${formatCoachDate(widget.item.expiresAt)}',
                      style: const TextStyle(
                        color: textMutedColor,
                        fontSize: 12,
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      alignment: Alignment.topRight,
                      child: _hovered
                          ? Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  TextButton(
                                    onPressed: widget.onDismiss,
                                    style: TextButton.styleFrom(
                                      foregroundColor: textMutedColor,
                                      minimumSize: const Size(0, 34),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                    ),
                                    child: const Text('فعلاً بی‌خیال'),
                                  ),
                                  FilledButton.icon(
                                    onPressed: widget.onCreateProgram,
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(0, 34),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 11,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('ساخت برنامه'),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
