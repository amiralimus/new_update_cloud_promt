import 'dart:async';

import 'package:flutter/material.dart';

import '../../colors.dart';
import '../data/coach_tools_api.dart';
import '../models/exercise_model.dart';
import 'coach_tools_common.dart';

Future<List<CoachExercise>?> showExercisePicker(
  BuildContext context, {
  List<CoachExercise> initiallySelected = const [],
}) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 760) {
    return showDialog<List<CoachExercise>>(
      context: context,
      barrierColor: scrimColor,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(28),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 920,
          height: MediaQuery.sizeOf(context).height * 0.88,
          child: ExercisePicker(initiallySelected: initiallySelected),
        ),
      ),
    );
  }
  return showModalBottomSheet<List<CoachExercise>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.9,
      child: ExercisePicker(initiallySelected: initiallySelected),
    ),
  );
}

class ExercisePicker extends StatefulWidget {
  const ExercisePicker({super.key, this.initiallySelected = const []});

  final List<CoachExercise> initiallySelected;

  @override
  State<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<ExercisePicker> {
  final CoachToolsApi _api = CoachToolsApi();
  final TextEditingController _searchController = TextEditingController();
  final List<CoachExercise> _selected = [];
  Timer? _debounce;

  List<CoachExercise> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initiallySelected);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), _load);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _api.fetchExercises(
        query: _searchController.text,
        pageSize: 40,
      );
      if (!mounted) return;
      setState(() => _items = page.items);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _selectionNumber(CoachExercise exercise) {
    return _selected.indexWhere(
          (item) => item.externalId == exercise.externalId,
        ) +
        1;
  }

  void _toggle(CoachExercise exercise) {
    final index = _selected.indexWhere(
      (item) => item.externalId == exercise.externalId,
    );
    setState(() {
      if (index >= 0) {
        _selected.removeAt(index);
      } else {
        _selected.add(exercise);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'افزودن از کتابخانه حرکات',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _selected.isEmpty
                            ? 'انتخاب حرکت'
                            : '${_selected.length} حرکت انتخاب شده',
                        style: const TextStyle(
                          color: textMutedColor,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'بستن',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: coachInputDecoration(
                hintText: 'جست‌وجو بر اساس نام، دستگاه یا عضله هدف',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _load();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _buildBody()),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(
              color: surfaceColor,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                TextButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => setState(_selected.clear),
                  child: const Text('پاک‌کردن انتخاب‌ها'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(List.of(_selected)),
                  icon: const Icon(Icons.add_task_rounded),
                  label: Text('افزودن ${_selected.length} حرکت'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null && _items.isEmpty) {
      return CoachErrorState(message: _error!, onRetry: _load);
    }
    if (!_loading && _items.isEmpty) {
      return CoachEmptyState(
        title: 'حرکتی پیدا نشد',
        message: 'عبارت جست‌وجو را کوتاه‌تر کنید یا آن را پاک کنید.',
        icon: Icons.search_off_rounded,
        action: TextButton(
          onPressed: () {
            _searchController.clear();
            _load();
          },
          child: const Text('پاک‌کردن جست‌وجو'),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 4
            : constraints.maxWidth >= 540
            ? 3
            : 2;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
          itemCount: _items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: constraints.maxWidth < 540 ? 170 : 184,
          ),
          itemBuilder: (context, index) {
            final exercise = _items[index];
            final selectionNumber = _selectionNumber(exercise);
            return _ExercisePickerCard(
              exercise: exercise,
              selectionNumber: selectionNumber,
              onTap: () => _toggle(exercise),
            );
          },
        );
      },
    );
  }
}

class _ExercisePickerCard extends StatelessWidget {
  const _ExercisePickerCard({
    required this.exercise,
    required this.selectionNumber,
    required this.onTap,
  });

  final CoachExercise exercise;
  final int selectionNumber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = selectionNumber > 0;
    final media = exercise.thumbnailUrl ?? exercise.gifUrl;
    return Material(
      color: selected ? infoBgColor : surfaceAltColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? primeColor : borderColor,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(13),
                        ),
                        child: CoachNetworkImage(
                          url: media,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 29,
                        height: 29,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? primeColor : surfaceColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? primeColor : borderStrongColor,
                          ),
                        ),
                        child: selected
                            ? Text(
                                '$selectionNumber',
                                style: const TextStyle(
                                  color: onPrimaryColor,
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                            : const Icon(Icons.add_rounded, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 7, 9, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [exercise.equipment, exercise.target]
                          .where((item) => item.trim().isNotEmpty)
                          .join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textMutedColor,
                        fontSize: 10,
                      ),
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
