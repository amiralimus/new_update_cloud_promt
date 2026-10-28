import 'dart:async';

import 'package:flutter/material.dart';
import '../colors.dart';
import '../core/platform/pdf_saver.dart';
import '../core/network/server_endpoints.dart';
import '../loging_system/loging_system.dart';
import '../responsive.dart';
import 'share_code_card.dart';
import '../rigester-login/token_manegment.dart' hide LoggerService;

// ============================================================
// Extension برای نمایش SnackBar با بررسی mounted
// ============================================================
extension SafeSnackBar on BuildContext {
  void showSafeSnackBar(String message, {Color? color, int seconds = 2}) {
    if (!mounted) return;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: seconds),
      ),
    );
  }
}

// ============================================================
// تابع تشخیص نوع دستگاه
// ============================================================
AppDeviceType _resolveDeviceType(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < AppBreakpoints.mobile) return AppDeviceType.mobile;
  if (width < AppBreakpoints.tablet) return AppDeviceType.tablet;
  return AppDeviceType.desktop;
}

// ============================================================
// مدل داده برنامه
// ============================================================
class ProgramHistory {
  final int id;
  final String name;
  final String type; // 'ورزشی' یا 'غذایی'
  final String date;
  final String? generatedWorkout;
  final String? generatedMealPlan;

  /// نوع خام برنامه از سرور: 'workout' | 'meal' | 'both' | null
  /// این فیلد برای تصمیم‌گیری دقیق‌تر درباره‌ی بخش قابل دانلود استفاده می‌شود.
  final String? rawProgramType;

  ProgramHistory({
    required this.id,
    required this.name,
    required this.type,
    required this.date,
    this.generatedWorkout,
    this.generatedMealPlan,
    this.rawProgramType,
  });

  /// آیا بخش ورزشی واقعاً محتوا دارد؟
  bool get hasWorkout =>
      generatedWorkout != null && generatedWorkout!.trim().isNotEmpty;

  bool get hasMealPlan =>
      generatedMealPlan != null && generatedMealPlan!.trim().isNotEmpty;

  /// آیا محتوای کامل (ورزشی/غذایی) در همین آبجکت موجود است؟
  /// اگر نه، باید قبل از تصمیم‌گیری، جزئیات را از سرور گرفت.
  bool get hasAnyContent => hasWorkout || hasMealPlan;

  factory ProgramHistory.fromJson(Map<String, dynamic> json) {
    final rawType = json['program_type']?.toString();

    String typeLabel;
    switch (rawType) {
      case 'workout':
        typeLabel = 'ورزشی';
        break;
      case 'meal':
        typeLabel = 'غذایی';
        break;
      case 'both':
        typeLabel = 'ورزشی و غذایی';
        break;
      default:
        typeLabel = 'ورزشی';
    }

    String dateLabel = '-';
    if (json['created_at'] != null) {
      final dt = DateTime.tryParse(json['created_at'].toString());
      if (dt != null) {
        dateLabel =
        '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
      }
    }

    return ProgramHistory(
      id: json['id'],
      name: json['name'] ?? 'بدون نام',
      type: typeLabel,
      date: dateLabel,
      generatedWorkout: json['generated_workout'],
      generatedMealPlan: json['generated_meal_plan'],
      rawProgramType: rawType,
    );
  }
}

// ============================================================
// صفحه اصلی History Programs
// ============================================================
class HistoryPrograms extends StatefulWidget {
  const HistoryPrograms({super.key});

  @override
  State<HistoryPrograms> createState() => _HistoryProgramsState();
}

class _HistoryProgramsState extends State<HistoryPrograms> {
  final ApiService _apiService = ApiService();

  List<ProgramHistory> _allPrograms = [];
  List<ProgramHistory> _filteredPrograms = [];

  bool _isLoading = true;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();

  int _currentPage = 1;
  static const int _itemsPerPage = 6;

  Timer? _searchDebounce;

  /// شناسه‌ی برنامه‌هایی که همین حالا در حال دانلودند.
  final Set<int> _downloadingIds = <int>{};

  /// شناسه‌ی برنامه‌هایی که همین حالا در حال واکشی جزئیات هستند
  /// (برای دکمه‌ی اشتراک/سپر).
  final Set<int> _resolvingIds = <int>{};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadHistory();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // بارگذاری تاریخچه از سرور -> GET /api/programs/history/
  // ============================================================
  Future<void> _loadHistory() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      LoggerService.logEvent(
        title: 'HISTORY_PROGRAMS',
        message: 'در حال بارگذاری تاریخچه برنامه‌ها...',
      );

      final response = await _apiService.get(
        endpoint: ServerEndpoints.programsHistory,
        requiresAuth: true,
      );

      if (!mounted) return;

      if (response.success && response.data != null) {
        final List<dynamic> rawList = response.data as List<dynamic>;
        final programs = rawList
            .map((e) => ProgramHistory.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          _allPrograms = programs;
          _filteredPrograms = List.from(programs);
          _currentPage = 1;
          _isLoading = false;
        });

        LoggerService.logProfile(
          action: 'LOAD_SUCCESS',
          message: 'تاریخچه برنامه‌ها بارگذاری شد (${programs.length} مورد)',
        );
      } else {
        setState(() {
          _errorMessage = response.error ?? 'خطای نامشخصی رخ داد';
          _isLoading = false;
        });

        LoggerService.logApiError(
          method: 'GET',
          url: ServerEndpoints.programsHistory,
          error: response.error ?? 'Unknown error',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'خطا: ${e.toString()}';
        _isLoading = false;
      });

      LoggerService.logApiError(
        method: 'GET',
        url: ServerEndpoints.programsHistory,
        error: e.toString(),
      );
    }
  }

  // ============================================================
  // واکشی جزئیات کامل برنامه از سرور
  // ============================================================
  /// اگر محتوا در لیست تاریخچه موجود نبود، این متد آن را از
  /// اندپوینت جزئیات می‌گیرد و به‌شکل یک ProgramHistory برمی‌گرداند.
  Future<ProgramHistory?> _fetchFullDetail(ProgramHistory program) async {
    try {
      final response = await _apiService.get(
        endpoint: ServerEndpoints.program(program.id),
        requiresAuth: true,
      );

      if (!response.success || response.data == null) {
        LoggerService.logApiError(
          method: 'GET',
          url: ServerEndpoints.program(program.id),
          error: response.error ?? 'Unknown error',
        );
        return null;
      }

      final detail = response.data as Map<String, dynamic>;

      // ادغام داده‌های جزئیات با متادیتای لیست، تا نام/تاریخ/نوع از دست نرود.
      return ProgramHistory(
        id: program.id,
        name: program.name,
        type: program.type,
        date: program.date,
        generatedWorkout: detail['generated_workout']?.toString(),
        generatedMealPlan: detail['generated_meal_plan']?.toString(),
        rawProgramType:
        detail['program_type']?.toString() ?? program.rawProgramType,
      );
    } catch (e) {
      LoggerService.logApiError(
        method: 'GET',
        url: ServerEndpoints.program(program.id),
        error: e.toString(),
      );
      return null;
    }
  }

  /// قبل از تصمیم‌گیری برای دانلود/اشتراک، مطمئن می‌شویم که محتوا داریم.
  /// اگر در لیست نبود، از سرور می‌گیریم.
  Future<ProgramHistory?> _ensureContent(ProgramHistory program) async {
    if (program.hasAnyContent) return program;
    return _fetchFullDetail(program);
  }

  // ============================================================
  // مشاهده متن برنامه -> GET /api/programs/{id}/
  // ============================================================
  Future<void> _onView(ProgramHistory program) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      LoggerService.logEvent(
        title: 'HISTORY_PROGRAMS',
        message: 'درخواست مشاهده جزئیات برنامه ${program.id}',
      );

      final response = await _apiService.get(
        endpoint: ServerEndpoints.program(program.id),
        requiresAuth: true,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // بستن لودینگ

      if (response.success && response.data != null) {
        final detail = response.data as Map<String, dynamic>;

        LoggerService.logProfile(
          action: 'VIEW_SUCCESS',
          message: 'جزئیات برنامه ${program.id} نمایش داده شد',
        );

        if (!mounted) return;

        showDialog(
          context: context,
          builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(program.name),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'برنامه ورزشی:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(detail['generated_workout']?.toString() ?? '(ندارد)'),
                    const SizedBox(height: 12),
                    const Text(
                      'برنامه غذایی:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      detail['generated_meal_plan']?.toString() ?? '(ندارد)',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('بستن'),
                ),
              ],
            ),
          ),
        );
      } else {
        LoggerService.logApiError(
          method: 'GET',
          url: ServerEndpoints.program(program.id),
          error: response.error ?? 'Unknown error',
        );

        if (mounted) {
          context.showSafeSnackBar(
            'خطا: ${response.error ?? "دریافت جزئیات ناموفق بود"}',
            color: Colors.red,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();

      LoggerService.logApiError(
        method: 'GET',
        url: ServerEndpoints.program(program.id),
        error: e.toString(),
      );

      context.showSafeSnackBar('خطا: $e', color: Colors.red);
    }
  }

  // ============================================================
  // دانلود PDF -> GET /api/programs/{id}/pdf/
  //
  // بدون هیچ پرسشی: مربی دکمه را می‌زند و فایل بلافاصله دانلود می‌شود.
  // بخش موردنیاز از روی محتوای خود برنامه تعیین می‌شود و اگر محتوا در
  // لیست تاریخچه نبود، اول از سرور گرفته می‌شود.
  // ============================================================
  Future<void> _onDownload(ProgramHistory program) async {
    // نگهبان تک‌درخواستی
    if (_downloadingIds.contains(program.id)) return;
    setState(() => _downloadingIds.add(program.id));
    context.showSafeSnackBar('در حال آماده‌سازی فایل...', seconds: 2);

    try {
      // اگر محتوا در لیست نبود، ابتدا جزئیات را از سرور می‌گیریم
      final full = await _ensureContent(program);
      if (!mounted) return;

      if (full == null) {
        context.showSafeSnackBar(
          'دریافت اطلاعات برنامه ناموفق بود.',
          color: dangerFgColor,
        );
        return;
      }

      final section = _defaultSection(full);
      if (section == null) {
        context.showSafeSnackBar(
          'این برنامه محتوایی ندارد.',
          color: warnFgColor,
        );
        return;
      }

      final bytes = await _apiService.getBytes(
        endpoint: _pdfEndpoint(program.id, section),
      );
      if (!mounted) return;

      if (bytes == null || bytes.isEmpty) {
        context.showSafeSnackBar(
          'دریافت فایل ناموفق بود. دوباره تلاش کنید.',
          color: dangerFgColor,
        );
        return;
      }

      await savePdf(bytes, _pdfFileName(program, section));
      if (!mounted) return;
      context.showSafeSnackBar('فایل دانلود شد', color: okFgColor);
    } catch (e) {
      if (!mounted) return;
      context.showSafeSnackBar('خطا در دانلود: $e', color: dangerFgColor);
    } finally {
      if (mounted) setState(() => _downloadingIds.remove(program.id));
    }
  }

  /// بخش پیش‌فرض برای دانلود/کد.
  ///
  /// اولویت اول: محتوای واقعی برنامه (اگر در لیست موجود باشد).
  /// اولویت دوم: فیلد خام `program_type` از سرور.
  /// اولویت سوم: برچسب نمایشی `type`.
  static String? _defaultSection(ProgramHistory program) {
    // ۱) اگر محتوا داریم، دقیق تصمیم بگیر
    if (program.hasWorkout && program.hasMealPlan) return 'both';
    if (program.hasWorkout) return 'workout';
    if (program.hasMealPlan) return 'meal';

    // ۲) بر اساس نوع خام سرور
    switch (program.rawProgramType) {
      case 'workout':
        return 'workout';
      case 'meal':
        return 'meal';
      case 'both':
        return 'both';
    }

    // ۳) بر اساس برچسب نمایشی
    switch (program.type) {
      case 'ورزشی':
        return 'workout';
      case 'غذایی':
        return 'meal';
      case 'ورزشی و غذایی':
        return 'both';
    }

    return null;
  }

  static String _pdfEndpoint(int programId, String section) {
    switch (section) {
      case 'workout':
        return ServerEndpoints.programPdfWorkout(programId);
      case 'meal':
        return ServerEndpoints.programPdfMeal(programId);
      default:
        return ServerEndpoints.programPdf(programId);
    }
  }

  static String _pdfFileName(ProgramHistory program, String section) {
    final safeName = program.name
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final base = safeName.isEmpty ? 'program_${program.id}' : safeName;
    return '${base}_$section.pdf';
  }

  // ============================================================
  // کد یکبارمصرف دانلود برای ورزشکار
  // ============================================================
  Future<void> _onShare(ProgramHistory program) async {
    if (_resolvingIds.contains(program.id)) return;
    setState(() => _resolvingIds.add(program.id));

    try {
      final full = await _ensureContent(program);
      if (!mounted) return;

      if (full == null) {
        context.showSafeSnackBar(
          'دریافت اطلاعات برنامه ناموفق بود.',
          color: dangerFgColor,
        );
        return;
      }

      final section = _defaultSection(full);
      if (section == null) {
        context.showSafeSnackBar(
          'این برنامه محتوایی ندارد.',
          color: warnFgColor,
        );
        return;
      }

      await showShareCodeCard(
        context: context,
        programId: program.id,
        programName: program.name,
        hasWorkout: full.hasWorkout,
        hasMealPlan: full.hasMealPlan,
        initialSection: section,
      );
    } catch (e) {
      if (!mounted) return;
      context.showSafeSnackBar('خطا: $e', color: dangerFgColor);
    } finally {
      if (mounted) setState(() => _resolvingIds.remove(program.id));
    }
  }

  // محاسبه آیتم‌های صفحه جاری
  List<ProgramHistory> _getCurrentPageItems() {
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, _filteredPrograms.length);
    return _filteredPrograms.sublist(start, end);
  }

  int get _totalPages => _filteredPrograms.isEmpty
      ? 1
      : (_filteredPrograms.length / _itemsPerPage).ceil();

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    setState(() => _currentPage = page);
  }

  /// جست‌وجو با تاخیر کوتاه.
  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), _applySearch);
  }

  void _applySearch() {
    if (!mounted) return;
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredPrograms = List.from(_allPrograms);
      } else {
        _filteredPrograms = _allPrograms
            .where((p) => p.name.toLowerCase().contains(query))
            .toList();
      }
      _currentPage = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final deviceType = _resolveDeviceType(context);
    final isDesktop = deviceType == AppDeviceType.desktop;
    final isMobile = deviceType == AppDeviceType.mobile;

    final sizes = _HistorySizes.of(deviceType);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: EdgeInsets.all(sizes.outerMargin),
        padding: EdgeInsets.symmetric(
          horizontal: sizes.horizontalPadding,
          vertical: sizes.verticalPadding,
        ),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(sizes.containerRadius),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Center(
            child: SizedBox(
              width: isDesktop ? 1100 : double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTitle(sizes),
                  const SizedBox(height: 24),
                  _buildSearchBar(sizes),
                  const SizedBox(height: 24),
                  if (isMobile)
                    Expanded(child: _buildMobileCards(sizes))
                  else
                    Expanded(child: _buildTable(sizes)),
                  const SizedBox(height: 20),
                  _buildPagination(sizes),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(_HistorySizes sizes) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: surfaceMutedColor,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          'تاریخچه برنامه‌ها',
          style: TextStyle(
            fontSize: sizes.titleFontSize,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(_HistorySizes sizes) {
    return Container(
      height: sizes.searchHeight,
      decoration: BoxDecoration(
        color: surfaceAltColor,
        borderRadius: BorderRadius.circular(sizes.searchRadius),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(
            Icons.search,
            color: textMutedColor,
            size: sizes.searchIconSize,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'جستجو بر اساس نام',
                hintStyle: TextStyle(
                  color: textFaintColor,
                  fontSize: sizes.searchHintSize,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(
                fontSize: sizes.searchTextSize,
                color: textPrimaryColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildTable(_HistorySizes sizes) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _buildErrorState(sizes);
    }

    final items = _getCurrentPageItems();
    final hasData = items.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(sizes.tableRadius),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TableHeader(sizes: sizes),
          if (!hasData)
            Expanded(
              child: Center(
                child: Text(
                  'هیچ برنامه‌ای پیدا نشد.',
                  style: TextStyle(
                    fontSize: sizes.emptyStateSize,
                    color: textFaintColor,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => Divider(
                  height: 0,
                  thickness: 1,
                  color: borderColor,
                ),
                itemBuilder: (context, index) {
                  return _TableRow(
                    program: items[index],
                    sizes: sizes,
                    onView: () => _onView(items[index]),
                    onDownload: () => _onDownload(items[index]),
                    onShare: () => _onShare(items[index]),
                    isDownloading: _downloadingIds.contains(items[index].id),
                    isResolving: _resolvingIds.contains(items[index].id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileCards(_HistorySizes sizes) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _buildErrorState(sizes);
    }

    final items = _getCurrentPageItems();
    final hasData = items.isNotEmpty;

    if (!hasData) {
      return Center(
        child: Text(
          'هیچ برنامه‌ای پیدا نشد.',
          style: TextStyle(
            fontSize: sizes.emptyStateSize,
            color: textFaintColor,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _HistoryCard(
          program: items[index],
          sizes: sizes,
          onView: () => _onView(items[index]),
          onDownload: () => _onDownload(items[index]),
          onShare: () => _onShare(items[index]),
          isDownloading: _downloadingIds.contains(items[index].id),
          isResolving: _resolvingIds.contains(items[index].id),
        );
      },
    );
  }

  Widget _buildErrorState(_HistorySizes sizes) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: sizes.emptyStateSize, color: Colors.red),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadHistory,
            child: const Text('تلاش دوباره'),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(_HistorySizes sizes) {
    if (_filteredPrograms.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${_filteredPrograms.length} تا برنامه',
          style: TextStyle(
            fontSize: sizes.paginationTextSize,
            color: textSecondaryColor,
          ),
        ),
        const SizedBox(width: 24),
        _buildPageButton(
          icon: Icons.chevron_left,
          onPressed: _currentPage > 1
              ? () => _goToPage(_currentPage - 1)
              : null,
          size: sizes.pageButtonSize,
        ),
        const SizedBox(width: 4),
        ..._buildPageNumbers(sizes),
        const SizedBox(width: 4),
        _buildPageButton(
          icon: Icons.chevron_right,
          onPressed: _currentPage < _totalPages
              ? () => _goToPage(_currentPage + 1)
              : null,
          size: sizes.pageButtonSize,
        ),
      ],
    );
  }

  List<Widget> _buildPageNumbers(_HistorySizes sizes) {
    const maxVisible = 5;
    final total = _totalPages;
    final current = _currentPage;

    List<int> pages = [];

    if (total <= maxVisible) {
      pages = List.generate(total, (i) => i + 1);
    } else {
      if (current <= 3) {
        pages = [1, 2, 3, 4, -1, total];
      } else if (current >= total - 2) {
        pages = [1, -1, total - 3, total - 2, total - 1, total];
      } else {
        pages = [1, -1, current - 1, current, current + 1, -1, total];
      }
    }

    return pages.map((page) {
      if (page == -1) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '...',
            style: TextStyle(fontSize: sizes.paginationTextSize),
          ),
        );
      }
      return _buildPageNumber(
        number: page,
        isActive: page == current,
        onTap: () => _goToPage(page),
        size: sizes.pageButtonSize,
      );
    }).toList();
  }

  Widget _buildPageNumber({
    required int number,
    required bool isActive,
    required VoidCallback onTap,
    required double size,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isActive ? primeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          number.toString(),
          style: TextStyle(
            fontSize: size * 0.45,
            fontWeight: FontWeight.w600,
            color: isActive ? onPrimaryColor : textPrimaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildPageButton({
    required IconData icon,
    VoidCallback? onPressed,
    required double size,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: size * 0.5,
          color: onPressed != null ? textPrimaryColor : textFaintColor,
        ),
      ),
    );
  }
}

// ============================================================
// Table Header
// ============================================================
class _TableHeader extends StatelessWidget {
  final _HistorySizes sizes;
  const _TableHeader({required this.sizes});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: sizes.headerHeight,
      padding: EdgeInsets.symmetric(horizontal: sizes.cellPaddingH),
      decoration: BoxDecoration(
        color: surfaceMutedColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(sizes.tableRadius),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'نام برنامه',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: sizes.headerTextSize,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'نوع برنامه',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: sizes.headerTextSize,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'تاریخ ایجاد',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: sizes.headerTextSize,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'عملیات',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: sizes.headerTextSize,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Table Row
// ============================================================
class _TableRow extends StatelessWidget {
  final ProgramHistory program;
  final _HistorySizes sizes;
  final VoidCallback onView;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final bool isDownloading;
  final bool isResolving;

  const _TableRow({
    required this.program,
    required this.sizes,
    required this.onView,
    required this.onDownload,
    required this.onShare,
    required this.isDownloading,
    required this.isResolving,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: sizes.rowHeight,
      padding: EdgeInsets.symmetric(horizontal: sizes.cellPaddingH),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _TypeIcon(type: program.type, size: sizes.typeIconSize),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    program.name,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: sizes.rowTextSize,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: _TypeBadge(type: program.type, sizes: sizes),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                program.date,
                style: TextStyle(
                  fontSize: sizes.rowTextSize,
                  fontWeight: FontWeight.w600,
                  color: textPrimaryColor,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _OperationButton(
                  icon: Icons.remove_red_eye_outlined,
                  onPressed: onView,
                  size: sizes.opButtonSize,
                  tooltip: 'مشاهده برنامه',
                ),
                const SizedBox(width: 6),
                _OperationButton(
                  icon: Icons.file_download_outlined,
                  onPressed: onDownload,
                  size: sizes.opButtonSize,
                  tooltip: 'دانلود PDF',
                  isBusy: isDownloading,
                ),
                const SizedBox(width: 6),
                // دکمه سپر: کد یکبارمصرف تا ورزشکار همین برنامه را دانلود کند
                _OperationButton(
                  icon: Icons.shield_outlined,
                  onPressed: onShare,
                  size: sizes.opButtonSize,
                  tooltip: 'کد یکبارمصرف برای ورزشکار',
                  highlighted: true,
                  isBusy: isResolving,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Type Badge
// ============================================================
class _TypeBadge extends StatelessWidget {
  final String type;
  final _HistorySizes sizes;
  const _TypeBadge({required this.type, required this.sizes});

  @override
  Widget build(BuildContext context) {
    final isWorkout = type == 'ورزشی';
    final isBoth = type == 'ورزشی و غذایی';

    final bgColor = isBoth
        ? primeColor.withValues(alpha: 0.10)
        : (isWorkout ? infoBgColor : warnBgColor);
    final textColor = isBoth
        ? primeColor
        : (isWorkout ? infoFgColor : warnFgColor);
    final icon = isBoth
        ? Icons.auto_awesome
        : (isWorkout ? Icons.fitness_center : Icons.restaurant);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: sizes.badgeIconSize, color: textColor),
          const SizedBox(width: 6),
          Text(
            type,
            style: TextStyle(
              fontSize: sizes.badgeTextSize,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Type Icon
// ============================================================
class _TypeIcon extends StatelessWidget {
  final String type;
  final double size;
  const _TypeIcon({required this.type, required this.size});

  @override
  Widget build(BuildContext context) {
    final isWorkout = type == 'ورزشی';
    final isBoth = type == 'ورزشی و غذایی';

    final bg = isBoth
        ? primeColor.withValues(alpha: 0.10)
        : (isWorkout ? infoBgColor : warnBgColor);
    final fg = isBoth
        ? primeColor
        : (isWorkout ? infoFgColor : warnFgColor);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        isBoth
            ? Icons.auto_awesome
            : (isWorkout ? Icons.fitness_center : Icons.restaurant),
        size: size * 0.6,
        color: fg,
      ),
    );
  }
}

// ============================================================
// Operation Button
// ============================================================
class _OperationButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final String? tooltip;

  /// دکمه‌ای که کار در حال انجام دارد — به‌جای آیکون، اسپینر نشان می‌دهد.
  final bool isBusy;

  /// دکمه‌ی شاخص (سپر) — با رنگ برند از بقیه جدا می‌شود.
  final bool highlighted;

  const _OperationButton({
    required this.icon,
    required this.onPressed,
    required this.size,
    this.tooltip,
    this.isBusy = false,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = highlighted ? primeColor : textSecondaryColor;

    final button = Material(
      color: highlighted
          ? primeColor.withValues(alpha: 0.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: isBusy ? null : onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: highlighted
                  ? primeColor.withValues(alpha: 0.35)
                  : borderStrongColor,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: isBusy
              ? SizedBox(
            width: size * 0.42,
            height: size * 0.42,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
              : Icon(icon, size: size * 0.5, color: fg),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

// ============================================================
// History Card (Mobile)
// ============================================================
class _HistoryCard extends StatelessWidget {
  final ProgramHistory program;
  final _HistorySizes sizes;
  final VoidCallback onView;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final bool isDownloading;
  final bool isResolving;

  const _HistoryCard({
    required this.program,
    required this.sizes,
    required this.onView,
    required this.onDownload,
    required this.onShare,
    required this.isDownloading,
    required this.isResolving,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _TypeIcon(type: program.type, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  program.name,
                  style: TextStyle(
                    fontSize: sizes.mobileCardNameSize,
                    fontWeight: FontWeight.bold,
                    color: textPrimaryColor,
                  ),
                ),
              ),
              _TypeBadge(type: program.type, sizes: sizes),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                program.date,
                style: TextStyle(
                  fontSize: sizes.mobileCardDateSize,
                  fontWeight: FontWeight.w600,
                  color: textSecondaryColor,
                ),
              ),
              Row(
                children: [
                  _OperationButton(
                    icon: Icons.remove_red_eye_outlined,
                    onPressed: onView,
                    size: 36,
                    tooltip: 'مشاهده برنامه',
                  ),
                  const SizedBox(width: 8),
                  _OperationButton(
                    icon: Icons.file_download_outlined,
                    onPressed: onDownload,
                    size: 36,
                    tooltip: 'دانلود PDF',
                    isBusy: isDownloading,
                  ),
                  const SizedBox(width: 8),
                  _OperationButton(
                    icon: Icons.shield_outlined,
                    onPressed: onShare,
                    size: 36,
                    tooltip: 'کد یکبارمصرف برای ورزشکار',
                    highlighted: true,
                    isBusy: isResolving,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// اندازه‌های ریسپانسیو
// ============================================================
class _HistorySizes {
  const _HistorySizes({
    required this.outerMargin,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.containerRadius,
    required this.titleFontSize,
    required this.searchHeight,
    required this.searchRadius,
    required this.searchIconSize,
    required this.searchHintSize,
    required this.searchTextSize,
    required this.tableRadius,
    required this.headerHeight,
    required this.headerTextSize,
    required this.rowHeight,
    required this.rowTextSize,
    required this.cellPaddingH,
    required this.typeIconSize,
    required this.badgeTextSize,
    required this.badgeIconSize,
    required this.opButtonSize,
    required this.paginationTextSize,
    required this.pageButtonSize,
    required this.emptyStateSize,
    required this.mobileCardNameSize,
    required this.mobileCardDateSize,
  });

  final double outerMargin;
  final double horizontalPadding;
  final double verticalPadding;
  final double containerRadius;
  final double titleFontSize;
  final double searchHeight;
  final double searchRadius;
  final double searchIconSize;
  final double searchHintSize;
  final double searchTextSize;
  final double tableRadius;
  final double headerHeight;
  final double headerTextSize;
  final double rowHeight;
  final double rowTextSize;
  final double cellPaddingH;
  final double typeIconSize;
  final double badgeTextSize;
  final double badgeIconSize;
  final double opButtonSize;
  final double paginationTextSize;
  final double pageButtonSize;
  final double emptyStateSize;
  final double mobileCardNameSize;
  final double mobileCardDateSize;

  factory _HistorySizes.of(AppDeviceType type) {
    switch (type) {
      case AppDeviceType.desktop:
        return const _HistorySizes(
          outerMargin: 24,
          horizontalPadding: 32,
          verticalPadding: 28,
          containerRadius: 24,
          titleFontSize: 26,
          searchHeight: 64,
          searchRadius: 20,
          searchIconSize: 24,
          searchHintSize: 16,
          searchTextSize: 16,
          tableRadius: 16,
          headerHeight: 46,
          headerTextSize: 15,
          rowHeight: 62,
          rowTextSize: 15,
          cellPaddingH: 20,
          typeIconSize: 26,
          badgeTextSize: 13,
          badgeIconSize: 16,
          opButtonSize: 36,
          paginationTextSize: 15,
          pageButtonSize: 40,
          emptyStateSize: 18,
          mobileCardNameSize: 18,
          mobileCardDateSize: 16,
        );
      case AppDeviceType.tablet:
        return const _HistorySizes(
          outerMargin: 20,
          horizontalPadding: 24,
          verticalPadding: 24,
          containerRadius: 20,
          titleFontSize: 22,
          searchHeight: 56,
          searchRadius: 18,
          searchIconSize: 22,
          searchHintSize: 14,
          searchTextSize: 14,
          tableRadius: 14,
          headerHeight: 42,
          headerTextSize: 13,
          rowHeight: 56,
          rowTextSize: 13,
          cellPaddingH: 16,
          typeIconSize: 22,
          badgeTextSize: 11.5,
          badgeIconSize: 15,
          opButtonSize: 34,
          paginationTextSize: 13,
          pageButtonSize: 36,
          emptyStateSize: 16,
          mobileCardNameSize: 16,
          mobileCardDateSize: 14,
        );
      case AppDeviceType.mobile:
        return const _HistorySizes(
          outerMargin: 12,
          horizontalPadding: 16,
          verticalPadding: 16,
          containerRadius: 16,
          titleFontSize: 18,
          searchHeight: 50,
          searchRadius: 16,
          searchIconSize: 20,
          searchHintSize: 13,
          searchTextSize: 14,
          tableRadius: 12,
          headerHeight: 36,
          headerTextSize: 12,
          rowHeight: 52,
          rowTextSize: 12,
          cellPaddingH: 12,
          typeIconSize: 20,
          badgeTextSize: 10.5,
          badgeIconSize: 13,
          opButtonSize: 32,
          paginationTextSize: 12,
          pageButtonSize: 32,
          emptyStateSize: 14,
          mobileCardNameSize: 16,
          mobileCardDateSize: 14,
        );
    }
  }
}