// lib/pages/gym_devices.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../colors.dart';
import '../core/network/server_endpoints.dart';
import '../responsive.dart';
import '../rigester-login/token_manegment.dart';

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
// مدل یک دستگاه (equipment) که از سرور می‌آید
// ============================================================
class _DeviceItem {
  final int id;
  final String name;

  const _DeviceItem({required this.id, required this.name});
}

// ============================================================
// صفحه اصلی مدیریت دستگاه‌ها
// ============================================================
class GymDevices extends StatefulWidget {
  const GymDevices({super.key});

  @override
  State<GymDevices> createState() => _GymDevicesState();
}

class _GymDevicesState extends State<GymDevices> {
  static const List<String> _defaultDevices = [
    'تردمیل',
    'دوچرخه',
    'سیم کش',
    'بارفیکس',
    'دمبل',
    'هالتر',
  ];

  static const String _defaultCategoryName = 'دستگاه‌های باشگاه';
  static const String _defaultMuscleGroup = 'full_body';
  static const String _seededPrefKey = 'gym_devices_default_seeded';

  final ApiService _api = ApiService();

  List<_DeviceItem> _allDevices = [];
  List<_DeviceItem> _filteredDevices = [];
  final TextEditingController _searchController = TextEditingController();

  int? _defaultCategoryId;

  bool _isLoading = true;
  String? _errorMessage;

  // For delete undo
  _DeviceItem? _deletedDevice;

  // Keys for popover positioning
  final GlobalKey _addButtonKey = GlobalKey();

  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initialize();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // Init / Load
  // ============================================================
  Future<void> _initialize() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 1) اطمینان از وجود دسته‌بندی پیش‌فرض
    final categoryOk = await _ensureDefaultCategory();
    if (!mounted) return;

    if (!categoryOk) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'خطا در آماده‌سازی دسته‌بندی پیش‌فرض';
      });
      return;
    }

    // 2) گرفتن لیست دستگاه‌ها از سرور
    final loaded = await _fetchDevicesFromServer();
    if (!mounted) return;

    if (loaded == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'خطا در دریافت لیست دستگاه‌ها';
      });
      return;
    }

    // 3) اگر تا حالا هیچ‌وقت seed نشده و لیست هم خالیه، دستگاه‌های پیش‌فرض رو بساز
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final alreadySeeded = prefs.getBool(_seededPrefKey) ?? false;

    if (!alreadySeeded && loaded.isEmpty) {
      final seeded = await _seedDefaultDevices();
      await prefs.setBool(_seededPrefKey, true);
      if (!mounted) return;

      setState(() {
        _allDevices = seeded;
        _applyFilter();
        _isLoading = false;
      });
      return;
    }

    if (!alreadySeeded) {
      // لیست خالی نبود ولی هنوز seed نشده بود؛ دیگه لازم نیست seed کنیم
      await prefs.setBool(_seededPrefKey, true);
    }

    if (!mounted) return;

    setState(() {
      _allDevices = loaded;
      _applyFilter();
      _isLoading = false;
    });
  }

  Future<bool> _ensureDefaultCategory() async {
    final response = await _api.get(
      endpoint: ServerEndpoints.equipmentCategories,
    );
    if (!mounted) return false;

    if (response.success && response.data is List) {
      final list = List<Map<String, dynamic>>.from(response.data as List);
      for (final item in list) {
        if (item['name']?.toString() == _defaultCategoryName) {
          _defaultCategoryId = _asInt(item['id']);
          return _defaultCategoryId != null;
        }
      }
    } else if (!response.success) {
      return false;
    }

    // پیدا نشد -> بسازش
    final createResponse = await _api.post(
      endpoint: ServerEndpoints.equipmentCategories,
      body: {
        'name': _defaultCategoryName,
        'description': 'دسته‌بندی پیش‌فرض دستگاه‌های باشگاه',
      },
    );

    if (!mounted) return false;

    if (createResponse.success && createResponse.data is Map) {
      _defaultCategoryId = _asInt(
        (createResponse.data as Map<String, dynamic>)['id'],
      );
      return _defaultCategoryId != null;
    }

    return false;
  }

  Future<List<_DeviceItem>?> _fetchDevicesFromServer() async {
    final response = await _api.get(endpoint: ServerEndpoints.equipments);
    if (!mounted) return null;

    if (!response.success || response.data is! List) return null;

    final list = List<Map<String, dynamic>>.from(response.data as List);
    return list
        .map((e) {
          final id = _asInt(e['id']);
          final name = e['name']?.toString();
          if (id == null || name == null) return null;
          return _DeviceItem(id: id, name: name);
        })
        .whereType<_DeviceItem>()
        .toList();
  }

  Future<List<_DeviceItem>> _seedDefaultDevices() async {
    final created = <_DeviceItem>[];
    for (final name in _defaultDevices) {
      final item = await _createDeviceOnServer(name);
      if (item != null) created.add(item);
    }
    return created;
  }

  // ============================================================
  // Server mutations
  // ============================================================
  Future<_DeviceItem?> _createDeviceOnServer(String name) async {
    if (_defaultCategoryId == null) return null;

    final response = await _api.post(
      endpoint: ServerEndpoints.equipments,
      body: {
        'name': name,
        'description': '',
        'category': _defaultCategoryId,
        'muscle_group': _defaultMuscleGroup,
      },
    );

    if (!mounted) return null;

    if (response.success && response.data is Map) {
      final data = response.data as Map<String, dynamic>;
      final id = _asInt(data['id']);
      if (id != null) {
        return _DeviceItem(id: id, name: data['name']?.toString() ?? name);
      }
    }
    return null;
  }

  Future<bool> _updateDeviceOnServer(int id, String newName) async {
    final response = await _api.patch(
      endpoint: ServerEndpoints.equipment(id),
      body: {
        'name': newName,
        'description': '',
        'category': _defaultCategoryId,
        'muscle_group': _defaultMuscleGroup,
      },
    );
    return response.success;
  }

  Future<bool> _deleteDeviceOnServer(int id) async {
    final response = await _api.delete(endpoint: ServerEndpoints.equipment(id));
    return response.success;
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  // ============================================================
  // Local list ops (search/filter)
  // ============================================================
  /// جست‌وجو با تاخیر کوتاه — هر کلید فشرده‌شده دیگر کل فهرست دستگاه‌ها
  /// را بازسازی نمی‌کند.
  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(_applyFilter);
    });
  }

  void _applyFilter() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _filteredDevices = List.from(_allDevices);
    } else {
      _filteredDevices = _allDevices
          .where((d) => d.name.contains(query))
          .toList();
    }
  }

  // ============================================================
  // CRUD handlers (with server calls)
  // ============================================================
  Future<void> _addDevice(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      context.showSafeSnackBar(
        'نام دستگاه نمی‌تواند خالی باشد.',
        color: Colors.red,
      );
      return;
    }
    if (_allDevices.any((d) => d.name == trimmed)) {
      context.showSafeSnackBar(
        'این دستگاه قبلاً اضافه شده است.',
        color: Colors.red,
      );
      return;
    }

    _closePopover();
    context.showSafeSnackBar('در حال افزودن...');

    final created = await _createDeviceOnServer(trimmed);
    if (!mounted) return;

    if (created == null) {
      context.showSafeSnackBar(
        'خطا در افزودن دستگاه به سرور',
        color: Colors.red,
      );
      return;
    }

    setState(() {
      _allDevices.add(created);
      _applyFilter();
    });
  }

  Future<void> _editDevice(_DeviceItem device, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      context.showSafeSnackBar(
        'نام دستگاه نمی‌تواند خالی باشد.',
        color: Colors.red,
      );
      return;
    }
    if (trimmed == device.name) {
      _closePopover();
      return;
    }
    if (_allDevices.any((d) => d.name == trimmed && d.id != device.id)) {
      context.showSafeSnackBar(
        'این دستگاه قبلاً اضافه شده است.',
        color: Colors.red,
      );
      return;
    }

    _closePopover();

    final ok = await _updateDeviceOnServer(device.id, trimmed);
    if (!mounted) return;

    if (!ok) {
      context.showSafeSnackBar('خطا در ویرایش دستگاه', color: Colors.red);
      return;
    }

    setState(() {
      final index = _allDevices.indexWhere((d) => d.id == device.id);
      if (index != -1) {
        _allDevices[index] = _DeviceItem(id: device.id, name: trimmed);
        _applyFilter();
      }
    });
  }

  Future<void> _deleteDevice(_DeviceItem device) async {
    final ok = await _deleteDeviceOnServer(device.id);
    if (!mounted) return;

    if (!ok) {
      context.showSafeSnackBar('خطا در حذف دستگاه', color: Colors.red);
      return;
    }

    setState(() {
      _allDevices.removeWhere((d) => d.id == device.id);
      _applyFilter();
      _deletedDevice = device;
    });

    // استفاده از روش safe برای SnackBar با Action
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('دستگاه حذف شد.'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'بازگردانی',
          onPressed: () async {
            final toRestore = _deletedDevice;
            if (toRestore == null) return;
            final recreated = await _createDeviceOnServer(toRestore.name);
            if (!mounted) return;
            if (recreated != null) {
              setState(() {
                _allDevices.add(recreated);
                _applyFilter();
                _deletedDevice = null;
              });
            } else {
              context.showSafeSnackBar(
                'بازگردانی دستگاه ناموفق بود',
                color: Colors.red,
              );
            }
          },
        ),
      ),
    );
  }

  // ============================================================
  // Popover Management
  // ============================================================
  OverlayEntry? _popoverEntry;

  void _showPopover({
    required String title,
    required String initialValue,
    required String hint,
    required String confirmLabel,
    required ValueChanged<String> onConfirm,
    required VoidCallback onCancel,
    Offset? anchorOffset,
    bool isCentered = false,
  }) {
    _closePopover();
    final overlay = Overlay.of(context);

    _popoverEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _closePopover();
              onCancel();
            },
            child: Container(color: Colors.transparent),
          ),
          if (isCentered)
            Positioned.fill(
              child: Center(
                child: _PopoverPanel(
                  title: title,
                  initialValue: initialValue,
                  hint: hint,
                  confirmLabel: confirmLabel,
                  onConfirm: onConfirm,
                  onCancel: () {
                    _closePopover();
                    onCancel();
                  },
                  onClose: _closePopover,
                ),
              ),
            )
          else
            Positioned(
              left: anchorOffset?.dx ?? 0 - 20,
              top: anchorOffset?.dy ?? 0 + 10,
              child: _PopoverPanel(
                title: title,
                initialValue: initialValue,
                hint: hint,
                confirmLabel: confirmLabel,
                onConfirm: onConfirm,
                onCancel: () {
                  _closePopover();
                  onCancel();
                },
                onClose: _closePopover,
              ),
            ),
        ],
      ),
    );

    overlay.insert(_popoverEntry!);
  }

  void _closePopover() {
    _popoverEntry?.remove();
    _popoverEntry = null;
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final deviceType = _resolveDeviceType(context);
    final _ = deviceType == AppDeviceType.desktop;

    final sizes = _DeviceSizes.of(deviceType);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(sizes),
                const SizedBox(height: 24),
                _buildSearchAndAddRow(sizes),
                const SizedBox(height: 20),
                if (_errorMessage != null) ...[
                  _buildErrorBanner(_errorMessage!),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildTable(sizes),
                ),
                if (!_isLoading) _buildPagination(sizes),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: dangerBgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dangerBorderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              textAlign: TextAlign.right,
              style: TextStyle(color: dangerFgColor, fontSize: 13),
            ),
          ),
          TextButton(onPressed: _initialize, child: const Text('تلاش مجدد')),
        ],
      ),
    );
  }

  // ============================================================
  // Header
  // ============================================================
  Widget _buildHeader(_DeviceSizes sizes) {
    return Row(
      children: [
        Container(
          width: sizes.headerIconSize,
          height: sizes.headerIconSize,
          decoration: BoxDecoration(
            color: primeColor,
            borderRadius: BorderRadius.circular(sizes.headerIconRadius),
          ),
          child: Icon(
            Icons.fitness_center,
            size: sizes.headerIconSize * 0.52,
            color: onPrimaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'دستگاه های باشگاه شما',
            style: TextStyle(
              fontSize: sizes.headerTitleSize,
              fontWeight: FontWeight.bold,
              color: logoColor,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Search and Add Row
  // ============================================================
  Widget _buildSearchAndAddRow(_DeviceSizes sizes) {
    return Row(
      children: [
        SizedBox(
          key: _addButtonKey,
          height: sizes.addButtonHeight,
          child: ElevatedButton.icon(
            onPressed: _isLoading
                ? null
                : () {
                    // برای اضافه کردن، isCentered = true
                    _showPopover(
                      title: 'افزودن دستگاه',
                      initialValue: '',
                      hint: 'نام دستگاه',
                      confirmLabel: 'افزودن',
                      onConfirm: (value) => _addDevice(value),
                      onCancel: () {},
                      anchorOffset: null,
                      isCentered: true, // <-- وسط صفحه
                    );
                  },
            icon: const Icon(Icons.add, color: onPrimaryColor, size: 20),
            label: const Text(
              'افزودن دستگاه',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primeColor,
              foregroundColor: onPrimaryColor,
              disabledBackgroundColor: primeColor.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(sizes.addButtonRadius),
              ),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
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
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Table
  // ============================================================
  Widget _buildTable(_DeviceSizes sizes) {
    final items = _filteredDevices;
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
                  'هیچ دستگاهی پیدا نشد.',
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
                  final device = items[index];
                  return _TableRow(
                    device: device,
                    index: index,
                    sizes: sizes,
                    onDelete: _deleteDevice,
                    showEditPopover: (item, anchorOffset) {
                      // برای ویرایش، isCentered = true
                      _showPopover(
                        title: 'ویرایش نام دستگاه',
                        initialValue: item.name,
                        hint: 'نام جدید',
                        confirmLabel: 'ذخیره',
                        onConfirm: (value) => _editDevice(item, value),
                        onCancel: () {},
                        anchorOffset: anchorOffset,
                        isCentered: true, // <-- وسط صفحه
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // Pagination (UI only)
  // ============================================================
  Widget _buildPagination(_DeviceSizes sizes) {
    final total = _filteredDevices.length;
    if (total == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$total دستگاه',
            style: TextStyle(
              fontSize: sizes.paginationTextSize,
              color: textSecondaryColor,
            ),
          ),
          const SizedBox(width: 24),
          _buildPageButton(
            icon: Icons.chevron_left,
            onPressed: null,
            size: sizes.pageButtonSize,
          ),
          const SizedBox(width: 4),
          _buildPageNumber(
            number: 1,
            isActive: true,
            onTap: () {},
            size: sizes.pageButtonSize,
          ),
          if (total > 10) ...[
            const SizedBox(width: 4),
            Text('...', style: TextStyle(fontSize: sizes.paginationTextSize)),
            const SizedBox(width: 4),
            _buildPageNumber(
              number: (total / 10).ceil(),
              isActive: false,
              onTap: () {},
              size: sizes.pageButtonSize,
            ),
          ],
          const SizedBox(width: 4),
          _buildPageButton(
            icon: Icons.chevron_right,
            onPressed: null,
            size: sizes.pageButtonSize,
          ),
        ],
      ),
    );
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
// Popover Panel
// ============================================================
class _PopoverPanel extends StatefulWidget {
  final String title;
  final String initialValue;
  final String hint;
  final String confirmLabel;
  final ValueChanged<String> onConfirm;
  final VoidCallback onCancel;
  final VoidCallback onClose;

  const _PopoverPanel({
    required this.title,
    required this.initialValue,
    required this.hint,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onCancel,
    required this.onClose,
  });

  @override
  State<_PopoverPanel> createState() => _PopoverPanelState();
}

class _PopoverPanelState extends State<_PopoverPanel> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleConfirm() {
    widget.onConfirm(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: widget.hint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _handleConfirm(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    widget.onCancel();
                    widget.onClose();
                  },
                  child: const Text('انصراف'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _handleConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primeColor,
                    foregroundColor: onPrimaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(widget.confirmLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Table Header
// ============================================================
class _TableHeader extends StatelessWidget {
  final _DeviceSizes sizes;

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
          SizedBox(
            width: sizes.indexColumnWidth,
            child: Text(
              'شماره',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: sizes.headerTextSize,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'نام دستگاه',
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
  final _DeviceItem device;
  final int index;
  final _DeviceSizes sizes;
  final void Function(_DeviceItem) onDelete;
  final void Function(_DeviceItem, Offset) showEditPopover;

  const _TableRow({
    required this.device,
    required this.index,
    required this.sizes,
    required this.onDelete,
    required this.showEditPopover,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: sizes.rowHeight,
      padding: EdgeInsets.symmetric(horizontal: sizes.cellPaddingH),
      child: Row(
        children: [
          SizedBox(
            width: sizes.indexColumnWidth,
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: sizes.rowTextSize,
                  fontWeight: FontWeight.w600,
                  color: textPrimaryColor,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              device.name,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: sizes.rowTextSize,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _OperationButton(
                  icon: Icons.edit_outlined,
                  onPressed: () {
                    final RenderBox? buttonRender =
                        context.findRenderObject() as RenderBox?;
                    if (buttonRender != null) {
                      final position = buttonRender.localToGlobal(Offset.zero);
                      final size = buttonRender.size;
                      final offset = Offset(
                        position.dx + size.width - 20,
                        position.dy + size.height,
                      );
                      showEditPopover(device, offset);
                    }
                  },
                  size: sizes.opButtonSize,
                ),
                const SizedBox(width: 8),
                _OperationButton(
                  icon: Icons.delete_outline,
                  onPressed: () => onDelete(device),
                  size: sizes.opButtonSize,
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
// Operation Button
// ============================================================
class _OperationButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;

  const _OperationButton({
    required this.icon,
    required this.onPressed,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(color: borderStrongColor),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: size * 0.5,
          color: icon == Icons.delete_outline
              ? dangerFgColor
              : textSecondaryColor,
        ),
      ),
    );
  }
}

// ============================================================
// اندازه‌های ریسپانسیو
// ============================================================
class _DeviceSizes {
  const _DeviceSizes({
    required this.outerMargin,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.containerRadius,
    required this.headerIconSize,
    required this.headerIconRadius,
    required this.headerTitleSize,
    required this.addButtonHeight,
    required this.addButtonRadius,
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
    required this.indexColumnWidth,
    required this.opButtonSize,
    required this.paginationTextSize,
    required this.pageButtonSize,
    required this.emptyStateSize,
  });

  final double outerMargin;
  final double horizontalPadding;
  final double verticalPadding;
  final double containerRadius;
  final double headerIconSize;
  final double headerIconRadius;
  final double headerTitleSize;
  final double addButtonHeight;
  final double addButtonRadius;
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
  final double indexColumnWidth;
  final double opButtonSize;
  final double paginationTextSize;
  final double pageButtonSize;
  final double emptyStateSize;

  factory _DeviceSizes.of(AppDeviceType type) {
    switch (type) {
      case AppDeviceType.desktop:
        return const _DeviceSizes(
          outerMargin: 24,
          horizontalPadding: 32,
          verticalPadding: 28,
          containerRadius: 24,
          headerIconSize: 56,
          headerIconRadius: 16,
          headerTitleSize: 28,
          addButtonHeight: 48,
          addButtonRadius: 14,
          searchHeight: 48,
          searchRadius: 16,
          searchIconSize: 22,
          searchHintSize: 15,
          searchTextSize: 15,
          tableRadius: 14,
          headerHeight: 56,
          headerTextSize: 14,
          rowHeight: 56,
          rowTextSize: 14,
          cellPaddingH: 16,
          indexColumnWidth: 60,
          opButtonSize: 36,
          paginationTextSize: 14,
          pageButtonSize: 36,
          emptyStateSize: 16,
        );
      case AppDeviceType.tablet:
        return const _DeviceSizes(
          outerMargin: 20,
          horizontalPadding: 24,
          verticalPadding: 24,
          containerRadius: 20,
          headerIconSize: 48,
          headerIconRadius: 14,
          headerTitleSize: 24,
          addButtonHeight: 44,
          addButtonRadius: 12,
          searchHeight: 44,
          searchRadius: 14,
          searchIconSize: 20,
          searchHintSize: 13,
          searchTextSize: 14,
          tableRadius: 12,
          headerHeight: 48,
          headerTextSize: 13,
          rowHeight: 50,
          rowTextSize: 13,
          cellPaddingH: 14,
          indexColumnWidth: 50,
          opButtonSize: 34,
          paginationTextSize: 13,
          pageButtonSize: 34,
          emptyStateSize: 15,
        );
      case AppDeviceType.mobile:
        return const _DeviceSizes(
          outerMargin: 12,
          horizontalPadding: 16,
          verticalPadding: 16,
          containerRadius: 16,
          headerIconSize: 40,
          headerIconRadius: 12,
          headerTitleSize: 20,
          addButtonHeight: 40,
          addButtonRadius: 10,
          searchHeight: 40,
          searchRadius: 12,
          searchIconSize: 18,
          searchHintSize: 12,
          searchTextSize: 13,
          tableRadius: 10,
          headerHeight: 40,
          headerTextSize: 12,
          rowHeight: 44,
          rowTextSize: 12,
          cellPaddingH: 10,
          indexColumnWidth: 40,
          opButtonSize: 32,
          paginationTextSize: 12,
          pageButtonSize: 30,
          emptyStateSize: 13,
        );
    }
  }
}
