import 'dart:async';

import 'package:flutter/material.dart';

import '../../colors.dart';
import '../data/coach_tools_api.dart';
import '../models/exercise_model.dart';
import '../widgets/coach_tools_common.dart';

class ExerciseLibraryPage extends StatefulWidget {
  const ExerciseLibraryPage({
    super.key,
    required this.onBack,
    required this.onAddToProgram,
  });

  final VoidCallback onBack;
  final ValueChanged<CoachExercise> onAddToProgram;

  @override
  State<ExerciseLibraryPage> createState() => _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends State<ExerciseLibraryPage> {
  final CoachToolsApi _api = CoachToolsApi();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<CoachExercise> _items = const [];
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String _equipment = '';
  String _bodyPart = '';
  CoachExercise? _selectedExercise;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _load(reset: true),
    );
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final targetPage = reset ? 1 : _page + 1;
      final result = await _api.fetchExercises(
        query: _searchController.text,
        equipment: _equipment,
        bodyPart: _bodyPart,
        page: targetPage,
        pageSize: 30,
      );
      if (!mounted) return;
      setState(() {
        _items = reset ? result.items : [..._items, ...result.items];
        _page = result.page;
        _hasMore = result.hasMore;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedExercise != null) {
      return ExerciseDetailView(
        exercise: _selectedExercise!,
        onBack: () => setState(() => _selectedExercise = null),
        onAddToProgram: widget.onAddToProgram,
      );
    }

    return CoachPageFrame(
      title: 'کتابخانه حرکات',
      onBack: widget.onBack,
      body: Column(
        children: [
          _buildToolbar(),
          const SizedBox(height: 14),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final equipments = <String, String>{};
    final bodyParts = <String, String>{};
    for (final item in _items) {
      if (item.equipmentKey.isNotEmpty) {
        equipments[item.equipmentKey] = item.equipment.isEmpty
            ? item.equipmentKey
            : item.equipment;
      }
      if (item.bodyPartKey.isNotEmpty) {
        bodyParts[item.bodyPartKey] = item.bodyPart.isEmpty
            ? item.bodyPartKey
            : item.bodyPart;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 760;
        final search = TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: coachInputDecoration(
            hintText: 'نام حرکت، دستگاه یا عضله هدف',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'پاک‌کردن',
                    onPressed: () {
                      _searchController.clear();
                      _load(reset: true);
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        );
        final filters = Row(
          children: [
            Expanded(
              child: _filterDropdown(
                label: 'دستگاه',
                value: equipments.containsKey(_equipment) ? _equipment : '',
                options: equipments,
                onChanged: (value) {
                  setState(() => _equipment = value);
                  _load(reset: true);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _filterDropdown(
                label: 'بخش بدن',
                value: bodyParts.containsKey(_bodyPart) ? _bodyPart : '',
                options: bodyParts,
                onChanged: (value) {
                  setState(() => _bodyPart = value);
                  _load(reset: true);
                },
              ),
            ),
          ],
        );
        if (stacked) {
          return Column(children: [search, const SizedBox(height: 9), filters]);
        }
        return Row(
          children: [
            Expanded(flex: 5, child: search),
            const SizedBox(width: 10),
            Expanded(flex: 4, child: filters),
          ],
        );
      },
    );
  }

  Widget _filterDropdown({
    required String label,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: coachInputDecoration(labelText: label, dense: true),
      items: [
        const DropdownMenuItem(value: '', child: Text('همه')),
        ...options.entries.map(
          (entry) => DropdownMenuItem(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (value) => onChanged(value ?? ''),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const CoachLoadingState(label: 'در حال دریافت کتابخانه حرکات...');
    }
    if (_error != null && _items.isEmpty) {
      return CoachErrorState(
        message: _error!,
        onRetry: () => _load(reset: true),
      );
    }
    if (_items.isEmpty) {
      return CoachEmptyState(
        title: 'حرکتی پیدا نشد',
        message: 'جست‌وجو یا فیلترها را تغییر دهید.',
        icon: Icons.search_off_rounded,
        action: OutlinedButton(
          onPressed: () {
            _searchController.clear();
            setState(() {
              _equipment = '';
              _bodyPart = '';
            });
            _load(reset: true);
          },
          child: const Text('حذف فیلترها'),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 5
            : constraints.maxWidth >= 760
            ? 4
            : constraints.maxWidth >= 520
            ? 3
            : 2;
        return CustomScrollView(
          slivers: [
            SliverGrid.builder(
              itemCount: _items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                mainAxisExtent: constraints.maxWidth < 520 ? 188 : 204,
              ),
              itemBuilder: (context, index) {
                final exercise = _items[index];
                return _ExerciseLibraryCard(
                  exercise: exercise,
                  onTap: () => setState(() => _selectedExercise = exercise),
                );
              },
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: _hasMore
                      ? OutlinedButton.icon(
                          onPressed: _loadingMore
                              ? null
                              : () => _load(reset: false),
                          icon: _loadingMore
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.expand_more_rounded),
                          label: Text(
                            _loadingMore
                                ? 'در حال دریافت...'
                                : 'نمایش حرکات بیشتر',
                          ),
                        )
                      : Text(
                          '${_items.length} حرکت نمایش داده شد',
                          style: const TextStyle(color: textMutedColor),
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ExerciseLibraryCard extends StatelessWidget {
  const _ExerciseLibraryCard({
    required this.exercise,
    required this.onTap,
  });

  final CoachExercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final media = exercise.thumbnailUrl ?? exercise.gifUrl;
    return Material(
      color: surfaceAltColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: _verticalContent(media),
        ),
      ),
    );
  }

  Widget _verticalContent(String? media) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: CoachNetworkImage(url: media, fit: BoxFit.contain),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
          child: _details(),
        ),
      ],
    );
  }

  Widget _details() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          exercise.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          [
            exercise.equipment,
            exercise.target,
          ].where((item) => item.trim().isNotEmpty).join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: textMutedColor, fontSize: 10.5),
        ),
        if (exercise.isCoachOwned) ...[
          const SizedBox(height: 4),
          const Text(
            'حرکت شخصی شما',
            style: TextStyle(
              color: primeColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class ExerciseDetailView extends StatelessWidget {
  const ExerciseDetailView({
    super.key,
    required this.exercise,
    required this.onBack,
    required this.onAddToProgram,
  });

  final CoachExercise exercise;
  final VoidCallback onBack;
  final ValueChanged<CoachExercise> onAddToProgram;

  @override
  Widget build(BuildContext context) {
    return CoachPageFrame(
      title: exercise.name,
      subtitle: 'جزئیات حرکت و روش اجرا',
      onBack: onBack,
      actions: [
        FilledButton.icon(
          onPressed: () => onAddToProgram(exercise),
          icon: const Icon(Icons.playlist_add_rounded),
          label: const Text('اضافه کردن این حرکت به برنامه'),
        ),
      ],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          final media = _ExerciseDetailMedia(exercise: exercise);
          final details = _ExerciseDetailsText(
            exercise: exercise,
            scrollable: wide,
          );
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 4, child: media),
                const SizedBox(width: 16),
                Expanded(flex: 5, child: details),
              ],
            );
          }
          return ListView(
            children: [
              SizedBox(height: 300, child: media),
              const SizedBox(height: 14),
              details,
            ],
          );
        },
      ),
    );
  }
}

class _ExerciseDetailMedia extends StatelessWidget {
  const _ExerciseDetailMedia({required this.exercise});

  final CoachExercise exercise;

  @override
  Widget build(BuildContext context) {
    final media = exercise.gifUrl ?? exercise.thumbnailUrl;
    return CoachSurface(
      padding: const EdgeInsets.all(8),
      color: surfaceAltColor,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CoachNetworkImage(
          url: media,
          fit: BoxFit.contain,
          iconSize: 64,
          preferHtmlElement: true,
        ),
      ),
    );
  }
}

class _ExerciseDetailsText extends StatelessWidget {
  const _ExerciseDetailsText({
    required this.exercise,
    required this.scrollable,
  });

  final CoachExercise exercise;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final facts = <MapEntry<String, String>>[
      MapEntry('دسته‌بندی', exercise.category),
      MapEntry('بخش بدن', exercise.bodyPart),
      MapEntry('عضله هدف', exercise.target),
      MapEntry('گروه عضلانی', exercise.muscleGroup),
      MapEntry('دستگاه', exercise.equipment),
      MapEntry('عضلات کمکی', exercise.secondaryMuscles.join('، ')),
    ].where((entry) => entry.value.trim().isNotEmpty).toList();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (facts.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 520
                  ? (constraints.maxWidth - 8) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: facts
                    .map(
                      (entry) => Container(
                        width: width,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: surfaceMutedColor,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(
                                color: textMutedColor,
                                fontSize: 10.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              entry.value,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        if (exercise.instructions.trim().isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'توضیحات',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(
            exercise.instructions,
            style: const TextStyle(fontSize: 14.5, height: 1.9),
          ),
        ],
        if (exercise.steps.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'مراحل اجرا',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...exercise.steps.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: infoBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        color: infoFgColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(height: 1.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (exercise.instructions.trim().isEmpty && exercise.steps.isEmpty)
          const CoachEmptyState(
            title: 'توضیحی ثبت نشده است',
            message: 'نام و اطلاعات اصلی حرکت از سرور دریافت شده‌اند.',
            icon: Icons.info_outline_rounded,
          ),
      ],
    );
    return CoachSurface(
      child: scrollable ? SingleChildScrollView(child: content) : content,
    );
  }
}
