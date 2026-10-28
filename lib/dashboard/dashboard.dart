import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../colors.dart';
import '../pages/buy_token.dart';
import '../pages/coments.dart';
import '../pages/dastgah.dart';
import '../pages/help.dart';
import '../pages/history.dart';
import '../pages/new_program.dart';
import '../coach_tools/pages/coach_tools_page.dart';
import '../responsive.dart';
import '../sidbar/sidbar.dart';

// ============================================================
// WELCOME DIALOG SERVICE
// ============================================================

class WelcomeDialogService {
  static const String _welcomeShownKey =
      'welcome_dialog_seen_v2';

  static Future<bool> hasWelcomeDialogShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_welcomeShownKey) ?? false;
    } catch (e) {
      print('❌ خطا در بررسی welcome dialog: $e');
      return false;
    }
  }

  static Future<void> markWelcomeDialogShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_welcomeShownKey, true);
      print('✅ دیالوگ خوش‌آمدی ذخیره شد');
    } catch (e) {
      print('❌ خطا در ذخیره welcome dialog: $e');
    }
  }

  static Future<void> clearWelcomeDialog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_welcomeShownKey);
      print('✅ دیالوگ خوش‌آمدی پاک شد');
    } catch (e) {
      print('❌ خطا در پاک کردن welcome dialog: $e');
    }
  }
}

// ============================================================
// DEVICE TYPE RESOLUTION
// ============================================================

AppDeviceType _resolveDeviceType(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < AppBreakpoints.mobile) return AppDeviceType.mobile;
  if (width < AppBreakpoints.tablet) return AppDeviceType.tablet;
  return AppDeviceType.desktop;
}

// ============================================================
// DASHBOARD MAIN WIDGET
// ============================================================

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  DashboardPage _selectedPage = DashboardPage.newProgram;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Map<DashboardPage, Widget> _pageCache = <DashboardPage, Widget>{};
  final Set<DashboardPage> _visitedPages = <DashboardPage>{
    DashboardPage.newProgram,
  };

  bool _isDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWelcomeDialog();
    });
  }

  void _showWelcomeDialog() async {
    if (_isDialogShown) return;
    _isDialogShown = true;

    final hasAlreadyShown = await WelcomeDialogService.hasWelcomeDialogShown();

    if (hasAlreadyShown) {
      print('✅ دیالوگ قبلاً برای این کاربر نشان داده شده، نمایش ندادن');
      return;
    }

    if (mounted) {
      showPremiumWelcomeDialog(
        context: context,
        onConfirm: () async {
          await WelcomeDialogService.markWelcomeDialogShown();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('به داشبورد خوش آمدید! حالا شروع کنید'),
                backgroundColor: primeColor,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
      );
    }
  }

  Widget _pageFor(DashboardPage page) {
    return _pageCache.putIfAbsent(page, () {
      switch (page) {
        case DashboardPage.newProgram:
          return const NewProgram();
        case DashboardPage.devices:
          return const GymDevices();
        case DashboardPage.buyToken:
          return const BuyToken();
        case DashboardPage.history:
          return const HistoryPrograms();
        case DashboardPage.coachFeedback:
          return const CoachInstructionsPage();
        case DashboardPage.coachTools:
          return const CoachToolsPage();
        case DashboardPage.help:
          return const HelpPage();
      }
    });
  }

  Widget _buildContent() {
    return RepaintBoundary(
      child: Stack(
        children: [
          for (final page in _visitedPages)
            Offstage(
              offstage: page != _selectedPage,
              child: TickerMode(
                enabled: page == _selectedPage,
                child: RepaintBoundary(child: _pageFor(page)),
              ),
            ),
        ],
      ),
    );
  }

  void _selectPage(DashboardPage page) {
    if (_selectedPage == page) return;
    setState(() {
      _visitedPages.add(page);
      _selectedPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    final deviceType = _resolveDeviceType(context);
    final bool isDesktop = deviceType == AppDeviceType.desktop;
    final bool isTablet = deviceType == AppDeviceType.tablet;
    final bool isMobile = deviceType == AppDeviceType.mobile;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: backgroundColor,
        drawer: isTablet
            ? Drawer(
                width: 300,
                backgroundColor: surfaceColor,
                child: Sidbar(
                  selectedPage: _selectedPage,
                  isDrawer: true,
                  onSelect: (page) {
                    _selectPage(page);
                    Navigator.of(context).pop();
                  },
                ),
              )
            : null,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              isDesktop
                  ? Row(
                      children: [
                        RepaintBoundary(
                          child: Sidbar(
                            selectedPage: _selectedPage,
                            onSelect: _selectPage,
                          ),
                        ),
                        Expanded(child: _buildContent()),
                      ],
                    )
                  : _buildContent(),
              if (isTablet)
                Positioned(
                  top: 16,
                  right: 16,
                  child: _TabletMenuButton(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: isMobile
            ? MobileBottomNav(
                selectedPage: _selectedPage,
                onSelect: _selectPage,
              )
            : null,
      ),
    );
  }
}

// ============================================================
// TABLET MENU BUTTON
// ============================================================

class _TabletMenuButton extends StatelessWidget {
  const _TabletMenuButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surfaceColor,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: textFaintColor,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(Icons.menu_rounded, size: 24, color: textPrimaryColor),
        ),
      ),
    );
  }
}

// ============================================================
// PLACEHOLDER PAGE
// ============================================================

class _PlaceholderPage extends StatefulWidget {
  const _PlaceholderPage({required this.title});

  final String title;

  @override
  State<_PlaceholderPage> createState() => _PlaceholderPageState();
}

class _PlaceholderPageState extends State<_PlaceholderPage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Text(
        '${widget.title} (به‌زودی)',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ============================================================
// PREMIUM WELCOME DIALOG
// ============================================================

class PremiumWelcomeDialog extends StatefulWidget {
  const PremiumWelcomeDialog({super.key, required this.onConfirm});

  final VoidCallback onConfirm;

  @override
  State<PremiumWelcomeDialog> createState() => _PremiumWelcomeDialogState();
}

class _PremiumWelcomeDialogState extends State<PremiumWelcomeDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final dialogWidth = isMobile
        ? MediaQuery.sizeOf(context).width * 0.92
        : 520.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            width: dialogWidth,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 50,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ===== HEADER GRADIENT =====
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 32,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primeColor,
                            primeColor.withValues(alpha: 0.85),
                          ],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(32),
                          topRight: Radius.circular(32),
                        ),
                      ),
                      child: Column(
                        children: [
                          // لوگو
                          Image.asset(
                            'assets/logo.webp',
                            height: 154,
                            width: 154,
                            cacheWidth: 308,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: surfaceColor.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.fitness_center_rounded,
                                  color: onPrimaryColor,
                                  size: 44,
                                ),
                              );
                            },
                          ),
                          const Text(
                            'به چغر خوش آمدید',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: onPrimaryColor,
                              letterSpacing: -0.8,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'همه‌چیز برای مدیریت ورزشکار و ساخت برنامه در یک پنل',
                            style: TextStyle(
                              fontSize: 14,
                              color: onPrimaryColor.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    // ===== CONTENT PADDING =====
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 28,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ===== SECTION 1: درباره چغر =====
                          _buildSectionTitle('شروع سریع'),
                          const SizedBox(height: 12),
                          _buildInfoBox(
                            icon: Icons.accessibility_new_outlined,
                            title: 'ساخت برنامه دستی',
                            description:
                                'در بخش «ساخت برنامه جدید» ورزشکار را انتخاب کنید و تمرین، تغذیه و مکمل‌ها را در یک برنامه کنار هم بسازید.',
                          ),
                          const SizedBox(height: 12),
                          _buildInfoBox(
                            icon: Icons.school,
                            title: 'مدیریت ورزشکارها',
                            description:
                                'پروفایل، سابقه برنامه‌ها و وضعیت هر ورزشکار را از داشبورد ساخت برنامه دنبال کنید.',
                          ),
                          const SizedBox(height: 12),
                          _buildInfoBox(
                            icon: Icons.edit,
                            title: 'حرکات و تمپلیت‌ها',
                            description:
                                'حرکت‌های آماده را از کتابخانه به برنامه اضافه کنید یا برای شروع سریع از تمپلیت‌ها استفاده کنید.',
                          ),

                          const SizedBox(height: 28),

                          // ===== SECTION 2: نکات مهم =====
                          _buildSectionTitle('نکته‌های کاربردی'),
                          const SizedBox(height: 12),
                          _buildWarningBox(
                            icon: Icons.warning_rounded,
                            title: 'برنامه‌های تمام‌شده',
                            description:
                                'داشبورد ساخت برنامه، ورزشکارانی را که برنامه‌شان تمام شده یادآوری می‌کند تا ادامه مسیرشان فراموش نشود.',
                            backgroundColor: infoBgColor,
                            borderColor: infoFgColor,
                            textColor: infoFgColor,
                          ),
                          const SizedBox(height: 12),
                          _buildWarningBox(
                            icon: Icons.favorite,
                            title: 'خروجی و سابقه',
                            description:
                                'بعد از ساخت، خروجی PDF آماده است و سابقه برنامه‌ها از بخش ورزشکارها در دسترس می‌ماند.',
                            backgroundColor: okBgColor,
                            borderColor: okFgColor,
                            textColor: okFgColor,
                          ),

                          const SizedBox(height: 28),

                          // ===== SECTION 3: کمک و پشتیبانی =====
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: infoBgColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: infoFgColor,
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: primeColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.help_outline,
                                    color: onPrimaryColor,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'سوال یا مشکلی دارید؟',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: primeColor,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'راهنمای هر بخش و راه ارتباط با ما در صفحه راهنما قرار دارد',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: textSecondaryColor,
                                          height: 1.5,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ===== ACTION BUTTONS =====
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    widget.onConfirm();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primeColor,
                                    foregroundColor: onPrimaryColor,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: const Text(
                                    'شروع کنیم',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: textPrimaryColor,
        letterSpacing: -0.3,
      ),
      textAlign: TextAlign.right,
    );
  }

  Widget _buildInfoBox({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: infoBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: infoFgColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textPrimaryColor,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondaryColor,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primeColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primeColor, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBox({
    required IconData icon,
    required String title,
    required String description,
    required Color backgroundColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: borderColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: textColor, size: 20),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SHOW DIALOG FUNCTION
// ============================================================

Future<void> showPremiumWelcomeDialog({
  required BuildContext context,
  required VoidCallback onConfirm,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: textPrimaryColor.withValues(alpha: 0.6),
    builder: (dialogContext) => PremiumWelcomeDialog(onConfirm: onConfirm),
  );
}
