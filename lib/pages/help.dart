import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../colors.dart';
import '../responsive.dart';

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
// صفحه اصلی Help
// ============================================================
class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final Set<int> _expandedIndexes = {};

  void _toggleAccordion(int index) {
    setState(() {
      if (_expandedIndexes.contains(index)) {
        _expandedIndexes.remove(index);
      } else {
        _expandedIndexes.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final deviceType = _resolveDeviceType(context);
    final isDesktop = deviceType == AppDeviceType.desktop;
    // حذف متغیرهای unused
    // final isTablet = deviceType == AppDeviceType.tablet;
    // final isMobile = deviceType == AppDeviceType.mobile;

    final sizes = _HelpSizes.of(deviceType);

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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Center(
              child: SizedBox(
                width: isDesktop ? 1100 : double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // عنوان صفحه
                    _buildTitle(sizes),

                    const SizedBox(height: 24),

                    // توضیحات
                    _buildDescription(sizes),

                    const SizedBox(height: 32),

                    // لیست Accordion‌ها
                    ...List.generate(_helpItems.length, (index) {
                      final item = _helpItems[index];
                      final isExpanded = _expandedIndexes.contains(index);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _HelpAccordion(
                          title: item.title,
                          content: item.content,
                          icon: item.icon,
                          isExpanded: isExpanded,
                          isContact: item.isContact,
                          onTap: () => _toggleAccordion(index),
                          sizes: sizes,
                        ),
                      );
                    }),

                    // فضای خالی پایین برای اسکرول بهتر
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Title
  // ============================================================
  Widget _buildTitle(_HelpSizes sizes) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: surfaceMutedColor,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          'راهنمای پنل مربی',
          style: TextStyle(
            fontSize: sizes.titleFontSize,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Description
  // ============================================================
  Widget _buildDescription(_HelpSizes sizes) {
    return Text(
      'این راهنما مسیرهای اصلی پنل مربی را به‌صورت کوتاه و کاربردی توضیح می‌دهد.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: sizes.descriptionFontSize,
        color: textSecondaryColor,
        height: 1.6,
      ),
    );
  }
}

// ============================================================
// مدل داده آیتم‌های راهنما
// ============================================================
class _HelpItem {
  final String title;
  final String content;
  final IconData icon;
  final bool isContact;

  const _HelpItem({
    required this.title,
    required this.content,
    required this.icon,
    this.isContact = false,
  });
}

// ============================================================
// لیست آیتم‌های راهنما
// ============================================================
final List<_HelpItem> _helpItems = [
  const _HelpItem(
    title: 'ساخت برنامه دستی',
    content: 'از بخش «ساخت برنامه جدید» ورزشکار را انتخاب کنید، تمرین‌ها را بچینید و در صورت نیاز برنامه غذایی، مکمل و دارو را اضافه کنید. در پایان، مدت اعتبار برنامه را مشخص کرده و خروجی PDF را بسازید.',
    icon: Icons.edit_note_rounded,
  ),
  const _HelpItem(
    title: 'داشبورد ساخت برنامه',
    content: 'از داشبورد به ساخت برنامه، پروفایل ورزشکارها، کتابخانه حرکات و تمپلیت‌ها دسترسی دارید. کارت «برنامه‌های تمام‌شده» نیز ورزشکارهایی را که نیاز به برنامه تازه دارند نمایش می‌دهد.',
    icon: Icons.dashboard_customize_outlined,
  ),
  const _HelpItem(
    title: 'ورزشکارها و سابقه برنامه',
    content: 'در بخش ورزشکارها اطلاعات فردی، هدف، آسیب‌دیدگی و حساسیت غذایی هر نفر را ویرایش کنید. برنامه‌های قبلی و فایل PDF آن‌ها نیز در همان پروفایل در دسترس است.',
    icon: Icons.groups_2_outlined,
  ),
  const _HelpItem(
    title: 'کتابخانه حرکات و تمپلیت‌ها',
    content: 'حرکت موردنظر را از کتابخانه جست‌وجو و به برنامه اضافه کنید. تمپلیت‌ها برای شروع سریع‌تر برنامه کاربرد دارند و می‌توانند محتوای فعلی را جایگزین کنند یا به ابتدا و انتهای آن اضافه شوند.',
    icon: Icons.fitness_center_rounded,
  ),
  const _HelpItem(
    title: 'دستگاه‌ها و دستورالعمل مربی',
    content: 'تجهیزات موجود در باشگاه را ثبت کنید تا در تولید برنامه مدنظر قرار بگیرند. در بخش «ثبت نظر مربی» نیز اصول، محدودیت‌ها و ترجیحات خود را برای برنامه‌ها وارد کنید.',
    icon: Icons.tune_outlined,
  ),
  const _HelpItem(
    title: 'توکن و تاریخچه',
    content: 'موجودی توکن را از بخش خرید توکن مدیریت کنید. برای مشاهده برنامه‌های تولیدشده خارج از بخش ورزشکارها نیز می‌توانید از تاریخچه استفاده کنید.',
    icon: Icons.history_outlined,
  ),
  const _HelpItem(
    title: 'ارتباط با ما',
    content: 'برای ارتباط با ما می‌توانید از راه‌های زیر با تیم چغر در تماس باشید:',
    icon: Icons.contact_support_outlined,
    isContact: true,
  ),
];

// ============================================================
// ویجت Accordion
// ============================================================
class _HelpAccordion extends StatelessWidget {
  const _HelpAccordion({
    required this.title,
    required this.content,
    required this.icon,
    required this.isExpanded,
    required this.isContact,
    required this.onTap,
    required this.sizes,
  });

  final String title;
  final String content;
  final IconData icon;
  final bool isExpanded;
  final bool isContact;
  final VoidCallback onTap;
  final _HelpSizes sizes;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              hoverColor: surfaceAltColor,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: sizes.accordionPaddingH,
                  vertical: sizes.accordionPaddingV,
                ),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Icon(
                      icon,
                      size: sizes.accordionIconSize,
                      color: primeColor,
                    ),
                    SizedBox(width: sizes.accordionIconSpacing),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: sizes.accordionTitleSize,
                          fontWeight: FontWeight.w600,
                          color: textPrimaryColor,
                          height: 1.3,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 150),
                      turns: isExpanded ? 0.5 : 0,
                      child: Icon(
                        Icons.keyboard_arrow_down_outlined,
                        color: textMutedColor,
                        size: sizes.accordionArrowSize,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 150),
            firstChild: Container(height: 0),
            secondChild: Padding(
              padding: EdgeInsets.fromLTRB(
                sizes.accordionPaddingH,
                0,
                sizes.accordionPaddingH,
                sizes.accordionPaddingH,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                textDirection: TextDirection.rtl,
                children: [
                  if (isContact) ...[
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: sizes.contactTextSize,
                        color: textSecondaryColor,
                        height: 1.7,
                      ),
                    ),
                    SizedBox(height: sizes.contactSpacing),
                    _ContactItem(
                      icon: Icons.phone_outlined,
                      label: '09925300536',
                      onCopy: () {
                        Clipboard.setData(const ClipboardData(text: '09925300536'));
                        context.showSafeSnackBar('شماره تماس کپی شد');
                      },
                      sizes: sizes,
                    ),
                    const SizedBox(height: 12),
                    _ContactItem(
                      icon: Icons.camera_alt,
                      label: 'chegher.web',
                      onCopy: () {
                        Clipboard.setData(const ClipboardData(text: 'chegher.web'));
                        context.showSafeSnackBar('آیدی اینستاگرام کپی شد');
                      },
                      sizes: sizes,
                    ),
                    const SizedBox(height: 12),
                    _ContactItem(
                      icon: Icons.email_outlined,
                      label: 'chegher.web@gmail.com',
                      onCopy: () {
                        Clipboard.setData(const ClipboardData(text: 'chegher.web@gmail.com'));
                        context.showSafeSnackBar('ایمیل کپی شد');
                      },
                      sizes: sizes,
                    ),
                  ] else ...[
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: sizes.contentTextSize,
                        color: textSecondaryColor,
                        height: 1.8,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ویجت آیتم تماس با قابلیت کپی (بدون لینک)
// ============================================================
class _ContactItem extends StatelessWidget {
  const _ContactItem({
    required this.icon,
    required this.label,
    required this.onCopy,
    required this.sizes,
  });

  final IconData icon;
  final String label;
  final VoidCallback onCopy;
  final _HelpSizes sizes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: sizes.contactItemPaddingV,
        horizontal: sizes.contactItemPaddingH,
      ),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(
            icon,
            size: sizes.contactIconSize,
            color: primeColor,
          ),
          SizedBox(width: sizes.contactIconSpacing),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: sizes.contactLabelSize,
                color: textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // دکمه کپی
          IconButton(
            onPressed: onCopy,
            icon: Icon(
              Icons.copy_outlined,
              size: sizes.contactCopySize,
              color: textFaintColor,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 20,
            tooltip: 'کپی',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// کلاس اندازه‌های ریسپانسیو
// ============================================================
class _HelpSizes {
  const _HelpSizes({
    required this.outerMargin,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.containerRadius,
    required this.titleFontSize,
    required this.descriptionFontSize,
    required this.accordionPaddingH,
    required this.accordionPaddingV,
    required this.accordionIconSize,
    required this.accordionIconSpacing,
    required this.accordionTitleSize,
    required this.accordionArrowSize,
    required this.contentTextSize,
    required this.contactTextSize,
    required this.contactSpacing,
    required this.contactItemPaddingV,
    required this.contactItemPaddingH,
    required this.contactIconSize,
    required this.contactIconSpacing,
    required this.contactLabelSize,
    required this.contactCopySize,
  });

  final double outerMargin;
  final double horizontalPadding;
  final double verticalPadding;
  final double containerRadius;
  final double titleFontSize;
  final double descriptionFontSize;

  final double accordionPaddingH;
  final double accordionPaddingV;
  final double accordionIconSize;
  final double accordionIconSpacing;
  final double accordionTitleSize;
  final double accordionArrowSize;

  final double contentTextSize;
  final double contactTextSize;
  final double contactSpacing;
  final double contactItemPaddingV;
  final double contactItemPaddingH;
  final double contactIconSize;
  final double contactIconSpacing;
  final double contactLabelSize;
  final double contactCopySize;

  factory _HelpSizes.of(AppDeviceType type) {
    switch (type) {
      case AppDeviceType.desktop:
        return const _HelpSizes(
          outerMargin: 24,
          horizontalPadding: 32,
          verticalPadding: 28,
          containerRadius: 24,
          titleFontSize: 26,
          descriptionFontSize: 18,
          accordionPaddingH: 20,
          accordionPaddingV: 18,
          accordionIconSize: 26,
          accordionIconSpacing: 16,
          accordionTitleSize: 17,
          accordionArrowSize: 28,
          contentTextSize: 16,
          contactTextSize: 16,
          contactSpacing: 20,
          contactItemPaddingV: 14,
          contactItemPaddingH: 16,
          contactIconSize: 22,
          contactIconSpacing: 16,
          contactLabelSize: 16,
          contactCopySize: 22,
        );
      case AppDeviceType.tablet:
        return const _HelpSizes(
          outerMargin: 20,
          horizontalPadding: 24,
          verticalPadding: 24,
          containerRadius: 20,
          titleFontSize: 22,
          descriptionFontSize: 16,
          accordionPaddingH: 16,
          accordionPaddingV: 15,
          accordionIconSize: 24,
          accordionIconSpacing: 14,
          accordionTitleSize: 16,
          accordionArrowSize: 26,
          contentTextSize: 15,
          contactTextSize: 15,
          contactSpacing: 18,
          contactItemPaddingV: 12,
          contactItemPaddingH: 14,
          contactIconSize: 20,
          contactIconSpacing: 14,
          contactLabelSize: 15,
          contactCopySize: 20,
        );
      case AppDeviceType.mobile:
        return const _HelpSizes(
          outerMargin: 12,
          horizontalPadding: 16,
          verticalPadding: 16,
          containerRadius: 16,
          titleFontSize: 18,
          descriptionFontSize: 14,
          accordionPaddingH: 16,
          accordionPaddingV: 14,
          accordionIconSize: 22,
          accordionIconSpacing: 12,
          accordionTitleSize: 15,
          accordionArrowSize: 24,
          contentTextSize: 14,
          contactTextSize: 14,
          contactSpacing: 16,
          contactItemPaddingV: 10,
          contactItemPaddingH: 12,
          contactIconSize: 20,
          contactIconSpacing: 12,
          contactLabelSize: 14,
          contactCopySize: 20,
        );
    }
  }
}
