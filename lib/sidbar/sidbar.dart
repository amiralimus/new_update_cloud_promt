import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:async';
import '../colors.dart';
import '../core/network/server_endpoints.dart';
import '../loging_system/loging_system.dart';
import '../rigester-login/token_manegment.dart' hide LoggerService;
import '../rigester-login/which_one.dart';

// ============================================================
// Extension برای نمایش SnackBar با بررسی mounted
// ============================================================
extension SafeSnackBar on BuildContext {
  void showSafeSnackBar(String message, {Color? color, int seconds = 3}) {
    if (!mounted) return;
    ScaffoldMessenger.of(this)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: seconds),
          content: Row(
            children: [
              if (color == Colors.red || color == dangerFgColor)
                const Icon(Icons.error_outline, color: onPrimaryColor, size: 20)
              else
                const Icon(
                  Icons.check_circle_outline,
                  color: onPrimaryColor,
                  size: 20,
                ),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}

enum DashboardPage {
  newProgram,
  devices,
  buyToken,
  history,
  coachFeedback,
  coachTools,
  help,
}

class _SidebarItem {
  const _SidebarItem({
    required this.page,
    required this.label,
    required this.icon,
  });

  final DashboardPage page;
  final String label;
  final IconData icon;
}

const List<_SidebarItem> _items = [
  _SidebarItem(
    page: DashboardPage.coachTools,
    label: 'ساخت برنامه دستی',
    icon: Icons.dashboard_customize_outlined,
  ),
  _SidebarItem(
    page: DashboardPage.newProgram,
    label: 'ساخت برنامه با هوش مصنوعی',
    icon: Icons.auto_awesome_outlined,
  ),
  _SidebarItem(
    page: DashboardPage.history,
    label: 'تاریخچه',
    icon: Icons.history_outlined,
  ),
  _SidebarItem(
    page: DashboardPage.buyToken,
    label: 'خرید توکن',
    icon: Icons.shopping_cart_outlined,
  ),
  _SidebarItem(
    page: DashboardPage.devices,
    label: 'دستگاه‌ها',
    icon: Icons.fitness_center_outlined,
  ),
  _SidebarItem(
    page: DashboardPage.coachFeedback,
    label: 'ثبت نظر',
    icon: Icons.feedback_outlined,
  ),
  _SidebarItem(
    page: DashboardPage.help,
    label: 'راهنما',
    icon: Icons.help_outlined,
  ),
];

// تعداد آیتم‌هایی که مستقیم توی نوار پایین موبایل نمایش داده می‌شن
const int _kPrimaryMobileNavCount = 3;

// ============================================================================
// وضعیت سراسری پروفایل / برند باشگاه
// ============================================================================

String? _profileImageUrl(Map<dynamic, dynamic> data) {
  const imageKeys = [
    'logo',
    'logo_url',
    'logoUrl',
    'brand_logo',
    'gym_logo',
    'profile_image',
    'profile_picture',
    'avatar',
    'image',
    'image_url',
    'photo',
    'picture',
  ];
  for (final key in imageKeys) {
    final imageUrl = _imageUrlFromValue(data[key]);
    if (imageUrl != null) return imageUrl;
  }

  for (final key in const ['data', 'result', 'gym_brand', 'brand']) {
    final value = data[key];
    if (value is Map) {
      final imageUrl = _profileImageUrl(value);
      if (imageUrl != null) return imageUrl;
    }
  }
  return null;
}

String? _imageUrlFromValue(dynamic value) {
  if (value is String) {
    final url = value.trim();
    return url.isEmpty || url == 'null' ? null : url;
  }

  if (value is Map) {
    for (final key in const [
      'url',
      'src',
      'file',
      'image',
      'original',
      'original_url',
      'absolute_url',
      'path',
    ]) {
      final imageUrl = _imageUrlFromValue(value[key]);
      if (imageUrl != null) return imageUrl;
    }
  }

  if (value is Iterable) {
    for (final item in value) {
      final imageUrl = _imageUrlFromValue(item);
      if (imageUrl != null) return imageUrl;
    }
  }

  return null;
}

String _cacheBustedImageUrl(String imageUrl, int version) {
  final resolvedUrl = ApiService.resolveMediaUrl(imageUrl);
  if (version == 0) return resolvedUrl;

  final uri = Uri.tryParse(resolvedUrl);
  if (uri == null) return resolvedUrl;

  return uri
      .replace(queryParameters: {...uri.queryParameters, 'v': '$version'})
      .toString();
}

class ProfileState extends ChangeNotifier {
  static final ProfileState _instance = ProfileState._internal();

  factory ProfileState() => _instance;

  ProfileState._internal();

  final ApiService _apiService = ApiService();

  String? gymName;
  String? phone;
  String? email;
  String? address;
  String? logoUrl;
  Uint8List? logoBytes;
  int _logoVersion = 0;
  int tokenBalance = 0;

  bool isLoaded = false;
  bool isLoading = false;
  Future<void>? _loadingFuture;

  int get logoVersion => _logoVersion;

  void _setLogoUrl(String? imageUrl, {bool clearCachedBytes = true}) {
    if (imageUrl == null) return;
    if (logoUrl != imageUrl) {
      _logoVersion = DateTime.now().microsecondsSinceEpoch;
    }
    logoUrl = imageUrl;
    if (clearCachedBytes) logoBytes = null;
  }

  // ===== Live Token Balance =====
  Timer? _tokenPollingTimer;
  bool _isPolling = false;
  bool _isTokenFetchInProgress = false;
  int _lastKnownTokenBalance = 0;
  DateTime? _lastTokenFetchAt;

  Future<void> loadAll({bool force = false}) async {
    if (isLoaded && !force) return;
    if (isLoading && _loadingFuture != null) return _loadingFuture;

    _loadingFuture = _loadAllInternal();
    return _loadingFuture;
  }

  Future<void> _loadAllInternal() async {
    isLoading = true;

    try {
      LoggerService.logProfile(
        action: 'LOAD_ALL',
        message: 'در حال دریافت پروفایل و برند باشگاه از سرور...',
      );

      final responses = await Future.wait<ApiResponse>([
        _apiService.get(
          endpoint: ServerEndpoints.userProfile,
          requiresAuth: true,
        ),
        _apiService.get(endpoint: ServerEndpoints.gymBrand, requiresAuth: true),
      ]);

      final profileResponse = responses[0];
      final brandResponse = responses[1];

      if (profileResponse.success && profileResponse.data is Map) {
        final data = profileResponse.data as Map<String, dynamic>;

        tokenBalance = (data['token_balance'] as num?)?.toInt() ?? tokenBalance;
        _lastKnownTokenBalance = tokenBalance;
        gymName = (data['gym_name'] as String?) ?? gymName;
        phone =
            (data['phone_number'] as String?) ??
            (data['phone'] as String?) ??
            phone;
        email = (data['email'] as String?) ?? email;
        address = (data['address'] as String?) ?? address;
        _setLogoUrl(_profileImageUrl(data));
      } else {
        LoggerService.logApiError(
          method: 'loadAll',
          url: ServerEndpoints.userProfile,
          error: profileResponse.error ?? 'خطای ناشناخته',
        );
      }

      if (brandResponse.success && brandResponse.data is Map) {
        final data = brandResponse.data as Map<String, dynamic>;

        gymName = (data['gym_name'] as String?) ?? gymName;
        phone = (data['phone'] as String?) ?? phone;
        email = (data['email'] as String?) ?? email;
        address = (data['address'] as String?) ?? address;
        _setLogoUrl(_profileImageUrl(data));
      }

      isLoaded = true;
      notifyListeners();
    } catch (e) {
      LoggerService.logApiError(
        method: 'loadAll',
        url: '${ServerEndpoints.userProfile} , ${ServerEndpoints.gymBrand}',
        error: e.toString(),
      );
    } finally {
      isLoading = false;
      _loadingFuture = null;
    }
  }

  // ===== Live Token Balance =====

  /// شروع Polling برای دریافت live موجودی توکن
  void startTokenPolling({Duration interval = const Duration(seconds: 30)}) {
    // اگر قبلاً شروع شده یا درخواست در حال اجراست، کاری نکن
    if (_isPolling) return;
    if (_tokenPollingTimer != null) return;

    LoggerService.logEvent(
      title: 'TOKEN_POLLING_STARTED',
      message: 'شروع Polling با فاصله ${interval.inSeconds} ثانیه',
    );

    _isPolling = true;
    _lastKnownTokenBalance = tokenBalance;

    // اولین درخواست فوری — اما فقط اگر به‌تازگی موجودی را نگرفته باشیم.
    // چون Polling با هر بار فوکوس‌گرفتن تب دوباره شروع می‌شود، بدون این
    // شرط، جابه‌جایی سریع بین تب‌ها یک رگبار درخواست می‌ساخت.
    final last = _lastTokenFetchAt;
    if (last == null || DateTime.now().difference(last) >= interval) {
      _fetchTokenBalance();
    }

    // سپس با تایمر
    _tokenPollingTimer = Timer.periodic(interval, (timer) {
      _fetchTokenBalance();
    });
  }

  /// توقف Polling
  void stopTokenPolling() {
    if (_tokenPollingTimer != null) {
      _tokenPollingTimer!.cancel();
      _tokenPollingTimer = null;
    }
    _isPolling = false;
    _isTokenFetchInProgress = false;

    LoggerService.logEvent(
      title: 'TOKEN_POLLING_STOPPED',
      message: 'Polling متوقف شد',
    );
  }

  /// دریافت فقط موجودی توکن از سرور
  Future<void> _fetchTokenBalance() async {
    // جلوگیری از درخواست‌های هم‌زمان
    if (_isTokenFetchInProgress) return;
    if (!_isPolling) return;

    _isTokenFetchInProgress = true;
    _lastTokenFetchAt = DateTime.now();

    try {
      final response = await _apiService.get(
        endpoint: ServerEndpoints.userProfile,
        requiresAuth: true,
      );

      if (!_isPolling) {
        _isTokenFetchInProgress = false;
        return;
      }

      if (response.success && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final newBalance = (data['token_balance'] as num?)?.toInt();

        if (newBalance != null && newBalance != _lastKnownTokenBalance) {
          // مقدار تغییر کرده - به‌روزرسانی
          tokenBalance = newBalance;
          _lastKnownTokenBalance = newBalance;
          notifyListeners();

          LoggerService.logEvent(
            title: 'TOKEN_UPDATED_LIVE',
            message: 'موجودی توکن به‌روزرسانی شد: $newBalance',
          );
        }
      } else {
        // خطا - مقدار قبلی حفظ می‌شود
        LoggerService.logApiError(
          method: '_fetchTokenBalance',
          url: ServerEndpoints.userProfile,
          error: response.error ?? 'خطا در دریافت موجودی توکن',
        );
      }
    } catch (e) {
      // خطا - مقدار قبلی حفظ می‌شود
      LoggerService.logApiError(
        method: '_fetchTokenBalance',
        url: ServerEndpoints.userProfile,
        error: e.toString(),
      );
    } finally {
      _isTokenFetchInProgress = false;
    }
  }

  /// بررسی اینکه آیا Polling فعال است
  bool get isPollingActive => _isPolling;

  Future<ApiResponse> saveBrand({
    required String gymName,
    String? phone,
    String? email,
    String? address,
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    // فیلدهای خالی هم فرستاده می‌شوند.
    //
    // پیش از این، فیلد خالی اصلاً در بدنه نمی‌آمد؛ یعنی کاربر می‌توانست
    // شماره‌ای را که اشتباه ثبت کرده پاک کند، دکمه ذخیره را بزند، پیام
    // موفقیت بگیرد و مقدار قدیمی همچنان روی سرور بماند.
    final fields = <String, String>{
      'gym_name': gymName,
      'phone': phone?.trim() ?? '',
      'email': email?.trim() ?? '',
      'address': address?.trim() ?? '',
    };

    late final ApiResponse response;

    if (imageBytes != null) {
      response = await _apiService.multipart(
        method: 'POST',
        endpoint: ServerEndpoints.gymBrand,
        fields: fields,
        fileFieldName: 'logo',
        fileBytes: imageBytes,
        fileName: imageFileName ?? 'logo.jpg',
        requiresAuth: true,
      );
    } else {
      response = await _apiService.post(
        endpoint: ServerEndpoints.gymBrand,
        body: fields,
        requiresAuth: true,
      );
    }

    if (response.success) {
      // پاسخ سرور مرجع است؛ مقدارهای محلی فقط تا رسیدن آن نگه‌داشته
      // می‌شوند. اگر سرور فیلدی را برنگرداند، همان چیزی می‌ماند که کاربر
      // فرستاده — نه مقدار قدیمیِ قبل از ویرایش.
      this.gymName = gymName;
      this.phone = phone?.trim() ?? '';
      this.email = email?.trim() ?? '';
      this.address = address?.trim() ?? '';
      if (imageBytes != null) {
        logoBytes = imageBytes;
        _logoVersion = DateTime.now().microsecondsSinceEpoch;
      }

      if (response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        this.gymName = (data['gym_name'] as String?) ?? this.gymName;
        this.phone = (data['phone'] as String?) ?? this.phone;
        this.email = (data['email'] as String?) ?? this.email;
        this.address = (data['address'] as String?) ?? this.address;
        _setLogoUrl(_profileImageUrl(data), clearCachedBytes: false);
      }

      final refreshedBrand = await _apiService.get(
        endpoint: ServerEndpoints.gymBrand,
        requiresAuth: true,
      );
      if (refreshedBrand.success && refreshedBrand.data is Map) {
        final data = refreshedBrand.data as Map<String, dynamic>;
        this.gymName = (data['gym_name'] as String?) ?? this.gymName;
        this.phone = (data['phone'] as String?) ?? this.phone;
        this.email = (data['email'] as String?) ?? this.email;
        this.address = (data['address'] as String?) ?? this.address;
        _setLogoUrl(_profileImageUrl(data));
      }

      // بعد از ذخیره برند، موجودی توکن را به‌روزرسانی کن
      _fetchTokenBalance();

      notifyListeners();
    }

    return response;
  }

  void clear() {
    // توقف Polling هنگام خروج
    stopTokenPolling();

    gymName = null;
    phone = null;
    email = null;
    address = null;
    logoUrl = null;
    logoBytes = null;
    _logoVersion = 0;
    tokenBalance = 0;
    _lastKnownTokenBalance = 0;
    isLoaded = false;
    isLoading = false;
    _loadingFuture = null;
    _isPolling = false;
    _isTokenFetchInProgress = false;
    _lastTokenFetchAt = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopTokenPolling();
    super.dispose();
  }
}

class Sidbar extends StatelessWidget {
  const Sidbar({
    super.key,
    required this.selectedPage,
    required this.onSelect,
    this.isDrawer = false,
  });

  final DashboardPage selectedPage;
  final ValueChanged<DashboardPage> onSelect;
  final bool isDrawer;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        if (isDrawer) const SizedBox(height: 2),
        // کلید تم بالای سایدبار: جایی که همیشه دیده می‌شود و زیر فهرست
        // صفحه‌ها گم نمی‌شود.

        Image.asset(
          'assets/logo.webp',
          width: isDrawer ? 150 : 200,
          cacheWidth: isDrawer ? 300 : 400,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 4),
        for (final item in _items) ...[
          _SidebarButton(
            item: item,
            isSelected: item.page == selectedPage,
            onTap: () => onSelect(item.page),
          ),
          const SizedBox(height: 4),
        ],
        const SizedBox(height: 20),
        const _GymBadge(),
      ],
    );

    if (isDrawer) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: SingleChildScrollView(child: content),
        ),
      );
    }

    return Container(
      width: 260,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(child: content),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _SidebarItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? primeColor.withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(
                item.icon,
                size: 24,
                color: isSelected ? primeColor : textPrimaryColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? primeColor : textPrimaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// مستطیل پایین سایدبار
// ============================================================================

class _GymBadge extends StatefulWidget {
  const _GymBadge();

  @override
  State<_GymBadge> createState() => _GymBadgeState();
}

class _GymBadgeState extends State<_GymBadge> {
  @override
  void initState() {
    super.initState();
    ProfileState().loadAll();
  }

  void _showGymDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: scrimColor,
      builder: (BuildContext context) {
        return const Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: _GymDialogContent(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showGymDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedBuilder(
          animation: ProfileState(),
          builder: (context, _) {
            final profile = ProfileState();
            final hasLogo =
                profile.logoBytes != null ||
                (profile.logoUrl != null && profile.logoUrl!.isNotEmpty);
            final displayName =
                (profile.gymName != null && profile.gymName!.isNotEmpty)
                ? profile.gymName!
                : 'باشگاه فیت';

            return Row(
              textDirection: TextDirection.rtl,
              children: [
                _ProfileAvatar(
                  imageBytes: profile.logoBytes,
                  imageUrl: hasLogo ? profile.logoUrl : null,
                  imageVersion: profile.logoVersion,
                  radius: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayName,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// نوار پایین موبایل - نسخه ریسپانسیو با آیتم‌های اصلی + شیت «بیشتر»
// ============================================================================

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.imageBytes,
    required this.imageUrl,
    required this.imageVersion,
    required this.radius,
    this.backgroundColor = borderStrongColor,
    this.fallbackColor = textMutedColor,
    this.fallbackSize = 22,
  });

  final Uint8List? imageBytes;
  final String? imageUrl;
  final int imageVersion;
  final double radius;
  final Color backgroundColor;
  final Color fallbackColor;
  final double fallbackSize;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    final size = radius * 2;
    final fallback = Icon(
      Icons.person_outline,
      color: fallbackColor,
      size: fallbackSize,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: imageBytes != null
          ? Image.memory(imageBytes!, fit: BoxFit.cover)
          : url.isEmpty
          ? Center(child: fallback)
          : Image.network(
              _cacheBustedImageUrl(url, imageVersion),
              key: ValueKey('$url:$imageVersion'),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(child: fallback),
            ),
    );
  }
}

class MobileBottomNav extends StatelessWidget {
  const MobileBottomNav({
    super.key,
    required this.selectedPage,
    required this.onSelect,
  });

  final DashboardPage selectedPage;
  final ValueChanged<DashboardPage> onSelect;

  List<_SidebarItem> get _primaryItems =>
      _items.take(_kPrimaryMobileNavCount).toList();

  List<_SidebarItem> get _moreItems =>
      _items.skip(_kPrimaryMobileNavCount).toList();

  bool get _isMoreSelected =>
      _moreItems.any((item) => item.page == selectedPage);

  void _showGymDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: scrimColor,
      builder: (BuildContext context) {
        return const Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: _GymDialogContent(),
        );
      },
    );
  }

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _MoreSheet(
          items: _moreItems,
          selectedPage: selectedPage,
          onSelect: (page) {
            Navigator.of(context).pop();
            onSelect(page);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final item in _primaryItems)
              _MobileNavItem(
                item: item,
                isSelected: item.page == selectedPage,
                onTap: () => onSelect(item.page),
              ),
            _MoreNavItem(
              isActive: _isMoreSelected,
              onTap: () => _showMoreSheet(context),
            ),
            _MobileProfileIcon(onTap: () => _showGymDialog(context)),
          ],
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  const _MobileNavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _SidebarItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? primeColor : textFaintColor;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? primeColor.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 22, color: color),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreNavItem extends StatelessWidget {
  const _MoreNavItem({required this.isActive, required this.onTap});

  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? primeColor : textFaintColor;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? primeColor.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.grid_view_rounded, size: 22, color: color),
              const SizedBox(height: 3),
              Text(
                'بیشتر',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileProfileIcon extends StatelessWidget {
  const _MobileProfileIcon({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: ProfileState(),
                builder: (context, _) {
                  final profile = ProfileState();
                  final hasLogo =
                      profile.logoBytes != null ||
                      (profile.logoUrl != null && profile.logoUrl!.isNotEmpty);
                  return _ProfileAvatar(
                    imageBytes: profile.logoBytes,
                    imageUrl: hasLogo ? profile.logoUrl : null,
                    imageVersion: profile.logoVersion,
                    radius: 13,
                    backgroundColor: backgroundColor,
                    fallbackColor: onPrimaryColor,
                    fallbackSize: 16,
                  );
                },
              ),
              const SizedBox(height: 3),
              Text(
                'پروفایل',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: textFaintColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// شیت «بیشتر» - نمایش بقیه‌ی آیتم‌ها به‌صورت گرید در موبایل
// ============================================================================

class _MoreSheet extends StatelessWidget {
  const _MoreSheet({
    required this.items,
    required this.selectedPage,
    required this.onSelect,
  });

  final List<_SidebarItem> items;
  final DashboardPage selectedPage;
  final ValueChanged<DashboardPage> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: borderStrongColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              textDirection: TextDirection.rtl,
              children: [
                Text(
                  'دسترسی سریع',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimaryColor,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = item.page == selectedPage;
                return _MoreSheetItem(
                  item: item,
                  isSelected: isSelected,
                  onTap: () => onSelect(item.page),
                );
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _MoreSheetItem extends StatelessWidget {
  const _MoreSheetItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _SidebarItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? primeColor.withValues(alpha: 0.10)
          : surfaceMutedColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                size: 26,
                color: isSelected ? primeColor : textPrimaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? primeColor : textPrimaryColor,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// DIALOG CONTENT - فرم ویرایش پروفایل با دکمه خروج
// ============================================================================

class _GymDialogContent extends StatefulWidget {
  const _GymDialogContent();

  @override
  State<_GymDialogContent> createState() => _GymDialogContentState();
}

class _GymDialogContentState extends State<_GymDialogContent>
    with SingleTickerProviderStateMixin {
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isLoading = false;
  bool _isLoggingOut = false;

  final TextEditingController _gymNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  final ProfileState _profileState = ProfileState();

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();

    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      LoggerService.logProfile(
        action: 'LOAD',
        message: 'در حال دریافت پروفایل کاربر...',
      );

      await _profileState.loadAll();

      if (!mounted) return;

      setState(() {
        _gymNameController.text = _profileState.gymName ?? '';
        _phoneController.text = _profileState.phone ?? '';
        _emailController.text = _profileState.email ?? '';
        _addressController.text = _profileState.address ?? '';
      });

      LoggerService.logProfile(
        action: 'LOAD_SUCCESS',
        message: 'پروفایل بارگذاری شد: ${_profileState.gymName}',
      );
    } catch (e) {
      LoggerService.logApiError(
        method: '_loadUserProfile',
        url: '${ServerEndpoints.userProfile} , ${ServerEndpoints.gymBrand}',
        error: e.toString(),
      );

      if (mounted) {
        context.showSafeSnackBar('خطا: $e', color: Colors.red);
      }
    }
  }

  /// اعتبارسنجی پیش از ارسال.
  ///
  /// سرور همین قواعد را دارد (`phone` حداکثر ۱۱ نویسه، `email` باید معتبر
  /// باشد)، اما اگر اجازه بدهیم درخواست برود و ۴۰۰ برگردد، کاربر یک پیام
  /// کلی می‌بیند و نمی‌داند کدام فیلد را درست کند.
  /// ارقام فارسی/عربی را به لاتین تبدیل می‌کند.
  ///
  /// کاربر فارسی‌زبان معمولاً شماره را با صفحه‌کلید فارسی می‌زند؛ بدون این
  /// تبدیل، هم اعتبارسنجی رد می‌کرد و هم شماره‌ای در دیتابیس می‌نشست که
  /// قابل جست‌وجو و تماس نبود.
  static String _toLatinDigits(String value) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final ch = String.fromCharCode(rune);
      final faIndex = fa.indexOf(ch);
      final arIndex = ar.indexOf(ch);
      if (faIndex >= 0) {
        buffer.write(faIndex);
      } else if (arIndex >= 0) {
        buffer.write(arIndex);
      } else {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  String? _validationError() {
    if (_gymNameController.text.trim().isEmpty) {
      return 'نام باشگاه الزامی است.';
    }

    final phone = _toLatinDigits(_phoneController.text.trim());
    if (phone.isNotEmpty) {
      if (!RegExp(r'^[0-9]{7,11}$').hasMatch(phone)) {
        return 'شماره تماس باید فقط رقم و حداکثر ۱۱ رقم باشد.';
      }
    }

    final email = _emailController.text.trim();
    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'ایمیل معتبر نیست.';
    }

    return null;
  }

  Future<void> _saveProfile() async {
    final gymName = _gymNameController.text.trim();

    final problem = _validationError();
    if (problem != null) {
      context.showSafeSnackBar(problem, color: dangerFgColor);
      return;
    }

    setState(() => _isLoading = true);

    try {
      LoggerService.logProfile(
        action: 'SAVE',
        message: 'در حال ذخیره‌سازی پروفایل: $gymName',
      );

      final response = await _profileState.saveBrand(
        gymName: gymName,
        phone: _toLatinDigits(_phoneController.text.trim()),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        imageBytes: _selectedImageBytes,
        imageFileName: _selectedImageName,
      );

      if (!mounted) return;

      if (response.success) {
        LoggerService.logProfile(
          action: 'SAVE_SUCCESS',
          message: 'پروفایل با موفقیت ذخیره شد',
        );

        // اسنک‌بار روی ScaffoldMessenger صفحه می‌نشیند (نه روی دیالوگ)،
        // پس بستن کارت بلافاصله بعدش پیام را از بین نمی‌برد.
        context.showSafeSnackBar(
          'پروفایل با موفقیت به‌روزرسانی شد',
          color: okFgColor,
        );
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.of(context).pop();
        return;
      } else {
        LoggerService.logApiError(
          method: '_saveProfile',
          url: ServerEndpoints.gymBrand,
          error: response.error ?? 'خطای ناشناخته',
        );

        context.showSafeSnackBar(
          response.error ?? 'خطا در ذخیره‌سازی',
          color: Colors.red,
        );
      }
    } catch (e) {
      LoggerService.logApiError(
        method: '_saveProfile',
        url: ServerEndpoints.gymBrand,
        error: e.toString(),
      );

      if (mounted) {
        context.showSafeSnackBar('خطا: $e', color: Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// خروج از حساب کاربری - نسخه اصلاح شده با نویگیشن صحیح
  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);

    try {
      LoggerService.logAuth(
        action: 'LOGOUT_STARTED',
        message: 'شروع فرآیند خروج از حساب کاربری...',
      );

      // 1) ارسال درخواست خروج به سرور
      final apiService = ApiService();
      final response = await apiService.post(
        endpoint: ServerEndpoints.authLogout,
        requiresAuth: true,
      );

      LoggerService.logAuth(
        action: 'LOGOUT_API',
        message: 'پاسخ سرور: success=${response.success}',
        isSuccess: response.success,
      );

      // 2) پاک کردن توکن از localStorage
      final authService = AuthTokenService();
      await authService.clearToken();
      LoggerService.logAuth(
        action: 'TOKEN_CLEARED',
        message: 'توکن از localStorage پاک شد',
      );

      // 3) ریست کردن ProfileState
      _profileState.clear();
      LoggerService.logAuth(
        action: 'PROFILE_RESET',
        message: 'ProfileState ریست شد',
      );

      // 4) نویگیشن
      //
      // ناوبر یک بار همین‌جا گرفته می‌شود، پیش از هر pop. اگر بعد از بستن
      // دیالوگ‌ها دوباره `Navigator.of(context)` صدا زده شود، آن context
      // دیگر در درخت نیست و خروج با خطا نیمه‌کاره می‌ماند.
      if (mounted) {
        final navigator = Navigator.of(context, rootNavigator: true);

        LoggerService.logAuth(
          action: 'NAVIGATION_START',
          message: 'شروع فرآیند نویگیشن به AuthChoicePage',
        );

        navigator.pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const AuthChoicePage()),
          (route) => false,
        );

        LoggerService.logAuth(
          action: 'NAVIGATION_SUCCESS',
          message: 'نویگیشن به AuthChoicePage با موفقیت انجام شد',
          isSuccess: true,
        );
      }
    } catch (e) {
      LoggerService.logApiError(
        method: 'logout',
        url: ServerEndpoints.authLogout,
        error: e.toString(),
      );

      if (mounted) {
        context.showSafeSnackBar('خطا در خروج: $e', color: Colors.red);
        setState(() => _isLoggingOut = false);
      }
    }
  }

  /// نمایش دیالوگ تایید خروج
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 40,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    textDirection: TextDirection.rtl,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: dangerBgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: dangerFgColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'خروج از حساب کاربری',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'آیا مطمئن هستید که می‌خواهید از حساب خود خارج شوید؟',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: textMutedColor,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'پس از خروج، برای ورود دوباره باید شماره و رمز خود را وارد کنید.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: textFaintColor,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: borderStrongColor),
                                ),
                              ),
                              child: Text(
                                'لغو',
                                style: TextStyle(
                                  color: textSecondaryColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoggingOut ? null : _logout,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: dangerFgColor,
                                foregroundColor: onPrimaryColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoggingOut
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              onPrimaryColor,
                                            ),
                                      ),
                                    )
                                  : const Text(
                                      'خروج',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _gymNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        final bytes = await image.readAsBytes();
        if (bytes.isEmpty) {
          if (mounted) {
            context.showSafeSnackBar(
              'فایل تصویر قابل خواندن نیست.',
              color: dangerFgColor,
            );
          }
          return;
        }
        if (mounted) {
          setState(() {
            _selectedImageBytes = bytes;
            _selectedImageName = _imageFileName(image.name);
          });
          LoggerService.logEvent(
            title: 'IMAGE_PICKED',
            message: 'تصویر انتخاب شد: ${image.name}',
          );
        }
      }
    } catch (e) {
      LoggerService.logApiError(
        method: '_pickImage',
        url: 'image_picker',
        error: e.toString(),
      );
      if (mounted) {
        context.showSafeSnackBar(
          'انتخاب تصویر ناموفق بود.',
          color: dangerFgColor,
        );
      }
    }
  }

  String _imageFileName(String value) {
    final fileName = value.trim();
    if (fileName.isEmpty || !fileName.contains('.')) return 'logo.jpg';
    return fileName;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(scale: _scaleAnimation, child: child),
        );
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          double maxWidth = 440;
          if (constraints.maxWidth < 600) {
            maxWidth = constraints.maxWidth * 0.92;
          } else if (constraints.maxWidth < 900) {
            maxWidth = constraints.maxWidth * 0.6;
          } else {
            maxWidth = 420;
          }

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: constraints.maxHeight * 0.9,
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 40,
                        offset: Offset(0, 12),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 36,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: TextDirection.rtl,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.of(context).pop(),
                            tooltip: 'بستن',
                            icon: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: textMutedColor,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: surfaceMutedColor,
                              padding: const EdgeInsets.all(6),
                              minimumSize: const Size(34, 34),
                            ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _profileState,
                          builder: (context, _) => _AvatarSection(
                            selectedImageBytes: _selectedImageBytes,
                            networkImageUrl: _profileState.logoUrl,
                            onImageTap: _pickImage,
                          ),
                        ),
                        const SizedBox(height: 28),
                        const _TokenCard(),
                        const SizedBox(height: 28),
                        _ModernTextField(
                          controller: _gymNameController,
                          label: 'نام باشگاه',
                          hint: 'نام باشگاه را وارد کنید',
                          icon: Icons.fitness_center_outlined,
                        ),
                        const SizedBox(height: 18),
                        _ModernTextField(
                          controller: _phoneController,
                          label: 'شماره تماس',
                          hint: 'شماره تماس',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          readOnly: true,
                        ),
                        const SizedBox(height: 18),
                        _ModernTextField(
                          controller: _emailController,
                          label: 'ایمیل',
                          hint: 'ایمیل باشگاه',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 18),
                        _ModernTextField(
                          controller: _addressController,
                          label: 'آدرس باشگاه',
                          hint: 'آدرس باشگاه را وارد کنید',
                          icon: Icons.location_on_outlined,
                        ),
                        const SizedBox(height: 28),

                        Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 52,
                                child: OutlinedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _showLogoutConfirmation,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: dangerBorderColor),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    backgroundColor: dangerBgColor,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.logout_outlined,
                                        color: dangerFgColor,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'خروج',
                                        style: TextStyle(
                                          color: dangerFgColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _saveProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primeColor,
                                    foregroundColor: onPrimaryColor,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  onPrimaryColor,
                                                ),
                                          ),
                                        )
                                      : const Text(
                                          'ذخیره',
                                          style: TextStyle(
                                            color: onPrimaryColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// کلاس‌های کمکی
class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.selectedImageBytes,
    required this.networkImageUrl,
    required this.onImageTap,
  });

  final Uint8List? selectedImageBytes;
  final String? networkImageUrl;
  final VoidCallback onImageTap;

  @override
  Widget build(BuildContext context) {
    Widget avatarChild;

    if (selectedImageBytes != null) {
      avatarChild = Image.memory(
        selectedImageBytes!,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
      );
    } else if (networkImageUrl != null && networkImageUrl!.isNotEmpty) {
      avatarChild = Image.network(
        ApiService.resolveMediaUrl(networkImageUrl!),
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.person_outline, size: 80, color: textFaintColor),
      );
    } else {
      avatarChild = Icon(Icons.person_outline, size: 80, color: textFaintColor);
    }

    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: surfaceMutedColor,
              boxShadow: [
                BoxShadow(
                  color: borderColor.withValues(alpha: 0.5),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ClipOval(child: avatarChild),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: onImageTap,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: primeColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    color: onPrimaryColor,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenCard extends StatefulWidget {
  const _TokenCard();

  @override
  State<_TokenCard> createState() => _TokenCardState();
}

class _TokenCardState extends State<_TokenCard> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // شروع Polling برای به‌روزرسانی live موجودی توکن
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ProfileState().startTokenPolling();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // توقف Polling هنگام خروج از صفحه
    ProfileState().stopTokenPolling();
    super.dispose();
  }

  /// وقتی تب مرورگر پنهان می‌شود، Polling متوقف و با بازگشت دوباره شروع
  /// می‌شود.
  ///
  /// بدون این، سایتی که در یک تب پس‌زمینه باز مانده هر ۳۰ ثانیه یک درخواست
  /// به سرور می‌زد و با هر پاسخ، درخت ویجت را دوباره می‌ساخت — بار بی‌فایده
  /// روی مرورگر کاربر و روی سرور.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;

    switch (state) {
      case AppLifecycleState.resumed:
        ProfileState().startTokenPolling();
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        ProfileState().stopTokenPolling();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ProfileState(),
      builder: (context, _) {
        final tokenCount = ProfileState().tokenBalance;

        return Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: infoBgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  textDirection: TextDirection.rtl,
                  children: [
                    Text(
                      'تعداد توکن باشگاه شما:',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: textMutedColor,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$tokenCount',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: primeColor,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Flexible(
                flex: 0,
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: Image.asset(
                    'assets/coin.webp',
                    cacheWidth: 96,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModernTextField extends StatefulWidget {
  const _ModernTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final bool readOnly;

  @override
  State<_ModernTextField> createState() => _ModernTextFieldState();
}

class _ModernTextFieldState extends State<_ModernTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: TextDirection.rtl,
      children: [
        Text(
          widget.label,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textPrimaryColor,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 50,
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isFocused ? primeColor : borderColor,
              width: _isFocused ? 2 : 1.5,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: primeColor.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 0),
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: surfaceMutedColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.icon,
                  color: _isFocused ? primeColor : textFaintColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  readOnly: widget.readOnly,
                  showCursor: !widget.readOnly,
                  enableInteractiveSelection: !widget.readOnly,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  keyboardType: widget.keyboardType,
                  style: TextStyle(
                    fontSize: 14,
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: textFaintColor,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ],
    );
  }
}
